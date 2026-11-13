import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_nearby_connections/native_nearby_connections.dart';

// Runtime permissions (Bluetooth / Nearby Wi-Fi / location) must be granted
// before advertising or discovering; this demo assumes they already are.
const _serviceId = 'com.maniak.native_nearby_connections.example';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> implements NearbyFlutterApi {
  final _nearby = NativeNearbyConnections();
  final _name = 'device-${DateTime.now().millisecondsSinceEpoch % 10000}';
  final _connected = <String>{};
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    _nearby.setListener(this);
  }

  @override
  void dispose() {
    _nearby.setListener(null);
    _nearby.stopAllEndpoints();
    super.dispose();
  }

  void _add(String line) => setState(() => _log.insert(0, line));

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      _add(label);
    } on PlatformException catch (e) {
      _add('$label failed: ${e.message}');
    }
  }

  @override
  void onEndpointFound(EndpointInfo info) {
    _add('Found ${info.name} (${info.endpointId})');
    _run(
      'Requested ${info.endpointId}',
      () => _nearby.requestConnection(_name, info.endpointId!),
    );
  }

  @override
  void onEndpointLost(String endpointId) => _add('Lost $endpointId');

  @override
  void onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _add('Initiated with ${info.endpointName}, code ${info.authDigits}');
    _run('Accepted $endpointId', () => _nearby.acceptConnection(endpointId));
  }

  @override
  void onConnectionResult(String endpointId, int statusCode) {
    if (statusCode == 0) setState(() => _connected.add(endpointId));
    _add('Connection $endpointId: status $statusCode');
  }

  @override
  void onDisconnected(String endpointId) {
    setState(() => _connected.remove(endpointId));
    _add('Disconnected $endpointId');
  }

  @override
  void onPayloadReceived(String endpointId, PayloadMessage payload) {
    final bytes = payload.bytes;
    _add(
      'From $endpointId: ${bytes == null ? payload.filePath : utf8.decode(bytes)}',
    );
  }

  @override
  void onPayloadTransferUpdate(String endpointId, TransferUpdate update) {}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Nearby: $_name')),
        body: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _run(
                    'Advertising',
                    () => _nearby.startAdvertising(
                      _name,
                      _serviceId,
                      NearbyStrategy.cluster,
                    ),
                  ),
                  child: const Text('Advertise'),
                ),
                ElevatedButton(
                  onPressed: () => _run(
                    'Discovering',
                    () => _nearby.startDiscovery(
                      _serviceId,
                      NearbyStrategy.cluster,
                    ),
                  ),
                  child: const Text('Discover'),
                ),
                ElevatedButton(
                  onPressed: _connected.isEmpty
                      ? null
                      : () => _run(
                          'Sent hello',
                          () => _nearby.sendBytes(
                            _connected.toList(),
                            utf8.encode('hello from $_name'),
                          ),
                        ),
                  child: const Text('Send hello'),
                ),
                ElevatedButton(
                  onPressed: () => _run('Stopped', () async {
                    await _nearby.stopAdvertising();
                    await _nearby.stopDiscovery();
                    await _nearby.stopAllEndpoints();
                    setState(_connected.clear);
                  }),
                  child: const Text('Stop'),
                ),
              ],
            ),
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
