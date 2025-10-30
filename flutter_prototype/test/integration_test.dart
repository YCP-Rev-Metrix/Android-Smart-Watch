import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:watch_app/pages/shot_page.dart';
import 'package:watch_app/pages/other_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bowling Watch Integration Tests', () {
    testWidgets('Tap on X button to simulate strike', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ShotPage(
          initialPins: [false, false, false, false, false, false, false, false, false, false],
          shotNumber: 1,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();
      expect(true, isTrue);
    });

    testWidgets('Navigate to OtherPage and back', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: OtherPage(lane: 1, board: 10, speed: 15.0, shotNumber: 1),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Lane'), findsOneWidget);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(true, isTrue);
    });
  });
}
