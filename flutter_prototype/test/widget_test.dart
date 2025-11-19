import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_app/pages/shot_page.dart';
import 'package:watch_app/pages/other_page.dart';
import 'package:watch_app/pages/game_page.dart';

void main() {

  testWidgets('ShotPage loads correctly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ShotPage(
        initialPins: [false, false, false, false, false, false, false, false, false, false],
        shotNumber: 1,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shot'), findsOneWidget);
  });

  testWidgets('OtherPage loads correctly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OtherPage(lane: 1, board: 10, speed: 15.0, shotNumber: 1),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lane'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('GameShell loads and returns safely', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameShell()));
    expect(find.byType(GameShell), findsOneWidget);
  });
}
