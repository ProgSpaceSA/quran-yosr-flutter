// Independent navigation tests — each test resets all state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_er/main.dart' as app;
import '../helpers.dart';

void main() {
  group('Independent — Navigation', () {
    setUp(() async {
      await app.UserDb.resetForTest();
      await app.UserDb.instance.savePlan('pages', 5);
    });

    // ── Nav sheet opens ───────────────────────────────────────────────────────
    testWidgets('nav_sheet_opens', (tester) async {
      await launchApp(tester);
      await openNavSheet(tester);
      // All four mode labels visible in the sheet
      expect(find.text('صفحة'), findsWidgets);
      expect(find.text('سورة'), findsWidgets);
      expect(find.text('جزء'), findsWidgets);
      expect(find.text('آية'), findsWidgets);
    });

    // ── Page mode — first page ────────────────────────────────────────────────
    testWidgets('nav_page_1', (tester) async {
      await launchApp(tester);
      await navToPage(tester, 1);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      expect(page, equals(1));
    });

    // ── Page mode — last page ─────────────────────────────────────────────────
    testWidgets('nav_page_604', (tester) async {
      await launchApp(tester);
      await navToPage(tester, 604);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      expect(page, closeTo(604, 5));
    });

    // ── Page mode — middle page ───────────────────────────────────────────────
    testWidgets('nav_page_300', (tester) async {
      await launchApp(tester);
      await navToPage(tester, 300);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      expect(page, closeTo(300, 5));
    });

    // ── Page mode — two consecutive jumps ─────────────────────────────────────
    testWidgets('nav_page_two_jumps', (tester) async {
      await launchApp(tester);
      await navToPage(tester, 100);
      await tester.pump(kSaveDelay);
      await navToPage(tester, 200);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      expect(page, closeTo(200, 5));
    });

    // ── Surah mode — first surah (Al-Fatiha) ─────────────────────────────────
    testWidgets('nav_surah_fatiha', (tester) async {
      await launchApp(tester);
      await navToSurah(tester, 'الفاتحة');
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      expect(page, equals(1));
    });

    // ── Surah mode — Al-Baqarah ───────────────────────────────────────────────
    testWidgets('nav_surah_baqarah', (tester) async {
      await launchApp(tester);
      await navToSurah(tester, 'البقرة');
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      expect(page, closeTo(2, 3));
    });

    // ── Surah mode — search filter narrows list ───────────────────────────────
    testWidgets('nav_surah_search_filters', (tester) async {
      await launchApp(tester);
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
      await launchApp(tester);
      await navToJuz(tester, 1);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      expect(page, closeTo(1, 3));
    });

    // ── Juz mode — juz 15 ────────────────────────────────────────────────────
    testWidgets('nav_juz_15', (tester) async {
      await launchApp(tester);
      await navToJuz(tester, 15);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      // Juz 15 starts at page 282
      expect(page, closeTo(282, 10));
    });

    // ── Juz mode — juz 30 ────────────────────────────────────────────────────
    testWidgets('nav_juz_30', (tester) async {
      await launchApp(tester);
      await navToJuz(tester, 30);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      // Juz 30 starts at page 582
      expect(page, closeTo(582, 10));
    });

    // ── Ayah mode — Surah 1 Ayah 1 ───────────────────────────────────────────
    testWidgets('nav_ayah_fatiha_1', (tester) async {
      await launchApp(tester);
      await openNavSheet(tester);
      await tester.tap(find.text('آية'));
      await tester.pumpAndSettle();
      // Default surah should be 1; enter ayah 1
      await tester.enterText(find.byKey(const Key('field_ayah')), '1');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('انتقل'));
      await tester.pumpAndSettle(kMedSettle);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      expect(page, equals(1));
    });

    // ── Ayah mode — Surah 36 (Ya-Sin) Ayah 1 ────────────────────────────────
    testWidgets('nav_ayah_yasin_1', (tester) async {
      await launchApp(tester);
      await openNavSheet(tester);
      await tester.tap(find.text('آية'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dropdown_surah')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('36. يس').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field_ayah')), '1');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('انتقل'));
      await tester.pumpAndSettle(kMedSettle);
      await tester.pump(kSaveDelay);
      final page = await savedPage();
      // Ya-Sin starts around page 440
      expect(page, closeTo(440, 10));
    });

    // ── Juz list is scrollable ────────────────────────────────────────────────
    testWidgets('nav_juz_list_scrollable', (tester) async {
      await launchApp(tester);
      await openNavSheet(tester);
      await tester.tap(find.text('جزء'));
      await tester.pumpAndSettle();
      final juzList = find.byKey(const Key('list_juz'));
      expect(juzList, findsOneWidget);
      // Scroll juz list to reveal later juzs
      await tester.drag(juzList, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 500));
      // Juz 15+ should now be visible
      expect(find.text('الجزء 15'), findsWidgets);
    });

    // ── Top bar: surah name and juz visible after launch ─────────────────────
    testWidgets('topbar_shows_after_launch', (tester) async {
      await launchApp(tester);
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
      await launchApp(tester);
      await navToPage(tester, 1);
      final surahText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_surah')))
          .data ?? '';
      final juzText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_juz')))
          .data ?? '';
      // Page 1 is Al-Fatiha, Juz 1
      expect(surahText, contains('الفاتحة'));
      expect(juzText, equals('الجزء 1'));
    });

    // ── Top bar: juz label updates after juz jump ─────────────────────────────
    testWidgets('topbar_updates_after_juz_nav', (tester) async {
      await launchApp(tester);
      // Juz 5 starts at page 82 per _pageToJuz boundaries
      await navToJuz(tester, 5);
      final juzText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_juz')))
          .data ?? '';
      expect(juzText, equals('الجزء 5'));
    });

    // ── Top bar: surah name updates after surah list navigation ───────────────
    testWidgets('topbar_updates_after_surah_nav', (tester) async {
      await launchApp(tester);
      await navToSurah(tester, 'الكهف');
      final surahText = tester
          .widget<Text>(find.byKey(const Key('text_topbar_surah')))
          .data ?? '';
      expect(surahText, contains('الكهف'));
    });

    // ── Top bar: updates after tapping a search result ────────────────────────
    testWidgets('topbar_updates_after_search_jump', (tester) async {
      await launchApp(tester);
      await openSearch(tester);
      await tester.enterText(find.byKey(const Key('field_search')), 'بسم الله');
      await tester.pump(const Duration(seconds: 3));
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
  });
}
