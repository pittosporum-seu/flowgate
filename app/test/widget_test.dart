import 'package:flutter_test/flutter_test.dart';
import 'package:flowgate/main.dart';

void main() {
  testWidgets('App renders shell', (WidgetTester tester) async {
    await tester.pumpWidget(const FlowGateApp());
    expect(find.text('FlowGate'), findsOneWidget);
  });
}
