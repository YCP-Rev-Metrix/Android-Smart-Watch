import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic Text widget renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Hello World'),
        ),
      ),
    );

    expect(find.text('Hello World'), findsOneWidget);
  });

  testWidgets('Button tap is detected', (WidgetTester tester) async {
    bool buttonTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => buttonTapped = true,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tap Me'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(buttonTapped, true);
  });

  testWidgets('Container with child renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            color: Colors.blue,
            child: const Center(
              child: Text('Content'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Content'), findsOneWidget);
    expect(find.byType(Container), findsOneWidget);
  });
}
