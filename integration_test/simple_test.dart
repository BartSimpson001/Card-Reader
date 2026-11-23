import 'package:flutter_test/flutter_test.dart';
import 'package:card_reader/main.dart';
import 'package:card_reader/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Can initialize app and rust lib', (WidgetTester tester) async {
    await tester.pumpWidget(const CardReaderApp());
    expect(find.text('NFC Card Reader'), findsOneWidget);
  });
}
