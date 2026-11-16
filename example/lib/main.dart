import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:native_nearby_connections/native_nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

const _serviceId = 'com.maniak.native_nearby_connections.example';

void main() => runApp(const MyApp());

enum PeerState { found, connecting, connected }

class Peer {
  Peer(this.name, this.state);
  final String name;
  PeerState state;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Roles are exclusive: the discoverer sends connection requests, the
/// advertiser only accepts them, so both sides never request each other.
class _MyAppState extends State<MyApp> implements NearbyFlutterApi {
  final _nearby = NativeNearbyConnections();
  final _name = 'device-${DateTime.now().millisecondsSinceEpoch % 10000}';
  final _peers = <String, Peer>{};
  final _log = <String>[];
  bool _advertising = false;
  bool _discovering = false;

  Iterable<String> get _connectedIds => _peers.entries
      .where((e) => e.value.state == PeerState.connected)
      .map((e) => e.key);

  @override
  void initState() {
    super.initState();
    _nearby.setListener(this);
  }

  @override
  void dispose() {
    _nearby.setListener(null);
    _nearby.stopAdvertising();
    _nearby.stopDiscovery();
    _nearby.stopAllEndpoints();
    super.dispose();
  }

  /// Every state change goes through here; async results may land after dispose.
  void _update(VoidCallback change, [String? log]) {
    if (!mounted) return;
    setState(() {
      change();
      if (log != null) _log.insert(0, log);
    });
  }

  void _add(String line) => _update(() {}, line);

  /// Asks for Nearby's runtime permissions; ones that don't apply to the
  /// device's Android version are reported granted by permission_handler.
  Future<void> _requestPermissions() async {
    final statuses =
        await (Platform.isIOS
                // Local network prompts by itself on first Bonjour use; location
                // lets Nearby join a peer's Wi-Fi hotspot (see Runner.entitlements).
                ? [Permission.bluetooth, Permission.locationWhenInUse]
                : [
                    Permission.bluetoothScan,
                    Permission.bluetoothAdvertise,
                    Permission.bluetoothConnect,
                    Permission.nearbyWifiDevices,
                    Permission.location,
                  ])
            .request();
    final denied = [
      for (final e in statuses.entries)
        if (!e.value.isGranted) e.key,
    ];
    // Location is only declared up to Android 12, so it reads denied on 13+.
    if (denied.isNotEmpty) _add('Not granted: $denied');
  }

  /// Runs [action], logs the outcome and returns whether it succeeded.
  Future<bool> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      _add(label);
      return true;
    } on PlatformException catch (e) {
      _add('$label failed: ${e.message}');
      return false;
    }
  }

  Future<void> _advertise() async {
    await _requestPermissions();
    final ok = await _run(
      'Advertising',
      () => _nearby.startAdvertising(_name, _serviceId, NearbyStrategy.cluster),
    );
    _update(() => _advertising = ok);
  }

  Future<void> _discover() async {
    await _requestPermissions();
    final ok = await _run(
      'Discovering',
      () => _nearby.startDiscovery(_serviceId, NearbyStrategy.cluster),
    );
    _update(() => _discovering = ok);
  }

  Future<void> _stop() async {
    await _run('Stopped', () async {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    });
    _update(() {
      _advertising = _discovering = false;
      _peers.clear();
    });
  }

  Future<void> _request(String endpointId) async {
    final peer = _peers[endpointId];
    if (peer == null || peer.state != PeerState.found) return;
    _update(() => peer.state = PeerState.connecting);
    final ok = await _run(
      'Requested ${peer.name}',
      () => _nearby.requestConnection(_name, endpointId),
    );
    // Back to found so it can be retried (tap the tile).
    if (!ok) _update(() => peer.state = PeerState.found);
  }

  @override
  void onEndpointFound(EndpointInfo info) {
    final id = info.endpointId!;
    if (_peers.containsKey(id)) return; // Already found or connecting.
    _update(
      () => _peers[id] = Peer(info.name ?? id, PeerState.found),
      'Found ${info.name}',
    );
    _request(id);
  }

  @override
  void onEndpointLost(String endpointId) {
    final peer = _peers[endpointId];
    // Losing discovery of a peer we're connected or connecting to is harmless.
    if (peer == null || peer.state != PeerState.found) return;
    _update(() => _peers.remove(endpointId), 'Lost ${peer.name}');
  }

  @override
  void onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _update(
      () => _peers[endpointId] = Peer(
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
    final peer = _peers[endpointId];
    if (peer == null) return;
    if (statusCode != 0) {
      // Discoverer keeps the peer to retry; advertiser waits for a new request.
      _update(
        () => _discovering
            ? peer.state = PeerState.found
            : _peers.remove(endpointId),
        'Connection to ${peer.name} failed: status $statusCode',
      );
      return;
    }
    _update(
      () => peer.state = PeerState.connected,
      'Connected to ${peer.name}',
    );
    // Scanning slows transfers; tap Discover again to find more peers.
    if (_discovering) {
      _nearby.stopDiscovery();
      _update(() => _discovering = false, 'Stopped discovery');
    }
  }

  @override
  void onDisconnected(String endpointId) {
    final peer = _peers[endpointId];
    _update(
      () => _peers.remove(endpointId),
      'Disconnected ${peer?.name ?? endpointId}',
    );
  }

  @override
  void onPayloadReceived(String endpointId, PayloadMessage payload) {
    final bytes = payload.bytes;
    final from = _peers[endpointId]?.name ?? endpointId;
    _add(
      'From $from: ${bytes == null ? payload.filePath : utf8.decode(bytes)}',
    );
  }

  @override
  void onPayloadTransferUpdate(String endpointId, TransferUpdate update) {}

  @override
  Widget build(BuildContext context) {
    final idle = !_advertising && !_discovering;
    final connected = _connectedIds.toList();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Nearby: $_name')),
        body: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: idle ? _advertise : null,
                  child: Text(_advertising ? 'Advertising…' : 'Advertise'),
                ),
                ElevatedButton(
                  onPressed: idle ? _discover : null,
                  child: Text(_discovering ? 'Discovering…' : 'Discover'),
                ),
                ElevatedButton(
                  onPressed: connected.isEmpty
                      ? null
                      : () => _run(
                          'Sent hello',
                          () => _nearby.sendBytes(
                            connected,
                            utf8.encode('hello from $_name'),
                          ),
                        ),
                  child: const Text('Send hello'),
                ),
                ElevatedButton(onPressed: _stop, child: const Text('Stop')),
              ],
            ),
            for (final MapEntry(key: id, value: peer) in _peers.entries)
              ListTile(
                title: Text(peer.name),
                subtitle: Text(peer.state.name),
                trailing: peer.state == PeerState.connecting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: peer.state == PeerState.found
                    ? () => _request(id)
                    : null,
              ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [for (final l in _log) ListTile(title: Text(l))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
