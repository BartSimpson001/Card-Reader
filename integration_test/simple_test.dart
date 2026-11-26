import 'package:flutter_test/flutter_test.dart';
import 'package:card_reader/main.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Can initialize app', (WidgetTester tester) async {
    await tester.pumpWidget(const CardReaderApp());
    expect(find.text('NFC Card Reader'), findsOneWidget);
  });
}

