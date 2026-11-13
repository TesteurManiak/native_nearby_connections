# native_nearby_connections

Flutter plugin for [Google Nearby Connections](https://developers.google.com/nearby/connections/overview) (Android), using [Pigeon](https://pub.dev/packages/pigeon) for type-safe platform channels.

## Usage

```dart
final nearby = NativeNearbyConnections();
nearby.setListener(myListener); // implements NearbyFlutterApi

await nearby.startAdvertising('Alice', 'com.example.service', NearbyStrategy.cluster);
await nearby.startDiscovery('com.example.service', NearbyStrategy.cluster);
// In onEndpointFound: requestConnection; in onConnectionInitiated: acceptConnection.
final payloadId = await nearby.sendBytes([endpointId], bytes);
```

The plugin declares the required permissions in its manifest, but the app must
request the runtime ones (Bluetooth scan/advertise/connect, Nearby Wi-Fi
devices, location on older Android) before advertising or discovering.

## Regenerating Pigeon code

Edit `pigeons/messages.dart`, then run:

```sh
dart run pigeon --input pigeons/messages.dart
```
