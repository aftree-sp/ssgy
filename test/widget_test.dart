import 'package:flutter_test/flutter_test.dart';
import 'package:ssgy/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SSGYApp());
    expect(find.text('爆闪狗眼'), findsOneWidget);
  });
}
