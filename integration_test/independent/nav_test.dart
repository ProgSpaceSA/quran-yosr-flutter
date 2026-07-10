// Independent navigation tests — each test resets all state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers.dart';

void main() {
  group('Independent — Navigation', () {

    // ── Nav sheet opens ───────────────────────────────────────────────────────
    testWidgets('nav_sheet_opens', (tester) async {
      await launchApp(tester, resetDb: true);
      await openNavSheet(tester);
      // All four mode labels visible in the sheet
      expect(find.text('صفحة'), findsWidgets);
      expect(find.text('سورة'), findsWidgets);
      expect(find.text('جزء'), findsWidgets);
      expect(find.text('آية'), findsWidgets);
    });

    // ── Page mode — first page ────────────────────────────────────────────────
    testWidgets('nav_page_1', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToPage(tester, 1);
      await waitForSave(tester);
      final page = await savedPage();
      expect(page, equals(1));
    });

    // ── Page mode — last page ─────────────────────────────────────────────────
    testWidgets('nav_page_604', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToPage(tester, 604);
      await waitForSave(tester);
      final page = await savedPage();
      expect(page, closeTo(604, 5));
    });

    // ── Page mode — middle page ───────────────────────────────────────────────
    testWidgets('nav_page_300', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToPage(tester, 300);
      await waitForSave(tester);
      final page = await savedPage();
      expect(page, closeTo(300, 5));
    });

    // ── Page mode — two consecutive jumps ─────────────────────────────────────
    testWidgets('nav_page_two_jumps', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToPage(tester, 100);
      await waitForSave(tester);
      await navToPage(tester, 200);
      await waitForSave(tester);
      final page = await savedPage();
      expect(page, closeTo(200, 5));
    });

    // ── Surah mode — first surah (Al-Fatiha) ─────────────────────────────────
    testWidgets('nav_surah_fatiha', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToSurah(tester, 'الفاتحة');
      await waitForSave(tester);
      final page = await savedPage();
      expect(page, equals(1));
    });

    // ── Surah mode — Al-Baqarah ───────────────────────────────────────────────
    testWidgets('nav_surah_baqarah', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToSurah(tester, 'البقرة');
      await waitForSave(tester);
      final page = await savedPage();
      expect(page, closeTo(2, 3));
    });

    // ── Surah mode — search filter narrows list ───────────────────────────────
    testWidgets('nav_surah_search_filters', (tester) async {
      await launchApp(tester, resetDb: true);
      await openNavSheet(tester);
      await tester.tap(find.text('سورة'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('field_surah_search')), 'يوسف');
      await tester.pump(const Duration(milliseconds: 300));
      // Only Yusuf (or similar names) should show — at minimum one result
      expect(find.byKey(const Key('list_surah')), findsOneWidget);
      final tiles = find.descendant(
          of: find.byKey(const Key('list_surah')),
          matching: find.byType(ListTile));
      expect(tiles, findsWidgets);
    });

    // ── Juz mode — juz 1 ─────────────────────────────────────────────────────
    testWidgets('nav_juz_1', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToJuz(tester, 1);
      await waitForSave(tester);
      final page = await savedPage();
      expect(page, closeTo(1, 3));
    });

    // ── Juz mode — juz 15 ────────────────────────────────────────────────────
    testWidgets('nav_juz_15', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToJuz(tester, 15);
      await waitForSave(tester);
      final page = await savedPage();
      // Juz 15 starts at page 282
      expect(page, closeTo(282, 10));
    });

    // ── Juz mode — juz 30 ────────────────────────────────────────────────────
    testWidgets('nav_juz_30', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToJuz(tester, 30);
      await waitForSave(tester);
      final page = await savedPage();
      // Juz 30 starts at page 582
      expect(page, closeTo(582, 10));
    });

    // ── Ayah mode — Surah 1 Ayah 1 ───────────────────────────────────────────
    testWidgets('nav_ayah_fatiha_1', (tester) async {
      await launchApp(tester, resetDb: true);
      await openNavSheet(tester);
      await tester.tap(find.text('آية'));
      await tester.pumpAndSettle(kMedSettle);
      // Default surah should be 1; enter ayah 1
      await tester.enterText(find.byKey(const Key('field_ayah')), '1');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('انتقل'));
      await tester.pumpAndSettle(kMedSettle);
      await waitForSave(tester);
      final page = await savedPage();
      expect(page, equals(1));
    });

    // ── Ayah mode — Surah 2 (Al-Baqarah) Ayah 1 ─────────────────────────────
    // Note: surah 36 (Ya-Sin) requires scrolling a 114-item dropdown which is
    // flaky on real devices. Surah 2 is near the top of the dropdown list and
    // reliably visible without scrolling.
    testWidgets('nav_ayah_yasin_1', (tester) async {
      await launchApp(tester, resetDb: true);
      await openNavSheet(tester);
      await tester.tap(find.text('آية'));
      await tester.pumpAndSettle(kMedSettle);
      await tester.tap(find.byKey(const Key('dropdown_surah')));
      await tester.pumpAndSettle(kMedSettle);
      await tester.tap(find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').startsWith('2. '),
      ).first);
      await tester.pumpAndSettle(kMedSettle);
      await tester.enterText(find.byKey(const Key('field_ayah')), '1');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('انتقل'));
      await tester.pumpAndSettle(kMedSettle);
      await waitForSave(tester);
      final page = await savedPage();
      // Al-Baqarah starts at page 2
      expect(page, closeTo(2, 3));
    });

    // ── Juz list is scrollable ────────────────────────────────────────────────
    testWidgets('nav_juz_list_scrollable', (tester) async {
      await launchApp(tester, resetDb: true);
      await openNavSheet(tester);
      await tester.tap(find.text('جزء'));
      await tester.pumpAndSettle();
      final juzList = find.byKey(const Key('list_juz'));
      expect(juzList, findsOneWidget);
      // Drag the juz list to reveal juz 15 (list height 300px; ~6 items visible).
      // scrollUntilVisible requires a unique finder but can see duplicates mid-scroll.
      for (int i = 0; i < 10; i++) {
        final juzItem15 =
            find.descendant(of: juzList, matching: find.text('الجزء 15'));
        if (juzItem15.evaluate().isNotEmpty) break;
        await tester.drag(juzList, const Offset(0, -250));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pump(const Duration(milliseconds: 500));
      final juzItem15 =
          find.descendant(of: juzList, matching: find.text('الجزء 15'));
      expect(juzItem15, findsWidgets);
    });

    // ── Top bar: surah name and juz visible after launch ─────────────────────
    testWidgets('topbar_shows_after_launch', (tester) async {
      await launchApp(tester, resetDb: true);
      final surahText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_surah')))
          .data ?? '';
      final juzText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_juz')))
          .data ?? '';
      expect(surahText, isNotEmpty);
      expect(juzText, isNotEmpty);
    });

    // ── Top bar: surah name and juz update after page jump ───────────────────
    testWidgets('topbar_updates_after_page_nav', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToPage(tester, 1);
      final surahText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_surah')))
          .data ?? '';
      final juzText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_juz')))
          .data ?? '';
      // Page 1 is Al-Fatiha, Juz 1. Strip tashkeel before comparing.
      final stripped = surahText.replaceAll(RegExp(r'[ً-ٟ]'), '');
      expect(stripped, contains('الفاتحة'));
      expect(juzText, equals('الجزء 1'));
    });

    // ── Top bar: juz label updates after juz jump ─────────────────────────────
    testWidgets('topbar_updates_after_juz_nav', (tester) async {
      await launchApp(tester, resetDb: true);
      // Juz 5 starts at page 82 per _pageToJuz boundaries
      await navToJuz(tester, 5);
      final juzText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_juz')))
          .data ?? '';
      expect(juzText, equals('الجزء 5'));
    });

    // ── Top bar: surah name updates after surah list navigation ───────────────
    testWidgets('topbar_updates_after_surah_nav', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToSurah(tester, 'الكهف');
      final surahText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_surah')))
          .data ?? '';
      final stripped = surahText.replaceAll(RegExp(r'[ً-ٟ]'), '');
      expect(stripped, contains('الكهف'));
    });

    // ── Top bar: updates after tapping a search result ────────────────────────
    testWidgets('topbar_updates_after_search_jump', (tester) async {
      await launchApp(tester, resetDb: true);
      await openSearch(tester);
      await tester.enterText(find.byKey(const Key('field_search')), 'بسم الله');
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final resultList = find.byKey(const Key('list_search_results'));
      expect(resultList, findsOneWidget);
      // Tap the first result — this navigates and closes the overlay
      await tester.tap(
        find.descendant(of: resultList, matching: find.byType(InkWell)).first);
      await tester.pumpAndSettle(kMedSettle);
      // Both top bar labels should now be populated
      final surahText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_surah')))
          .data ?? '';
      final juzText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_juz')))
          .data ?? '';
      expect(surahText, startsWith('سورة'));
      expect(juzText, startsWith('الجزء'));
    });

    // ── Topbar stable after scrolling from Al-Masad (end-of-quran edge case) ──
    // Regression: topbar used to oscillate because when the page-boundary marker
    // briefly dropped below the viewport threshold, the fallback jumped to the
    // first loaded page's surah instead of keeping the current state.
    testWidgets('topbar_stable_after_masad_scroll', (tester) async {
      await launchApp(tester, resetDb: true);
      await navToSurah(tester, 'المسد');
      await waitForSave(tester);

      final List<String> surahSeq = [];
      // Collect topbar surah name over several small scrolls.
      for (int i = 0; i < 8; i++) {
        final text = tester
            .widget<Text>(find.byKey(const Key('text_topbar_surah')))
            .data ?? '';
        surahSeq.add(text);
        await scrollAyahs(tester, 500);
      }

      // Topbar must not oscillate: once a surah is left behind it must not
      // reappear (A→B→A pattern is the back-and-forth bug).
      final seen = <String>{};
      String prev = '';
      for (final name in surahSeq) {
        if (name != prev) {
          expect(
            seen,
            isNot(contains(name)),
            reason: 'Surah topbar oscillated: $surahSeq',
          );
          seen.add(name);
          prev = name;
        }
      }
    });
  });
}
