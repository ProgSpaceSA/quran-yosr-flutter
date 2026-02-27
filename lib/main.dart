import 'dart:async';
import 'package:flutter/scheduler.dart' show Ticker;
import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() => runApp(const MyApp());

// ── Theme ──────────────────────────────────────────────────────────────────

const _bgLight = Color(0xFFFFFFFF);
const _bgDark  = Color(0xFF1C1C1E);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: isDark ? _bgDark : _bgLight,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? _bgDark : _bgLight,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: isDark ? Colors.white24 : Colors.black12,
  );
}

// ── App root ───────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDark = true;
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
        home: _splashDone
            ? AyahsPage(
                isDark: _isDark,
                onToggleTheme: () => setState(() => _isDark = !_isDark),
              )
            : _SplashScreen(onDone: () => setState(() => _splashDone = true)),
      ),
    );
  }
}

// ── Splash screen ───────────────────────────────────────────────────────────

class _SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const _SplashScreen({required this.onDone});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF053A3A),
      body: Center(
        child: Image.asset(
          'assets/images/quran-yosr-splash.png',
          width: 220,
        ),
      ),
    );
  }
}

// ── Models ─────────────────────────────────────────────────────────────────

class Ayah {
  final int id;
  final int suraNo;
  final int ayaNo;
  final int page;
  final String suraNameAr;
  final String ayaText;

  Ayah({
    required this.id,
    required this.suraNo,
    required this.ayaNo,
    required this.page,
    required this.suraNameAr,
    required this.ayaText,
  });
}

// ── Display item types ──────────────────────────────────────────────────────

abstract class _Item {}

class _SurahHeader extends _Item {
  final int suraNo;
  final String suraNameAr;
  _SurahHeader(this.suraNo, this.suraNameAr);
}

class _PageMarker extends _Item {
  final int page;
  _PageMarker(this.page);
}

class _AyahRun extends _Item {
  final List<Ayah> ayahs;
  _AyahRun(this.ayahs);
}

class _BasmalaItem extends _Item {
  final String text;
  _BasmalaItem(this.text);
}

class SurahInfo {
  final int no;
  final String nameAr;
  final int ayaCount;
  SurahInfo({required this.no, required this.nameAr, required this.ayaCount});
}

class SearchResult {
  final int id;
  final int suraNo;
  final int ayaNo;
  final String suraNameAr;
  final String ayaTextEmlaey;
  SearchResult({
    required this.id,
    required this.suraNo,
    required this.ayaNo,
    required this.suraNameAr,
    required this.ayaTextEmlaey,
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────

String _colToString(Object? value) {
  if (value is String) return value;
  if (value is List<int>) return utf8.decode(value);
  return value?.toString() ?? '';
}

Future<Database> _openDb() async {
  final dbDir = await getDatabasesPath();
  final dbPath = join(dbDir, 'quran.db');
  if (!await File(dbPath).exists()) {
    final data = await rootBundle.load('assets/database/quran.db');
    await File(dbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
  }
  return openDatabase(dbPath, readOnly: true);
}

// ── AppBar button helper ───────────────────────────────────────────────────

Widget _barBtn({
  required IconData icon,
  required VoidCallback onPressed,
  required String tooltip,
  required bool isDark,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    ),
  );
}

// ── AyahsPage ──────────────────────────────────────────────────────────────

class AyahsPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const AyahsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<AyahsPage> createState() => _AyahsPageState();
}

class _AyahsPageState extends State<AyahsPage> with SingleTickerProviderStateMixin {
  final List<Ayah> _ayahs = [];
  List<_Item> _items = [];
  final ScrollController _scrollController = ScrollController();

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _loadingPrev = false;
  bool _reachedTop = false;
  bool _reachedBottom = false;
  String? _error;

  int _minId = 0;
  int _maxId = 0;
  static const int _chunk = 30;

  double _fontScale = 1.0;
  double _baseFontScale = 1.0;

  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  List<SearchResult> _searchResults = [];
  bool _searching = false;

  bool _autoScrolling = false;
  bool _userDragging  = false; // true while finger is actively dragging
  bool _isPinching    = false; // true during 2-finger pinch-to-zoom
  int _speedLevel = 1; // 0 = slowest … 6 = fastest
  Ticker? _autoScrollTicker;
  Duration _lastTickElapsed = Duration.zero;
  // px per millisecond for each of the 7 speed levels (reduced ~25% from v1)
  static const _kSpeedPxPerMs = [0.007, 0.018, 0.045, 0.10, 0.19, 0.34, 0.60];

  static const _kPrefMinId = 'last_min_id';
  int _lastKnownSaveId = 0; // cached so dispose() can write without a scroll controller
  bool _justNavigated = false; // blocks auto _loadPrev right after navigation
  bool _navigating  = false;  // overlay shown during navigate + back-buffer load
  DateTime _prevCooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Diagnostic 100ms sampler — runs forever; helps trace the scroll-jump bug.
  Timer? _diagTimer;

  // Title-bar state — updated on every visible-ayah change.
  String _currentSuraName = '';
  int    _currentJuz      = 0;

  // Singleton highlight — the ayah id navigated to from search.  null = no highlight.
  // When true, _highlightId was set by a user tap (not navigation).
  // The highlight is cleared automatically when it scrolls off screen.
  bool _tapHighlight = false;

  // _highlightKey is attached to the highlighted widget so ensureVisible can
  // precisely scroll to it after correctBy gives the approximate position.
  int?      _highlightId;
  GlobalKey? _highlightKey;

  // Basmala text (surah 1 aya 1) — used as the standalone centred line after
  // surah headers for surahs 2-8 and 10-114.  Loaded once at startup.
  String _basmalaText = '';

  // Map Quran page → juz number (standard Hafs mushaf boundaries).
  static int _pageToJuz(int page) {
    const starts = [
      1, 22, 42, 62, 82, 102, 121, 142, 162, 182,
      201, 221, 242, 262, 282, 302, 322, 342, 362, 382,
      402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
    ];
    for (int i = starts.length - 1; i >= 0; i--) {
      if (page >= starts[i]) return i + 1;
    }
    return 1;
  }

  void _recomputeItems() {
    final items = <_Item>[];
    int? curSura, curPage;
    final run = <Ayah>[];

    void flushRun() {
      if (run.isNotEmpty) {
        items.add(_AyahRun(List.from(run)));
        run.clear();
      }
    }

    for (final a in _ayahs) {
      final newSura = a.suraNo != curSura;
      final newPage = a.page != curPage;

      if (newSura || newPage) {
        flushRun();
        if (newPage && curPage != null) items.add(_PageMarker(curPage));
        if (newSura) {
          // Only show surah header at the actual first ayah of the surah,
          // never mid-surah just because it's the first loaded item.
          if (a.ayaNo == 1) {
            items.add(_SurahHeader(a.suraNo, a.suraNameAr));
            // Insert the Basmala as a standalone centred line after the header
            // for surahs 2-8 and 10-114.  The Basmala text is the same fixed
            // text as surah 1 aya 1 — NOT aya 1 of the current surah.
            if (a.suraNo != 1 && a.suraNo != 9 && _basmalaText.isNotEmpty) {
              items.add(_BasmalaItem(_basmalaText));
            }
          }
          curSura = a.suraNo;
        }
        curPage = a.page;
      }
      run.add(a);
    }
    flushRun();
    _items = items;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[Init] initState — starting app');
    WakelockPlus.enable();
    _loadInitial();
    _scrollController.addListener(_onScroll);

    // ── 100ms diagnostic sampler ──────────────────────────────────────────
    // Prints the "middle" ayah id (by pixel fraction) every 100ms so we can
    // see exactly what happens to the scroll position during and after
    // navigation — in particular whether correctBy fires correctly and
    // whether any subsequent event causes a jump.
    double prevMax = 0;
    _diagTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (_ayahs.isEmpty || pos.maxScrollExtent <= 0) return;
      final px   = pos.pixels;
      final mx   = pos.maxScrollExtent;
      final frac = (px / mx).clamp(0.0, 1.0);
      final idx  = (frac * (_ayahs.length - 1)).round();
      final mid  = _ayahs[idx];
      // Detect unexpected max changes (not from a correctBy we just fired).
      if (prevMax > 0 && (mx - prevMax).abs() > 5) {
        debugPrint('[100ms-JUMP] max changed ${prevMax.toStringAsFixed(0)}→${mx.toStringAsFixed(0)} '
            '(+${(mx - prevMax).toStringAsFixed(0)}) px=${px.toStringAsFixed(0)} '
            'lp=$_loadingPrev lm=$_loadingMore nav=$_navigating');
      }
      prevMax = mx;
      debugPrint('[100ms] px=${px.toStringAsFixed(0)}/${mx.toStringAsFixed(0)} '
          'frac=${frac.toStringAsFixed(3)} midId=${mid.id} '
          'hl=$_highlightId nav=$_navigating jn=$_justNavigated '
          'lp=$_loadingPrev lm=$_loadingMore');
    });
  }

