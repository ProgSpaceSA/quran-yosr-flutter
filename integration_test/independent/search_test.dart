// Independent search tests — each test resets all state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_er/main.dart' as app;
import '../helpers.dart';

void main() {
  group('Independent — Search', () {
    setUp(() async {
      await app.UserDb.resetForTest();
      // Pre-create a plan so the app starts on the reader tab
      await app.UserDb.instance.savePlan('pages', 5);
    });

    // ── Overlay opens ─────────────────────────────────────────────────────────
    testWidgets('search_overlay_opens', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      expect(find.byKey(const Key('field_search')), findsOneWidget);
    });

    // ── 2-char query: surah hits appear, ayah results list does not ──────────
    // Surah search fires at ≥ 2 chars; ayah full-text search fires at ≥ 3.
    testWidgets('short_query_shows_surahs_not_ayahs', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(find.byKey(const Key('field_search')), 'ال');
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('field_search')), findsOneWidget);
      // Ayah results list must NOT appear.
      expect(find.byKey(const Key('list_search_results')), findsNothing);
      // Surah hits list DO appear (many surahs match "ال").
      expect(find.byKey(const Key('list_surah_hits')), findsOneWidget);
    });

    // ── 1-char query: nothing shown ───────────────────────────────────────────
    testWidgets('one_char_query_no_results', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(find.byKey(const Key('field_search')), 'ا');
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('list_search_results')), findsNothing);
      expect(find.byKey(const Key('list_surah_hits')), findsNothing);
    });

    // ── Known query returns results ───────────────────────────────────────────
    testWidgets('known_query_returns_results', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(find.byKey(const Key('field_search')), 'الرحمن الرحيم');
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('list_search_results')), findsOneWidget);
    });

    // ── Rare query shows "لا توجد نتائج" ─────────────────────────────────────
    testWidgets('no_results_message_shown', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(
          find.byKey(const Key('field_search')), 'خخخقققزززخخخ');
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('لا توجد نتائج'), findsWidgets);
    });

    // ── Close button dismisses overlay ────────────────────────────────────────
    testWidgets('close_button_dismisses_overlay', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      expect(find.byKey(const Key('field_search')), findsOneWidget);
      // Tap the close icon inside the search card
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('field_search')), findsNothing);
    });

    // ── Tapping a result closes overlay ──────────────────────────────────────
    testWidgets('result_tap_closes_overlay', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(find.byKey(const Key('field_search')), 'بسم الله');
      await tester.pump(const Duration(seconds: 4));
      final resultList = find.byKey(const Key('list_search_results'));
      if (resultList.evaluate().isNotEmpty) {
        final firstRow = find.descendant(
            of: resultList, matching: find.byType(InkWell));
        await tester.tap(firstRow.first);
        await tester.pumpAndSettle(kMedSettle);
        expect(find.byKey(const Key('field_search')), findsNothing);
      }
    });

    // ── Tapping a result navigates reader ────────────────────────────────────
    testWidgets('result_tap_navigates', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(find.byKey(const Key('field_search')), 'الرحمن');
      await tester.pump(const Duration(seconds: 4));
      final resultList = find.byKey(const Key('list_search_results'));
      if (resultList.evaluate().isNotEmpty) {
        final firstRow = find.descendant(
            of: resultList, matching: find.byType(InkWell));
        await tester.tap(firstRow.first);
        await tester.pumpAndSettle(kMedSettle);
        await tester.pump(kSaveDelay);
        final page = await savedPage();
        expect(page, greaterThan(0));
        expect(page, lessThanOrEqualTo(604));
      }
    });

    // ── Surah name search returns hits ────────────────────────────────────────
    testWidgets('surah_name_search_returns_hits', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(
          find.byKey(const Key('field_search')), 'البقرة');
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('list_surah_hits')), findsOneWidget);
    });

    // ── Surah hit tap closes overlay and navigates ────────────────────────────
    testWidgets('surah_hit_tap_navigates', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(
          find.byKey(const Key('field_search')), 'الكهف');
      await tester.pump(const Duration(seconds: 3));
      final surahList = find.byKey(const Key('list_surah_hits'));
      if (surahList.evaluate().isNotEmpty) {
        final surahRow = find.descendant(
            of: surahList, matching: find.byType(InkWell));
        await tester.tap(surahRow.first);
        await tester.pumpAndSettle(kMedSettle);
        await tester.pump(kSaveDelay);
        // Overlay should be dismissed.
        expect(find.byKey(const Key('field_search')), findsNothing);
        // Al-Kahf starts at page 293.
        final page = await savedPage();
        expect(page, closeTo(293, 20));
      }
    });

    // ── Surah name search mixed with ayah results ─────────────────────────────
    testWidgets('surah_and_ayah_results_coexist', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      // "الرحمن" matches a surah name AND appears in many ayah texts.
      await tester.enterText(
          find.byKey(const Key('field_search')), 'الرحمن');
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('list_surah_hits')), findsOneWidget);
      expect(find.byKey(const Key('list_search_results')), findsOneWidget);
    });

    // ── Multiple searches in a row ────────────────────────────────────────────
    testWidgets('multiple_searches_in_row', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      for (final query in ['الله', 'الرحيم', 'المؤمنون']) {
        await tester.enterText(find.byKey(const Key('field_search')), query);
        await tester.pump(const Duration(seconds: 3));
        // Should not crash
        expect(find.byKey(const Key('field_search')), findsOneWidget);
      }
    });
  });
}
