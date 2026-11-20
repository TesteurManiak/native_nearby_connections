import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:native_nearby_connections/native_nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

const _serviceId = 'com.maniak.native_nearby_connections.example';

enum PeerState { found, connecting, connected }

class Peer(final String name, var PeerState state);

/// Owns the Nearby session and its state; the UI listens for changes.
///
/// Roles are exclusive: the discoverer sends connection requests, the
/// advertiser only accepts them, so both sides never request each other.
class ConnectionManager extends ChangeNotifier implements NearbyFlutterApi {
  ConnectionManager() {
    _nearby.setListener(this);
  }

  final _nearby = NativeNearbyConnections();
  final name = 'device-${DateTime.now().millisecondsSinceEpoch % 10000}';
  final peers = <String, Peer>{};
  final logLines = <String>[];

  bool advertising = false;
  bool startingAdvertising = false;
  bool discovering = false;
  bool _disposed = false;

  Iterable<String> get connectedIds => peers.entries
      .where((e) => e.value.state == PeerState.connected)
      .map((e) => e.key);

  @override
  void dispose() {
    _disposed = true;
    _nearby.setListener(null);
    _nearby.stopAdvertising();
    _nearby.stopDiscovery();
    _nearby.stopAllEndpoints();
    super.dispose();
  }

  /// Every state change goes through here; async results may land after dispose.
  void _update(VoidCallback change, [String? line]) {
    if (_disposed) return;
    change();
    if (line != null) logLines.insert(0, line);
    notifyListeners();
  }

  void _add(String line) => _update(() {}, line);

  void clearLog() => _update(logLines.clear);

  /// Asks for Nearby's runtime permissions and logs any not granted.
  Future<void> _requestPermissions() async {
    final statuses = Platform.isIOS
        ? await _requestIosPermissions()
        : await _requestAndroidPermissions();
    final denied = [
      for (final e in statuses.entries)
        if (!e.value.isGranted) e.key,
    ];
    if (denied.isNotEmpty) _add('Not granted: $denied');
  }

  /// Local network prompts by itself on first Bonjour use; location lets
  /// Nearby join a peer's Wi-Fi hotspot (see Runner.entitlements).
  Future<Map<Permission, PermissionStatus>> _requestIosPermissions() =>
      [Permission.bluetooth, Permission.locationWhenInUse].request();

  /// Ones that don't apply to the device's Android version are reported
  /// granted by permission_handler. Location is only declared up to
  /// Android 12, so it reads denied on 13+.
  Future<Map<Permission, PermissionStatus>> _requestAndroidPermissions() => [
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.nearbyWifiDevices,
    Permission.location,
  ].request();

  /// Runs [action], logs the outcome and returns whether it succeeded.
  Future<bool> _run(String label, FutureOr<void> Function() action) async {
    try {
      await action();
      _add(label);
      return true;
    } on PlatformException catch (e, s) {
      _add('$label failed: ${e.message}');
      log('Failed', error: e, stackTrace: s, name: '_run($label)');
      return false;
    }
  }

  Future<void> advertise() async {
    _update(() => startingAdvertising = true);
    await _requestPermissions();
    final ok = await _run(
      'Advertising',
      () => _nearby.startAdvertising(name, _serviceId, NearbyStrategy.cluster),
    );
    _update(() {
      advertising = ok;
      startingAdvertising = false;
    });
  }

  Future<void> discover() async {
    await _requestPermissions();
    final ok = await _run(
      'Discovering',
      () => _nearby.startDiscovery(_serviceId, NearbyStrategy.cluster),
    );
    _update(() => discovering = ok);
  }

  Future<void> stop() async {
    await _run('Stopped', () {
      _nearby.stopAdvertising();
      _nearby.stopDiscovery();
      _nearby.stopAllEndpoints();
    });
    _update(() {
      advertising = discovering = false;
      peers.clear();
    });
  }

  Future<void> sendHello() => _run(
    'Sent hello',
    () => _nearby.sendBytes(
      connectedIds.toList(),
      utf8.encode('hello from $name'),
    ),
  );

  Future<void> request(String endpointId) async {
    final peer = peers[endpointId];
    if (peer == null || peer.state != PeerState.found) return;
    _update(() => peer.state = PeerState.connecting);
    final ok = await _run(
      'Requested ${peer.name}',
      () => _nearby.requestConnection(name, endpointId),
    );
    // Back to found so it can be retried (tap the tile).
    if (!ok) _update(() => peer.state = PeerState.found);
  }

  @override
  void onEndpointFound(EndpointInfo info) {
    final id = info.endpointId!;
    if (peers.containsKey(id)) return; // Already found or connecting.
    _update(
      () => peers[id] = Peer(info.name ?? id, PeerState.found),
      'Found ${info.name}',
    );
    request(id);
  }

  @override
  void onEndpointLost(String endpointId) {
    final peer = peers[endpointId];
    // Losing discovery of a peer we're connected or connecting to is harmless.
    if (peer == null || peer.state != PeerState.found) return;
    _update(() => peers.remove(endpointId), 'Lost ${peer.name}');
  }

  @override
  void onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _update(
      () => peers[endpointId] = Peer(
        info.endpointName ?? endpointId,
        PeerState.connecting,
      ),
      'Initiated with ${info.endpointName}, code ${info.authDigits}',
    );
    _run(
      'Accepted ${info.endpointName}',
      () => _nearby.acceptConnection(endpointId),
    );
  }

  @override
  void onConnectionResult(String endpointId, int statusCode) {
    final peer = peers[endpointId];
    if (peer == null) return;
    if (statusCode != 0) {
      // Discoverer keeps the peer to retry; advertiser waits for a new request.
      _update(
        () => discovering
            ? peer.state = PeerState.found
            : peers.remove(endpointId),
        'Connection to ${peer.name} failed: status $statusCode',
      );
      return;
    }
    _update(
      () => peer.state = PeerState.connected,
      'Connected to ${peer.name}',
    );
    // Scanning slows transfers; tap Discover again to find more peers.
    if (discovering) {
      _nearby.stopDiscovery();
      _update(() => discovering = false, 'Stopped discovery');
    }
  }

  @override
  void onDisconnected(String endpointId) {
    final peer = peers[endpointId];
    _update(
      () => peers.remove(endpointId),
      'Disconnected ${peer?.name ?? endpointId}',
    );
  }

  @override
  void onPayloadReceived(String endpointId, PayloadMessage payload) {
    final bytes = payload.bytes;
    final from = peers[endpointId]?.name ?? endpointId;
    _add(
      'From $from: ${bytes == null ? payload.filePath : utf8.decode(bytes)}',
    );
  }

  @override
  void onPayloadTransferUpdate(String endpointId, TransferUpdate update) {}
}