  @override
  void dispose() {
    debugPrint('[Dispose] dispose — saving lastKnownSaveId=$_lastKnownSaveId');
    WakelockPlus.disable();
    _diagTimer?.cancel();
    _autoScrollTicker?.dispose();
    // Use cached ID — scroll controller has no clients by the time dispose() runs.
    if (_lastKnownSaveId > 0) {
      SharedPreferences.getInstance()
          .then((p) => p.setInt(_kPrefMinId, _lastKnownSaveId));
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // During navigation the ayahs list is in a partially-cleared/loading state.
    // Allowing _loadMore or _loadPrev here would append stale items to the new
    // list and produce out-of-order pages (the "page mixing" bug).
    if (_navigating) return;

    // Clear a tap-set highlight once it scrolls outside the built range
    // (cacheExtent). currentContext == null means the widget is no longer
    // in the tree — the ayah is off screen.
    if (_tapHighlight && _highlightKey?.currentContext == null) {
      setState(() {
        _highlightId  = null;
        _highlightKey = null;
        _tapHighlight = false;
      });
    }

    final pos = _scrollController.position;

    // Track position — but only while the list is stable.
    // During prepend/append and scroll corrections the fraction-based index
    // drifts (list length changes), so saving it would persist a wrong position.
    if (!_loadingPrev && !_loadingMore &&
        _ayahs.isNotEmpty && pos.maxScrollExtent > 0) {
      final fraction = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
      final idx = (fraction * (_ayahs.length - 1)).round();
      final ayah = _ayahs[idx];
      final saveId = ayah.id;
      if (saveId != _lastKnownSaveId) {
        _lastKnownSaveId = saveId;
        debugPrint('[Scroll] Position → ayah id=$saveId '
            '(idx=$idx/${_ayahs.length - 1}, '
            'frac=${fraction.toStringAsFixed(3)}, '
            'px=${pos.pixels.toStringAsFixed(0)}/${pos.maxScrollExtent.toStringAsFixed(0)})');
        SharedPreferences.getInstance()
            .then((p) => p.setInt(_kPrefMinId, saveId));
        // Update title bar whenever the visible ayah changes.
        final juz = _pageToJuz(ayah.page);
        if (ayah.suraNameAr != _currentSuraName || juz != _currentJuz) {
          setState(() {
            _currentSuraName = ayah.suraNameAr;
            _currentJuz      = juz;
          });
        }
      }
    }

    if (!_loadingMore && !_reachedBottom && pos.pixels >= pos.maxScrollExtent - 400) {
      debugPrint('[Scroll] Near bottom → _loadMore');
      _loadMore();
    }
    // Once the user has scrolled meaningfully down, lift the startup/nav guard
    // so a subsequent scroll back to the top will load the back-buffer normally.
    if (_justNavigated && pos.pixels > 800) _justNavigated = false;

    if (!_loadingPrev && !_reachedTop && !_justNavigated && pos.pixels <= 400) {
      // Cooldown: prevents rapid re-firing while correctBy is still settling.
      final now = DateTime.now();
      if (now.isBefore(_prevCooldownUntil)) {
        debugPrint('[Scroll] Near top — cooldown, skipping _loadPrev');
        return;
      }
      _prevCooldownUntil = now.add(const Duration(milliseconds: 350));
      debugPrint('[Scroll] Near top → _loadPrev');
      _loadPrev();
    }
  }

  Future<List<Ayah>> _fetch(String where, List<Object> args, String order) async {
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT id, sura_no, aya_no, page, sura_name_ar, aya_text '
      'FROM quran_ayahs WHERE $where ORDER BY $order LIMIT $_chunk',
      args,
    );
    await db.close();
    return rows
        .map((r) => Ayah(
              id: r['id'] as int,
              suraNo: r['sura_no'] as int,
              ayaNo: r['aya_no'] as int,
              page: r['page'] as int,
              suraNameAr: r['sura_name_ar'] as String,
              ayaText: _colToString(r['aya_text']),
            ))
        .toList();
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_kPrefMinId) ?? 1;
    debugPrint('[Init] Saved ayah id=$savedId');
    try {
      // Look up the page of the saved ayah, and fetch the Basmala text once.
      final db = await _openDb();
      final pageRows = await db.rawQuery(
        'SELECT page FROM quran_ayahs WHERE id >= ? ORDER BY id LIMIT 1',
        [savedId],
      );
      final basmalaRows = await db.rawQuery(
        'SELECT aya_text FROM quran_ayahs WHERE sura_no=1 AND aya_no=1 LIMIT 1',
      );
      debugPrint('[Init] Basmala query rows=${basmalaRows.length}');
      if (basmalaRows.isNotEmpty) {
        // Strip the trailing ayah-number marker (e.g. ﴿١﴾ / ۝١ / ١) that is
        // embedded in the stored aya_text — the standalone Basmala line should
        // not carry a verse number.  We strip rune-by-rune from the end so the
        // encoding used by HafsSmart doesn't matter.
        final raw = _colToString(basmalaRows.first['aya_text']);
        debugPrint('[Init] Basmala raw last-cp=0x${raw.runes.last.toRadixString(16)} len=${raw.length}');
        final runes = raw.runes.toList();
        while (runes.isNotEmpty) {
          final cp = runes.last;
          if ((cp >= 0x30   && cp <= 0x39)   || // ASCII 0-9
              (cp >= 0x0660 && cp <= 0x0669) || // Arabic-Indic ٠-٩
              (cp >= 0x06F0 && cp <= 0x06F9) || // Extended Arabic-Indic ۰-۹
              (cp >= 0xE000 && cp <= 0xF8FF) || // Private Use Area (HafsSmart glyphs)
              cp == 0x06DD || cp == 0xFD3E || cp == 0xFD3F || // ۝ ﴿ ﴾
              cp == 0x20   || cp == 0x00A0) {   // space / NBSP
            runes.removeLast();
          } else {
            break;
          }
        }
        _basmalaText = String.fromCharCodes(runes);
        debugPrint('[Init] Basmala text length=${_basmalaText.length} '
            'last-cp=0x${_basmalaText.runes.last.toRadixString(16)}');
      }
      final savedPage = pageRows.isNotEmpty ? pageRows.first['page'] as int : 1;
      final toPage   = (savedPage + 2).clamp(1, 604);
      debugPrint('[Init] savedPage=$savedPage → loading pages $savedPage–$toPage');

      // Phase 1: load from savedPage forward — user sees their position at top.
      final rows = await db.rawQuery(
        'SELECT id, sura_no, aya_no, page, sura_name_ar, aya_text '
        'FROM quran_ayahs WHERE page >= ? AND page <= ? ORDER BY id ASC',
        [savedPage, toPage],
      );
      await db.close();

      final ayahs = rows
          .map((r) => Ayah(
                id: r['id'] as int,
                suraNo: r['sura_no'] as int,
                ayaNo: r['aya_no'] as int,
                page: r['page'] as int,
                suraNameAr: r['sura_name_ar'] as String,
                ayaText: _colToString(r['aya_text']),
              ))
          .toList();

      debugPrint('[Init] Loaded ${ayahs.length} ayahs '
          '(pages $savedPage–$toPage, ids ${ayahs.first.id}–${ayahs.last.id})');

      // Treat resume-from-saved exactly like a search navigation:
      // show the nav overlay, pin the saved ayah, and only dismiss once the
      // layout has fully stabilised.  This prevents the startup shift caused
      // by correctBy's inaccurate estimated-height delta.
      final target = ayahs.firstWhere(
        (a) => a.id >= savedId, orElse: () => ayahs.first);
      setState(() {
        _ayahs.addAll(ayahs);
        _recomputeItems();
        _minId = ayahs.first.id;
        _maxId = ayahs.last.id;
        _reachedTop    = savedPage == 1;
        _reachedBottom = toPage  >= 604;
        _initialLoading = false;
        // Initialise title bar from the saved ayah.
        _currentSuraName = target.suraNameAr;
        _currentJuz      = _pageToJuz(target.page);
        // Reuse the navigation overlay + stability-pinFrame path.
        _highlightId  = savedId;
        _highlightKey = GlobalKey();
        _tapHighlight = false;
        _navigating   = true; // overlay shown; _onScroll blocked entirely
        _justNavigated = true;
      });
      debugPrint('[Init] Done: _minId=$_minId _maxId=$_maxId '
          'reachedTop=$_reachedTop reachedBottom=$_reachedBottom '
          'resumeTarget=$savedId');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
        if (savedPage > 1 && mounted && !_loadingPrev) {
          debugPrint('[Init] Pre-loading back-buffer and pinning saved ayah...');
          _loadPrevAndDismiss(); // correctBy + stability-pinFrame → dismisses overlay
        } else {
          // Already at the top of the Quran — no back-buffer needed.
          _justNavigated = false;
          setState(() => _navigating = false);
          debugPrint('[Init] Settled — no back-buffer needed');
        }
      });
    } catch (e) {
      debugPrint('[Init] ERROR: $e');
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    debugPrint('[LoadMore] Fetching id > $_maxId');
    setState(() => _loadingMore = true);
    try {
      final ayahs = await _fetch('id > ?', [_maxId], 'id ASC');
      debugPrint('[LoadMore] Got ${ayahs.length} ayahs'
          '${ayahs.isNotEmpty ? " (ids ${ayahs.first.id}–${ayahs.last.id})" : ""}');
      setState(() {
        _ayahs.addAll(ayahs);
        _recomputeItems();
        if (ayahs.isNotEmpty) _maxId = ayahs.last.id;
        _reachedBottom = ayahs.length < _chunk;
        _loadingMore = false;
      });
      if (_reachedBottom) debugPrint('[LoadMore] Reached bottom of Quran');
    } catch (e) {
      debugPrint('[LoadMore] ERROR: $e');
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadPrev() async {
    debugPrint('[LoadPrev] Fetching id < $_minId');
    setState(() => _loadingPrev = true);
    try {
      final ayahs =
          (await _fetch('id < ?', [_minId], 'id DESC')).reversed.toList();
      if (ayahs.isEmpty) {
        debugPrint('[LoadPrev] Reached top of Quran');
        setState(() { _reachedTop = true; _loadingPrev = false; });
        return;
      }
      debugPrint('[LoadPrev] Got ${ayahs.length} ayahs '
          '(ids ${ayahs.first.id}–${ayahs.last.id})');
      final oldMax = _scrollController.position.maxScrollExtent;
      // Keep _loadingPrev = true through correctBy so _onScroll cannot
      // re-trigger _loadPrev the instant items are inserted (cascade bug).
      setState(() {
        _ayahs.insertAll(0, ayahs);
        _recomputeItems();
        _minId = ayahs.first.id;
        _reachedTop = _minId == 1;
        // _loadingPrev intentionally left true here
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final pos    = _scrollController.position;
          final newMax = pos.maxScrollExtent;
          final delta  = newMax - oldMax;
          debugPrint('[LoadPrev-correctBy] BEFORE px=${pos.pixels.toStringAsFixed(0)} '
              'oldMax=${oldMax.toStringAsFixed(0)} '
              'newMax=${newMax.toStringAsFixed(0)} '
              'delta=${delta.toStringAsFixed(0)}');
          if (delta > 0) {
            pos.correctBy(delta);
            debugPrint('[LoadPrev-correctBy] AFTER  px=${pos.pixels.toStringAsFixed(0)} '
                'max=${pos.maxScrollExtent.toStringAsFixed(0)}');
          }
        }
        // One more frame to let the corrected position settle, THEN release.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _loadingPrev = false);
        });
      });
    } catch (e) {
      debugPrint('[LoadPrev] ERROR: $e');
      setState(() => _loadingPrev = false);
    }
  }

  Future<void> _navigateTo(int startId) async {
    debugPrint('[Navigate] Navigating to startId=$startId');
    _autoScrollTicker?.dispose();
    _autoScrollTicker = null;
    // Show overlay immediately — keeps old content visible underneath while loading.
    setState(() {
      _autoScrolling = false;
      _ayahs.clear();
      _items.clear();
      _loadingMore = false;
      _loadingPrev = false;
      _reachedTop = false;
      _reachedBottom = false;
      _navigating = true; // overlay replaces the old _initialLoading spinner
    });
    try {
      final db = await _openDb();
      final pageRows = await db.rawQuery(
        'SELECT page FROM quran_ayahs WHERE id >= ? ORDER BY id LIMIT 1',
        [startId],
      );
      final targetPage = pageRows.isNotEmpty ? pageRows.first['page'] as int : 1;
      final fromPage = targetPage;
      final toPage   = (targetPage + 2).clamp(1, 604);
      debugPrint('[Navigate] targetPage=$targetPage → loading pages $fromPage–$toPage');

      final rows = await db.rawQuery(
        'SELECT id, sura_no, aya_no, page, sura_name_ar, aya_text '
        'FROM quran_ayahs WHERE page >= ? AND page <= ? ORDER BY id ASC',
        [fromPage, toPage],
      );
      await db.close();

      final ayahs = rows.map((r) => Ayah(
        id: r['id'] as int,
        suraNo: r['sura_no'] as int,
        ayaNo: r['aya_no'] as int,
        page: r['page'] as int,
        suraNameAr: r['sura_name_ar'] as String,
        ayaText: _colToString(r['aya_text']),
      )).toList();

      final targetIdx = ayahs.indexWhere((a) => a.id >= startId);
      debugPrint('[Navigate] Loaded ${ayahs.length} ayahs'
          '${ayahs.isNotEmpty ? " (ids ${ayahs.first.id}–${ayahs.last.id})" : ""}'
          ' — target id=$startId at list-idx=$targetIdx');

      _justNavigated = true;
      setState(() {
        _ayahs.addAll(ayahs);
        _recomputeItems();
        if (ayahs.isNotEmpty) {
          _minId = ayahs.first.id;
          _maxId = ayahs.last.id;
          _reachedTop = fromPage == 1;
          // Update title bar to the target ayah.
          final target = ayahs.firstWhere(
            (a) => a.id >= startId, orElse: () => ayahs.first);
          _currentSuraName = target.suraNameAr;
          _currentJuz      = _pageToJuz(target.page);
        }
        _reachedBottom = toPage >= 604;
        // Set singleton highlight to the navigated ayah.
        // Fresh key each navigation so ensureVisible finds the right widget.
        _highlightId  = startId;
        _highlightKey = GlobalKey();
        _tapHighlight = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
        if (fromPage > 1 && mounted && !_loadingPrev) {
          debugPrint('[Navigate] Pre-loading back-buffer...');
          _loadPrevAndDismiss(); // dismisses overlay after correctBy
        } else {
          _justNavigated = false;
          setState(() => _navigating = false);
          debugPrint('[Navigate] Settled — overlay dismissed');
        }
      });
    } catch (e) {
      setState(() { _error = e.toString(); _navigating = false; });
    }
  }

  // Like _loadPrev, but dismisses the navigation overlay after correctBy runs.
  Future<void> _loadPrevAndDismiss() async {
    debugPrint('[LoadPrev] Fetching id < $_minId');
    setState(() => _loadingPrev = true);
    try {
      final ayahs =
          (await _fetch('id < ?', [_minId], 'id DESC')).reversed.toList();
      if (ayahs.isEmpty) {
        debugPrint('[LoadPrev] Reached top of Quran');
        _justNavigated = false;
        setState(() { _reachedTop = true; _loadingPrev = false; _navigating = false; });
        return;
      }
      debugPrint('[LoadPrev] Got ${ayahs.length} ayahs '
          '(ids ${ayahs.first.id}–${ayahs.last.id})');
      final oldMax = _scrollController.position.maxScrollExtent;
      setState(() {
        _ayahs.insertAll(0, ayahs);
        _recomputeItems();
        _minId = ayahs.first.id;
        _reachedTop = _minId == 1;
        _loadingPrev = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Frame A: apply correctBy for approximate position.
        if (_scrollController.hasClients) {
          final pos    = _scrollController.position;
          final newMax = pos.maxScrollExtent;
          final delta  = newMax - oldMax;
          debugPrint('[Nav-correctBy] BEFORE px=${pos.pixels.toStringAsFixed(0)} '
              'oldMax=${oldMax.toStringAsFixed(0)} '
              'newMax=${newMax.toStringAsFixed(0)} '
              'delta=${delta.toStringAsFixed(0)}');
          if (delta > 0) {
            pos.correctBy(delta);
            debugPrint('[Nav-correctBy] AFTER  px=${pos.pixels.toStringAsFixed(0)} '
                'max=${pos.maxScrollExtent.toStringAsFixed(0)}');
          }
        }
        final buildCtx = this.context; // path.dart exports 'context' — use 'this' to get BuildContext
        final initialMax = _scrollController.hasClients
            ? _scrollController.position.maxScrollExtent
            : 0.0;

        // Frames B+: re-pin the highlighted item every frame.
        // Navigation is only considered done when ALL three hold:
        //   (a) keyboard is fully gone (viewInsets.bottom == 0)
        //   (b) maxScrollExtent has not changed by more than 5 px for 3
        //       consecutive frames (layout has fully settled after item
        //       re-measurement — this is the root cause of the first-touch jump)
        //   (c) safety cap: at most 60 frames (~1 s at 60 fps) so we never
        //       hang if something unexpected prevents stability.
        //
        // If the highlight item is outside cacheExtent (ctx == null), we fall
        // back to a rough fraction-based jumpTo to pull it into the cache, then
        // ensureVisible can work on the next frame.
        void pinFrame(int framesLeft, double prevMax, int stableCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // Pin the highlight item — ensureVisible if built, rough jump if not.
            final ctx = _highlightKey?.currentContext;
            if (ctx != null) {
              Scrollable.ensureVisible(ctx, alignment: 0.25, duration: Duration.zero);
            } else if (_scrollController.hasClients && _highlightId != null) {
              final idx = _ayahs.indexWhere((a) => a.id == _highlightId);
              if (idx >= 0 && _ayahs.length > 1) {
                final pos  = _scrollController.position;
                final frac = idx / (_ayahs.length - 1);
                _scrollController.jumpTo(
                    (frac * pos.maxScrollExtent).clamp(0.0, pos.maxScrollExtent));
              }
            }
            final currentMax = _scrollController.hasClients
                ? _scrollController.position.maxScrollExtent
                : prevMax;
            final maxDelta  = (currentMax - prevMax).abs();
            final newStable = maxDelta < 5.0 ? stableCount + 1 : 0;
            final kbHeight  = MediaQuery.of(buildCtx).viewInsets.bottom;
            debugPrint('[pin] left=$framesLeft max=${currentMax.toStringAsFixed(0)} '
                'Δ=${maxDelta.toStringAsFixed(1)} stable=$newStable '
                'kb=${kbHeight.toStringAsFixed(0)}');
            if ((kbHeight == 0 && newStable >= 5) || framesLeft <= 0) {
              debugPrint('[Nav-ensureVisible] settled hl=$_highlightId '
                  'stable=$newStable timedOut=${framesLeft <= 0}');
              _justNavigated = false;
              // Capture locals before setState so the delayed closure sees them.
              final hlIdNow  = _highlightId;
              final hlKeyNow = _highlightKey;
              // Mark this as the saved position baseline so we can detect
              // whether the user has scrolled away before the re-pin fires.
              if (hlIdNow != null) _lastKnownSaveId = hlIdNow;
              setState(() => _navigating = false);
              debugPrint('[Navigate] Settled — overlay dismissed, highlight=$hlIdNow');
              // Post-settle quiet re-pin: layout may still shift ~500ms after
              // overlay dismissal as off-screen items get measured. If user
              // hasn't scrolled away, silently re-pin the highlight one more time.
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!mounted || _navigating) return;
                // Only skip if user's finger is actively down. Don't use
                // _lastKnownSaveId — layout-induced scroll changes update it
                // and silently block the re-pin on startup.
                if (_userDragging) return;
                final postCtx = hlKeyNow?.currentContext;
                if (postCtx == null) return; // scrolled off screen
                Scrollable.ensureVisible(postCtx, alignment: 0.25, duration: Duration.zero);
                debugPrint('[Nav-postSettle] quiet re-pin hl=$hlIdNow');
              });
            } else {
              pinFrame(framesLeft - 1, currentMax, newStable);
            }
          });
        }
        pinFrame(60, initialMax, 0);
      });
    } catch (e) {
      debugPrint('[LoadPrev] ERROR: $e');
      _justNavigated = false;
      setState(() { _loadingPrev = false; _navigating = false; });
    }
  }

  void _openSearch() {
    _stopAutoScroll();
    setState(() {
      _showSearch = true;
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  void _closeSearch() => setState(() => _showSearch = false);

  void _onTapAyah(int id) {
    setState(() {
      _highlightId  = id;
      _highlightKey = GlobalKey();
      _tapHighlight = true;
    });
  }

  // ── Auto-scroll ────────────────────────────────────────────────────────────

  void _startAutoScroll() {
    _autoScrollTicker?.dispose();
    _lastTickElapsed = Duration.zero;
    _autoScrollTicker = createTicker((elapsed) {
      final dt = (elapsed - _lastTickElapsed).inMicroseconds / 1000.0; // ms
      _lastTickElapsed = elapsed;
      // While the user's finger is down, let their gesture drive the scroll;
      // just advance the clock so we don't lurch forward when they lift.
      if (_userDragging) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final target = (pos.pixels + _kSpeedPxPerMs[_speedLevel] * dt)
          .clamp(0.0, pos.maxScrollExtent);
      _scrollController.jumpTo(target);
      // _onScroll won't fire when jumpTo is a no-op (already at maxExtent),
      // so explicitly trigger a load when we're near the end of loaded content.
      if (!_loadingMore && !_reachedBottom &&
          pos.pixels >= pos.maxScrollExtent - 800) {
        _loadMore();
      }
    })
      ..start();
    setState(() => _autoScrolling = true);
  }

  void _stopAutoScroll() {
    _autoScrollTicker?.dispose();
    _autoScrollTicker = null;
    setState(() => _autoScrolling = false);
  }

  void _toggleAutoScroll() =>
      _autoScrolling ? _stopAutoScroll() : _startAutoScroll();

  void _speedDown() {
    if (_speedLevel > 0) setState(() => _speedLevel--);
  }

  void _speedUp() {
    if (_speedLevel < 6) setState(() => _speedLevel++);
  }

  Future<void> _doSearch(String query) async {
    if (query.length < 3) {
      setState(() { _searchResults = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT id, sura_no, aya_no, sura_name_ar, aya_text_emlaey '
      'FROM quran_ayahs WHERE aya_text_emlaey LIKE ? ORDER BY id LIMIT 20',
      ['%$query%'],
    );
    await db.close();
    setState(() {
      _searchResults = rows
          .map((r) => SearchResult(
                id: r['id'] as int,
                suraNo: r['sura_no'] as int,
                ayaNo: r['aya_no'] as int,
                suraNameAr: r['sura_name_ar'] as String,
                ayaTextEmlaey: _colToString(r['aya_text_emlaey']),
              ))
          .toList();
      _searching = false;
    });
  }

  void _showInfoDialog() {
    _stopAutoScroll();
    final ctx = this.context;
    showDialog(
      context: ctx,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/quran-yosr-logo.svg',
              height: 64,
            ),
            const SizedBox(height: 8),
            const Text('المصدر:', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6)),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://qurancomplex.gov.sa/quran-dev/'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text(
                'مجمع الملك فهد للقرآن الكريم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, height: 1.6,
                  color: Color(0xFF1E88E5),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('للتواصل:', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6)),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('mailto:info@progspace.sa')),
              child: const Text(
                'info@progspace.sa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, height: 1.6,
                  color: Color(0xFF1E88E5),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showNavSheet() {
    _stopAutoScroll();
    final ctx = this.context;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? _bgDark : _bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NavSheet(
        onNavigate: (startId) {
          Navigator.pop(ctx);
          _navigateTo(startId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? const Color(0xFFE8D5B0) : Colors.black;
    final headerBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final dividerColor = isDark ? Colors.white24 : Colors.black12;
    final headerTextColor = isDark ? Colors.white70 : Colors.black87;

    if (_initialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          textDirection: TextDirection.ltr,
          children: [
            // LEFT side
            _barBtn(
              icon: isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              tooltip: isDark ? 'وضع النهار' : 'وضع الليل',
              onPressed: widget.onToggleTheme,
              isDark: isDark,
            ),
            _barBtn(
              icon: Icons.info_outline,
              tooltip: 'عن التطبيق',
              onPressed: _showInfoDialog,
              isDark: isDark,
            ),
            // CENTER title
            const Expanded(
              child: Text(
                'القرآن الكريم',
                textAlign: TextAlign.center,
              ),
            ),
            // RIGHT side
            _barBtn(
              icon: Icons.menu_book_outlined,
              tooltip: 'انتقل إلى',
              onPressed: _showNavSheet,
              isDark: isDark,
            ),
            _barBtn(
              icon: Icons.search,
              tooltip: 'بحث',
              onPressed: _openSearch,
              isDark: isDark,
            ),
            const SizedBox(width: 4),
          ],
        ),
        // ── Title bar: surah name | juz ──────────────────────────────
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: dividerColor, width: 0.5),
              ),
            ),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                // Left: surah name
                Expanded(
                  child: Text(
                    _currentSuraName.isNotEmpty
                        ? 'سورة $_currentSuraName'
                        : '',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
                // Vertical hairline
                SizedBox(
                  height: 16,
                  child: VerticalDivider(
                    color: dividerColor,
                    width: 1,
                    thickness: 1,
                  ),
                ),
                // Right: juz number
                Expanded(
                  child: Text(
                    _currentJuz > 0 ? 'الجزء $_currentJuz' : '',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? _bgDark : _bgLight,
          border: Border(top: BorderSide(color: dividerColor, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
          children: [
            const SizedBox(width: 4),
            // Play / Pause
            _barBtn(
              icon: _autoScrolling ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: _autoScrolling ? 'إيقاف' : 'تشغيل',
              onPressed: _toggleAutoScroll,
              isDark: isDark,
            ),
            const SizedBox(width: 4),
            VerticalDivider(
              width: 1, thickness: 1,
              color: dividerColor,
              indent: 12, endIndent: 12,
            ),
            const Spacer(),
            // Speed control
            _barBtn(
              icon: Icons.remove,
              tooltip: 'أبطأ',
              onPressed: _speedDown,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '${_speedLevel + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            _barBtn(
              icon: Icons.add,
              tooltip: 'أسرع',
              onPressed: _speedUp,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
          ],
        ),
          ),
        ),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onScaleStart: (_) {
              _baseFontScale = _fontScale;
              _isPinching = false;
            },
            onScaleUpdate: (d) {
              if (d.pointerCount >= 2) {
                if (!_isPinching) {
                  // First frame with 2 fingers — re-anchor base scale here so
                  // any drift while 1 finger was down doesn't cause a jump.
                  _baseFontScale = _fontScale;
                  setState(() => _isPinching = true);
                }
                setState(() {
                  _fontScale = (_baseFontScale * d.scale).clamp(0.5, 3.0);
                });
              }
            },
            onScaleEnd: (_) {
              if (_isPinching) setState(() => _isPinching = false);
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                // Track whether the user's finger is actively dragging so
                // the auto-scroll ticker can yield to manual input.
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _userDragging = true;
                } else if (n is ScrollEndNotification) {
                  _userDragging = false;
                }
                return false; // don't absorb — let _onScroll still fire
              },
              child: ListView.builder(
              controller: _scrollController,
              // Disable scroll physics during pinch so the ListView yields
              // pointer events to the parent ScaleGestureRecognizer.
              physics: _isPinching
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              // Larger cache ensures more back-buffer items are measured before
              // correctBy fires, giving it a more accurate delta to work with.
              cacheExtent: 1500,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];

                // ── Surah header ──────────────────────────────────────
                if (item is _SurahHeader) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    color: headerBg,
                    child: Column(
                      children: [
                        Divider(height: 1, thickness: 1, color: dividerColor),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'سورة ${item.suraNameAr}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: headerTextColor,
                            ),
                          ),
                        ),
                        Divider(height: 1, thickness: 1, color: dividerColor),
                      ],
                    ),
                  );
                }

                // ── Basmala line (aya 1, surahs 2-8 and 10-114) ──────
                if (item is _BasmalaItem) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      item.text,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'CustomFont',
                        fontSize: 28 * _fontScale,
                        color: textColor,
                        height: 1.8,
                      ),
                    ),
                  );
                }

                // ── Page marker ───────────────────────────────────────
                if (item is _PageMarker) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: dividerColor, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${item.page}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: dividerColor, thickness: 1)),
                      ],
                    ),
                  );
                }

                // ── Ayah run ──────────────────────────────────────────
                if (item is _AyahRun) {
                  final baseStyle = TextStyle(
                    fontFamily: 'CustomFont',
                    fontSize: 28 * _fontScale,
                    color: textColor,
                    height: 1.8,
                  );
                  final hlColor = isDark
                      ? const Color(0xFFFFD54F)   // amber 300
                      : const Color(0xFFF57F17);  // amber 900

                  // Helper: build a tappable TextSpan for one ayah.
                  TextSpan ayahSpan(Ayah a) => TextSpan(
                    text: '${a.ayaText} ',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _onTapAyah(a.id),
                    style: a.id == _highlightId
                        ? TextStyle(color: hlColor)
                        : null,
                  );

                  final hasHighlight = _highlightId != null &&
                      item.ayahs.any((a) => a.id == _highlightId);

                  if (hasHighlight) {
                    // Keep all ayahs in one RichText so the text flows
                    // continuously (no paragraph break before the highlight).
                    // A zero-size WidgetSpan anchors _highlightKey at the
                    // exact highlight position so ensureVisible(alignment:0.0)
                    // scrolls precisely to that ayah without splitting the run.
                    final hlIdx = item.ayahs.indexWhere((a) => a.id == _highlightId);
                    final before = item.ayahs.sublist(0, hlIdx);
                    final fromHl = item.ayahs.sublist(hlIdx);
                    return RichText(
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: baseStyle,
                        children: <InlineSpan>[
                          ...before.map<InlineSpan>(ayahSpan),
                          WidgetSpan(
                            child: SizedBox.shrink(key: _highlightKey),
                          ),
                          ...fromHl.map<InlineSpan>(ayahSpan),
                        ],
                      ),
                    );
                  }

                  // No highlight — single RichText with tappable spans.
                  return RichText(
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: baseStyle,
                      children: item.ayahs.map<InlineSpan>(ayahSpan).toList(),
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),  // closes ListView.builder
          ),    // closes NotificationListener
          ),    // closes GestureDetector
          // ── Navigation overlay ─────────────────────────────────────
          // Shown during the entire navigate + back-buffer + correctBy
          // sequence so the user never sees a mid-load jump.
          if (_navigating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          // ── Search overlay ──────────────────────────────────────────
          if (_showSearch)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeSearch,
                  // Use SafeArea + Padding + Column(min) so the card is never
                  // constrained to the full overlay height (which caused overflow
                  // when the keyboard was shown).
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: LayoutBuilder(builder: (_, lc) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {},
                              child: Material(
                                color: isDark
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                elevation: 12,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 8, 12),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Search field row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _searchCtrl,
                                              autofocus: true,
                                              textDirection: TextDirection.rtl,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 16,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'ابحث في القرآن الكريم...',
                                                hintStyle: TextStyle(
                                                  color: isDark
                                                      ? Colors.white38
                                                      : Colors.black38,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 12),
                                              ),
                                              onChanged: _doSearch,
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.close,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black45),
                                            onPressed: _closeSearch,
                                          ),
                                        ],
                                      ),
                                      // Spinner
                                      if (_searching)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 14),
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                      // No results
                                      if (!_searching &&
                                          _searchResults.isEmpty &&
                                          _searchCtrl.text.length >= 3)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          child: Text(
                                            'لا توجد نتائج',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38,
                                            ),
                                          ),
                                        ),
                                      // Results — maxHeight shrinks with keyboard
                                      if (!_searching &&
                                          _searchResults.isNotEmpty) ...[
                                        Divider(
                                          color: isDark
                                              ? Colors.white12
                                              : Colors.black12,
                                          height: 1,
                                        ),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            // lc.maxHeight = body height minus
                                            // keyboard minus overlay padding.
                                            // Subtract ~96dp to account for the
                                            // search field row (56) + card padding
                                            // (16) + divider (1) + breathing room.
                                            maxHeight:
                                                (lc.maxHeight - 96)
                                                    .clamp(40.0, 360.0),
                                          ),
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            itemCount: _searchResults.length,
                                            separatorBuilder: (_, __) =>
                                                Divider(
                                              height: 1,
                                              color: isDark
                                                  ? Colors.white12
                                                  : Colors.black12,
                                            ),
                                            itemBuilder: (ctx, i) {
                                              final r = _searchResults[i];
                                              return InkWell(
                                                onTap: () {
                                                  _closeSearch();
                                                  _navigateTo(r.id);
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            'آية ${r.ayaNo}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: isDark
                                                                  ? Colors
                                                                      .white38
                                                                  : Colors
                                                                      .black38,
                                                            ),
                                                          ),
                                                          Text(
                                                            'سورة ${r.suraNameAr}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isDark
                                                                  ? Colors
                                                                      .white70
                                                                  : Colors
                                                                      .black87,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        r.ayaTextEmlaey,
                                                        textDirection:
                                                            TextDirection.rtl,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? Colors.white60
                                                              : Colors.black87,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Navigation bottom sheet ────────────────────────────────────────────────

class _NavSheet extends StatefulWidget {
  final void Function(int startId) onNavigate;
  const _NavSheet({required this.onNavigate});

  @override
  State<_NavSheet> createState() => _NavSheetState();
}

class _NavSheetState extends State<_NavSheet> {
  int _mode = 0; // 0=page  1=surah  2=ayah
  List<SurahInfo> _surahs = [];
  bool _loadingSurahs = true;
  int _selectedSurahNo = 1;

  final _pageCtrl  = TextEditingController();
  final _ayaNoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _ayaNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT sura_no, sura_name_ar, COUNT(*) as aya_count '
      'FROM quran_ayahs GROUP BY sura_no ORDER BY sura_no',
    );
    await db.close();
    setState(() {
      _surahs = rows
          .map((r) => SurahInfo(
                no: r['sura_no'] as int,
                nameAr: r['sura_name_ar'] as String,
                ayaCount: r['aya_count'] as int,
              ))
          .toList();
      _loadingSurahs = false;
    });
  }

  Future<void> _goToPage() async {
    final page = int.tryParse(_pageCtrl.text.trim());
    if (page == null || page < 1 || page > 604) return;
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT id FROM quran_ayahs WHERE page >= ? ORDER BY page, id LIMIT 1',
      [page],
    );
    await db.close();
    if (rows.isNotEmpty) widget.onNavigate(rows.first['id'] as int);
  }

  Future<void> _goToSurah(int suraNo) async {
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT id FROM quran_ayahs WHERE sura_no = ? ORDER BY id LIMIT 1',
      [suraNo],
    );
    await db.close();
    if (rows.isNotEmpty) widget.onNavigate(rows.first['id'] as int);
  }

  Future<void> _goToAyah() async {
    final ayaNo = int.tryParse(_ayaNoCtrl.text.trim());
    if (ayaNo == null || ayaNo < 1) return;
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT id FROM quran_ayahs WHERE sura_no = ? AND aya_no = ? LIMIT 1',
      [_selectedSurahNo, ayaNo],
    );
    await db.close();
    if (rows.isNotEmpty) widget.onNavigate(rows.first['id'] as int);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    final labelStyle = TextStyle(color: isDark ? Colors.white70 : Colors.black87);
    final modeLabels = ['صفحة', 'سورة', 'آية'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Mode selector chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final selected = _mode == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _mode = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? (isDark ? Colors.white.withOpacity(0.15) : Colors.black87)
                            : Colors.transparent,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        modeLabels[i],
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Divider(color: borderColor, height: 16),
          // ── Page mode ─────────────────────────────────────────────────
          if (_mode == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pageCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                      decoration: InputDecoration(
                        labelText: 'رقم الصفحة  (١ – ٦٠٤)',
                        labelStyle: labelStyle,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      onPressed: _goToPage,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('انتقل'),
                    ),
                  ),
                ],
              ),
            ),
          // ── Surah mode ────────────────────────────────────────────────
          if (_mode == 1)
            _loadingSurahs
                ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
                : SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: _surahs.length,
                      itemBuilder: (ctx, i) {
                        final s = _surahs[i];
                        return ListTile(
                          dense: true,
                          leading: Text('${s.no}',
                              style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 12)),
                          title: Text(s.nameAr,
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87)),
                          trailing: Text('${s.ayaCount} آية',
                              style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 12)),
                          onTap: () => _goToSurah(s.no),
                        );
                      },
                    ),
                  ),
          // ── Ayah mode ─────────────────────────────────────────────────
          if (_mode == 2)
            _loadingSurahs
                ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          value: _selectedSurahNo,
                          decoration: InputDecoration(
                            labelText: 'السورة',
                            labelStyle: labelStyle,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: _surahs
                              .map((s) => DropdownMenuItem(
                                    value: s.no,
                                    child: Text('${s.no}. ${s.nameAr}'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedSurahNo = v!),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _ayaNoCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: labelStyle,
                                decoration: InputDecoration(
                                  labelText: 'رقم الآية',
                                  labelStyle: labelStyle,
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextButton(
                                onPressed: _goToAyah,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                child: const Text('انتقل'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
