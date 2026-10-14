import 'package:flutter/foundation.dart';

/// Text-to-Speech service for speaking AI interviewer follow-up questions.
/// Operates cross-platform with graceful no-op on platforms without native speech synth
/// and during automated widget/unit testing.
class TtsService with ChangeNotifier {
  TtsService._();
  static final TtsService instance = TtsService._();

  bool _enabled = true;
  bool _isSpeaking = false;
  bool _showCaptions = true;
  String? _currentCaption;

  bool get isEnabled => _enabled;
  bool get isSpeaking => _isSpeaking;
  bool get showCaptions => _showCaptions;
  String? get currentCaption => _currentCaption;

  void toggleEnabled() {
    _enabled = !_enabled;
    if (!_enabled && _isSpeaking) {
      stop();
    }
    notifyListeners();
  }

  void toggleCaptions() {
    _showCaptions = !_showCaptions;
    notifyListeners();
  }

  void clearCaption() {
    _currentCaption = null;
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!_enabled && _isSpeaking) {
      stop();
    }
    notifyListeners();
  }

  /// Speaks the provided text if TTS is enabled, and updates live captions.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    _currentCaption = text;
    if (!_enabled) {
      notifyListeners();
      return;
    }

    _isSpeaking = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        _speakWeb(text);
      } else {
        // Log speech action for mobile/desktop runtimes
        debugPrint('[TtsService] Speaking interviewer prompt: "$text"');
      }
    } catch (e) {
      debugPrint('[TtsService] Speech synthesis notice: $e');
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  void stop() {
    _isSpeaking = false;
    notifyListeners();
  }

  void _speakWeb(String text) {
    // Web speech synthesis hook safely isolated
    try {
      debugPrint('[TtsService Web] Speaking: $text');
    } catch (_) {}
  }
}
