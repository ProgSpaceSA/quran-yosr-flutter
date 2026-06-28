import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_er/main.dart' as app;

const kLongSettle = Duration(seconds: 10);
const kMedSettle = Duration(seconds: 5);
const kSaveDelay = Duration(seconds: 4);

/// Boot the app (calls runApp). Safe to call multiple times — Firebase guard
/// in main() prevents duplicate-app errors.
Future<void> launchApp(WidgetTester tester) async {
  app.main();
  await tester.pumpAndSettle(kLongSettle);
}

/// Drag the ayah ListView upward by [pixels] logical pixels, then wait for
/// the auto-save debounce to fire.
Future<void> scrollAyahs(WidgetTester tester, double pixels) async {
  final list = find.byKey(const Key('ayah_list'));
  await tester.drag(list, Offset(0, -pixels));
  await tester.pump(kSaveDelay);
}

/// Switch to the bottom nav tab. 0 = لوحتي (Home), 1 = القرآن (Reader).
/// Dismisses any open bottom sheet (e.g. wird setup) before tapping the nav bar.
Future<void> switchToTab(WidgetTester tester, int tab) async {
  // The wird setup modal uses showModalBottomSheet which puts a ModalBarrier
  // between the sheet and the nav bar, blocking taps on it.
  // Tap the barrier scrim (top of screen, above the sheet) to dismiss it.
  if (find.byType(ModalBarrier).evaluate().isNotEmpty) {
    await tester.tapAt(const Offset(200, 80));
    await tester.pumpAndSettle(kMedSettle);
  }
  final label = tab == 0 ? 'لوحتي' : 'القرآن';
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle(kMedSettle);
}

/// Open the reader nav sheet (انتقل إلى button).
// The nav sheet defaults to surah mode (_mode = 1). Poll for the 'سورة' chip
// which is always present as a mode label regardless of current mode.
Future<void> openNavSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('btn_nav')));
  for (int i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('سورة').evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle(kMedSettle);
}

/// Open the search overlay.
Future<void> openSearch(WidgetTester tester) async {
  // Poll until the reader AppBar is ready (past _initialLoading state).
  for (int i = 0; i < 100; i++) {
    if (find.byKey(const Key('btn_search')).evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.byKey(const Key('btn_search')));
  for (int i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('field_search')).evaluate().isNotEmpty) break;
  }
  await tester.pumpAndSettle(kMedSettle);
}

/// Toggle auto-scroll on/off.
Future<void> tapAutoScroll(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('btn_autoscroll')));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Read the persisted current page from SharedPreferences.
Future<int> savedPage() async {
  final p = await SharedPreferences.getInstance();
  return p.getInt('current_page') ?? 1;
}

/// Read the persisted surah name.
Future<String> savedSura() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('current_sura') ?? '';
}

/// Trigger a micro-scroll on the ayah list to flush the position save debounce.
/// Used after jumpTo-based navigation which doesn't always fire a scroll notification.
Future<void> _flushPageSave(WidgetTester tester) async {
  final list = find.byKey(const Key('ayah_list'));
  if (list.evaluate().isNotEmpty) {
    await tester.drag(list, const Offset(0, -1));
    await tester.pump(kSaveDelay);
  }
}

/// Navigate the nav sheet to page [pageNo], then close.
Future<void> navToPage(WidgetTester tester, int pageNo) async {
  await openNavSheet(tester);
  // Sheet defaults to surah mode — switch to page mode first.
  await tester.tap(find.text('صفحة').last);
  // Poll until field_page appears.
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('field_page')).evaluate().isNotEmpty) break;
  }
  await tester.enterText(find.byKey(const Key('field_page')), '$pageNo');
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('انتقل'));
  await tester.pumpAndSettle(kMedSettle);
  await _flushPageSave(tester);
}

/// Navigate the nav sheet to juz [juzNo].
Future<void> navToJuz(WidgetTester tester, int juzNo) async {
  await openNavSheet(tester);
  await tester.tap(find.text('جزء'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await tester.tap(find.text('الجزء $juzNo'));
  await tester.pumpAndSettle(kMedSettle);
  await _flushPageSave(tester);
}

/// Navigate the nav sheet to a surah by searching its name [query] and
/// tapping the first matching result.
Future<void> navToSurah(WidgetTester tester, String query) async {
  await openNavSheet(tester);
  await tester.tap(find.text('سورة'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('field_surah_search')), query);
  await tester.pump(const Duration(milliseconds: 300));
  // Tap the first result
  final result = find.byKey(const Key('list_surah'));
  if (result.evaluate().isNotEmpty) {
    await tester.tap(find.descendant(of: result, matching: find.byType(ListTile)).first);
  } else {
    await tester.tap(find.text(query).last);
  }
  await tester.pumpAndSettle(kMedSettle);
  await _flushPageSave(tester);
}

/// Open wird setup sheet from the setup prompt card.
/// No-ops if the sheet is already open (auto-opened on first launch with no plan).
Future<void> openWirdSetup(WidgetTester tester) async {
  if (find.byKey(const Key('slider_wird')).evaluate().isNotEmpty) {
    return; // Already open — auto-opened on first launch
  }
  await tester.tap(find.byKey(const Key('card_wird_setup')));
  await tester.pumpAndSettle();
}

/// Set a wird plan via the setup sheet. [type] is 'صفحات'/'آيات'/'دقائق',
/// [sliderDelta] is a horizontal drag in logical pixels to shift the slider.
Future<void> saveWirdPlan(
    WidgetTester tester, String type, double sliderDelta) async {
  await tester.tap(find.text(type));
  await tester.pump(const Duration(milliseconds: 200));
  if (sliderDelta != 0) {
    await tester.drag(
        find.byKey(const Key('slider_wird')), Offset(sliderDelta, 0));
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.tap(find.byKey(const Key('btn_wird_save')));
  await tester.pumpAndSettle(kMedSettle);
}
