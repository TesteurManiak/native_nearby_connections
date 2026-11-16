import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_nearby_connections_pigeon.dart';
import 'src/gen/messages.g.dart';

abstract class NativeNearbyConnectionsPlatform extends PlatformInterface {
  /// Constructs a NativeNearbyConnectionsPlatform.
  NativeNearbyConnectionsPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeNearbyConnectionsPlatform _instance =
      PigeonNativeNearbyConnections();

  /// The default instance of [NativeNearbyConnectionsPlatform] to use.
  ///
  /// Defaults to [PigeonNativeNearbyConnections].
  static NativeNearbyConnectionsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NativeNearbyConnectionsPlatform] when
  /// they register themselves.
  static set instance(NativeNearbyConnectionsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Registers the receiver of native Nearby events; `null` unregisters.
  void setListener(NearbyFlutterApi? listener) =>
      throw UnimplementedError('setListener() has not been implemented.');

  Future<void> startAdvertising(
    String name,
    String serviceId,
    NearbyStrategy strategy,
  ) => throw UnimplementedError('startAdvertising() has not been implemented.');

  Future<void> startDiscovery(String serviceId, NearbyStrategy strategy) =>
      throw UnimplementedError('startDiscovery() has not been implemented.');

  Future<void> requestConnection(String name, String endpointId) =>
      throw UnimplementedError('requestConnection() has not been implemented.');

  Future<void> acceptConnection(String endpointId) =>
      throw UnimplementedError('acceptConnection() has not been implemented.');

  Future<void> rejectConnection(String endpointId) =>
      throw UnimplementedError('rejectConnection() has not been implemented.');

  /// Returns the payload id.
  Future<int> sendBytes(List<String> endpointIds, Uint8List bytes) =>
      throw UnimplementedError('sendBytes() has not been implemented.');

  /// Returns the payload id.
  Future<int> sendFile(List<String> endpointIds, String path) =>
      throw UnimplementedError('sendFile() has not been implemented.');

  Future<void> cancelPayload(int payloadId) =>
      throw UnimplementedError('cancelPayload() has not been implemented.');

  Future<void> stopAdvertising() =>
      throw UnimplementedError('stopAdvertising() has not been implemented.');

  Future<void> stopDiscovery() =>
      throw UnimplementedError('stopDiscovery() has not been implemented.');

  Future<void> disconnect(String endpointId) =>
      throw UnimplementedError('disconnect() has not been implemented.');

  Future<void> stopAllEndpoints() =>
      throw UnimplementedError('stopAllEndpoints() has not been implemented.');
}
