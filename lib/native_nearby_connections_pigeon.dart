import 'package:flutter/foundation.dart';

import 'native_nearby_connections_platform_interface.dart';
import 'src/gen/messages.g.dart';

/// An implementation of [NativeNearbyConnectionsPlatform] backed by Pigeon.
class PigeonNativeNearbyConnections extends NativeNearbyConnectionsPlatform {
  PigeonNativeNearbyConnections({@visibleForTesting NearbyHostApi? hostApi})
    : _api = hostApi ?? NearbyHostApi();

  final NearbyHostApi _api;

  @override
  void setListener(NearbyFlutterApi? listener) =>
      NearbyFlutterApi.setUp(listener);

  @override
  Future<void> startAdvertising(
    String name,
    String serviceId,
    NearbyStrategy strategy,
  ) => _api.startAdvertising(name, serviceId, strategy);

  @override
  Future<void> startDiscovery(String serviceId, NearbyStrategy strategy) =>
      _api.startDiscovery(serviceId, strategy);

  @override
  Future<void> requestConnection(String name, String endpointId) =>
      _api.requestConnection(name, endpointId);

  @override
  Future<void> acceptConnection(String endpointId) =>
      _api.acceptConnection(endpointId);

  @override
  Future<void> rejectConnection(String endpointId) =>
      _api.rejectConnection(endpointId);

  @override
  Future<int> sendBytes(List<String> endpointIds, Uint8List bytes) =>
      _api.sendBytes(endpointIds, bytes);

  @override
  Future<int> sendFile(List<String> endpointIds, String path) =>
      _api.sendFile(endpointIds, path);

  @override
  Future<void> cancelPayload(int payloadId) => _api.cancelPayload(payloadId);

  @override
  Future<void> stopAdvertising() => _api.stopAdvertising();

  @override
  Future<void> stopDiscovery() => _api.stopDiscovery();

  @override
  Future<void> disconnect(String endpointId) => _api.disconnect(endpointId);

  @override
  Future<void> stopAllEndpoints() => _api.stopAllEndpoints();
}
