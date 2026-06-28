# QuranER — Integration Test Suite

Automated end-to-end tests that run directly on a physical Android device.
No mocking, no stubs — every test exercises the full app stack including
SQLite, SharedPreferences, Firebase, and real widget rendering.

---

## Quick Start

```bash
# Full suite (~63 tests, allow ~15 minutes)
flutter test integration_test/app_test.dart -d R5CY10APEAV --timeout=600s

# Single group
flutter test integration_test/sequential_test.dart          -d R5CY10APEAV
flutter test integration_test/independent/wird_test.dart    -d R5CY10APEAV
flutter test integration_test/independent/search_test.dart  -d R5CY10APEAV
flutter test integration_test/independent/nav_test.dart     -d R5CY10APEAV
flutter test integration_test/independent/autoscroll_test.dart -d R5CY10APEAV
flutter test integration_test/independent/dashboard_test.dart  -d R5CY10APEAV

# List connected devices
flutter devices
```

---

## File Structure

```
integration_test/
├── app_test.dart               — Main runner; imports and runs all groups
├── helpers.dart                — Shared test utilities and timing constants
├── sequential_test.dart        — 20 ordered tests (state accumulates)
└── independent/
    ├── wird_test.dart          —  8 wird/habit tests (each resets state)
    ├── search_test.dart        —  7 search tests
    ├── nav_test.dart           — 12 navigation tests (page/surah/juz/ayah)
    ├── autoscroll_test.dart    —  7 auto-scroll tests
    └── dashboard_test.dart     — 10 home dashboard tests
```

---

## Test Design: Two Strategies

### Sequential Tests (`sequential_test.dart`)

All 20 tests run in **declaration order** within a single `flutter test` run.

- Device state (SharedPreferences + SQLite) **accumulates** between tests — each test builds on the previous one's outcome.
- A **single `setUpAll`** resets all state at the start of the group.
- Covers the main user journey end-to-end: cold start → scroll → position save/restore → auto-scroll → search → navigation → wird setup.

| # | Test | What it verifies |
|---|------|-----------------|
| 01 | `cold_start_no_plan` | Home tab shows, "ابدأ من البداية", setup card visible |
| 02 | `switch_to_reader_tab` | Reader tab accessible, ayah list renders |
| 03 | `scroll_saves_page` | Scrolling updates `current_page` in SharedPreferences |
| 04 | `position_restored` | Fresh app load reads saved page correctly |
| 05 | `autoscroll_advances_position` | Autoscroll moves position forward |
| 06 | `autoscroll_hides_nav` | NavigationBar collapses to height 0 during autoscroll |
| 07 | `autoscroll_stop_restores_nav` | Stop restores nav labels |
| 08 | `speed_buttons_work` | Speed up/down changes the displayed level |
| 09 | `search_shows_results` | Searching "الرحمن" renders the results list |
| 10 | `search_tap_closes_overlay` | Tapping a result closes the search overlay |
| 11 | `nav_page_50` | Nav sheet jumps reader to page 50 (±5) |
| 12 | `nav_surah_kahf` | Surah search jumps to Al-Kahf (~page 293) |
| 13 | `nav_juz_5` | Juz 5 jumps to page 82 (±10) |
| 14 | `nav_ayah_baqarah_255` | Ayah mode: sura 2, aya 255 → page 42 (±8) |
| 15 | `dashboard_shows_reading_position` | Home tab shows saved sura name |
| 16 | `wird_setup_opens_and_saves` | Setup sheet opens, save closes it, wird card appears |
| 17 | `read_now_switches_to_reader` | "اقرأ الآن" button switches to reader tab |
| 18 | `continue_reading_switches_to_reader` | Continue card switches to reader tab |
| 19 | `autoscroll_multiple_bursts` | Three autoscroll start/stop cycles, no crash |
| 20 | `search_no_results_message` | Gibberish query shows "لا توجد نتائج" |

### Independent Tests (`independent/`)

Each test runs in isolation. A **`setUp`** before every test calls `UserDb.resetForTest()` which:
1. Closes and deletes `user_data.db`
2. Calls `SharedPreferences.clear()`

This guarantees every test starts from a clean state regardless of prior failures.

---

## Independent Test Groups

### Wird / Habit (`wird_test.dart`, 8 tests)

