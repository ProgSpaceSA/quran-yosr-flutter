# QuranER — Development Log

## Project Overview
A Flutter app that renders the full Quran text (6,236 ayahs) using the HafsSmart font,
loaded from a bundled SQLite database. Supports bidirectional infinite scroll, surah headers,
page boundaries, pinch-to-zoom, dark/light theme, fast-travel navigation, and full-text search.

---

## App Identity

| Field | Value |
|---|---|
| App name | القرآن الكريم يسر |
| Package ID | com.quraner.yosr |
| Primary color | `#053a3a` |

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Database | SQLite via `sqflite ^2.3.3` |
| Font | HafsSmart_08.ttf (custom Quran glyph encoding) |
| SVG rendering | `flutter_svg ^2.0.10` |
| Persistence | `shared_preferences ^2.3.2` |
| Links | `url_launcher ^6.3.1` |
| Screen wake | `wakelock_plus ^1.2.10` |
| Source DB | MySQL 8.0 → exported to SQLite via Python |
| Target | Android (emulator: `sdk gphone64 x86 64` / `emulator-5554`) |

---

## Key Files

| File | Purpose |
|---|---|
| `lib/main.dart` | Entire app (single-file architecture) |
| `assets/database/quran.db` | Bundled SQLite database (6,236 ayahs) |
| `assets/fonts/HafsSmart_08.ttf` | Quran font (private-use Unicode glyphs) |
| `database/schema.sql` | Original MySQL schema |
| `database/hafs_smart_v8_table_name.sql` | MySQL INSERT data (6,236 rows) |
| `database/export_to_sqlite.py` | Python script: MySQL → SQLite export |
| `pubspec.yaml` | Dependencies and asset declarations |

---

## Database Schema (`quran_ayahs`)

```sql
CREATE TABLE quran_ayahs (
  id             INT PRIMARY KEY AUTO_INCREMENT,
  sura_no        TINYINT UNSIGNED NOT NULL,
  aya_no         SMALLINT UNSIGNED NOT NULL,
  page           SMALLINT UNSIGNED,          -- Mushaf page (1–604)
  sura_name_ar   VARCHAR(50)  CHARSET utf8mb4,
  aya_text       TEXT         CHARSET utf8mb4 COLLATE utf8mb4_bin,  -- HafsSmart glyphs
  aya_text_emlaey TEXT        CHARSET utf8mb4,                       -- searchable Arabic
  ...
  FULLTEXT INDEX ft_emlaey (aya_text_emlaey)
);
```

**Important:** `aya_text` uses `utf8mb4_bin` collation → MySQL Python connector
returns `bytes`, not `str`. Must `decode('utf-8')` explicitly. In Flutter,
use `utf8.decode(value)` not `String.fromCharCodes(value)`.

---

## Architecture — `lib/main.dart`

### Models
- **`Ayah`** — single verse: `id, suraNo, ayaNo, page, suraNameAr, ayaText`
- **`_Item`** (abstract) — display list item, three subtypes:
  - `_SurahHeader` — surah name header (shown when sura changes)
  - `_PageMarker(page)` — page number + HR divider (shown when `page` field changes)
  - `_AyahRun(ayahs)` — consecutive ayahs on same page & same surah, rendered as inline flowing text
- **`SurahInfo`** — used in nav sheet surah list
- **`SearchResult`** — search overlay result row

### State — `_MyAppState`
- `_isDark: bool` — theme mode (default: `true`)
- `_splashDone: bool` — switches home from `_SplashScreen` to `AyahsPage`

### State — `_AyahsPageState`
- `_ayahs: List<Ayah>` — flat ordered list of loaded ayahs
- `_items: List<_Item>` — derived display items (recomputed by `_recomputeItems()`)
- `_minId / _maxId` — bounds for bidirectional pagination
- `_chunk = 30` — rows per DB fetch
- `_fontScale / _baseFontScale / _isPinching` — pinch-to-zoom state
- `_showSearch / _searchCtrl / _searchResults / _searching` — search overlay state
- `_autoScrolling / _userDragging / _speedLevel / _autoScrollTicker / _lastTickElapsed` — auto-scroll state (vsync Ticker)
- `_navigating: bool` — true during the entire navigate+back-buffer+correctBy+pinFrame sequence; overlay shown; `_onScroll` blocked
- `_justNavigated: bool` — blocks `_loadPrev` from `_onScroll` right after navigation until user scrolls past 800 px
- `_highlightId / _highlightKey / _tapHighlight` — ayah highlight: `_highlightId` is the highlighted ayah ID; `_highlightKey` (GlobalKey) anchors the widget for `ensureVisible`; `_tapHighlight = true` means it was set by user tap (auto-clears on scroll-out) vs navigation
- `_lastKnownSaveId` — last ayah ID saved to SharedPreferences; also used to prevent duplicate saves

