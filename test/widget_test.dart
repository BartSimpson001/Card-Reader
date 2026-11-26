import 'package:flutter_test/flutter_test.dart';
import 'package:card_reader/main.dart';

void main() {
  testWidgets('CardReaderApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CardReaderApp());
    expect(find.text('NFC Connect'), findsOneWidget);
  });
}
