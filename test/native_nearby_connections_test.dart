import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_nearby_connections/src/gen/messages.g.dart';
import 'package:native_nearby_connections/src/native_nearby_connections_pigeon.dart';
import 'package:native_nearby_connections/src/native_nearby_connections_platform_interface.dart';

class _FakeHost extends Fake implements NearbyHostApiForNativeInterop {
  List<Object?>? sent;
  Object? error;
  final syncCalls = <String>[];

  @override
  Future<int> sendBytes(List<String> endpointIds, Uint8List bytes) async {
    sent = [endpointIds, bytes];
    return 42;
  }

  @override
  Future<void> startDiscovery(String serviceId, NearbyStrategy strategy) async {
    if (error != null) throw error!;
  }

  @override
  void cancelPayload(int payloadId) =>
      syncCalls.add('cancelPayload:$payloadId');

  @override
  void stopAdvertising() => syncCalls.add('stopAdvertising');

  @override
  void stopDiscovery() => syncCalls.add('stopDiscovery');

  @override
  void disconnect(String endpointId) => syncCalls.add('disconnect:$endpointId');

  @override
  void stopAllEndpoints() => syncCalls.add('stopAllEndpoints');
}

void main() {
  test('Pigeon implementation is the default instance', () {
    expect(
      NativeNearbyConnectionsPlatform.instance,
      isA<PigeonNativeNearbyConnections>(),
    );
  });

  test('sendBytes sends args to host and returns payload id', () async {
    final host = _FakeHost();
    final plugin = PigeonNativeNearbyConnections(hostApi: host);

    final id = await plugin.sendBytes(['ep1'], Uint8List.fromList([1, 2]));

    expect(id, 42);
    expect(host.sent, [
      ['ep1'],
      Uint8List.fromList([1, 2]),
    ]);
  });

  test('host error propagates', () async {
    final host = _FakeHost()..error = StateError('8002');
    final plugin = PigeonNativeNearbyConnections(hostApi: host);

    expect(
      plugin.startDiscovery('svc', NearbyStrategy.star),
      throwsA(isA<StateError>()),
    );
  });

  test('synchronous operations call the host immediately', () {
    final host = _FakeHost();
    final plugin = PigeonNativeNearbyConnections(hostApi: host);

    plugin.cancelPayload(12);
    plugin.stopAdvertising();
    plugin.stopDiscovery();
    plugin.disconnect('ep1');
    plugin.stopAllEndpoints();

    expect(host.syncCalls, [
      'cancelPayload:12',
      'stopAdvertising',
      'stopDiscovery',
      'disconnect:ep1',
      'stopAllEndpoints',
    ]);
  });
}
