// Independent dashboard / home-tab tests — each test resets all state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_er/main.dart' as app;
import '../helpers.dart';

void main() {
  group('Independent — Dashboard', () {
    setUp(() async {
      await app.UserDb.resetForTest();
    });

    // ── No plan — setup card and invite text visible ───────────────────────────
    testWidgets('no_plan_shows_invite', (tester) async {
      await launchApp(tester);
      expect(find.byKey(const Key('card_wird_setup')), findsOneWidget);
      expect(find.text('ابدأ بخطوة صغيرة — ولو صفحة واحدة'), findsOneWidget);
    });

    // ── Continue reading card always visible ──────────────────────────────────
    testWidgets('continue_card_always_present', (tester) async {
      await launchApp(tester);
      expect(find.byKey(const Key('card_continue')), findsOneWidget);
    });

    // ── No prior reading → "ابدأ من البداية" ─────────────────────────────────
    testWidgets('no_prior_reading_shows_default', (tester) async {
      await launchApp(tester);
      expect(find.text('ابدأ من البداية'), findsOneWidget);
    });

    // ── After scrolling, dashboard shows updated sura name ────────────────────
    testWidgets('dashboard_reflects_reader_position', (tester) async {
      await app.UserDb.instance.savePlan('pages', 5);
      await launchApp(tester);
      // Scroll in reader
      await scrollAyahs(tester, 4000);
      final sura = await savedSura();
      // Switch to home
      await switchToTab(tester, 0);
      if (sura.isNotEmpty) {
        expect(find.textContaining(sura), findsWidgets);
      }
      // Card is still there
      expect(find.byKey(const Key('card_continue')), findsOneWidget);
    });

    // ── Continue card taps navigates to reader ────────────────────────────────
    testWidgets('continue_card_tap_switches_tab', (tester) async {
      await app.UserDb.instance.savePlan('pages', 5);
      await launchApp(tester);
      await switchToTab(tester, 0);
      await tester.tap(find.byKey(const Key('card_continue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ayah_list')), findsOneWidget);
    });

    // ── With plan — wird section visible ─────────────────────────────────────
    testWidgets('with_plan_shows_wird_section', (tester) async {
      await app.UserDb.instance.savePlan('pages', 5);
      await launchApp(tester);
      await switchToTab(tester, 0);
      expect(find.text('وردك اليوم'), findsOneWidget);
      expect(find.text('متابعة الورد اليومي'), findsOneWidget);
    });

    // ── With plan — progress bar visible ─────────────────────────────────────
    testWidgets('with_plan_shows_progress_bar', (tester) async {
      await app.UserDb.instance.savePlan('pages', 5);
      await launchApp(tester);
      await switchToTab(tester, 0);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    // ── With plan — "اقرأ الآن" visible when not done ─────────────────────────
    testWidgets('read_now_visible_when_not_done', (tester) async {
      await app.UserDb.instance.savePlan('pages', 100); // big target, won't finish
      await launchApp(tester);
      await switchToTab(tester, 0);
      expect(find.byKey(const Key('btn_read_now')), findsOneWidget);
    });

    // ── Streak card visible ───────────────────────────────────────────────────
    testWidgets('streak_card_visible', (tester) async {
      await app.UserDb.instance.savePlan('pages', 5);
      await launchApp(tester);
      await switchToTab(tester, 0);
      // Streak shows "ابدأ اليوم" when 0 days
      expect(find.text('ابدأ اليوم'), findsOneWidget);
    });

    // ── Tab switch back and forth keeps state ─────────────────────────────────
    testWidgets('tab_round_trip_preserves_state', (tester) async {
      await app.UserDb.instance.savePlan('pages', 5);
      await launchApp(tester);
      // Start on reader (plan exists)
      await switchToTab(tester, 0);
      expect(find.byKey(const Key('card_continue')), findsOneWidget);
      await switchToTab(tester, 1);
      expect(find.byKey(const Key('ayah_list')), findsOneWidget);
      await switchToTab(tester, 0);
      expect(find.byKey(const Key('card_continue')), findsOneWidget);
    });
  });
}
