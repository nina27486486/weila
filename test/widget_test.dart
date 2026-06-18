import 'package:flutter_test/flutter_test.dart';
import 'package:weila/app_widget.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AppWidget());
    expect(find.text('薇拉'), findsOneWidget);
  });
}
