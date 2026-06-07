// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:netscope/main.dart';

void main() {
  testWidgets('renders navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(const NetScopeApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Live Map'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('NetScope 5G'), findsOneWidget);
  });
}