| Test | Verifies |
|------|----------|
| `no_plan_shows_setup_card` | Setup card + invite text visible when no plan |
| `save_pages_plan` | صفحات plan saves, wird card appears |
| `save_ayahs_plan` | آيات plan saves |
| `save_minutes_plan` | دقائق plan saves |
| `edit_plan_reopens_sheet` | "تعديل" link re-opens setup sheet |
| `slider_changes_value` | Slider drag changes value without crash |
| `progress_starts_at_zero` | "0 من X" shown after fresh plan |
| `read_now_switches_tab` | "اقرأ الآن" switches to reader tab |
| `with_plan_starts_on_reader` | Returning user with plan starts on reader tab |

### Search (`search_test.dart`, 7 tests)

| Test | Verifies |
|------|----------|
| `search_overlay_opens` | Search field visible after tapping search button |
| `short_query_no_results` | Queries < 3 chars don't trigger search |
| `known_query_returns_results` | "الرحمن الرحيم" renders the results list |
| `no_results_message_shown` | Rare query shows "لا توجد نتائج" |
| `close_button_dismisses_overlay` | × button closes search overlay |
| `result_tap_closes_overlay` | Tapping result closes overlay |
| `result_tap_navigates` | Result tap leaves reader at a valid page (1–604) |
| `multiple_searches_in_row` | Three consecutive searches, no crash |

### Navigation (`nav_test.dart`, 12 tests)

| Test | Verifies |
|------|----------|
| `nav_sheet_opens` | All four mode chips visible |
| `nav_page_1` | Jump to page 1 |
| `nav_page_604` | Jump to last page |
| `nav_page_300` | Jump to middle page |
| `nav_page_two_jumps` | Two consecutive page jumps |
| `nav_surah_fatiha` | Jump to Al-Fatiha → page 1 |
| `nav_surah_baqarah` | Jump to Al-Baqarah → page ~2 |
| `nav_surah_search_filters` | Search in surah list filters results |
| `nav_juz_1` | Jump to Juz 1 → page 1 |
| `nav_juz_15` | Jump to Juz 15 → page ~282 |
| `nav_juz_30` | Jump to Juz 30 → page ~582 |
| `nav_ayah_fatiha_1` | Ayah mode: Sura 1, Aya 1 → page 1 |
| `nav_ayah_yasin_1` | Ayah mode: Sura 36 (Ya-Sin) → page ~440 |
| `nav_juz_list_scrollable` | Juz list scrolls to reveal later entries |
| `topbar_shows_after_launch` | Both surah name and juz labels non-empty after app boot |
| `topbar_updates_after_page_nav` | Page 1 → top bar shows 'سورة الفاتحة' and 'الجزء 1' |
| `topbar_updates_after_juz_nav` | Juz 5 jump → top bar shows 'الجزء 5' |
| `topbar_updates_after_surah_nav` | Surah nav to Al-Kahf → top bar shows 'سورة الكهف' |
| `topbar_updates_after_search_jump` | Search result tap → top bar labels populated |

### Auto-Scroll (`autoscroll_test.dart`, 7 tests)

| Test | Verifies |
|------|----------|
| `autoscroll_starts` | Position advances after 5 s of autoscroll |
| `autoscroll_hides_appbar` | Speed buttons accessible (AppBar slid off-screen) |
| `speed_up_increments_level` | Two taps: 1→2→3 |
| `speed_down_decrements_level` | Bump up then down: 2→1 |
| `speed_min_clamped` | Five taps down never goes below 1 |
| `autoscroll_pause_stops_movement` | Page doesn't advance while paused |
| `autoscroll_pause_and_resume` | Resume after pause continues advancing |
| `nav_visible_after_stop` | Nav labels visible again after stop |

### Dashboard / Home Tab (`dashboard_test.dart`, 10 tests)

| Test | Verifies |
|------|----------|
| `no_plan_shows_invite` | Invite card + subtitle visible |
| `continue_card_always_present` | Card renders regardless of plan state |
| `no_prior_reading_shows_default` | "ابدأ من البداية" when no saved position |
| `dashboard_reflects_reader_position` | Sura name updates after scrolling in reader |
| `continue_card_tap_switches_tab` | Card tap navigates to reader |
| `with_plan_shows_wird_section` | "وردك اليوم" + "متابعة الورد اليومي" visible |
| `with_plan_shows_progress_bar` | LinearProgressIndicator rendered |
| `read_now_visible_when_not_done` | "اقرأ الآن" appears when plan not complete |
| `streak_card_visible` | "ابدأ اليوم" shown for 0-day streak |
| `tab_round_trip_preserves_state` | Home→Reader→Home round trip, state intact |

