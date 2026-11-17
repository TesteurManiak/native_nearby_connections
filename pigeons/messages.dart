import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/gen/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/maniak/native_nearby_connections/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.maniak.native_nearby_connections',
    ),
    swiftOut: 'ios/native_nearby_connections/Sources/native_nearby_connections/Messages.g.swift',
    dartPackageName: 'native_nearby_connections',
  ),
)
/// Connection topology. Advertiser and discoverer must use the same strategy.
///
/// See https://developers.google.com/nearby/connections/strategies.
enum NearbyStrategy {
  /// M-to-N: every device can advertise, discover and hold several
  /// connections. Lowest bandwidth; suits small payloads and mesh-like use
  /// such as multiplayer games.
  cluster,

  /// 1-to-N: one hub accepts many spokes, each device is a hub or a spoke
  /// but not both. Higher bandwidth than [cluster].
  star,

  /// 1-to-1: a single connection at a time. Highest bandwidth.
  pointToPoint,
}

/// A nearby advertiser reported by [NearbyFlutterApi.onEndpointFound].
class EndpointInfo {
  String? endpointId;
  String? name;
  String? serviceId;
}

/// Details of a pending connection, given by
/// [NearbyFlutterApi.onConnectionInitiated] on both sides.
class ConnectionInfo {
  /// Name the remote device advertised or requested with.
  String? endpointName;

  /// Short code to show on both devices so users can confirm they match
  /// before accepting. Connections that skip this check are insecure.
  String? authDigits;

  /// True when the remote device requested the connection.
  bool? isIncoming;
}

/// Data received from a connected endpoint.
///
/// [type] mirrors Android `Payload.Type`: 1 = bytes, 2 = file, 3 = stream.
/// [bytes] is set for bytes payloads, [filePath] for file payloads. A file is
/// only complete once [TransferUpdate.status] reports success.
class PayloadMessage {
  int? id;
  int? type;
  Uint8List? bytes;
  String? filePath;
}

/// Progress of an incoming or outgoing payload.
///
/// [status] mirrors Android `PayloadTransferUpdate.Status`:
/// 1 = success, 2 = failure, 3 = in progress, 4 = canceled.
class TransferUpdate {
  int? payloadId;
  int? status;
  int? bytesTransferred;
  int? totalBytes;
}

@HostApi()
abstract class NearbyHostApi {
  @async
  void startAdvertising(String name, String serviceId, NearbyStrategy strategy);
  @async
  void startDiscovery(String serviceId, NearbyStrategy strategy);
  @async
  void requestConnection(String name, String endpointId);
  @async
  void acceptConnection(String endpointId);
  @async
  void rejectConnection(String endpointId);
  @async
  int sendBytes(List<String> endpointIds, Uint8List bytes);
  @async
  int sendFile(List<String> endpointIds, String path);
  void cancelPayload(int payloadId);
  void stopAdvertising();
  void stopDiscovery();
  void disconnect(String endpointId);
  void stopAllEndpoints();
}

@FlutterApi()
/// Events from Nearby Connections. Implement and register with
/// `NativeNearbyConnections.setListener`.
abstract class NearbyFlutterApi {
  /// Discovery found an advertiser with the same service id.
  void onEndpointFound(EndpointInfo info);

  /// A previously found advertiser is no longer reachable.
  void onEndpointLost(String endpointId);

  /// A connection was requested, by either side. Both sides must call
  /// `acceptConnection` (ideally after users compare [ConnectionInfo.authDigits])
  /// or `rejectConnection`.
  void onConnectionInitiated(String endpointId, ConnectionInfo info);

  /// Outcome of a connection request, using Android `ConnectionsStatusCodes`:
  /// 0 = connected, 8004 = rejected by one or both sides, 13 = connection
  /// broke before it was accepted.
  void onConnectionResult(String endpointId, int statusCode);

  /// The connection ended. No more data can be sent or received.
  void onDisconnected(String endpointId);

  /// A payload started arriving. Bytes payloads are complete here; wait for
  /// [onPayloadTransferUpdate] success before reading a file payload.
  void onPayloadReceived(String endpointId, PayloadMessage payload);

  /// Progress of a payload being sent or received.
  void onPayloadTransferUpdate(String endpointId, TransferUpdate update);
}
