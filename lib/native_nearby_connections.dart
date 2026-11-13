import 'dart:typed_data';

import 'native_nearby_connections_platform_interface.dart';
import 'src/messages.g.dart';

export 'src/messages.g.dart'
    show
        NearbyStrategy,
        EndpointInfo,
        ConnectionInfo,
        PayloadMessage,
        TransferUpdate,
        NearbyFlutterApi;

/// Google Nearby Connections for Flutter.
///
/// Implement [NearbyFlutterApi] and pass it to [setListener] to receive
/// discovery, connection and payload events.
class NativeNearbyConnections {
  NativeNearbyConnectionsPlatform get _p =>
      NativeNearbyConnectionsPlatform.instance;

  void setListener(NearbyFlutterApi? listener) => _p.setListener(listener);

  Future<void> startAdvertising(
    String name,
    String serviceId,
    NearbyStrategy strategy,
  ) => _p.startAdvertising(name, serviceId, strategy);

  Future<void> startDiscovery(String serviceId, NearbyStrategy strategy) =>
      _p.startDiscovery(serviceId, strategy);

  Future<void> requestConnection(String name, String endpointId) =>
      _p.requestConnection(name, endpointId);

  Future<void> acceptConnection(String endpointId) =>
      _p.acceptConnection(endpointId);

  Future<void> rejectConnection(String endpointId) =>
      _p.rejectConnection(endpointId);

  /// Returns the payload id, matching [TransferUpdate.payloadId].
  Future<int> sendBytes(List<String> endpointIds, Uint8List bytes) =>
      _p.sendBytes(endpointIds, bytes);

  /// Returns the payload id, matching [TransferUpdate.payloadId].
  Future<int> sendFile(List<String> endpointIds, String path) =>
      _p.sendFile(endpointIds, path);

  Future<void> cancelPayload(int payloadId) => _p.cancelPayload(payloadId);

  Future<void> stopAdvertising() => _p.stopAdvertising();

  Future<void> stopDiscovery() => _p.stopDiscovery();

  Future<void> disconnect(String endpointId) => _p.disconnect(endpointId);

  Future<void> stopAllEndpoints() => _p.stopAllEndpoints();
}
