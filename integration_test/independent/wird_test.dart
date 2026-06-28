// Independent wird tests — each test resets all state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_er/main.dart' as app;
import '../helpers.dart';

void main() {
  group('Independent — Wird', () {
    setUp(() async {
      await app.UserDb.resetForTest();
    });

    // ── No plan → setup card visible ─────────────────────────────────────────
    testWidgets('no_plan_shows_setup_card', (tester) async {
      await launchApp(tester);
      expect(find.byKey(const Key('card_wird_setup')), findsOneWidget);
      expect(find.text('إعداد الورد اليومي'), findsOneWidget);
    });

    // ── Save صفحات plan ───────────────────────────────────────────────────────
    testWidgets('save_pages_plan', (tester) async {
      await launchApp(tester);
      await openWirdSetup(tester);
      await saveWirdPlan(tester, 'صفحات', 30);
      expect(find.text('وردك اليوم'), findsOneWidget);
      // Setup card should be gone
      expect(find.byKey(const Key('card_wird_setup')), findsNothing);
    });

    // ── Save آيات plan ────────────────────────────────────────────────────────
    testWidgets('save_ayahs_plan', (tester) async {
      await launchApp(tester);
      await openWirdSetup(tester);
      await saveWirdPlan(tester, 'آيات', 20);
      expect(find.text('وردك اليوم'), findsOneWidget);
    });

    // ── Save دقائق plan ───────────────────────────────────────────────────────
    testWidgets('save_minutes_plan', (tester) async {
      await launchApp(tester);
      await openWirdSetup(tester);
      await saveWirdPlan(tester, 'دقائق', 20);
      expect(find.text('وردك اليوم'), findsOneWidget);
    });

    // ── Edit plan opens sheet again ───────────────────────────────────────────
    testWidgets('edit_plan_reopens_sheet', (tester) async {
      await launchApp(tester);
      await openWirdSetup(tester);
      await saveWirdPlan(tester, 'صفحات', 0);
      // Tap "تعديل" link in the wird card
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('slider_wird')), findsOneWidget);
      // Change type to آيات and save
      await saveWirdPlan(tester, 'آيات', 20);
      expect(find.text('وردك اليوم'), findsOneWidget);
    });

    // ── Slider drag changes value ─────────────────────────────────────────────
    testWidgets('slider_changes_value', (tester) async {
      await launchApp(tester);
      await openWirdSetup(tester);
      final slider = find.byKey(const Key('slider_wird'));
      expect(slider, findsOneWidget);
      // Drag right — value should increase; just verify no crash
      await tester.drag(slider, const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.drag(slider, const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 200));
      // Still showing save button
      expect(find.byKey(const Key('btn_wird_save')), findsOneWidget);
    });

    // ── Progress bar shows 0 initially ───────────────────────────────────────
    testWidgets('progress_starts_at_zero', (tester) async {
      await launchApp(tester);
      // Force _HomePageState.refresh() so it re-reads the (now empty) DB.
      await switchToTab(tester, 1);
      await switchToTab(tester, 0);
      await openWirdSetup(tester);
      await saveWirdPlan(tester, 'صفحات', 0);
      // Progress text: "0 من X صفحات"
      expect(find.textContaining('0 من'), findsOneWidget);
    });

    // ── "اقرأ الآن" button switches to reader tab ──────────────────────────────
    testWidgets('read_now_switches_tab', (tester) async {
      await launchApp(tester);
      await openWirdSetup(tester);
      await saveWirdPlan(tester, 'صفحات', 0);
      final readNow = find.byKey(const Key('btn_read_now'));
      expect(readNow, findsOneWidget);
      await tester.tap(readNow);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ayah_list')), findsOneWidget);
    });

    // ── With plan, app starts on reader tab ──────────────────────────────────
    testWidgets('with_plan_starts_on_reader', (tester) async {
      // Pre-create a plan without going through UI
      await app.UserDb.instance.savePlan('pages', 5);
      await launchApp(tester);
      // App should start on reader (returning user with plan)
      expect(find.byKey(const Key('ayah_list')), findsOneWidget);
    });
  });
}
