import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:native_nearby_connections/native_nearby_connections.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('host API is wired', (WidgetTester tester) async {
    // Stop calls need no permissions; they only fail if the Pigeon channel is not registered.
    final plugin = NativeNearbyConnections();
    await plugin.stopDiscovery();
    await plugin.stopAdvertising();
    await plugin.stopAllEndpoints();
  });
}
