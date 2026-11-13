import 'package:flutter_test/flutter_test.dart';

import 'package:native_nearby_connections_example/main.dart';

void main() {
  testWidgets('Shows Nearby controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Advertise'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
  });
}
