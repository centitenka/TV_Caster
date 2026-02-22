import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisense_caster/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the splash screen is shown
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