### Data Flow
```
SQLite (assets/database/quran.db)
  → copied to device on first launch (_openDb)
  → _fetch(where, args, order) → List<Ayah>
  → _ayahs (flat list)
  → _recomputeItems() → _items (display list)
  → ListView.builder renders _SurahHeader | _PageMarker | _AyahRun
```

### Scroll Loading
- `ScrollController` listener triggers `_loadMore()` (scroll near bottom) or `_loadPrev()` (scroll near top)
- Prepend scroll restoration: capture `oldMax = maxScrollExtent` before `setState`, then `jumpTo(pixels + (newMax - oldMax))` in `postFrameCallback`

### Navigation
- `_navigateTo(startId)` — clears `_ayahs/_items`, fetches pages around `startId`, then calls `_loadPrevAndDismiss()` to preload back-buffer and run pinFrame
- Startup resume treated identically to search navigation: `_navigating = true` overlay, same `_loadPrevAndDismiss` + `pinFrame` path
- `_loadPrevAndDismiss()` — loads 30 ayahs before `_minId`, calls `correctBy(newMax - oldMax)`, then runs `pinFrame(60, initialMax, 0)`
- `pinFrame(framesLeft, prevMax, stableCount)` — fires `ensureVisible` every frame; exits when `maxScrollExtent` is stable (Δ < 5 px) for 5 consecutive frames or timeout; then dismisses overlay and schedules 500 ms post-settle re-pin

### Highlight System
- `_highlightId` set by navigation (`_tapHighlight = false`) or user tap (`_tapHighlight = true`)
- `_highlightKey` (GlobalKey) is attached via a zero-size `WidgetSpan(child: SizedBox.shrink(key: _highlightKey))` inserted inline in the `_AyahRun` `RichText` at the highlight boundary — text flows continuously, no paragraph break
- Navigation highlights persist until the next navigation; tap highlights auto-clear in `_onScroll` when `_highlightKey.currentContext == null` (ayah scrolled outside `cacheExtent`)
- All ayah spans use `TapGestureRecognizer` for tap-to-highlight

---

## Features Implemented

| Feature | Notes |
|---|---|
| HafsSmart font rendering | `fontFamily: 'CustomFont'` in pubspec |
| Full Quran SQLite load | Bundled asset, copied to device storage on first launch |
| Bidirectional infinite scroll | Chunks of 30, scroll restoration on prepend |
| Surah name headers | Shown on sura boundary, with two HR dividers + light bg |
| Inline ayah flow | Ayahs within same sura+page run join with space, no line breaks |
| Page number markers | `_PageMarker` shown when `page` field changes; centered page number between two HR dividers |
| Pinch-to-zoom | `GestureDetector.onScaleUpdate`; `_isPinching` flag switches `ListView` to `NeverScrollableScrollPhysics` during pinch so scroll recognizer yields to scale recognizer; base scale re-anchored on first 2-finger frame |
| Dark / Light theme | `ThemeMode` toggle, dark default, sun/moon icons in AppBar |
| Fast-travel bottom sheet | 3 modes: page number (1–604), surah list, ayah (surah + aya number) |
| Full-text search | Blur overlay, `aya_text_emlaey LIKE '%query%'`, results after 3 chars |
| RTL layout | `Directionality(textDirection: TextDirection.rtl)` wrapping `MaterialApp` |
| Custom AppBar | LTR `Row`: theme+info on left, centered title, nav+search on right |
| Auto-scroll | Bottom bar: play/pause + 7-level speed control (reduced ~25% from v1); vsync `Ticker` (60/120 fps); stops on search/nav/info; yields to manual drag; triggers `_loadMore` ticker-side when near bottom |
| Splash screen | `_SplashScreen` widget: `#053a3a` bg + PNG logo (`quran-yosr-splash.png`), 2500 ms |
| SVG logos | Colored SVG logo in info dialog header |
| App icon | Generated from `quran-yosr-icon.svg` via `@resvg/resvg-js` + `flutter_launcher_icons` |
| Adaptive icon | Android 8+ adaptive icon with `#053a3a` background (`mipmap-anydpi-v26`) |
| Persistent position | `SharedPreferences` saves estimated visible ayah ID; restored on launch via navigation overlay + stability `pinFrame` (stable=5); save suppressed during loads |
| Tap-to-highlight | Tap any ayah → amber highlight; persists while on screen; auto-clears when off `cacheExtent` |
| Clickable links | Info dialog: source URL + mailto link via `url_launcher` |
| Screen wake | `WakelockPlus.enable()` on enter, `.disable()` on exit — phone stays on while reading |