---

## Widget Keys Reference

Keys added to `lib/main.dart` for test targeting:

| Key | Widget | Location |
|-----|--------|----------|
| `btn_nav` | Navigation sheet button | Reader AppBar (right) |
| `btn_search` | Search overlay button | Reader AppBar (right) |
| `text_topbar_surah` | Surah name `Text` (`'سورة X'`) | Reader AppBar bottom strip |
| `text_topbar_juz` | Juz number `Text` (`'الجزء N'`) | Reader AppBar bottom strip |
| `btn_autoscroll` | Play/Pause toggle | Reader bottom player bar |
| `btn_speed_down` | Speed − button | Reader bottom player bar |
| `btn_speed_up` | Speed + button | Reader bottom player bar |
| `text_speed_level` | Speed level `Text` (e.g. `'1'`) | Reader bottom player bar |
| `ayah_list` | Main ayah `ListView.builder` | Reader body |
| `field_search` | Search `TextField` | Search overlay |
| `list_search_results` | Results `ListView.separated` | Search overlay |
| `field_page` | Page number `TextField` | Nav sheet — page mode |
| `field_surah_search` | Surah search `TextField` | Nav sheet — surah mode |
| `list_surah` | Filtered surah `ListView` | Nav sheet — surah mode |
| `list_juz` | Juz `ListView` | Nav sheet — juz mode |
| `dropdown_surah` | Surah `DropdownButtonFormField` | Nav sheet — ayah mode |
| `field_ayah` | Ayah number `TextField` | Nav sheet — ayah mode |
| `slider_wird` | Wird target `Slider` | Wird setup sheet |
| `btn_wird_save` | Save `ElevatedButton` | Wird setup sheet |
| `card_continue` | "تابع القراءة" `GestureDetector` | Home → continue card |
| `card_wird_setup` | Setup invite `GestureDetector` | Home → wird card (no plan) |
| `btn_read_now` | "اقرأ الآن" `GestureDetector` | Home → wird card (with plan) |

---

## SharedPreferences Keys (used in assertions)

| Key | Type | Meaning |
|-----|------|---------|
| `current_page` | `int` | Last known Mushaf page (1–604) |
| `current_sura` | `String` | Last known surah name (Arabic) |
| `last_min_id` | `int` | Min visible ayah ID (position anchor) |
| `anchor_offset` | `double` | Scroll offset within anchor ayah |
| `font_scale` | `double` | Text size multiplier |
| `is_dark` | `bool` | Dark mode preference |

---

## `UserDb.resetForTest()`

Added to `UserDb` for test teardown. Closes and deletes `user_data.db` then clears SharedPreferences:

```dart
static Future<void> resetForTest() async {
  await instance._db?.close();
  instance._db = null;
  final dbDir = await getDatabasesPath();
  await deleteDatabase(join(dbDir, 'user_data.db'));
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  // Suppress tutorial overlay so it doesn't block UI during tests.
  await prefs.setBool('tutorial_shown', true);
}
```

---

## Timing Constants (`helpers.dart`)

| Constant | Value | Used for |
|----------|-------|----------|
| `kLongSettle` | 10 s | Initial app boot (`pumpAndSettle`) |
| `kMedSettle` | 5 s | Navigation / overlay transitions |
| `kSaveDelay` | 4 s | Wait for position auto-save debounce |

---

## Notes

- **`pumpAndSettle` vs `pump`**: Auto-scroll runs a continuous ticker, so `pumpAndSettle` never settles while scrolling is active. Always use `pump(duration)` to advance time during autoscroll, then `pumpAndSettle` after stopping.
- **Page assertions use `closeTo`**: The reader may land 1–5 pages away from the target due to ayah boundary snapping. Tolerances are set conservatively.
- **Firebase**: The `main()` guard `if (Firebase.apps.isEmpty)` prevents duplicate-app errors when `app.main()` is called multiple times within the same test binary.
- **`IndexedStack`**: Both tabs are always mounted. The `AyahsPage` initialises and loads from DB even when the home tab is visible — this is intentional and tests rely on it.
