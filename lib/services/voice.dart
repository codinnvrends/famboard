import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Why voice input stopped without a result.
enum VoiceProblem { unavailable, permission, needsInternet, noMatch, other }

/// Voice entry (spec FR-41). Uses the phone's speech recogniser; it runs
/// offline when the phone has the offline pack for the chosen language and
/// needs internet otherwise.
class VoiceInput {
  VoiceInput([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  bool _available = false;
  void Function(VoiceProblem)? _onProblem;

  bool get isListening => _speech.isListening;

  Future<bool> ensureReady() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech.initialize(
        onError: _handleError,
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _available = false;
    }
    return _available;
  }

  void _handleError(SpeechRecognitionError error) {
    final msg = error.errorMsg.toLowerCase();
    final problem = msg.contains('network') || msg.contains('server')
        ? VoiceProblem.needsInternet
        : msg.contains('no_match') || msg.contains('speech_timeout')
            ? VoiceProblem.noMatch
            : msg.contains('permission')
                ? VoiceProblem.permission
                : msg.contains('language')
                    ? VoiceProblem.needsInternet
                    : VoiceProblem.other;
    _onProblem?.call(problem);
  }

  /// Starts listening in [localeId] (e.g. `en_IN`, `hi_IN`). [onText] gets
  /// partial and final transcripts.
  Future<VoiceProblem?> listen({
    required String localeId,
    required void Function(String text, bool isFinal) onText,
    required void Function(VoiceProblem problem) onProblem,
  }) async {
    if (!await ensureReady()) return VoiceProblem.unavailable;
    _onProblem = onProblem;
    await _speech.listen(
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    return null;
  }

  Future<void> stop() => _speech.stop();
}
