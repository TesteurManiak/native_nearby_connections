import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/maniak/native_nearby_connections/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.maniak.native_nearby_connections',
    ),
    swiftOut:
        'ios/native_nearby_connections/Sources/native_nearby_connections/Messages.g.swift',
    dartPackageName: 'native_nearby_connections',
  ),
)
enum NearbyStrategy { cluster, star, pointToPoint }

class EndpointInfo {
  String? endpointId;
  String? name;
  String? serviceId;
}

class ConnectionInfo {
  String? endpointName;
  String? authDigits;
  bool? isIncoming;
}

/// [type] mirrors Android `Payload.Type`: 1 = bytes, 2 = file, 3 = stream.
class PayloadMessage {
  int? id;
  int? type;
  Uint8List? bytes;
  String? filePath;
}

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
abstract class NearbyFlutterApi {
  void onEndpointFound(EndpointInfo info);
  void onEndpointLost(String endpointId);
  void onConnectionInitiated(String endpointId, ConnectionInfo info);
  void onConnectionResult(String endpointId, int statusCode);
  void onDisconnected(String endpointId);
  void onPayloadReceived(String endpointId, PayloadMessage payload);
  void onPayloadTransferUpdate(String endpointId, TransferUpdate update);
}