---

## Known Gotchas

### `path` package name collision
`package:path/path.dart` exports a top-level `context` variable of type `Context`.
Inside `State` methods, `context` resolves to `State.context` (BuildContext) correctly,
but in lambdas or closures the compiler may resolve to `path.context` instead.
**Fix:** capture `final ctx = this.context` before passing to `showModalBottomSheet`.

### Search overlay overflow (keyboard)
`BackdropFilter` + `Container(alignment: topCenter)` constrains child height to the
container's remaining height. When keyboard is shown, this becomes very small.
**Fix:** Use `LayoutBuilder` inside the `Padding` to get actual post-keyboard available height.
`ConstrainedBox(maxHeight: (lc.maxHeight - 80).clamp(60, 360))` on the results list.

### NDK version warning (non-blocking)
```
sqflite_android requires Android NDK 27.0.12077973
Project configured with NDK 26.3.11579264
```
Fix: add `ndkVersion = "27.0.12077973"` in `android/app/build.gradle.kts` → `android { }`.
Build succeeds without this fix.

### `aya_text` stored as BLOB
MySQL `utf8mb4_bin` collation causes `aya_text` to return as `bytes` from both
Python connector and SQLite (if not decoded at export time).
**Fix (Python):** `v.decode('utf-8') if isinstance(v, (bytes, bytearray)) else v`
**Fix (Dart):** `_colToString()` helper using `utf8.decode(value as List<int>)`

---

## Python Export Script (`database/export_to_sqlite.py`)
- Connects with `charset='utf8mb4', use_unicode=True`
- Decodes all `bytes`/`bytearray` columns to `str` before inserting into SQLite
- Exports to `assets/database/quran.db`
- Run: `python database/export_to_sqlite.py` (requires `mysql-connector-python`)

---

## Dependency Versions (`pubspec.yaml`)
```yaml
dependencies:
  sqflite: ^2.3.3
  path: ^1.9.0
  url_launcher: ^6.3.1
  flutter_svg: ^2.0.10
  shared_preferences: ^2.3.2
  wakelock_plus: ^1.2.10

dev_dependencies:
  flutter_launcher_icons: ^0.13.1
```

Font:
```yaml
fonts:
  - family: CustomFont
    fonts:
      - asset: assets/fonts/HafsSmart_08.ttf
```

## App Icon Generation
SVG → PNG conversion done with Node.js `@resvg/resvg-js` (pure WASM, no native Cairo required):
```js
// C:\Users\Ali\AppData\Local\Temp\convert_icon.js
const { Resvg } = require('@resvg/resvg-js');
const svg = fs.readFileSync('C:/ClauseProjects/QuranER/assets/images/quran-yosr-icon.svg');
const resvg = new Resvg(svg, { fitTo: { mode: 'width', value: 1024 } });
fs.writeFileSync('.../quran-yosr-icon-1024.png', resvg.render().asPng());
```
Then: `flutter pub run flutter_launcher_icons`

---

## Emulator Setup
- Device: `sdk gphone64 x86 64` (`emulator-5554`)
- Run: `flutter run -d emulator-5554`
- NDK warning appears every build but does not block

---

## Session History (brief)

