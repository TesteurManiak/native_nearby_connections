import 'dart:typed_data';

import 'src/native_nearby_connections_platform_interface.dart';
import 'src/gen/messages.g.dart';

export 'src/gen/messages.g.dart'
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

  /// Registers [listener] for events, or removes it when null.
  void setListener(NearbyFlutterApi? listener) => _p.setListener(listener);

  /// Makes this device discoverable by devices running [startDiscovery] with
  /// the same [serviceId] and [strategy].
  ///
  /// [name] is shown to discoverers. [serviceId] must uniquely identify your
  /// app; the package name is the usual choice. Incoming connection requests
  /// arrive through [NearbyFlutterApi.onConnectionInitiated].
  Future<void> startAdvertising(
    String name,
    String serviceId,
    NearbyStrategy strategy,
  ) => _p.startAdvertising(name, serviceId, strategy);

  /// Looks for devices advertising the same [serviceId] and [strategy].
  ///
  /// Results arrive through [NearbyFlutterApi.onEndpointFound] and
  /// [NearbyFlutterApi.onEndpointLost]. Discovery is radio-heavy and can
  /// break established connections: call [stopDiscovery] once you have
  /// found the peers you need.
  Future<void> startDiscovery(String serviceId, NearbyStrategy strategy) =>
      _p.startDiscovery(serviceId, strategy);

  /// Asks the discovered endpoint [endpointId] to connect, presenting this
  /// device as [name].
  ///
  /// Both sides then get [NearbyFlutterApi.onConnectionInitiated] and must
  /// accept before the connection is established.
  Future<void> requestConnection(String name, String endpointId) =>
      _p.requestConnection(name, endpointId);

  /// Accepts a pending connection. It is established once both sides
  /// accept, reported by [NearbyFlutterApi.onConnectionResult].
  Future<void> acceptConnection(String endpointId) =>
      _p.acceptConnection(endpointId);

  /// Rejects a pending connection.
  Future<void> rejectConnection(String endpointId) =>
      _p.rejectConnection(endpointId);

  /// Sends [bytes] to connected [endpointIds] in one chunk.
  ///
  /// Limited to 32 KB; use [sendFile] for larger data. Returns the payload
  /// id, matching [TransferUpdate.payloadId].
  Future<int> sendBytes(List<String> endpointIds, Uint8List bytes) =>
      _p.sendBytes(endpointIds, bytes);

  /// Sends the file at [path], of any size, to connected [endpointIds].
  ///
  /// The receiver gets it without its original name; send the name
  /// separately with [sendBytes] if needed. Returns the payload id,
  /// matching [TransferUpdate.payloadId].
  Future<int> sendFile(List<String> endpointIds, String path) =>
      _p.sendFile(endpointIds, path);

  /// Cancels an in-flight payload sent or being received.
  void cancelPayload(int payloadId) => _p.cancelPayload(payloadId);

  /// Stops advertising. Existing connections stay open.
  void stopAdvertising() => _p.stopAdvertising();

  /// Stops discovery. Already found endpoints can still be connected to;
  /// existing connections stay open.
  void stopDiscovery() => _p.stopDiscovery();

  /// Closes the connection to [endpointId].
  void disconnect(String endpointId) => _p.disconnect(endpointId);

  /// Stops advertising and discovery and disconnects from every endpoint.
  void stopAllEndpoints() => _p.stopAllEndpoints();
}
