import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:native_nearby_connections/src/gen/messages.g.dart';
import 'package:native_nearby_connections/src/native_nearby_connections_pigeon.dart';
import 'package:native_nearby_connections/src/native_nearby_connections_platform_interface.dart';

class _FakeHost extends Fake implements NearbyHostApiForNativeInterop {
  List<Object?>? sent;
  Object? error;

  @override
  Future<int> sendBytes(List<String> endpointIds, Uint8List bytes) async {
    sent = [endpointIds, bytes];
    return 42;
  }

  @override
  Future<void> startDiscovery(String serviceId, NearbyStrategy strategy) async {
    if (error != null) throw error!;
  }
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
    final plugin = PigeonNativeNearbyConnections(
      hostApi: NearbyHostApi(nativeInteropApi: host),
    );

    final id = await plugin.sendBytes(['ep1'], Uint8List.fromList([1, 2]));

    expect(id, 42);
    expect(host.sent, [
      ['ep1'],
      Uint8List.fromList([1, 2]),
    ]);
  });

  test('host error propagates', () async {
    final host = _FakeHost()..error = StateError('8002');
    final plugin = PigeonNativeNearbyConnections(
      hostApi: NearbyHostApi(nativeInteropApi: host),
    );

    expect(
      plugin.startDiscovery('svc', NearbyStrategy.star),
      throwsA(isA<StateError>()),
    );
  });
}
