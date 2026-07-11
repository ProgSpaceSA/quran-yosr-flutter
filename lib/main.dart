import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart' show Ticker;
import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Top-level handler for background/terminated FCM messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
      '[FCM-bg] ${message.notification?.title}: ${message.notification?.body}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

// ── Theme ──────────────────────────────────────────────────────────────────

const _bgLight = Color(0xFFFFFFFF);
const _bgDark  = Color(0xFF1C1C1E);

// Opaque text colors — lerp(bg, fg, α) — prevents Arabic ligature overlap from
// accumulating opacity. Reference: dark bg=_bgDark, light bg=_bgLight.
const _tw85 = Color(0xFFDDDDDD); // white × 0.85
const _tw70 = Color(0xFFBBBBBC); // white × 0.70
const _tw60 = Color(0xFFA4A4A5); // white × 0.60
const _tw54 = Color(0xFF979798); // white × 0.54
const _tw38 = Color(0xFF727274); // white × 0.38
const _tb87 = Color(0xFF212121); // black × 0.87
const _tb54 = Color(0xFF757575); // black × 0.54
const _tb45 = Color(0xFF8C8C8C); // black × 0.45
const _tb38 = Color(0xFF9E9E9E); // black × 0.38

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    brightness: brightness,
    fontFamily: 'Rubik',
    scaffoldBackgroundColor: isDark ? _bgDark : _bgLight,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? _bgDark : _bgLight,
      foregroundColor: isDark ? Colors.white : _tb87,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: isDark ? Colors.white24 : Colors.black12,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? _bgDark : _bgLight,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.06),
      height: 60,
      labelTextStyle: WidgetStateProperty.all(TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: isDark ? _tw70 : _tb54,
      )),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? (isDark ? Colors.white : _tb87)
              : (isDark ? _tw54 : _tb45),
          size: 22,
        );
      }),
    ),
  );
  return base;
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

  static const _kPrefIsDark = 'is_dark';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _isDark = p.getBool(_kPrefIsDark) ?? true);
    });
  }

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kPrefIsDark, _isDark));
  }

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
            ? _AppShell(
                isDark: _isDark,
                onToggleTheme: _toggleTheme,
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

class SurahHit {
  final int suraNo;
  final String nameAr;
  final int firstAyahId;
  const SurahHit({required this.suraNo, required this.nameAr, required this.firstAyahId});
}

// ── User data models ──────────────────────────────────────────────────────

class WirdPlan {
  final int id;
  final String targetType; // 'pages' | 'ayahs' | 'minutes'
  final double targetValue;
  final int createdAt;

  WirdPlan({
    required this.id,
    required this.targetType,
    required this.targetValue,
    required this.createdAt,
  });

  factory WirdPlan.fromMap(Map<String, Object?> m) => WirdPlan(
        id: m['id'] as int,
        targetType: m['target_type'] as String,
        targetValue: (m['target_value'] as num).toDouble(),
        createdAt: m['created_at'] as int,
      );
}

class DailyProgress {
  final String date;
  final int planId;
  final double completedValue;
  final bool isCompleted;

  DailyProgress({
    required this.date,
    required this.planId,
    required this.completedValue,
    required this.isCompleted,
  });

  factory DailyProgress.fromMap(Map<String, Object?> m) => DailyProgress(
        date: m['date'] as String,
        planId: m['plan_id'] as int,
        completedValue: (m['completed_value'] as num).toDouble(),
        isCompleted: (m['is_completed'] as int) == 1,
      );
}

class ReadingSession {
  final String date;
  final int startAyahId;
  final int endAyahId;
  final int startPage;
  final int endPage;
  final int pagesRead;
  final int durationSeconds;
  final int startedAt;
  final int endedAt;

  ReadingSession({
    required this.date,
    required this.startAyahId,
    required this.endAyahId,
    required this.startPage,
    required this.endPage,
    required this.pagesRead,
    required this.durationSeconds,
    required this.startedAt,
    required this.endedAt,
  });
}

// ── UserDb — writable local user database ─────────────────────────────────

class UserDb {
  UserDb._();
  static final UserDb instance = UserDb._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    _db = await openDatabase(
      join(dbDir, 'user_data.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS wird_plan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target_type TEXT NOT NULL,
            target_value REAL NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_progress (
            date TEXT PRIMARY KEY,
            plan_id INTEGER NOT NULL,
            completed_value REAL NOT NULL DEFAULT 0.0,
            is_completed INTEGER NOT NULL DEFAULT 0,
            completed_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reading_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            start_ayah_id INTEGER NOT NULL,
            end_ayah_id INTEGER NOT NULL,
            start_page INTEGER NOT NULL,
            end_page INTEGER NOT NULL,
            pages_read INTEGER NOT NULL DEFAULT 0,
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            started_at INTEGER NOT NULL,
            ended_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<WirdPlan?> getActivePlan() async {
    final db = await _database;
    final rows = await db.query(
      'wird_plan',
      where: 'is_active = 1',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : WirdPlan.fromMap(rows.first);
  }

  Future<void> savePlan(String type, double value) async {
    final db = await _database;
    await db.update('wird_plan', {'is_active': 0});
    await db.insert('wird_plan', {
      'target_type': type,
      'target_value': value,
      'is_active': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<DailyProgress?> getTodayProgress() async {
    final db = await _database;
    final rows = await db.query(
      'daily_progress',
      where: 'date = ?',
      whereArgs: [_todayStr()],
    );
    return rows.isEmpty ? null : DailyProgress.fromMap(rows.first);
  }

  Future<void> upsertProgress(String date, int planId, double delta) async {
    if (delta <= 0) return;
    final db = await _database;
    final existing = await db.query(
      'daily_progress',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (existing.isEmpty) {
      final plan = await getActivePlan();
      final done = plan != null && delta >= plan.targetValue ? 1 : 0;
      await db.insert('daily_progress', {
        'date': date,
        'plan_id': planId,
        'completed_value': delta,
        'is_completed': done,
        if (done == 1) 'completed_at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      final row = existing.first;
      final newVal = (row['completed_value'] as num).toDouble() + delta;
      final plan = await getActivePlan();
      final alreadyDone = (row['is_completed'] as int) == 1;
      final nowDone =
          !alreadyDone && plan != null && newVal >= plan.targetValue;
      await db.update(
        'daily_progress',
        {
          'completed_value': newVal,
          if (nowDone) 'is_completed': 1,
          if (nowDone) 'completed_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'date = ?',
        whereArgs: [date],
      );
    }
  }

  Future<void> insertSession(ReadingSession s) async {
    final db = await _database;
    await db.insert('reading_sessions', {
      'date': s.date,
      'start_ayah_id': s.startAyahId,
      'end_ayah_id': s.endAyahId,
      'start_page': s.startPage,
      'end_page': s.endPage,
      'pages_read': s.pagesRead,
      'duration_seconds': s.durationSeconds,
      'started_at': s.startedAt,
      'ended_at': s.endedAt,
    });
  }

  Future<int> calculateStreak() async {
    final db = await _database;
    final rows = await db.query(
      'daily_progress',
      where: 'is_completed = 1',
      orderBy: 'date DESC',
    );
    if (rows.isEmpty) return 0;
    int streak = 0;
    DateTime check = DateTime.now();
    final today = _todayStr();
    // If today is not yet completed, start counting from yesterday.
    if ((rows.first['date'] as String) != today) {
      check = check.subtract(const Duration(days: 1));
    }
    for (final row in rows) {
      final dateStr = row['date'] as String;
      final y = check.year;
      final m = check.month.toString().padLeft(2, '0');
      final d = check.day.toString().padLeft(2, '0');
      if (dateStr == '$y-$m-$d') {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> resetForTest() async {
    await instance._db?.close();
    instance._db = null;
    final dbDir = await getDatabasesPath();
    await deleteDatabase(join(dbDir, 'user_data.db'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Suppress the tutorial overlay so it doesn't block UI during tests.
    await prefs.setBool('tutorial_shown', true);
  }
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
  Key? key,
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
        key: key,
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

// ── App shell (2-tab navigation) ──────────────────────────────────────────

class _AppShell extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const _AppShell({required this.isDark, required this.onToggleTheme});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedTab =
      0; // 0=home, 1=reader; starts on home, switches to reader if plan exists
  bool _isAutoScrolling = false;
  bool _isFocusMode = false;

  final _homeKey = GlobalKey<_HomePageState>();

  @override
  void initState() {
    super.initState();
    // Returning users with an active wird plan start directly on the reader tab.
    UserDb.instance.getActivePlan().then((plan) {
      if (!mounted) return;
      if (plan != null) setState(() => _selectedTab = 1);
    });
  }

  void _switchTab(int tab) {
    setState(() => _selectedTab = tab);
    if (tab == 0) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _homeKey.currentState?.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final dividerColor = isDark ? Colors.white24 : Colors.black12;

    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          HomePage(
            key: _homeKey,
            isDark: isDark,
            onToggleTheme: widget.onToggleTheme,
            onGoToReader: () => _switchTab(1),
          ),
          AyahsPage(
            isDark: isDark,
            onToggleTheme: widget.onToggleTheme,
            isActiveTab: _selectedTab == 1,
            onAutoScrollChanged: (v) => setState(() => _isAutoScrolling = v),
            onFocusModeChanged: (v) => setState(() => _isFocusMode = v),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        height: ((_isAutoScrolling || _isFocusMode) && _selectedTab == 1)
            ? 0.0
            : 60.0 + MediaQuery.of(context).viewPadding.bottom,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: dividerColor, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTab,
          onDestinationSelected: _switchTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'لوحتي',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'القرآن',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home page ──────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onGoToReader;

  const HomePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onGoToReader,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WirdPlan? _plan;
  DailyProgress? _progress;
  int _streak = 0;
  String _resumeSurahName = '';
  int _resumePage = 1;
  int _khatmahPercent = 0;
  bool _loading = true;
  bool _setupShown = false;

  static const _goldColor = Color(0xFFc9a84c);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> refresh() => _loadData();

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt('last_min_id') ?? 1;
    // Read sura name and page from SharedPreferences (written by AyahsPage on each save).
    // This avoids opening quran.db here, which would race with AyahsPage's own DB connection.
    final suraName = prefs.getString('current_sura') ?? '';
    final page = prefs.getInt('current_page') ?? 1;

    final plan = await UserDb.instance.getActivePlan();
    DailyProgress? progress;
    int streak = 0;
    if (plan != null) {
      progress = await UserDb.instance.getTodayProgress();
      streak = await UserDb.instance.calculateStreak();
    }

    if (!mounted) return;
    setState(() {
      _resumeSurahName = suraName;
      _resumePage = page;
      _khatmahPercent = (savedId / 6236 * 100).round().clamp(0, 100);
      _plan = plan;
      _progress = progress;
      _streak = streak;
      _loading = false;
    });

    if (plan == null && mounted && !_setupShown) {
      _setupShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showWirdSetup();
      });
    }
  }

  void _showWirdSetup() {
    if (!mounted) return;
    final ctx = this.context;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WirdSetupSheet(
        onSaved: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? _bgDark : _bgLight;
    final textColor = isDark ? Colors.white : _tb87;
    final subColor = isDark ? _tw60 : _tb54;
    final cardColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                isDark
                    ? 'assets/images/quran-type-white.png'
                    : 'assets/images/quran-type.png',
                height: 28,
              ),
              const SizedBox(width: 6),
              Text(
                'يُسْرٌ',
                style: TextStyle(
                  fontFamily: 'LaylaThuluth',
                  fontSize: 22,
                  color: textColor,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            _barBtn(
              icon: isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              tooltip: isDark ? 'فاتح' : 'داكن',
              onPressed: widget.onToggleTheme,
              isDark: isDark,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildContinueCard(cardColor, textColor, subColor),
                    const SizedBox(height: 12),
                    _buildWirdSection(
                        isDark, bg, cardColor, textColor, subColor),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildWirdSection(
      bool isDark, Color bg, Color cardColor, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'متابعة الورد اليومي',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildWirdCard(isDark, bg, textColor, subColor),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildStreakCard(bg, textColor, subColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildKhatmahCard(bg, textColor, subColor)),
          ]),
        ],
      ),
    );
  }

  Widget _buildContinueCard(Color cardColor, Color textColor, Color subColor) {
    return GestureDetector(
      key: const Key('card_continue'),
      onTap: widget.onGoToReader,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.menu_book, color: _goldColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تابع القراءة',
                      style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    _resumeSurahName.isNotEmpty
                        ? 'سورة $_resumeSurahName • صفحة $_resumePage'
                        : 'ابدأ من البداية',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new, color: subColor, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWirdCard(
      bool isDark, Color cardColor, Color textColor, Color subColor) {
    if (_plan == null) {
      return GestureDetector(
        key: const Key('card_wird_setup'),
        onTap: _showWirdSetup,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _goldColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: _goldColor, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إعداد الورد اليومي',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('ابدأ بخطوة صغيرة — ولو صفحة واحدة',
                      style: TextStyle(color: subColor, fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final completed = _progress?.completedValue ?? 0.0;
    final target = _plan!.targetValue;
    final progressFraction = (completed / target).clamp(0.0, 1.0);
    final isDone = _progress?.isCompleted ?? false;
    final unitLabel = _plan!.targetType == 'pages'
        ? 'صفحات'
        : _plan!.targetType == 'minutes'
            ? 'دقيقة'
            : 'آيات';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('وردك اليوم',
                style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (isDone)
              Text('✓ أتممت وردك',
                  style: TextStyle(color: _goldColor, fontSize: 14))
            else
              GestureDetector(
                onTap: _showWirdSetup,
                child: Text('تعديل',
                    style: TextStyle(color: subColor, fontSize: 14)),
              ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDone ? const Color(0xFF4CAF50) : _goldColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text(
              '${completed.toStringAsFixed(completed == completed.roundToDouble() ? 0 : 1)} من ${target.toInt()} $unitLabel',
              style: TextStyle(color: subColor, fontSize: 14),
              textDirection: TextDirection.rtl,
            ),
            const Spacer(),
            if (!isDone)
              GestureDetector(
                key: const Key('btn_read_now'),
                onTap: widget.onGoToReader,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _goldColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('اقرأ الآن',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  static String _dayLabel(int n) {
    if (n == 1) return 'يوم';
    if (n == 2) return 'يومان';
    if (n % 10 >= 3 && n % 10 <= 9 && (n ~/ 10) % 10 == 0) return '$n أيام';
    if ((n ~/ 10) % 10 != 0) return '$n يومًا';
    return '$n أيام';
  }

  Widget _buildStreakCard(Color cardColor, Color textColor, Color subColor) {
    final label = _streak > 0 ? _dayLabel(_streak) : 'ابدأ اليوم';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // const Text('🔥', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        Text('فراءة دون انقطاع',
            style: TextStyle(color: subColor, fontSize: 13)),
      ]),
    );
  }

  Widget _buildKhatmahCard(Color cardColor, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // const Text('📖', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text('$_khatmahPercent٪',
            style: TextStyle(
                color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        Text('من الختمة', style: TextStyle(color: subColor, fontSize: 13)),
      ]),
    );
  }
}

// ── Wird setup bottom sheet ────────────────────────────────────────────────

class _WirdSetupSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _WirdSetupSheet({required this.onSaved});

  @override
  State<_WirdSetupSheet> createState() => _WirdSetupSheetState();
}

class _WirdSetupSheetState extends State<_WirdSetupSheet> {
  String _type = 'pages';
  double _value = 5;
  bool _saving = false;

  static const _goldColor = Color(0xFFc9a84c);

  double get _min => _type == 'ayahs' ? 5.0 : 5.0;
  double get _max =>
      _type == 'pages' ? 30.0 : (_type == 'ayahs' ? 200.0 : 120.0);
  int get _divisions => (_max - _min).round();

  String get _summaryText {
    final v = _value.round();
    if (_type == 'pages') {
      if (v == 1) return 'ستقرأ صفحة واحدة يومياً';
      if (v == 2) return 'ستقرأ صفحتين يومياً';
      return 'ستقرأ $v صفحات يومياً';
    } else if (_type == 'ayahs') {
      if (v == 1) return 'ستقرأ آية واحدة يومياً';
      if (v == 2) return 'ستقرأ آيتين يومياً';
      return 'ستقرأ $v آيات يومياً';
    } else {
      if (v == 1) return 'ستقرأ دقيقة واحدة يومياً';
      if (v == 2) return 'ستقرأ دقيقتين يومياً';
      return 'ستقرأ $v دقيقة يومياً';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await UserDb.instance.savePlan(_type, _value.roundToDouble());
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? Colors.white : _tb87;
    final subColor = isDark ? _tw60 : _tb54;

    final types = [
      ['pages', 'صفحات'],
      ['ayahs', 'آيات'],
      ['minutes', 'دقائق'],
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('حدد وردك اليومي',
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: types.map((t) {
                final selected = _type == t[0];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _type = t[0];
                      _value = _min;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _goldColor : Colors.transparent,
                        border: Border.all(
                            color: selected
                                ? _goldColor
                                : (isDark ? Colors.white30 : Colors.black26)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        t[1],
                        style: TextStyle(
                          color: selected ? Colors.white : textColor,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Slider(
              key: const Key('slider_wird'),
              value: _value.clamp(_min, _max),
              min: _min,
              max: _max,
              divisions: _divisions,
              activeColor: _goldColor,
              label: '${_value.round()}',
              onChanged: (v) => setState(() => _value = v),
            ),
            Text(
              '${_value.round()}',
              style: const TextStyle(
                  color: _goldColor, fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(_summaryText,
                style: TextStyle(color: subColor, fontSize: 14),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('btn_wird_save'),
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _goldColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ الورد',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── AyahsPage ──────────────────────────────────────────────────────────────

class AyahsPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final bool isActiveTab;
  final ValueChanged<bool>? onAutoScrollChanged;
  final ValueChanged<bool>? onFocusModeChanged;

  const AyahsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.isActiveTab = true,
    this.onAutoScrollChanged,
    this.onFocusModeChanged,
  });

  @override
  State<AyahsPage> createState() => _AyahsPageState();
}

// Draws 3 thin vertical lines on the right (odd pages) or left (even pages)
// edge of each _AyahRun item, mimicking the Quran book page-edge decoration.
class _PageEdgePainter extends CustomPainter {
  final bool isOdd;
  final Color color;
  const _PageEdgePainter(this.isOdd, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final xs = isOdd
        ? [size.width - 1, size.width - 4, size.width - 7]
        : [1.0, 4.0, 7.0];
    for (final x in xs) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_PageEdgePainter old) =>
      old.isOdd != isOdd || old.color != color;
}

class _AyahsPageState extends State<AyahsPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  static const int _chunk = 80;

  double _fontScale = 1.0;
  double _baseFontScale = 1.0;

  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  List<SearchResult> _searchResults = [];
  List<SurahHit> _surahHits = [];
  bool _searching = false;

  bool _autoScrolling = false;
  bool _focusMode = false;
  bool _userDragging = false; // true while finger is actively dragging
  bool _isPinching = false; // true during 2-finger pinch-to-zoom
  int _pointerCount = 0; // live touch-point count (for instant pinch detection)
  GlobalKey? _zoomAnchorKey; // ayah-run key that acts as zoom anchor
  double _zoomAnchorViewportOffset = 0.0; // anchor item's topOnScreen at pinch start
  bool _zoomRestorePending = false; // coalesce per-frame restore calls
  bool _showZoomBadge = false; // true while pinching + 1.5 s after release
  Timer? _zoomBadgeTimer;
  Timer? _saveDebounce;
  OverlayEntry? _tutorialEntry;
  bool _tutorialPending = false;
  final GlobalKey _playBtnTutorialKey = GlobalKey();
  int _speedLevel = 2; // 0 = slowest … 9 = fastest
  Ticker? _autoScrollTicker;
  Duration _lastTickElapsed = Duration.zero;
  // px per millisecond for each of the 10 speed levels (geometric, max unchanged)
  static const _kSpeedPxPerMs = [
    0.007,
    0.011,
    0.019,
    0.031,
    0.051,
    0.083,
    0.14,
    0.22,
    0.37,
    0.60,
  ];

  static const _kPrefMinId = 'last_min_id';
  static const _kPrefFontScale = 'font_scale';
  static const _kPrefAnchorOffset = 'anchor_offset';
  static const _kPrefCurrentSura = 'current_sura';
  static const _kPrefCurrentPage = 'current_page';
  int _lastKnownSaveId =
      0; // cached so dispose() can write without a scroll controller
  double _lastKnownAnchorOffset = 0.0; // cached alongside saveId for dispose()
  // Keys for each rendered _AyahRun, keyed by run's first ayah id.
  // Used to scan for visible runs at save time.
  final Map<int, GlobalKey> _runKeyCache = {};
  // Keys for each rendered _PageMarker, keyed by marker's page number.
  // Used to detect which page top is at the viewport top.
  final Map<int, GlobalKey> _pageMarkerKeyCache = {};
  int _lastTitleUpdateMs = 0;
  final Map<int, GlobalKey> _surahHeaderKeyCache = {};
  int? _navHeaderSuraNo; // when set, pin to surah header instead of first ayah
  // First surah name seen on each Mushaf page (built from _ayahs).
  final Map<int, String> _pageToSuraName = {};
  bool _justNavigated = false; // blocks auto _loadPrev right after navigation
  bool _navigating = false; // overlay shown during navigate + back-buffer load
  DateTime _prevCooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Title-bar state — updated on every visible-ayah change.
  String _currentSuraName = '';
  int _currentJuz = 0;
  int _currentPage = 1;

  // Session tracking — records each continuous reading session for wird progress.
  int _sessionStartAyahId = 0;
  int _sessionStartPage = 1;
  DateTime? _sessionStartTime;

  // Singleton highlight — the ayah id navigated to from search.  null = no highlight.
  // When true, _highlightId was set by a user tap (not navigation).
  // The highlight is cleared automatically when it scrolls off screen.
  bool _tapHighlight = false;

  // _highlightKey is attached to the highlighted widget so ensureVisible can
  // precisely scroll to it after correctBy gives the approximate position.
  int? _highlightId;
  GlobalKey? _highlightKey;

  // Basmala text (surah 1 aya 1) — used as the standalone centred line after
  // surah headers for surahs 2-8 and 10-114.  Loaded once at startup.
  String _basmalaText = '';

  // Map Quran page → juz number (standard Hafs mushaf boundaries).
  static int _pageToJuz(int page) {
    const starts = [
      1,
      22,
      42,
      62,
      82,
      102,
      121,
      142,
      162,
      182,
      201,
      221,
      242,
      262,
      282,
      302,
      322,
      342,
      362,
      382,
      402,
      422,
      442,
      462,
      482,
      502,
      522,
      542,
      562,
      582,
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
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[Init] initState — starting app');
    WakelockPlus.enable();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_autoScrolling) _stopAutoScroll();
      // Reset gesture flags: OS may cancel active touches without sending
      // pointer-up events (e.g. notification drawer, home button), leaving
      // _userDragging true and silently blocking the auto-scroll ticker.
      _userDragging = false;
      _isPinching = false;
      _pointerCount = 0;
      // Save precise reading position before app is backgrounded.
      _schedulePositionSave();
      if (widget.isActiveTab) _endSession();
    } else if (state == AppLifecycleState.resumed) {
      // Safety net: clear any flags that may have gone stale across the gap.
      _userDragging = false;
      _isPinching = false;
      _pointerCount = 0;
      if (widget.isActiveTab) _startSession();
    }
  }

  // ── Shared top-inset: every "place at top" call uses this margin. ──────────
  static const double _kTopInset = 24.0;

  /// Top offset that scales with zoom so the landed position feels consistent.
  double get _navTopOffset => _kTopInset * _fontScale;

  /// Scans page markers and surah headers to determine what is currently at the
  /// viewport top, then updates _currentSuraName / _currentJuz.
  ///
  /// _PageMarker(N) sits at the N→N+1 page boundary; when it has scrolled
  /// above the viewport top the visible page is N+1.
  ///
  /// _SurahHeader(S) sits at the start of surah S; the last header to scroll
  /// above the viewport top is the current surah — more precise than
  /// _pageToSuraName when multiple surahs share one Mushaf page.
  void _updateTitleBarFromViewport() {
    if (!_scrollController.hasClients || _ayahs.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastTitleUpdateMs < 100) return;
    _lastTitleUpdateMs = nowMs;
    final pos = _scrollController.position;

    // ── Page detection (for juz) ─────────────────────────────────────────────
    int primPage = 0;
    double primTop = double.negativeInfinity;
    for (final entry in _pageMarkerKeyCache.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      try {
        final reveal =
            RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset;
        final top = reveal - pos.pixels;
        if (top <= 0 && top > primTop) {
          primTop = top;
          primPage = entry.key;
        }
      } catch (_) {}
    }
    // marker(N) above viewport → page N+1 is at top.
    // When primPage == 0 (no marker above viewport), keep the last known page
    // rather than jumping to _ayahs.first.page — that jump is the root cause of
    // the topbar oscillating back to an early surah when the marker briefly
    // drops below the viewport threshold due to scroll physics.
    final int currentPage;
    if (primPage != 0) {
      currentPage = primPage + 1;
    } else {
      currentPage = _currentPage > 0 ? _currentPage : _ayahs.first.page;
    }
    _currentPage = currentPage;

    // ── Surah detection (more granular than page→surah map) ──────────────────
    int primSurahNo = 0;
    double primSurahTop = double.negativeInfinity;
    for (final entry in _surahHeaderKeyCache.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      try {
        final reveal =
            RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset;
        final top = reveal - pos.pixels;
        if (top <= 0 && top > primSurahTop) {
          primSurahTop = top;
          primSurahNo = entry.key;
        }
      } catch (_) {}
    }
    // Last surah header above viewport = current surah.
    // Fall back to _currentSuraName (set on navigation) so the topbar is
    // immediately correct even before the first header scrolls past.
    final String suraName;
    if (primSurahNo != 0) {
      final a = _ayahs.firstWhere((a) => a.suraNo == primSurahNo,
          orElse: () => _ayahs.first);
      suraName = a.suraNameAr;
    } else if (_currentSuraName.isNotEmpty) {
      suraName = _currentSuraName;
    } else {
      suraName = _pageToSuraName[currentPage] ?? _ayahs.first.suraNameAr;
    }

    final juz = _pageToJuz(currentPage);
    if (suraName != _currentSuraName || juz != _currentJuz) {
      setState(() {
        _currentSuraName = suraName;
        _currentJuz = juz;
      });
    }
  }

  /// Unified placement helper.  Scrolls so [key]'s widget top sits at
  /// [offsetFromTop] pixels below the viewport top (negative = above top).
  /// Uses [_kTopInset] by default.
  void _placeItemAtTop(GlobalKey key, {double offsetFromTop = _kTopInset}) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final reveal =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset;
    final target = (reveal - offsetFromTop).clamp(0.0, pos.maxScrollExtent);
    debugPrint('[PlaceAtTop] offset=${offsetFromTop.toStringAsFixed(1)} '
        'reveal=${reveal.toStringAsFixed(0)} → ${target.toStringAsFixed(0)}');
    _scrollController.jumpTo(target);
  }

  /// Captures the top-viewport anchor at pinch start (run-based + raw-pixel fallback).
  /// Captures raw scroll pixels at pinch start.  Run-based anchoring is
  /// unreliable for zoom because the anchor run may be far above the viewport
  /// (outside ListView's live layout range), giving stale revealOffset values.
  /// Proportional pixel scaling is algebraically equivalent for uniform content
  /// and is always reliable.
  /// Captures the ayah-run closest to the viewport top as the zoom anchor.
  /// We prefer runs at or just above the top (negative topOnScreen) over runs
  /// further below, so we pick the one with topOnScreen nearest to 0 while
  /// still being within the visible region.
  void _captureZoomAnchor() {
    if (!_scrollController.hasClients) return;
    _zoomAnchorKey = null;
    final pos = _scrollController.position;
    final viewH = pos.viewportDimension;
    GlobalKey? bestKey;
    double bestDist = double.infinity;
    for (final key in _runKeyCache.values) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      try {
        final reveal =
            RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset;
        final topOnScreen = reveal - pos.pixels;
        // Only consider runs that are near or in the viewport.
        if (topOnScreen < viewH) {
          final dist = topOnScreen.abs();
          if (dist < bestDist) {
            bestDist = dist;
            bestKey = key;
            _zoomAnchorViewportOffset = topOnScreen;
          }
        }
      } catch (_) {}
    }
    _zoomAnchorKey = bestKey;
  }

  /// Restores scroll so the anchor run stays at the same viewport offset.
  /// After the jump, recaptures the anchor so subsequent corrections are
  /// relative to the actual new view rather than a stale far-away run top.
  void _restoreZoomAnchor() {
    final key = _zoomAnchorKey;
    if (key == null) return;
    _placeItemAtTop(key, offsetFromTop: _zoomAnchorViewportOffset);
    // Recapture so next frame anchors to the now-visible content,
    // not to a run top that may be far off-screen.
    _captureZoomAnchor();
  }

  void _schedulePositionSave() {
    if (!mounted || !_scrollController.hasClients || _ayahs.isEmpty) return;
    _doSaveReadingPosition();
  }

  void _debounceSave() {
    _saveDebounce?.cancel();
    _saveDebounce =
        Timer(const Duration(milliseconds: 1500), _doSaveReadingPosition);
  }

  /// Scans visible _AyahRun widgets, picks the one that owns the viewport top
  /// (top-edge at or just above y=0), and saves anchor id + topOnScreen to prefs.
  void _doSaveReadingPosition() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final viewportH = pos.viewportDimension;

    // Primary: run whose top is ≤ 0 and extends into viewport (owns viewport top).
    // Fallback: first run fully below viewport top.
    double primTop = double.negativeInfinity;
    int primId = 0;
    double fallTop = double.infinity;
    int fallId = 0;

    for (final entry in _runKeyCache.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      try {
        final reveal =
            RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset;
        final top = reveal - pos.pixels;
        final h = box.size.height;
        if (top < viewportH && top + h > 0) {
          // visible
          if (top <= 0 && top > primTop) {
            primTop = top;
            primId = entry.key;
          }
          if (top > 0 && top < fallTop) {
            fallTop = top;
            fallId = entry.key;
          }
        }
      } catch (_) {}
    }

    final anchorId = primId != 0
        ? primId
        : (fallId != 0
            ? fallId
            : (_lastKnownSaveId > 0
                ? _lastKnownSaveId
                : (_ayahs.isNotEmpty ? _ayahs.first.id : 0)));
    final anchorOffset = primId != 0 ? primTop : (fallId != 0 ? fallTop : 0.0);
    final measured = primId != 0 || fallId != 0;

    // Only update the cache when we actually measured something.  If no run
    // was in the render tree (e.g. called right after a navigation clear),
    // keep the last known values so dispose() doesn't write anchorOffset=0.0.
    if (measured) {
      _lastKnownSaveId = anchorId;
      _lastKnownAnchorOffset = anchorOffset;
    }
    debugPrint('[Save] anchor=$_lastKnownSaveId '
        'topOffset=${_lastKnownAnchorOffset.toStringAsFixed(1)} scale=$_fontScale '
        'measured=$measured');
    if (_lastKnownSaveId > 0) {
      SharedPreferences.getInstance().then((p) {
        p.setInt(_kPrefMinId, _lastKnownSaveId);
        p.setDouble(_kPrefAnchorOffset, _lastKnownAnchorOffset);
        p.setDouble(_kPrefFontScale, _fontScale);
        if (_currentSuraName.isNotEmpty)
          p.setString(_kPrefCurrentSura, _currentSuraName);
        if (_currentPage > 0) p.setInt(_kPrefCurrentPage, _currentPage);
      });
    }
  }

  @override
  void didUpdateWidget(AyahsPage old) {
    super.didUpdateWidget(old);
    if (widget.isActiveTab && !old.isActiveTab) {
      _startSession();
      if (_tutorialPending) {
        _tutorialPending = false;
        _showTutorialStep(1);
      }
    } else if (!widget.isActiveTab && old.isActiveTab) {
      _endSession();
    }
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _startSession() {
    _sessionStartAyahId = _lastKnownSaveId > 0
        ? _lastKnownSaveId
        : (_ayahs.isNotEmpty ? _ayahs.first.id : 1);
    _sessionStartPage = _currentPage > 0 ? _currentPage : 1;
    _sessionStartTime = DateTime.now();
  }

  Future<void> _endSession() async {
    if (_sessionStartTime == null) return;
    final startTime = _sessionStartTime!;
    final startedAt = startTime.millisecondsSinceEpoch;
    final startAyahId = _sessionStartAyahId;
    final startPage = _sessionStartPage;
    _sessionStartTime =
        null; // clear immediately to prevent double-end on re-entry

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime).inSeconds;
    if (duration < 5) return; // ignore accidental taps

    final endAyahId = _lastKnownSaveId > 0
        ? _lastKnownSaveId
        : (_ayahs.isNotEmpty ? _ayahs.last.id : startAyahId);
    final endPage = _currentPage > 0 ? _currentPage : startPage;
    final pagesRead = (endPage - startPage).abs();

    final session = ReadingSession(
      date: _todayString(),
      startAyahId: startAyahId,
      endAyahId: endAyahId,
      startPage: startPage,
      endPage: endPage,
      pagesRead: pagesRead,
      durationSeconds: duration,
      startedAt: startedAt,
      endedAt: endTime.millisecondsSinceEpoch,
    );
    await UserDb.instance.insertSession(session);

    final plan = await UserDb.instance.getActivePlan();
    if (plan == null) return;
    final delta = plan.targetType == 'pages'
        ? pagesRead.toDouble()
        : plan.targetType == 'minutes'
            ? (duration / 60.0)
            : (endAyahId - startAyahId).abs().toDouble();
    await UserDb.instance.upsertProgress(_todayString(), plan.id, delta);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('[Dispose] dispose — saving lastKnownSaveId=$_lastKnownSaveId');
    WakelockPlus.disable();
    _tutorialEntry?.remove();
    _tutorialEntry = null;
    _saveDebounce?.cancel();
    _zoomBadgeTimer?.cancel();
    _autoScrollTicker?.dispose();
    // Use cached ID — scroll controller has no clients by the time dispose() runs.
    if (_lastKnownSaveId > 0) {
      SharedPreferences.getInstance().then((p) {
        p.setInt(_kPrefMinId, _lastKnownSaveId);
        p.setDouble(_kPrefAnchorOffset, _lastKnownAnchorOffset);
        p.setDouble(_kPrefFontScale, _fontScale);
        if (_currentSuraName.isNotEmpty)
          p.setString(_kPrefCurrentSura, _currentSuraName);
        if (_currentPage > 0) p.setInt(_kPrefCurrentPage, _currentPage);
      });
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
        _highlightId = null;
        _highlightKey = null;
        _tapHighlight = false;
      });
    }

    final pos = _scrollController.position;

    // Debounce a precise key-based save so _kPrefMinId and _kPrefAnchorOffset
    // are always written together from the same snapshot.
    if (!_loadingPrev && !_loadingMore && _ayahs.isNotEmpty) {
      _debounceSave();
    }
    // Update title bar based on which page top is at the viewport top.
    _updateTitleBarFromViewport();

    if (!_loadingMore &&
        !_reachedBottom &&
        pos.pixels >= pos.maxScrollExtent - 1500) {
      debugPrint('[Scroll] Near bottom → _loadMore');
      _loadMore();
    }
    // Once the user has scrolled meaningfully down, lift the startup/nav guard
    // so a subsequent scroll back to the top will load the back-buffer normally.
    if (_justNavigated && pos.pixels > 800) _justNavigated = false;

    if (!_loadingPrev && !_reachedTop && !_justNavigated && pos.pixels <= 600) {
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

  Future<List<Ayah>> _fetch(
      String where, List<Object> args, String order) async {
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

  // Guard: FCM init must only happen once per process; calling requestPermission
  // again while a prior call is pending throws a FirebaseException in tests.
  static bool _fcmInitDone = false;

  Future<void> _initFcm() async {
    if (_fcmInitDone) return;
    _fcmInitDone = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      debugPrint('[FCM] device token: $token');
    } catch (e) {
      debugPrint('[FCM] init failed (emulator?): $e');
      return;
    }
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null || !mounted) return;
      final ctx = this.context;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('${n.title ?? ''}\n${n.body ?? ''}'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ));
    });
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_kPrefMinId) ?? 1;
    final savedScale = prefs.getDouble(_kPrefFontScale) ?? 1.0;
    final savedAnchorOffset = prefs.getDouble(_kPrefAnchorOffset) ?? 0.0;
    if (savedScale != _fontScale) {
      setState(() => _fontScale = savedScale.clamp(0.5, 3.0));
    }
    debugPrint('[Init] Saved ayah id=$savedId fontScale=$savedScale '
        'anchorOffset=${savedAnchorOffset.toStringAsFixed(1)}');
    _initFcm(); // fire-and-forget; runs in parallel with DB load
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
        debugPrint(
            '[Init] Basmala raw last-cp=0x${raw.runes.last.toRadixString(16)} len=${raw.length}');
        final runes = raw.runes.toList();
        while (runes.isNotEmpty) {
          final cp = runes.last;
          if ((cp >= 0x30 && cp <= 0x39) || // ASCII 0-9
              (cp >= 0x0660 && cp <= 0x0669) || // Arabic-Indic ٠-٩
              (cp >= 0x06F0 && cp <= 0x06F9) || // Extended Arabic-Indic ۰-۹
              (cp >= 0xE000 &&
                  cp <= 0xF8FF) || // Private Use Area (HafsSmart glyphs)
              cp == 0x06DD ||
              cp == 0xFD3E ||
              cp == 0xFD3F || // ۝ ﴿ ﴾
              cp == 0x20 ||
              cp == 0x00A0) {
            // space / NBSP
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
      // Load a symmetric window: 4 pages before and 2 after the target.
      // This pre-populates the back-buffer so correctBy is never needed —
      // the target lands near the middle of the list and ensureVisible is
      // guaranteed to find it regardless of zoom level.
      final fromPage = (savedPage - 4).clamp(1, 604);
      final toPage = (savedPage + 2).clamp(1, 604);
      debugPrint(
          '[Init] savedPage=$savedPage → loading pages $fromPage–$toPage');

      final rows = await db.rawQuery(
        'SELECT id, sura_no, aya_no, page, sura_name_ar, aya_text '
        'FROM quran_ayahs WHERE page >= ? AND page <= ? ORDER BY id ASC',
        [fromPage, toPage],
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
      final target =
          ayahs.firstWhere((a) => a.id >= savedId, orElse: () => ayahs.first);
      for (final a in ayahs) {
        _pageToSuraName.putIfAbsent(a.page, () => a.suraNameAr);
      }
      if (!mounted) return;
      setState(() {
        _ayahs.addAll(ayahs);
        _recomputeItems();
        _minId = ayahs.first.id;
        _maxId = ayahs.last.id;
        _reachedTop = fromPage == 1;
        _reachedBottom = toPage >= 604;
        _initialLoading = false;
        // Initialise title bar and page tracker from the saved ayah.
        _currentSuraName = target.suraNameAr;
        _currentJuz = _pageToJuz(target.page);
        _currentPage = target.page;
        // Navigation overlay + stability-pinFrame path.
        _highlightId = savedId;
        _highlightKey = GlobalKey();
        _tapHighlight = false;
        _navigating = true; // overlay shown; _onScroll blocked entirely
        _justNavigated = true;
      });
      debugPrint('[Init] Done: _minId=$_minId _maxId=$_maxId '
          'reachedTop=$_reachedTop reachedBottom=$_reachedBottom '
          'resumeTarget=$savedId');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Only skip pin when truly restoring to the very beginning
        // (first ayah, no offset saved). Any non-trivial target still needs
        // the full pinFrame path to land at the right position.
        final isDefaultStart =
            savedId <= (_ayahs.isNotEmpty ? _ayahs.first.id : 1) &&
                savedAnchorOffset == 0.0;
        if (fromPage == 1 && savedPage == 1 && isDefaultStart) {
          // Already at the very top with nothing to restore — skip pin.
          _justNavigated = false;
          setState(() => _navigating = false);
          debugPrint('[Init] Settled — at top, no pin needed (default start)');
        } else {
          // Target is pre-buffered near the middle of the list.
          // Rough jump brings it into cacheExtent; pinFrame corrects precisely.
          _roughJumpToHighlight();
          final initMax = _scrollController.hasClients
              ? _scrollController.position.maxScrollExtent
              : 0.0;
          debugPrint('[Init] Rough jump done — starting pinFrame '
              'postOffset=${savedAnchorOffset.toStringAsFixed(1)}');
          _runPinFrame(60, initMax, 0, postOffset: savedAnchorOffset);
        }
      });
    } catch (e) {
      debugPrint('[Init] ERROR: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
    _checkTutorial();
    if (widget.isActiveTab && _ayahs.isNotEmpty) _startSession();
  }

  Future<void> _loadMore() async {
    debugPrint('[LoadMore] Fetching id > $_maxId');
    setState(() => _loadingMore = true);
    try {
      final ayahs = await _fetch('id > ?', [_maxId], 'id ASC');
      debugPrint('[LoadMore] Got ${ayahs.length} ayahs'
          '${ayahs.isNotEmpty ? " (ids ${ayahs.first.id}–${ayahs.last.id})" : ""}');
      for (final a in ayahs) {
        _pageToSuraName.putIfAbsent(a.page, () => a.suraNameAr);
      }
      setState(() {
        _ayahs.addAll(ayahs);
        _recomputeItems();
        if (ayahs.isNotEmpty) _maxId = ayahs.last.id;
        _reachedBottom = ayahs.length < _chunk;
      });
      // Reset flag after the next frame so the layout-triggered scroll
      // notification sees _loadingMore=true and doesn't double-fire.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _loadingMore = false);
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
        setState(() {
          _reachedTop = true;
          _loadingPrev = false;
        });
        return;
      }
      debugPrint('[LoadPrev] Got ${ayahs.length} ayahs '
          '(ids ${ayahs.first.id}–${ayahs.last.id})');
      // Capture position BEFORE the async gap so we know where the user was.
      final oldMax = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final oldPixels = _scrollController.hasClients
          ? _scrollController.position.pixels
          : 0.0;
      for (final a in ayahs) {
        _pageToSuraName.putIfAbsent(a.page, () => a.suraNameAr);
      }
      setState(() {
        _ayahs.insertAll(0, ayahs);
        _recomputeItems();
        _minId = ayahs.first.id;
        _reachedTop = _minId == 1;
        // _loadingPrev intentionally left true here
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final pos = _scrollController.position;
          final newMax = pos.maxScrollExtent;
          final delta = newMax - oldMax;
          debugPrint(
              '[LoadPrev-correctBy] oldPx=${oldPixels.toStringAsFixed(0)} '
              'oldMax=${oldMax.toStringAsFixed(0)} '
              'newMax=${newMax.toStringAsFixed(0)} '
              'delta=${delta.toStringAsFixed(0)}');
          if (delta > 0) {
            // If the user had already hit the hard top (pixels ≈ 0) by the
            // time the DB returned, scroll to 0 so the new pages are
            // immediately visible.  Otherwise keep the viewport locked on the
            // same content (stable correction).
            final target =
                oldPixels < 10.0 ? 0.0 : (oldPixels + delta).clamp(0.0, newMax);
            _scrollController.jumpTo(target);
            debugPrint(
                '[LoadPrev-correctBy] → jumpTo=${target.toStringAsFixed(0)}');
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
      _runKeyCache.clear();
      _pageMarkerKeyCache.clear();
      _surahHeaderKeyCache.clear();
      _pageToSuraName.clear();
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
      final targetPage =
          pageRows.isNotEmpty ? pageRows.first['page'] as int : 1;
      // Symmetric window: 4 pages before + 2 after target.
      // Back-buffer is pre-loaded so correctBy is never needed.
      final fromPage = (targetPage - 4).clamp(1, 604);
      final toPage = (targetPage + 2).clamp(1, 604);
      debugPrint(
          '[Navigate] targetPage=$targetPage → loading pages $fromPage–$toPage');

      final rows = await db.rawQuery(
        'SELECT id, sura_no, aya_no, page, sura_name_ar, aya_text '
        'FROM quran_ayahs WHERE page >= ? AND page <= ? ORDER BY id ASC',
        [fromPage, toPage],
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

      final targetIdx = ayahs.indexWhere((a) => a.id >= startId);
      debugPrint('[Navigate] Loaded ${ayahs.length} ayahs'
          '${ayahs.isNotEmpty ? " (ids ${ayahs.first.id}–${ayahs.last.id})" : ""}'
          ' — target id=$startId at list-idx=$targetIdx');

      for (final a in ayahs) {
        _pageToSuraName.putIfAbsent(a.page, () => a.suraNameAr);
      }
      _justNavigated = true;
      setState(() {
        _ayahs.addAll(ayahs);
        _recomputeItems();
        if (ayahs.isNotEmpty) {
          _minId = ayahs.first.id;
          _maxId = ayahs.last.id;
          _reachedTop = fromPage == 1;
          // Update title bar to the target ayah.
          final target = ayahs.firstWhere((a) => a.id >= startId,
              orElse: () => ayahs.first);
          _currentSuraName = target.suraNameAr;
          _currentJuz = _pageToJuz(target.page);
          _currentPage = target.page;
        }
        _reachedBottom = toPage >= 604;
        // Set singleton highlight to the navigated ayah.
        // Fresh key each navigation so ensureVisible finds the right widget.
        _highlightId = startId;
        _highlightKey = GlobalKey();
        _tapHighlight = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Target is pre-buffered; rough jump brings it into cacheExtent,
        // then pinFrame corrects precisely — no correctBy needed.
        _roughJumpToHighlight();
        final initMax = _scrollController.hasClients
            ? _scrollController.position.maxScrollExtent
            : 0.0;
        debugPrint('[Navigate] Rough jump done — starting pinFrame');
        _runPinFrame(60, initMax, 0, postOffset: _navTopOffset);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _navigating = false;
      });
    }
  }

  // ── Position helpers ──────────────────────────────────────────────────────

  /// Rough-scrolls the list so the highlighted ayah is approximately centred.
  /// Uses item-index fraction of maxScrollExtent — zoom-independent because
  /// we only need to land within cacheExtent (1500 px) of the target; the
  /// precise correction is done by ensureVisible in _runPinFrame.
  void _roughJumpToHighlight() {
    if (!_scrollController.hasClients || _highlightId == null) return;
    final itemIdx = _items.indexWhere(
      (it) => it is _AyahRun && it.ayahs.any((a) => a.id == _highlightId),
    );
    if (itemIdx < 0 || _items.length <= 1) return;
    final frac = itemIdx / (_items.length - 1);
    final pos = _scrollController.position;
    _scrollController
        .jumpTo((frac * pos.maxScrollExtent).clamp(0.0, pos.maxScrollExtent));
  }

  /// Frame-by-frame pin loop.  Places the highlight widget at [postOffset]
  /// below the viewport top each frame until layout has been stable for 5
  /// consecutive frames.  Falls back to _roughJumpToHighlight while the
  /// target widget is not yet built.
  /// [postOffset] defaults to [_kTopInset] (navigation) or the saved
  /// topOnScreen value (cold-resume).
  void _runPinFrame(int framesLeft, double prevMax, int stableCount,
      {double postOffset = _kTopInset}) {
    final buildCtx = this.context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hlKey = _highlightKey;
      final headerKey = _navHeaderSuraNo != null
          ? _surahHeaderKeyCache[_navHeaderSuraNo]
          : null;
      final pinKey = (headerKey?.currentContext != null) ? headerKey : hlKey;
      if (pinKey?.currentContext != null) {
        _placeItemAtTop(pinKey!, offsetFromTop: postOffset);
      } else {
        _roughJumpToHighlight(); // pull target into cacheExtent, try again next frame
      }
      final pos =
          _scrollController.hasClients ? _scrollController.position : null;
      final currentMax = pos?.maxScrollExtent ?? prevMax;
      final maxDelta = (currentMax - prevMax).abs();
      final newStable = maxDelta < 5.0 ? stableCount + 1 : 0;
      final kbHeight = MediaQuery.of(buildCtx).viewInsets.bottom;
      debugPrint('[pin] left=$framesLeft max=${currentMax.toStringAsFixed(0)} '
          'Δ=${maxDelta.toStringAsFixed(1)} stable=$newStable '
          'kb=${kbHeight.toStringAsFixed(0)}');
      if ((kbHeight == 0 && newStable >= 5) || framesLeft <= 0) {
        debugPrint('[Nav-postSettle] settled hl=$_highlightId '
            'stable=$newStable timedOut=${framesLeft <= 0}');
        _justNavigated = false;
        final hlIdNow = _highlightId;
        final hlKeyNow = _highlightKey;
        if (hlIdNow != null) _lastKnownSaveId = hlIdNow;
        // Final precise placement before dismissing the overlay.
        final finalHeaderKey = _navHeaderSuraNo != null
            ? _surahHeaderKeyCache[_navHeaderSuraNo]
            : null;
        final finalPinKey = (finalHeaderKey?.currentContext != null)
            ? finalHeaderKey
            : hlKeyNow;
        if (finalPinKey?.currentContext != null) {
          _placeItemAtTop(finalPinKey!, offsetFromTop: postOffset);
        }
        _navHeaderSuraNo = null;
        setState(() => _navigating = false);
        _doSaveReadingPosition(); // persist current_page/sura now that navigation settled
        debugPrint(
            '[Navigate] Settled — overlay dismissed, highlight=$hlIdNow');
        // Safety re-pin 500ms later — use captured pin key (header or ayah).
        final safetyPinKey = finalPinKey;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _navigating || _userDragging) return;
          if (safetyPinKey?.currentContext == null) return;
          _placeItemAtTop(safetyPinKey!, offsetFromTop: postOffset);
          debugPrint('[Nav-postSettle] safety re-pin hl=$hlIdNow');
        });
      } else {
        _runPinFrame(framesLeft - 1, currentMax, newStable,
            postOffset: postOffset);
      }
    });
  }

  Future<void> _navigateToSurah(int suraNo, int firstAyahId) async {
    _navHeaderSuraNo = suraNo;
    await _navigateTo(firstAyahId);
  }

  void _openSearch() {
    _stopAutoScroll();
    setState(() {
      _showSearch = true;
      _searchResults = [];
      _surahHits = [];
      _searchCtrl.clear();
    });
  }

  void _closeSearch() => setState(() => _showSearch = false);

  void _onTapAyah(int id) {
    setState(() {
      _highlightId = id;
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
      if (!_loadingMore &&
          !_reachedBottom &&
          pos.pixels >= pos.maxScrollExtent - 1500) {
        _loadMore();
      }
    })
      ..start();
    setState(() => _autoScrolling = true);
    widget.onAutoScrollChanged?.call(true);
  }

  void _stopAutoScroll() {
    _autoScrollTicker?.dispose();
    _autoScrollTicker = null;
    setState(() => _autoScrolling = false);
    widget.onAutoScrollChanged?.call(false);
  }

  void _toggleAutoScroll() =>
      _autoScrolling ? _stopAutoScroll() : _startAutoScroll();

  void _toggleFocusMode() {
    setState(() => _focusMode = !_focusMode);
    widget.onFocusModeChanged?.call(_focusMode);
  }

  void _speedDown() {
    if (_speedLevel > 0) setState(() => _speedLevel--);
    if (!_autoScrolling) _startAutoScroll();
  }

  void _speedUp() {
    if (_speedLevel < 9) setState(() => _speedLevel++);
    if (!_autoScrolling) _startAutoScroll();
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tutorial_shown') ?? false;
    if (!seen && mounted) {
      if (widget.isActiveTab) {
        _showTutorialStep(1);
      } else {
        _tutorialPending = true;
      }
    }
  }

  void _showTutorialStep(int step) {
    _tutorialEntry?.remove();
    final entry = OverlayEntry(
      builder: (_) => step == 1
          ? _TutorialStep1Overlay(
              playBtnKey: _playBtnTutorialKey,
              onNext: () => _showTutorialStep(2),
            )
          : _TutorialStep2Overlay(onDone: _closeTutorial),
    );
    _tutorialEntry = entry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Overlay.of(this.context).insert(entry);
    });
  }

  void _closeTutorial() {
    _tutorialEntry?.remove();
    _tutorialEntry = null;
    SharedPreferences.getInstance()
        .then((p) => p.setBool('tutorial_shown', true));
  }

  Future<void> _doSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _surahHits = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final db = await _openDb();
    // Strip tashkeel so search matches diacritic-laden DB surah names
    final strippedQuery = query.replaceAll(RegExp(r'[ً-ٰٟ]'), '');
    final allSurahRows = await db.rawQuery(
      'SELECT sura_no, sura_name_ar, MIN(id) as first_id '
      'FROM quran_ayahs GROUP BY sura_no ORDER BY sura_no',
    );
    final surahRows = allSurahRows.where((r) {
      final name = (r['sura_name_ar'] as String)
          .replaceAll(RegExp(r'[ً-ٰٟ]'), '');
      return name.contains(strippedQuery);
    }).toList();
    List<Map<String, Object?>> ayahRows = [];
    if (query.length >= 3) {
      ayahRows = await db.rawQuery(
        'SELECT id, sura_no, aya_no, sura_name_ar, aya_text_emlaey '
        'FROM quran_ayahs WHERE aya_text_emlaey LIKE ? ORDER BY id LIMIT 20',
        ['%$query%'],
      );
    }
    await db.close();
    setState(() {
      _surahHits = surahRows
          .map((r) => SurahHit(
                suraNo: r['sura_no'] as int,
                nameAr: r['sura_name_ar'] as String,
                firstAyahId: r['first_id'] as int,
              ))
          .toList();
      _searchResults = ayahRows
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
            const Text('المصدر:',
                textAlign: TextAlign.center,
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
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF1E88E5),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('للتواصل:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6)),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('mailto:info@progspace.sa')),
              child: const Text(
                'info@progspace.sa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
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
        onNavigateToSurah: (suraNo, firstAyahId) {
          Navigator.pop(ctx);
          _navigateToSurah(suraNo, firstAyahId);
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
    final headerTextColor = isDark ? _tw70 : _tb87;
    final edgeLineColor = isDark
        ? const Color(0xFFC8A842).withValues(alpha: 0.20)
        : const Color(0xFF8B6914).withValues(alpha: 0.15);

    if (_initialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Error: $_error')));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          (_autoScrolling || _focusMode) ? 0 : kToolbarHeight + 30.0,
        ),
        child: ClipRect(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            offset: (_autoScrolling || _focusMode) ? const Offset(0, -1) : Offset.zero,
            child: AppBar(
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Row(
                textDirection: TextDirection.ltr,
                children: [
                  // LEFT side
                  _barBtn(
                    icon: isDark
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
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
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        isDark
                            ? 'assets/images/quran-type-white.png'
                            : 'assets/images/quran-type.png',
                        height: 26,
                      ),
                    ),
                  ),
                  // RIGHT side
                  _barBtn(
                    key: const Key('btn_nav'),
                    icon: Icons.menu_book_outlined,
                    tooltip: 'انتقل إلى',
                    onPressed: _showNavSheet,
                    isDark: isDark,
                  ),
                  _barBtn(
                    key: const Key('btn_search'),
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
                          key: const Key('text_topbar_surah'),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? _tw54 : _tb54,
                            fontFamily: 'sans-serif',
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
                          key: const Key('text_topbar_juz'),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? _tw54 : _tb54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ), // AppBar
          ), // AnimatedSlide
        ), // ClipRect
      ), // PreferredSize
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        height: _focusMode ? 0.0 : 56.0 + MediaQuery.of(context).viewPadding.bottom,
        clipBehavior: Clip.hardEdge,
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
                KeyedSubtree(
                  key: _playBtnTutorialKey,
                  child: _barBtn(
                    key: const Key('btn_autoscroll'),
                    icon: _autoScrolling
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: _autoScrolling ? 'إيقاف' : 'تشغيل',
                    onPressed: _toggleAutoScroll,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 4),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: dividerColor,
                  indent: 12,
                  endIndent: 12,
                ),
                const Spacer(),
                // Speed control
                _barBtn(
                  key: const Key('btn_speed_down'),
                  icon: Icons.remove,
                  tooltip: 'أبطأ',
                  onPressed: _speedDown,
                  isDark: isDark,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${_speedLevel + 1}',
                    key: const Key('text_speed_level'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? _tw70 : _tb87,
                    ),
                  ),
                ),
                _barBtn(
                  key: const Key('btn_speed_up'),
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
          Listener(
            // Detect 2-finger touch-down instantly (before any movement),
            // so NeverScrollableScrollPhysics kicks in before the ListView
            // can intercept the vertical component of the pinch gesture.
            onPointerDown: (_) {
              _pointerCount++;
              if (_pointerCount >= 2 && !_isPinching) {
                _baseFontScale = _fontScale; // anchor before first scale frame
                _zoomBadgeTimer?.cancel();
                setState(() {
                  _isPinching = true;
                  _showZoomBadge = true;
                });
              }
            },
            onPointerUp: (_) {
              _pointerCount = (_pointerCount - 1).clamp(0, 10);
              if (_pointerCount < 2 && _isPinching) {
                setState(() => _isPinching = false);
                // Restore position after layout settles with the new font scale.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _restoreZoomAnchor();
                });
                SharedPreferences.getInstance()
                    .then((p) => p.setDouble(_kPrefFontScale, _fontScale));
                _zoomBadgeTimer?.cancel();
                _zoomBadgeTimer = Timer(const Duration(milliseconds: 1500), () {
                  if (mounted) setState(() => _showZoomBadge = false);
                });
              }
            },
            onPointerCancel: (_) {
              _pointerCount = (_pointerCount - 1).clamp(0, 10);
              if (_pointerCount < 2 && _isPinching) {
                setState(() => _isPinching = false);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _restoreZoomAnchor();
                });
                SharedPreferences.getInstance()
                    .then((p) => p.setDouble(_kPrefFontScale, _fontScale));
                _zoomBadgeTimer?.cancel();
                _zoomBadgeTimer = Timer(const Duration(milliseconds: 1500), () {
                  if (mounted) setState(() => _showZoomBadge = false);
                });
              }
            },
            child: GestureDetector(
              onTap: _toggleFocusMode,
              onScaleStart: (_) {
                if (!_isPinching) _baseFontScale = _fontScale;
                _captureZoomAnchor();
              },
              onScaleUpdate: (d) {
                if (_isPinching) {
                  setState(() {
                    final damped = 1.0 + (d.scale - 1.0) * 0.5;
                    _fontScale = (_baseFontScale * damped).clamp(0.5, 3.0);
                  });
                  if (!_zoomRestorePending) {
                    _zoomRestorePending = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _zoomRestorePending = false;
                      if (mounted) _restoreZoomAnchor();
                    });
                  }
                }
              },
              onScaleEnd: (_) {}, // managed by Listener
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
                  key: const Key('ayah_list'),
                  controller: _scrollController,
                  // Disable scroll physics during pinch so the ListView yields
                  // pointer events to the parent ScaleGestureRecognizer.
                  physics: _isPinching
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  // Larger cache ensures more back-buffer items are measured before
                  // correctBy fires, giving it a more accurate delta to work with.
                  cacheExtent: 1500,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];

                    // ── Surah header ──────────────────────────────────────
                    if (item is _SurahHeader) {
                      return KeyedSubtree(
                        key: _surahHeaderKeyCache.putIfAbsent(
                            item.suraNo, GlobalKey.new),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          color: headerBg,
                          child: Column(
                            children: [
                              Divider(
                                  height: 1, thickness: 1, color: dividerColor),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'سورة ${item.suraNameAr}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20 * _fontScale,
                                    fontWeight: FontWeight.bold,
                                    color: headerTextColor,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ),
                              Divider(
                                  height: 1, thickness: 1, color: dividerColor),
                            ],
                          ),
                        ),
                      );
                    }

                    // ── Basmala line (aya 1, surahs 2-8 and 10-114) ──────
                    if (item is _BasmalaItem) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                      final markerKey = _pageMarkerKeyCache.putIfAbsent(
                          item.page, GlobalKey.new);
                      return KeyedSubtree(
                        key: markerKey,
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color: dividerColor, thickness: 1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '${item.page}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? _tw38 : _tb38,
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: dividerColor, thickness: 1)),
                            ],
                          ),
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
                          ? const Color(0xFFFFD54F) // amber 300
                          : const Color(0xFFF57F17); // amber 900

                      // Flatten all ayahs into one Wrap so words flow across
                      // ayah boundaries naturally. Each word is a separate
                      // RichText to isolate HarfBuzz shaping contexts and
                      // prevent cross-word GSUB reordering (e.g. يعرفون+كلا).
                      final wordWidgets = <Widget>[];
                      for (final a in item.ayahs) {
                        final isHl = a.id == _highlightId;
                        final words = a.ayaText
                            .split(' ')
                            .where((w) => w.isNotEmpty)
                            .toList();
                        for (int i = 0; i < words.length; i++) {
                          Widget w = RichText(
                            textDirection: TextDirection.rtl,
                            text: TextSpan(
                              style: baseStyle.copyWith(
                                color: isHl ? hlColor : null,
                              ),
                              text: '${words[i]} ',
                            ),
                          );
                          if (isHl && i == 0 && _highlightKey != null) {
                            w = KeyedSubtree(key: _highlightKey!, child: w);
                          }
                          wordWidgets.add(GestureDetector(
                            onLongPress: () => _onTapAyah(a.id),
                            child: w,
                          ));
                        }
                      }
                      final runKey = _runKeyCache.putIfAbsent(
                          item.ayahs.first.id, GlobalKey.new);
                      return CustomPaint(
                        foregroundPainter: _PageEdgePainter(
                          item.ayahs.first.page.isOdd,
                          edgeLineColor,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: KeyedSubtree(
                            key: runKey,
                            child: Wrap(
                              textDirection: TextDirection.rtl,
                              alignment: WrapAlignment.center,
                              children: wordWidgets,
                            ),
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ), // closes ListView.builder
              ), // closes NotificationListener
            ), // closes GestureDetector
          ), // closes Listener
          // ── Zoom badge ─────────────────────────────────────────────
          Positioned(
            top: 72,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showZoomBadge ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Text(
                      '${_fontScale.toStringAsFixed(1)}×',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                        child: LayoutBuilder(
                            builder: (_, lc) {
                              // Overhead: Material padding(16) + Row(~48) +
                              // dividers(≤2) + buffer = 120 dp. Keeps the
                              // Column within lc.maxHeight on small/keyboard-up
                              // screens (observed h=313 on SM G9880).
                              const overhead = 120.0;
                              final budget =
                                  (lc.maxHeight - overhead).clamp(80.0, 540.0);
                              final bothLists = !_searching &&
                                  _surahHits.isNotEmpty &&
                                  _searchResults.isNotEmpty;
                              final surahMax = bothLists
                                  ? (budget * 0.4).clamp(40.0, 120.0)
                                  : budget.clamp(40.0, 240.0);
                              final ayahMax = bothLists
                                  ? (budget - surahMax).clamp(40.0, 360.0)
                                  : budget.clamp(40.0, 360.0);
                              return Column(
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
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 4, 8, 12),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Search field row
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      key: const Key('field_search'),
                                                      controller: _searchCtrl,
                                                      autofocus: true,
                                                      textDirection:
                                                          TextDirection.rtl,
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors.white
                                                            : _tb87,
                                                        fontSize: 16,
                                                      ),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            'ابحث في القرآن الكريم...',
                                                        hintStyle: TextStyle(
                                                          color: isDark ? _tw38 : _tb38,
                                                        ),
                                                        border:
                                                            InputBorder.none,
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 4,
                                                                vertical: 12),
                                                      ),
                                                      onChanged: _doSearch,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.close,
                                                        color: isDark ? _tw54 : _tb45),
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
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2),
                                                  ),
                                                ),
                                              // No results
                                              if (!_searching &&
                                                  _searchResults.isEmpty &&
                                                  _surahHits.isEmpty &&
                                                  _searchCtrl.text.length >= 2)
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 14),
                                                  child: Text(
                                                    'لا توجد نتائج',
                                                    style: TextStyle(
                                                      color: isDark ? _tw38 : _tb38,
                                                    ),
                                                  ),
                                                ),
                                              // Surah hits
                                              if (!_searching && _surahHits.isNotEmpty) ...[
                                                Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                                                ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight: surahMax,
                                                  ),
                                                  child: ListView.separated(
                                                    key: const Key('list_surah_hits'),
                                                    shrinkWrap: true,
                                                    itemCount: _surahHits.length,
                                                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                                                    itemBuilder: (ctx, i) {
                                                      final s = _surahHits[i];
                                                      return InkWell(
                                                        onTap: () {
                                                          _closeSearch();
                                                          _navigateToSurah(s.suraNo, s.firstAyahId);
                                                        },
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                                          child: Row(
                                                            textDirection: TextDirection.rtl,
                                                            children: [
                                                              Icon(Icons.menu_book_outlined, size: 18, color: isDark ? _tw54 : _tb45),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                s.nameAr,
                                                                textDirection: TextDirection.rtl,
                                                                style: TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: isDark ? _tw85 : _tb87,
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              Text(
                                                                'سورة ${s.suraNo}',
                                                                style: TextStyle(fontSize: 11, color: isDark ? _tw38 : _tb38),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                              // Ayah results — maxHeight shrinks with keyboard
                                              if (!_searching &&
                                                  _searchResults
                                                      .isNotEmpty) ...[
                                                Divider(
                                                  color: isDark
                                                      ? Colors.white12
                                                      : Colors.black12,
                                                  height: 1,
                                                ),
                                                ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight: ayahMax,
                                                  ),
                                                  child: ListView.separated(
                                                    key: const Key('list_search_results'),
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        _searchResults.length,
                                                    separatorBuilder: (_, __) =>
                                                        Divider(
                                                      height: 1,
                                                      color: isDark
                                                          ? Colors.white12
                                                          : Colors.black12,
                                                    ),
                                                    itemBuilder: (ctx, i) {
                                                      final r =
                                                          _searchResults[i];
                                                      return InkWell(
                                                        onTap: () {
                                                          _closeSearch();
                                                          _navigateTo(r.id);
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 10),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: [
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Text(
                                                                    'آية ${r.ayaNo}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: isDark
                                                                          ? Colors
                                                                              .white38
                                                                          : Colors
                                                                              .black38,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'سورة ${r.suraNameAr}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          13,
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
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(
                                                                r.ayaTextEmlaey,
                                                                textDirection:
                                                                    TextDirection
                                                                        .rtl,
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 14,
                                                                  color: isDark
                                                                      ? Colors
                                                                          .white60
                                                                      : Colors
                                                                          .black87,
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
                                );
                            }),
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

// ── Tutorial overlays ─────────────────────────────────────────────────────

class _TutorialStep1Overlay extends StatelessWidget {
  final GlobalKey playBtnKey;
  final VoidCallback onNext;
  const _TutorialStep1Overlay(
      {required this.playBtnKey, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    Offset center = Offset(28, size.height - 80);
    double radius = 36.0;
    final btnCtx = playBtnKey.currentContext;
    if (btnCtx != null) {
      final box = btnCtx.findRenderObject() as RenderBox?;
      if (box != null) {
        center = box.localToGlobal(box.size.center(Offset.zero));
        radius = box.size.longestSide / 2 + 24;
      }
    }

    // Text sits 120px above the spotlight top
    final textTopY = center.dy - radius - 150;
    // Arrow goes from just below the text (centered) to just above the spotlight
    final arrowFrom = Offset(size.width / 2, textTopY + 44);
    final arrowTo = Offset(center.dx, center.dy - radius - 6);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Full-screen dark overlay with spotlight hole — absorbs taps
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: CustomPaint(
                painter: _SpotlightPainter(center: center, radius: radius),
              ),
            ),
          ),
          // Label
          Positioned(
            top: textTopY,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'جرب النزول الذاتي',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          // Curved arrow tilted toward the button
          Positioned.fill(
            child: CustomPaint(
              painter: _CurvedArrowPainter(from: arrowFrom, to: arrowTo),
            ),
          ),
          // حسنا button at the bottom
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onNext,
                child: const _TutorialOkBtn(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialStep2Overlay extends StatelessWidget {
  final VoidCallback onDone;
  const _TutorialStep2Overlay({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          color: const Color(0xE6000000),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'قرّب وباعد بين إصبعين\nلتغيير حجم الخط',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 56),
                const _PinchAnimWidget(),
                const SizedBox(height: 72),
                GestureDetector(
                  onTap: onDone,
                  child: const _TutorialOkBtn(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialOkBtn extends StatelessWidget {
  const _TutorialOkBtn();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFc9a84c),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'حسناً',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _CurvedArrowPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  const _CurvedArrowPainter({required this.from, required this.to});

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFc9a84c);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Control point pulled toward the button side so the curve tilts that way
    final ctrl = Offset(
      from.dx + (to.dx - from.dx) * 0.25,
      from.dy + (to.dy - from.dy) * 0.65,
    );

    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy),
      paint,
    );

    // Arrowhead: tangent direction at end = (to - ctrl) normalised
    final angle = math.atan2(to.dy - ctrl.dy, to.dx - ctrl.dx);
    const headLen = 14.0;
    const headAngle = 0.45;
    canvas.drawLine(
      to,
      Offset(to.dx - headLen * math.cos(angle - headAngle),
          to.dy - headLen * math.sin(angle - headAngle)),
      paint,
    );
    canvas.drawLine(
      to,
      Offset(to.dx - headLen * math.cos(angle + headAngle),
          to.dy - headLen * math.sin(angle + headAngle)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CurvedArrowPainter old) =>
      old.from != from || old.to != to;
}

class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final double radius;
  const _SpotlightPainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.largest, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xE6000000),
    );
    canvas.drawCircle(center, radius, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.center != center || old.radius != radius;
}

class _PinchAnimWidget extends StatefulWidget {
  const _PinchAnimWidget();

  @override
  State<_PinchAnimWidget> createState() => _PinchAnimWidgetState();
}

class _PinchAnimWidgetState extends State<_PinchAnimWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        // True 45° diagonal: fingers move along bottom-left ↔ top-right axis
        final d = (10.0 + _anim.value * 54.0) * 0.707;
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(-d, d), // bottom-left
                child: _fingertip(),
              ),
              Transform.translate(
                offset: Offset(d, -d), // top-right
                child: _fingertip(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fingertip() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
      );
}

// ── Navigation bottom sheet ────────────────────────────────────────────────

class _NavSheet extends StatefulWidget {
  final void Function(int startId) onNavigate;
  final void Function(int suraNo, int firstAyahId) onNavigateToSurah;
  const _NavSheet({required this.onNavigate, required this.onNavigateToSurah});

  @override
  State<_NavSheet> createState() => _NavSheetState();
}

class _NavSheetState extends State<_NavSheet> {
  int _mode = 1; // 0=page  1=surah  2=juz  3=ayah  — default: surah
  List<SurahInfo> _surahs = [];
  bool _loadingSurahs = true;
  int _selectedSurahNo = 1;

  final _pageCtrl = TextEditingController();
  final _ayaNoCtrl = TextEditingController();
  final _surahSearchCtrl = TextEditingController();
  final _pageFocus = FocusNode();
  final _surahSearchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSurahs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mode == 1) _surahSearchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _ayaNoCtrl.dispose();
    _surahSearchCtrl.dispose();
    _pageFocus.dispose();
    _surahSearchFocus.dispose();
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

  static String _normalizeAr(String s) =>
      s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

  bool _surahMatches(String name, String q) {
    if (q.isEmpty) return true;
    final n = _normalizeAr(name);
    final qq = _normalizeAr(q);
    if (n.contains(qq)) return true;
    // subsequence match (loose)
    int qi = 0;
    for (int ci = 0; ci < n.length && qi < qq.length; ci++) {
      if (n[ci] == qq[qi]) qi++;
    }
    return qi == qq.length;
  }

  List<SurahInfo> get _filteredSurahs {
    final q = _surahSearchCtrl.text.trim();
    if (q.isEmpty) return _surahs;
    return _surahs.where((s) => _surahMatches(s.nameAr, q)).toList();
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
    if (rows.isNotEmpty)
      widget.onNavigateToSurah(suraNo, rows.first['id'] as int);
  }

  static const _kJuzPageStarts = [
    1,
    22,
    42,
    62,
    82,
    102,
    121,
    142,
    162,
    182,
    201,
    221,
    242,
    262,
    282,
    302,
    322,
    342,
    362,
    382,
    402,
    422,
    442,
    462,
    482,
    502,
    522,
    542,
    562,
    582,
  ];

  Future<void> _goToJuz(int juzNo) async {
    final page = _kJuzPageStarts[juzNo - 1];
    final db = await _openDb();
    final rows = await db.rawQuery(
      'SELECT id FROM quran_ayahs WHERE page >= ? ORDER BY page, id LIMIT 1',
      [page],
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
    final labelStyle =
        TextStyle(color: isDark ? _tw70 : _tb87);
    final modeLabels = ['صفحة', 'سورة', 'جزء', 'آية'];

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
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
              children: List.generate(4, (i) {
                final selected = _mode == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    key: i == 0 ? const Key('tab_page') : null,
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_mode == 0 && i != 0) _pageFocus.unfocus();
                      setState(() => _mode = i);
                      if (i == 0) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _pageFocus.requestFocus());
                      } else if (i == 1) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _surahSearchFocus.requestFocus());
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? (isDark
                                ? Colors.white.withOpacity(0.15)
                                : Colors.black87)
                            : Colors.transparent,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        modeLabels[i],
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isDark ? _tw70 : _tb87),
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
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
                      key: const Key('field_page'),
                      controller: _pageCtrl,
                      focusNode: _pageFocus,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                      decoration: InputDecoration(
                        labelText: 'رقم الصفحة  (١ – ٦٠٤)',
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
                      onPressed: _goToPage,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
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
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          key: const Key('field_surah_search'),
                          controller: _surahSearchCtrl,
                          focusNode: _surahSearchFocus,
                          textDirection: TextDirection.rtl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن سورة...',
                            hintStyle: TextStyle(
                                color:
                                    isDark ? _tw38 : _tb38),
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 260,
                        child: _filteredSurahs.isEmpty
                            ? Center(
                                child: Text('لا نتائج',
                                    style: TextStyle(
                                        color: isDark ? _tw38 : _tb38)))
                            : ListView.builder(
                                key: const Key('list_surah'),
                                itemCount: _filteredSurahs.length,
                                itemBuilder: (ctx, i) {
                                  final s = _filteredSurahs[i];
                                  return ListTile(
                                    dense: true,
                                    leading: Text('${s.no}',
                                        style: TextStyle(
                                            color: isDark ? _tw38 : _tb38,
                                            fontSize: 12)),
                                    title: Text(s.nameAr,
                                        style: TextStyle(
                                            color: isDark ? Colors.white : _tb87)),
                                    trailing: Text('${s.ayaCount} آية',
                                        style: TextStyle(
                                            color: isDark ? _tw38 : _tb38,
                                            fontSize: 12)),
                                    onTap: () => _goToSurah(s.no),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          // ── Juz mode ──────────────────────────────────────────────────
          if (_mode == 2)
            SizedBox(
              height: 300,
              child: ListView.builder(
                key: const Key('list_juz'),
                itemCount: 30,
                itemBuilder: (ctx, i) {
                  final juzNo = i + 1;
                  final page = _kJuzPageStarts[i];
                  return ListTile(
                    dense: true,
                    leading: Text(
                      '$juzNo',
                      style: TextStyle(
                        color: isDark ? _tw38 : _tb38,
                        fontSize: 12,
                      ),
                    ),
                    title: Text(
                      'الجزء $juzNo',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: isDark ? Colors.white : _tb87,
                      ),
                    ),
                    trailing: Text(
                      'صفحة $page',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: isDark ? _tw38 : _tb38,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => _goToJuz(juzNo),
                  );
                },
              ),
            ),
          // ── Ayah mode ─────────────────────────────────────────────────
          if (_mode == 3)
            _loadingSurahs
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          key: const Key('dropdown_surah'),
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
                                key: const Key('field_ayah'),
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
