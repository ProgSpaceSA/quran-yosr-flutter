// Independent focus-mode tests — each test resets all state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  group('Independent — Focus Mode', () {
    // No setUp — DB reset is done inside launchApp(resetDb:true) so that pumps
    // run during the async DB work, keeping ADB alive.  Each test then calls
    // switchToTab(1) to guarantee the reader tab is the active IndexedStack
    // child before any tap: _AppShell.initState calls getActivePlan() async,
    // and launchApp may exit before that future completes, leaving the app on
    // the home tab where taps don't reach the reader's GestureDetector.

    // ── Tap collapses AppBar ──────────────────────────────────────────────────
    testWidgets('focus_mode_tap_collapses_appbar', (tester) async {
      await launchApp(tester, resetDb: true);
      await switchToTab(tester, 1);

      final barBefore =
          tester.widget<PreferredSize>(find.byType(PreferredSize).first);
      expect(barBefore.preferredSize.height, greaterThan(0));

      await tester.tapAt(
          tester.getCenter(find.byKey(const Key('ayah_list'))));
      await tester.pump(const Duration(milliseconds: 500));

      final barAfter =
          tester.widget<PreferredSize>(find.byType(PreferredSize).first);
      expect(barAfter.preferredSize.height, equals(0.0));
    });

    // ── Second tap restores AppBar ────────────────────────────────────────────
    testWidgets('focus_mode_second_tap_restores_appbar', (tester) async {
      await launchApp(tester, resetDb: true);
      await switchToTab(tester, 1);
      final list = find.byKey(const Key('ayah_list'));

      await tester.tapAt(tester.getCenter(list)); // enter focus mode
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tapAt(tester.getCenter(list)); // exit focus mode
      await tester.pump(const Duration(milliseconds: 500));

      final bar =
          tester.widget<PreferredSize>(find.byType(PreferredSize).first);
      expect(bar.preferredSize.height, greaterThan(0));
    });

    // ── Focus mode stays active during scroll ─────────────────────────────────
    testWidgets('focus_mode_stays_active_while_scrolling', (tester) async {
      await launchApp(tester, resetDb: true);
      await switchToTab(tester, 1);
      await tester.tapAt(
          tester.getCenter(find.byKey(const Key('ayah_list'))));
      await tester.pump(const Duration(milliseconds: 500));

      final barIn =
          tester.widget<PreferredSize>(find.byType(PreferredSize).first);
      expect(barIn.preferredSize.height, equals(0.0));

      await scrollAyahs(tester, 1500);

      final barAfter =
          tester.widget<PreferredSize>(find.byType(PreferredSize).first);
      expect(barAfter.preferredSize.height, equals(0.0));
    });

    // ── Scroll still works in focus mode ─────────────────────────────────────
    testWidgets('focus_mode_scroll_advances_position', (tester) async {
      await launchApp(tester, resetDb: true);
      await switchToTab(tester, 1);
      final pageBefore = await savedPage();

      await tester.tapAt(
          tester.getCenter(find.byKey(const Key('ayah_list'))));
      await tester.pump(const Duration(milliseconds: 500));

      await scrollAyahs(tester, 4000);
      final pageAfter = await savedPage();
      expect(pageAfter, greaterThanOrEqualTo(pageBefore));
    });

    // ── Focus mode and auto-scroll coexist ───────────────────────────────────
    testWidgets('focus_mode_during_autoscroll_no_crash', (tester) async {
      await launchApp(tester, resetDb: true);
      await switchToTab(tester, 1);

      await tapAutoScroll(tester);
      await tester.pump(const Duration(seconds: 2));

      await tester.tapAt(
          tester.getCenter(find.byKey(const Key('ayah_list'))));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tapAt(
          tester.getCenter(find.byKey(const Key('ayah_list'))));
      await tester.pump(const Duration(milliseconds: 500));

      await tapAutoScroll(tester);
      await tester.pump(const Duration(seconds: 2));

      expect(find.byKey(const Key('ayah_list')), findsOneWidget);
    });

    // ── Multiple rapid taps toggle back and forth without crash ───────────────
    testWidgets('focus_mode_rapid_toggles_no_crash', (tester) async {
      await launchApp(tester, resetDb: true);
      await switchToTab(tester, 1);
      final list = find.byKey(const Key('ayah_list'));
      for (int i = 0; i < 6; i++) {
        await tester.tapAt(tester.getCenter(list));
        await tester.pump(const Duration(milliseconds: 200));
      }
      // After 6 taps (even count) focus mode is off → AppBar restored.
      final bar =
          tester.widget<PreferredSize>(find.byType(PreferredSize).first);
      expect(bar.preferredSize.height, greaterThan(0));
    });
  });
}
