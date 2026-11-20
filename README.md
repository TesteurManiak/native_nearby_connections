# native_nearby_connections

![GitHub License](https://img.shields.io/github/license/TesteurManiak/native_nearby_connections)

Flutter plugin for [Google Nearby Connections](https://developers.google.com/nearby/connections/overview) (Android and iOS), using [Pigeon](https://pub.dev/packages/pigeon) Native Interop (JNI on Android and FFI on iOS).

:warning: **This plugin is in early development, the API may change and instability is expected.**

## Usage

```dart
final nearby = NativeNearbyConnections();
nearby.setListener(myListener); // implements NearbyFlutterApi

await nearby.startAdvertising('Alice', 'com.example.service', NearbyStrategy.cluster);
await nearby.startDiscovery('com.example.service', NearbyStrategy.cluster);
// In onEndpointFound: requestConnection; in onConnectionInitiated: acceptConnection.
final payloadId = await nearby.sendBytes([endpointId], bytes);

nearby.cancelPayload(payloadId);
nearby.stopDiscovery();
nearby.stopAdvertising();
nearby.disconnect(endpointId);
```

Advertising, discovery, connection, and send operations return futures.
`cancelPayload`, `stopAdvertising`, `stopDiscovery`, `disconnect`, and
`stopAllEndpoints` are synchronous: don't `await` them. They run directly on
the calling thread, and native errors are thrown before the method returns.

The plugin declares the required permissions in its manifest, but the app must
request the runtime ones (Bluetooth scan/advertise/connect, Nearby Wi-Fi
devices, location on older Android) before advertising or discovering.

## iOS setup

- Requires Swift Package Manager (the Nearby Swift SDK has no CocoaPods release): `flutter config --enable-swift-package-manager`.
- Add to your app's `Info.plist`:
  - `NSBluetoothAlwaysUsageDescription`, `NSLocalNetworkUsageDescription`, `NSLocationWhenInUseUsageDescription`
  - `NSBonjourServices` containing `_<HASH>._tcp`, where `<HASH>` is the upper-case hex of the
    first 6 bytes of SHA-256 of your service ID:
    `printf %s "your.service.id" | shasum -a 256 | cut -c1-12 | tr a-f A-F`
- Optional, for Wi-Fi hotspot transfers: enable the *Access Wi-Fi Information* and *Hotspot
  Configuration* capabilities and request location permission.

Differences from Android: endpoint names are sent as UTF-8 endpoint info; incoming requests
are accepted at the first stage automatically, so `onConnectionInitiated` +
`acceptConnection`/`rejectConnection` behave as on Android. Connection failures report Android
status codes (`8004` rejected, `13` error).

## Regenerating Pigeon code

Edit `pigeons/messages.dart`, then run:

```sh
dart run pigeon --input pigeons/messages.dart
```

With Native Interop enabled, this also runs the FFI and JNI generators. Code
generation requires Xcode Command Line Tools on macOS and an Android SDK plus
JDK 17–21.