1. Switched font to `HafsSmart_08.ttf`
2. Created MySQL schema, imported `hafs_smart_v8_table_name.sql`
3. Exported MySQL → SQLite via Python; fixed UTF-8 pipeline
4. Built Flutter UI: load from SQLite, wrap, scroll
5. Added RTL, bidirectional scroll loading, surah headers, inline ayah flow
6. Added pinch-to-zoom, dark/light theme toggle
7. Added fast-travel bottom sheet (page / surah / ayah modes)
8. Added search button with blur overlay, 3-char suggestions, tap-to-navigate
9. Fixed `Context`/`BuildContext` collision (`path` package shadow)
10. Fixed search overlay overflow when keyboard shown (LayoutBuilder)
11. Added page number markers + HR dividers at page boundaries
12. Added custom AppBar: LTR Row (theme+info | title | nav+search), dark default
13. Added `url_launcher` — clickable source URL + email in info dialog
14. Added auto-scroll bottom bar: play/pause + 5-level speed control
15. Added splash screen (`_SplashScreen`, `#053a3a` + white SVG logo, 2500 ms)
16. Added colored SVG logo to info dialog header
17. Changed app name → `القرآن الكريم يسر`, package ID → `com.quraner.yosr`
18. Generated launcher icon from SVG via Node.js resvg-js + flutter_launcher_icons
19. Added `shared_preferences` — saves `last_min_id` + `last_scroll_offset` on scroll (debounced 2 s) and restores on app launch
20. Added `wakelock_plus` — screen stays on while app is open
21. Splash: switched from SVG to PNG (`quran-yosr-splash.png`)
22. Auto-scroll: replaced `Timer.periodic(50ms)` with vsync `Ticker` (`SingleTickerProviderStateMixin`) for 60/120 fps smoothness; extended to 7 speed levels (`_kSpeedPxPerMs`)
23. Scroll restore fix: save estimated visible ayah ID (scroll fraction × ayah count) instead of `_minId`; on launch load from that exact ayah ID → user resumes at correct position
24. Scroll prepend jump fix: replaced `ScrollController.jumpTo(pixels + delta)` with `ScrollPosition.correctBy(delta)` in `_loadPrev` → silent pixel adjustment, no scroll notifications fired, no visible frame jump when loading previous content
25. Removed `_preventPrevLoad` flag and `_restoringPosition` 800ms spinner — both were workarounds for the jump; `correctBy` eliminates the root cause, making them unnecessary
26. Added navigation overlay (`_navigating` flag + semi-transparent `Positioned.fill` with spinner) covering the entire navigate+back-buffer+correctBy sequence; `_onScroll` returns early while overlay is shown, preventing page-mixing bug
27. Replaced ad-hoc settle loop with stability-based `pinFrame`: recursive `addPostFrameCallback` fires `ensureVisible` every frame, requires `maxScrollExtent` Δ < 5 px for 5 consecutive frames before dismissing overlay (was 3, raised to 5 after false-positive in logs)
28. Treated startup position restore identically to search navigation: `_loadInitial` sets `_navigating = true`, `_highlightId = savedId`, `_highlightKey = GlobalKey()`, then calls `_loadPrevAndDismiss()` → same pinFrame path as search; eliminates ~10-page startup jump
29. Added `_justNavigated` flag to block `_loadPrev` from `_onScroll` right after navigation/startup until user scrolls past 800 px; prevents cascading `_loadPrev` calls while pinFrame is still running
30. Position save guard: added `!_loadingPrev && !_loadingMore` condition around `_onScroll` position save — prevents fraction-based index drift when list length changes during append/prepend
31. Added 500 ms post-dismiss quiet re-pin: after overlay dismisses, `Future.delayed(500ms)` re-fires `ensureVisible` to correct any residual layout shift; bails if `_userDragging` or `currentContext == null`; gate changed from `_lastKnownSaveId` check (was blocked by layout-induced scroll updates) to `_userDragging` only
32. `_AyahRun` highlight rendering: replaced `Column([RichText(before), RichText(fromHl)])` split (which created a visible paragraph break) with a single `RichText` containing a zero-size `WidgetSpan(child: SizedBox.shrink(key: _highlightKey))` anchor at the highlight boundary — text flows continuously, `ensureVisible` still lands precisely
33. Added `TapGestureRecognizer` to every ayah `TextSpan`; tap sets `_highlightId + _highlightKey + _tapHighlight = true`; tap highlight auto-clears in `_onScroll` when `_highlightKey.currentContext == null`; navigation always sets `_tapHighlight = false`
34. Pinch-to-zoom reliability: added `_isPinching` bool; on first frame with 2 fingers re-anchors `_baseFontScale`; sets `ListView.physics = NeverScrollableScrollPhysics()` during pinch so vertical-drag recognizer yields to scale recognizer; restores `ClampingScrollPhysics` on `onScaleEnd`
35. Auto-scroll manual override: `NotificationListener<ScrollNotification>` around `ListView` sets `_userDragging = true` on `ScrollStartNotification` with dragDetails, `false` on `ScrollEndNotification`; ticker skips `jumpTo` while `_userDragging`
36. Auto-scroll speed table reduced ~25% across all 7 levels: `[0.007, 0.018, 0.045, 0.10, 0.19, 0.34, 0.60]` px/ms
37. Auto-scroll ticker now explicitly calls `_loadMore()` when within 800 px of `maxScrollExtent`; fixes hang when zooming out shrinks content height and `jumpTo(maxScrollExtent)` becomes a no-op (no scroll notification → `_onScroll` never fires → `_loadMore` never triggered)
38. Auto-scroll stops automatically when opening search (`_openSearch`), fast-travel sheet (`_showNavSheet`), or info dialog (`_showInfoDialog`)
39. Search field keyboard jump fix: removed `MediaQuery.of(context).viewInsets.bottom` from search overlay bottom padding; Scaffold `resizeToAvoidBottomInset: true` (default) already shrinks the body — adding `viewInsets.bottom` was double-counting the keyboard height and pushing the card above the screen
