import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/session_result.dart';
import '../repositories/session_repository.dart';

enum ResultsLoadState { loading, analyzing, ready, failed, error }

/// Holds the current session results and drives the exponential backoff polling loop.
/// Used by ResultsScreen to show real AI-analyzed numbers.
class SessionResultsProvider extends ChangeNotifier {
  final _repo = SessionRepository.instance;

  SessionResult? _result;
  ResultsLoadState _state = ResultsLoadState.loading;
  String? _errorMessage;
  Timer? _pollTimer;
  DateTime? _pollStartTime;
  Duration _currentInterval = AppConfig.resultsPollInitialInterval;
  bool _disposed = false;

  SessionResult? get result => _result;
  ResultsLoadState get state => _state;
  String? get errorMessage => _errorMessage;

  /// Called by ResultsScreen when it receives a session_id.
  void loadSession(String sessionId) {
    _state = ResultsLoadState.loading;
    _errorMessage = null;
    _pollStartTime = DateTime.now();
    _currentInterval = AppConfig.resultsPollInitialInterval;
    notifyListeners();
    _startPolling(sessionId);
  }

  /// Re-runs server-side analysis for a failed session, then resumes polling.
  /// A timed-out poll (state == error) just resumes polling instead.
  Future<void> retry(String sessionId) async {
    if (_state == ResultsLoadState.failed) {
      try {
        await _repo.retryAnalysis(sessionId);
      } catch (_) {
        _errorMessage = 'Could not restart the analysis. Please try again.';
        notifyListeners();
        return;
      }
    }
    _errorMessage = null;
    loadSession(sessionId);
  }

  void _startPolling(String sessionId) {
    _pollTimer?.cancel();

    // Check timeout
    if (_pollStartTime != null &&
        DateTime.now().difference(_pollStartTime!) > AppConfig.resultsPollTimeout) {
      _state = ResultsLoadState.error;
      _errorMessage = 'Analysis timed out. Tap retry to check again.';
      notifyListeners();
      return;
    }

    _pollTimer = Timer(_currentInterval, () async {
      if (_disposed) return;

      try {
        final session = await _repo.getSession(sessionId);
        _result = session;

        if (session.isAnalyzed) {
          if (session.analysisFailed) {
            _state = ResultsLoadState.failed;
            _errorMessage = session.failureReason ?? 'Analysis could not be completed.';
          } else {
            _state = ResultsLoadState.ready;
          }
          notifyListeners();
          return;
        } else {
          _state = ResultsLoadState.analyzing;
          notifyListeners();
        }
      } catch (_) {
        // Transient network error: continue backoff polling without breaking
      }

      if (_disposed) return;

      // Exponential backoff: multiply interval by 1.5 up to max interval
      final nextMs = min(
        AppConfig.resultsPollMaxInterval.inMilliseconds,
        (_currentInterval.inMilliseconds * 1.5).round(),
      );
      _currentInterval = Duration(milliseconds: nextMs);

      _startPolling(sessionId);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
