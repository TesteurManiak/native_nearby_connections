import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_nearby_connections/native_nearby_connections.dart';
import 'package:native_nearby_connections/native_nearby_connections_pigeon.dart';
import 'package:native_nearby_connections/native_nearby_connections_platform_interface.dart';
import 'package:native_nearby_connections/src/gen/messages.g.dart';

const _prefix = 'dev.flutter.pigeon.native_nearby_connections';

class _Listener extends Fake implements NearbyFlutterApi {
  final found = <EndpointInfo>[];
  @override
  void onEndpointFound(EndpointInfo info) => found.add(info);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = NearbyHostApi.pigeonChannelCodec;

  test('Pigeon implementation is the default instance', () {
    expect(
      NativeNearbyConnectionsPlatform.instance,
      isA<PigeonNativeNearbyConnections>(),
    );
  });

  test('sendBytes sends args to host and returns payload id', () async {
    late List<Object?> sent;
    messenger.setMockMessageHandler('$_prefix.NearbyHostApi.sendBytes', (
      data,
    ) async {
      sent = codec.decodeMessage(data)! as List<Object?>;
      return codec.encodeMessage(<Object?>[42]);
    });
    addTearDown(
      () => messenger.setMockMessageHandler(
        '$_prefix.NearbyHostApi.sendBytes',
        null,
      ),
    );

    final id = await NativeNearbyConnections().sendBytes([
      'ep1',
    ], Uint8List.fromList([1, 2]));

    expect(id, 42);
    expect(sent[0], ['ep1']);
    expect(sent[1], Uint8List.fromList([1, 2]));
  });

  test('host error surfaces as PlatformException', () async {
    const channel = '$_prefix.NearbyHostApi.startDiscovery';
    messenger.setMockMessageHandler(
      channel,
      (_) async => codec.encodeMessage(<Object?>['ApiException', '8002', null]),
    );
    addTearDown(() => messenger.setMockMessageHandler(channel, null));

    expect(
      NativeNearbyConnections().startDiscovery('svc', NearbyStrategy.star),
      throwsA(isA<PlatformException>()),
    );
  });

  test('native events reach the listener', () async {
    final listener = _Listener();
    final plugin = NativeNearbyConnections()..setListener(listener);
    addTearDown(() => plugin.setListener(null));

    await messenger.handlePlatformMessage(
      '$_prefix.NearbyFlutterApi.onEndpointFound',
      codec.encodeMessage(<Object?>[
        EndpointInfo(endpointId: 'ep1', name: 'Bob', serviceId: 'svc'),
      ]),
      (_) {},
    );

    expect(listener.found.single.endpointId, 'ep1');
    expect(listener.found.single.name, 'Bob');
  });
}
