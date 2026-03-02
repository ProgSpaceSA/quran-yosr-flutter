import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Pluggable ASR interface — swap Phase 1 (built-in STT) for Phase 2
/// (Whisper) without touching FollowController or main.dart.
abstract class AsrEngine {
  /// Emits partial transcript strings as they arrive.
  Stream<String> get transcripts;

  Future<bool> initialize();
  Future<void> start();
  Future<void> stop();
  void dispose();
}

/// Phase 1: wraps Android / iOS built-in speech recogniser via speech_to_text.
///
/// Continuous mode: when the recogniser stops (e.g. after a pause), it
/// automatically restarts as long as [_active] is true.
class SpeechToTextEngine implements AsrEngine {
  final SpeechToText _stt = SpeechToText();
  final StreamController<String> _ctrl = StreamController.broadcast();

  bool _initialized = false;
  bool _active      = false;

  // Best Arabic locale found on this device; falls back to 'ar'.
  String _localeId = 'ar';

  @override
  Stream<String> get transcripts => _ctrl.stream;

  @override
  Future<bool> initialize() async {
    _initialized = await _stt.initialize(
      onError:  (e) => debugPrint('[ASR] Error: ${e.errorMsg}'),
      onStatus: (s) {
        debugPrint('[ASR] Status: $s');
        // Automatically restart when the recogniser stops mid-session.
        if (s == SpeechToText.notListeningStatus && _active) {
          Future.delayed(const Duration(milliseconds: 300), _doListen);
        }
      },
    );
    if (_initialized) await _detectLocale();
    return _initialized;
  }

  @override
  Future<void> start() async {
    if (!_initialized) return;
    _active = true;
    await _doListen();
  }

  @override
  Future<void> stop() async {
    _active = false;
    if (_stt.isListening) await _stt.stop();
  }

  @override
  void dispose() {
    _active = false;
    _stt.stop();
    _ctrl.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────

  Future<void> _doListen() async {
    if (!_active || !_initialized) return;
    if (_stt.isListening) return; // already listening
    await _stt.listen(
      onResult:    _onResult,
      localeId:    _localeId,
      listenFor:   const Duration(seconds: 30),
      pauseFor:    const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        listenMode:     ListenMode.dictation,
        cancelOnError:  false,
        partialResults: true,
        onDevice:       false,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) {
      debugPrint('[ASR] transcript: $words (final=${result.finalResult})');
      _ctrl.add(words);
    }
  }

  Future<void> _detectLocale() async {
    try {
      final locales = await _stt.locales();
      debugPrint('[ASR] Available locales (${locales.length}): '
          '${locales.map((l) => l.localeId).join(', ')}');
      // Prefer ar_SA, then ar_EG, then any ar_* locale, then fall back to 'ar'.
      const preferred = ['ar_SA', 'ar-SA', 'ar_EG', 'ar-EG'];
      for (final p in preferred) {
        if (locales.any((l) => l.localeId == p)) {
          _localeId = p;
          debugPrint('[ASR] Locale selected: $_localeId');
          return;
        }
      }
      final anyAr = locales.where((l) => l.localeId.startsWith('ar'));
      if (anyAr.isNotEmpty) {
        _localeId = anyAr.first.localeId;
        debugPrint('[ASR] Locale selected: $_localeId');
      } else {
        debugPrint('[ASR] No Arabic locale found — using "ar"');
      }
    } catch (e) {
      debugPrint('[ASR] Locale detection failed: $e');
    }
  }
}
