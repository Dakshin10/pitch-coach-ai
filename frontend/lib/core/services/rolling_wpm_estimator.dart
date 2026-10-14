import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PacingState {
  measuring, // Initial buffer (< 3s)
  optimal,   // 120 - 160 WPM (target band) -> Green
  warning,   // 100 - 120 WPM or 160 - 180 WPM -> Amber
  alert,     // < 100 WPM or > 180 WPM -> Red
}

/// Rolling-window speech pacing and WPM estimator.
/// Computes cadence smoothly from incoming live audio amplitude energy pulses
/// without adding UI jank or requiring external cloud APIs.
class RollingWpmEstimator {
  final Duration windowDuration;
  final List<DateTime> _speechPulses = [];

  bool _inSpeechPeak = false;
  DateTime? _lastPeakTime;
  double _smoothedWpm = 135.0; // Default optimal baseline
  int _sampleCount = 0;

  RollingWpmEstimator({
    this.windowDuration = const Duration(seconds: 8),
  });

  double get currentWpm => _smoothedWpm;
  int get sampleCount => _sampleCount;

  PacingState get pacingState {
    if (_sampleCount < 15 || _speechPulses.isEmpty) {
      return PacingState.measuring;
    }
    if (_smoothedWpm >= 120 && _smoothedWpm <= 160) {
      return PacingState.optimal;
    } else if ((_smoothedWpm >= 100 && _smoothedWpm < 120) ||
        (_smoothedWpm > 160 && _smoothedWpm <= 180)) {
      return PacingState.warning;
    } else {
      return PacingState.alert;
    }
  }

  Color get pacingColor {
    switch (pacingState) {
      case PacingState.measuring:
        return AppColors.primaryPurple;
      case PacingState.optimal:
        return AppColors.successGreen;
      case PacingState.warning:
        return AppColors.warningAmber;
      case PacingState.alert:
        return AppColors.dangerRed;
    }
  }

  /// Ingests an amplitude level [0.0, 1.0] from microphone stream.
  void updateWithAmplitude(double level) {
    _sampleCount++;
    final now = DateTime.now();

    // Voice peak onset detection (syllable envelope)
    // Refractory lockout of 130ms avoids double-counting a single syllable
    const threshold = 0.16;
    if (level > threshold && !_inSpeechPeak) {
      if (_lastPeakTime == null ||
          now.difference(_lastPeakTime!) > const Duration(milliseconds: 130)) {
        _inSpeechPeak = true;
        _lastPeakTime = now;
        _speechPulses.add(now);
      }
    } else if (level < (threshold * 0.7)) {
      _inSpeechPeak = false;
    }

    // Prune pulses outside sliding window
    final cutoff = now.subtract(windowDuration);
    _speechPulses.removeWhere((t) => t.isBefore(cutoff));

    // Calculate rolling instantaneous WPM
    // Average 1.45 syllables per English word
    if (_speechPulses.length >= 3) {
      final windowSec = windowDuration.inMilliseconds / 1000.0;
      final syllablesPerSec = _speechPulses.length / windowSec;
      final rawWpm = (syllablesPerSec / 1.45) * 60.0;

      // Exponential moving average for smooth transitions without jank
      _smoothedWpm = (_smoothedWpm * 0.70) + (rawWpm.clamp(60.0, 240.0) * 0.30);
    }
  }

  /// Sets WPM directly for deterministic testing.
  void setWpmForTesting(double wpm) {
    _sampleCount = 50;
    _speechPulses.add(DateTime.now());
    _smoothedWpm = wpm;
  }

  /// Resets state for a new recording take.
  void reset() {
    _speechPulses.clear();
    _inSpeechPeak = false;
    _lastPeakTime = null;
    _smoothedWpm = 135.0;
    _sampleCount = 0;
  }
}
