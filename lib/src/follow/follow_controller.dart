import 'dart:async';
import 'aligner.dart';
import 'normalizer.dart';

enum FollowStatus {
  idle,       // follow mode off
  listening,  // active but no useful transcript yet
  matching,   // strong match found, scrolling
  weakMatch,  // match below strong threshold — waiting for more
  lost,       // no match for several seconds
}

/// Drives "Read-Aloud Follow" mode.
///
/// Receives partial ASR transcripts via [onTranscript], aligns them to the
/// nearby ayah window, applies debounce + stability rules, then calls
/// [onScrollTo] when a reliable match is found.
class FollowController {
  // ── Thresholds (tune after field testing) ──────────────────────────────
  static const _kStrong  = 0.45;
  static const _kWeak    = 0.30;
  static const _kScrollGap = Duration(milliseconds: 600);
  static const _kLostAfter = Duration(seconds: 6);
  static const _kStableNeeded = 1; // one strong match is enough to scroll

  /// Integrator scrolls to this ayah id.
  final void Function(int ayahId) onScrollTo;

  /// Provides the current ±N ayah window for alignment.
  final List<IndexedAyah> Function() getWindow;

  /// Called whenever status changes (drive UI).
  final void Function(FollowStatus) onStatusChange;

  /// Optional debug callback — called every cycle with a human-readable string.
  final void Function(String)? onDebug;

  FollowController({
    required this.onScrollTo,
    required this.getWindow,
    required this.onStatusChange,
    this.onDebug,
  });

  // ── State ───────────────────────────────────────────────────────────────
  FollowStatus _status = FollowStatus.idle;
  FollowStatus get status => _status;

  final List<String> _rolling = [];
  int? _lastBestId;
  int  _stableCount = 0;
  DateTime _lastScrollTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer?   _lostTimer;
  Timer?   _recoveryTimer;  // fires after lost to auto-return to listening
  static const _kRecoverAfter = Duration(seconds: 3);

  // ── Public API ──────────────────────────────────────────────────────────

  void start() {
    _rolling.clear();
    _lastBestId   = null;
    _stableCount  = 0;
    _lostTimer?.cancel();
    _setStatus(FollowStatus.listening);
  }

  void stop() {
    _lostTimer?.cancel();
    _recoveryTimer?.cancel();
    _rolling.clear();
    _lastBestId  = null;
    _stableCount = 0;
    _setStatus(FollowStatus.idle);
  }

  /// Feed a partial or final ASR transcript string.
  void onTranscript(String partial) {
    if (_status == FollowStatus.idle) return;
    final trimmed = partial.trim();
    if (trimmed.isEmpty) return;

    // Normalise & tokenise
    final tokens = tokenize(normalizeArabic(trimmed));
    if (tokens.isEmpty) return;

    // Replace buffer with the latest transcript — do NOT accumulate.
    // Accumulating partials (e.g. "بسم" then "بسم الله") bloats the buffer
    // with duplicate tokens, diluting the score below the match threshold.
    _rolling
      ..clear()
      ..addAll(tokens);

    // Reset lost-timer on every non-empty transcript
    _lostTimer?.cancel();
    _lostTimer = Timer(_kLostAfter, _onLost);

    // Align against window
    final window = getWindow();
    final result = align(_rolling, window);

    if (result == null || result.score < _kWeak) {
      onDebug?.call('no match (score=${result?.score.toStringAsFixed(2) ?? "—"} win=${window.length})');
      _setStatus(FollowStatus.listening);
      _stableCount = 0;
      return;
    }

    if (result.score < _kStrong) {
      onDebug?.call('weak id=${result.ayahId} score=${result.score.toStringAsFixed(2)}');
      _setStatus(FollowStatus.weakMatch);
      _stableCount = 0;
      return;
    }

    // Strong match — check stability
    _setStatus(FollowStatus.matching);
    if (result.ayahId == _lastBestId) {
      _stableCount++;
    } else {
      _lastBestId  = result.ayahId;
      _stableCount = 1;
    }

    final now = DateTime.now();
    final gapOk = now.difference(_lastScrollTime) >= _kScrollGap;
    onDebug?.call('STRONG id=${result.ayahId} score=${result.score.toStringAsFixed(2)} stable=$_stableCount gapOk=$gapOk');

    if (_stableCount >= _kStableNeeded && gapOk) {
      _lastScrollTime = now;
      onScrollTo(result.ayahId);
    }
  }

  void dispose() {
    _lostTimer?.cancel();
    _recoveryTimer?.cancel();
  }

  // ── Internal ────────────────────────────────────────────────────────────

  void _onLost() {
    _stableCount = 0;
    _lastBestId  = null;
    _setStatus(FollowStatus.lost);
    // Auto-recover to listening after 3 s — user doesn't need to restart follow
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(_kRecoverAfter, () {
      if (_status == FollowStatus.lost) {
        _stableCount = 0;
        _lastBestId  = null;
        _setStatus(FollowStatus.listening);
      }
    });
  }

  void _setStatus(FollowStatus s) {
    if (_status != s) {
      _status = s;
      onStatusChange(s);
    }
  }
}
