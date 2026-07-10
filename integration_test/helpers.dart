import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_er/main.dart' as app;

// Use short pump intervals so the ADB connection stays alive on high-refresh
// Android 16 devices.  Long pauses (≥ 5 s) between pumps cause the device to
// drop the connection.  pumpAndSettle with 200 ms is still correct: the cursor
// animation's 500 ms timer means hasScheduledFrame is false between blinks, so
// pumpAndSettle exits after ≤ 2 pumps.  The pin-frame loop (60 frames) finishes
// in ≈ 10 × 200 ms = 2 s.
const kLongSettle = Duration(milliseconds: 200);
const kMedSettle = Duration(milliseconds: 200);
const kSaveDelay = Duration(seconds: 4);

/// Boot the app (calls runApp). Safe to call multiple times — Firebase guard
/// in main() prevents duplicate-app errors.
///
/// Polls for btn_nav (the reader AppBar nav button) instead of using
/// pumpAndSettle with a fixed timeout.  This handles two cases cleanly:
///   1. Fresh start: waits for initState async DB load to complete
///   2. Retained state (Android 16 fast transition): btn_nav already visible
///
/// [resetDb] — when true, wipes UserDb + SharedPreferences and seeds a default
/// 5-page wird plan before starting the app.  Pass true for independent tests
/// that need clean state.  This MUST be done here (not in setUp) so a pump
/// fires BEFORE the async DB work, keeping the ADB connection alive on Android
/// 16 (which drops after ~5 s of silence; setUp has no pump).
Future<void> launchApp(WidgetTester tester, {bool resetDb = false}) async {
  if (resetDb) {
    // Reset runs before runApp so no pump is possible here.  This is safe:
    // the inter-test gap (tearDown + this reset) is ~2 s, well under the
    // Android-16 ADB drop threshold of ~5 s.
    await app.UserDb.resetForTest();
    await app.UserDb.instance.savePlan('pages', 5);
  }
  app.main();
  for (int i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    // Plan case: reader tab active, btn_nav appears once _loadInitial completes.
    if (find.byKey(const Key('btn_nav')).evaluate().isNotEmpty) break;
    // No-plan case: break when the auto-opened wird setup modal is rendered.
    // slider_wird lives INSIDE the modal, so its presence means:
    //   (a) _HomePageState._loadData() has completed (_plan == null, !_loading)
    //   (b) the modal route has been pushed AND its first frame has been built
    //   (c) ModalBarrier is in the tree — switchToTab can safely dismiss it
    // This is one pump later than card_wird_setup (which appears the frame
    // before addPostFrameCallback fires the modal).  That one extra pump is
    // critical: without it ModalBarrier is empty and the dismiss is skipped.
    if (find.byKey(const Key('slider_wird')).evaluate().isNotEmpty) break;
  }
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
// Retries up to 3 times — after a navigation the AppBar tap can be briefly
// blocked by a residual scroll animation.
Future<void> openNavSheet(WidgetTester tester) async {
  for (int attempt = 0; attempt < 3; attempt++) {
    await tester.tap(find.byKey(const Key('btn_nav')), warnIfMissed: false);
    bool found = false;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('سورة').evaluate().isNotEmpty) { found = true; break; }
    }
    if (found) break;
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

/// Wait for the position-save debounce to fire without a single long pump.
/// 40 × 100 ms = 4 s total; each 100 ms pump keeps the ADB connection alive on
/// Android 16 (which drops the connection after ~5 s of silence).
Future<void> waitForSave(WidgetTester tester) async {
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Flush the position save debounce after navigation.
/// Navigation's own _doSaveReadingPosition() call starts the debounce;
/// we just need to pump long enough for it to fire.
///
/// IMPORTANT: Do NOT drag the list here. A drag < kTouchSlop (18 px) is
/// recognised by Flutter's gesture arena as a *tap*, which fires the outer
/// GestureDetector's onTap: _toggleFocusMode callback — hiding the AppBar and
/// breaking any subsequent navToPage call.
Future<void> _flushPageSave(WidgetTester tester) async {
  await waitForSave(tester);
}

/// Navigate the nav sheet to page [pageNo], then close.
///
/// Avoids openNavSheet/pumpAndSettle because the surah search field's cursor
/// animation keeps scheduling frames indefinitely, causing pumpAndSettle to
/// spin for ~30 s per call. Instead we poll with 100 ms pumps so we can tap
/// tab_page the moment it appears — without waiting for full settle.
Future<void> navToPage(WidgetTester tester, int pageNo) async {
  for (int attempt = 0; attempt < 3; attempt++) {
    // If focus mode is active, the AppBar (and btn_nav) is collapsed to height 0.
    // Tapping btn_nav at y=0 misses _showNavSheet. Detect via rect height and
    // dismiss focus mode by tapping the reading area before opening the sheet.
    final btnNavFinder = find.byKey(const Key('btn_nav'));
    if (btnNavFinder.evaluate().isNotEmpty) {
      final rect = tester.getRect(btnNavFinder);
      if (rect.height <= 1.0) {
        debugPrint('[navToPage] attempt=$attempt focus mode active (btn_nav h=${rect.height}) — tapping to exit');
        await tester.tapAt(const Offset(200, 400));
        // Wait for the AppBar slide-in animation (320 ms).
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    }
    // Tap btn_nav to open the sheet.
    debugPrint('[navToPage] attempt=$attempt tapping btn_nav');
    await tester.tap(find.byKey(const Key('btn_nav')), warnIfMissed: false);

    // Poll until the page tab chip is visible (100 ms each, max 5 s).
    bool tabVisible = false;
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('tab_page')).evaluate().isNotEmpty) {
        tabVisible = true;
        debugPrint('[navToPage] attempt=$attempt tab_page found at i=$i');
        break;
      }
    }
    if (!tabVisible) {
      debugPrint('[navToPage] attempt=$attempt tab_page NOT found after 50 pumps');
      await tester.pump(const Duration(seconds: 1));
      continue;
    }

    // Tap the page-mode tab.
    debugPrint('[navToPage] attempt=$attempt tapping tab_page');
    await tester.tap(find.byKey(const Key('tab_page')));

    // Poll until field_page appears (100 ms each, max 3 s).
    bool fieldVisible = false;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(const Key('field_page')).evaluate().isNotEmpty) {
        fieldVisible = true;
        debugPrint('[navToPage] attempt=$attempt field_page found at i=$i');
        break;
      }
    }
    if (fieldVisible) break;

    debugPrint('[navToPage] attempt=$attempt field_page NOT found after 30 pumps');
    // Mode switch didn't produce field_page — close any residual overlay.
    if (find.byType(ModalBarrier).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(200, 80));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  await tester.enterText(find.byKey(const Key('field_page')), '$pageNo');
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.text('انتقل'));
  await tester.pumpAndSettle(kMedSettle);
  await _flushPageSave(tester);
  await tester.pumpAndSettle(kMedSettle);
}

/// Navigate the nav sheet to juz [juzNo].
Future<void> navToJuz(WidgetTester tester, int juzNo) async {
  await openNavSheet(tester);
  await tester.tap(find.text('جزء'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  final juzList = find.byKey(const Key('list_juz'));
  // scrollUntilVisible requires a unique finder but during scroll transitions
  // the same item can appear twice (cache + viewport). Use manual drag instead.
  // Each ListTile is ~48px; the list is 300px tall (~6 visible items).
  // Drag in chunks of 250px until the item appears.
  for (int i = 0; i < 15; i++) {
    final juzItem =
        find.descendant(of: juzList, matching: find.text('الجزء $juzNo'));
    if (juzItem.evaluate().isNotEmpty) break;
    await tester.drag(juzList, const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 200));
  }
  final juzItem =
      find.descendant(of: juzList, matching: find.text('الجزء $juzNo'));
  await tester.tap(juzItem.first);
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
