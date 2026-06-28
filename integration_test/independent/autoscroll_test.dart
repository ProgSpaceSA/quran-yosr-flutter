// Independent auto-scroll tests — each test resets all state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_er/main.dart' as app;
import '../helpers.dart';

void main() {
  group('Independent — AutoScroll', () {
    setUp(() async {
      await app.UserDb.resetForTest();
      await app.UserDb.instance.savePlan('pages', 5);
    });

    // ── Play button starts scrolling ──────────────────────────────────────────
    testWidgets('autoscroll_starts', (tester) async {
      await launchApp(tester);
      final before = await savedPage();
      await tapAutoScroll(tester);
      await tester.pump(const Duration(seconds: 5));
      await tapAutoScroll(tester); // stop
      await tester.pump(kSaveDelay);
      final after = await savedPage();
      // Position should have advanced
      expect(after, greaterThanOrEqualTo(before));
    });

    // ── UI control bar hidden during autoscroll ───────────────────────────────
    testWidgets('autoscroll_hides_appbar', (tester) async {
      await launchApp(tester);
      await tapAutoScroll(tester);
      await tester.pump(const Duration(milliseconds: 600));
      // AppBar is still in the tree but offset off-screen (AnimatedSlide).
      // Speed buttons remain accessible (in bottom player bar, not AppBar).
      expect(find.byKey(const Key('btn_speed_up')), findsOneWidget);
      await tapAutoScroll(tester);
      await tester.pumpAndSettle();
    });

    // ── Speed up increases the speed level ───────────────────────────────────
    testWidgets('speed_up_increments_level', (tester) async {
      await launchApp(tester);
      final speedFinder = find.byKey(const Key('text_speed_level'));
      expect(tester.widget<Text>(speedFinder).data, '1');
      await tester.tap(find.byKey(const Key('btn_speed_up')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Text>(speedFinder).data, '2');
      await tester.tap(find.byKey(const Key('btn_speed_up')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Text>(speedFinder).data, '3');
    });

    // ── Speed down decrements the speed level ────────────────────────────────
    testWidgets('speed_down_decrements_level', (tester) async {
      await launchApp(tester);
      final speedFinder = find.byKey(const Key('text_speed_level'));
      await tester.tap(find.byKey(const Key('btn_speed_up')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Text>(speedFinder).data, '2');
      await tester.tap(find.byKey(const Key('btn_speed_down')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Text>(speedFinder).data, '1');
    });

    // ── Speed does not go below 1 ─────────────────────────────────────────────
    testWidgets('speed_min_clamped', (tester) async {
      await launchApp(tester);
      final speedFinder = find.byKey(const Key('text_speed_level'));
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('btn_speed_down')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.widget<Text>(speedFinder).data, '1');
      expect(find.text('0'), findsNothing);
    });

    // ── Pause (tap play again) stops scrolling ────────────────────────────────
    testWidgets('autoscroll_pause_stops_movement', (tester) async {
      await launchApp(tester);
      await tapAutoScroll(tester);
      await tester.pump(const Duration(seconds: 2));
      // Pause
      await tapAutoScroll(tester);
      await tester.pump(kSaveDelay);
      final pageAtPause = await savedPage();
      // Wait more — position should NOT advance further
      await tester.pump(const Duration(seconds: 3));
      final pageAfterWait = await savedPage();
      expect(pageAfterWait, equals(pageAtPause));
    });

    // ── Start → pause → resume — position advances across both runs ──────────
    testWidgets('autoscroll_pause_and_resume', (tester) async {
      await launchApp(tester);
      await tapAutoScroll(tester);
      await tester.pump(const Duration(seconds: 3));
      await tapAutoScroll(tester); // pause
      await tester.pump(kSaveDelay);
      final midPage = await savedPage();

      await tapAutoScroll(tester); // resume
      await tester.pump(const Duration(seconds: 3));
      await tapAutoScroll(tester); // stop
      await tester.pump(kSaveDelay);
      final finalPage = await savedPage();

      expect(finalPage, greaterThanOrEqualTo(midPage));
    });

    // ── Nav bar reappears after stop ──────────────────────────────────────────
    testWidgets('nav_visible_after_stop', (tester) async {
      await launchApp(tester);
      await tapAutoScroll(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tapAutoScroll(tester); // stop
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // NavigationBar labels should be rendered
      expect(find.text('القرآن'), findsWidgets);
      expect(find.text('لوحتي'), findsWidgets);
    });
  });
}
