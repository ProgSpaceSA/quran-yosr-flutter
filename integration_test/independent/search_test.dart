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

    // ── Short query (<3 chars) shows no spinner / no results ──────────────────
    testWidgets('short_query_no_results', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(find.byKey(const Key('field_search')), 'ال');
      await tester.pump(const Duration(seconds: 2));
      // Should not have crashed; field still visible
      expect(find.byKey(const Key('field_search')), findsOneWidget);
      // Results list should not appear (query too short to trigger search)
      expect(find.byKey(const Key('list_search_results')), findsNothing);
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
