import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:native_nearby_connections/native_nearby_connections.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('host API is wired', (WidgetTester tester) {
    // Stop calls need no permissions; they only fail if the native API is not registered.
    final plugin = NativeNearbyConnections();
    plugin.stopDiscovery();
    plugin.stopAdvertising();
    plugin.stopAllEndpoints();
    return Future<void>.value();
  });
}
