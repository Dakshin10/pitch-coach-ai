import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/session_result.dart';
import '../repositories/session_repository.dart';

enum ResultsLoadState { loading, analyzing, ready, failed, error }

/// Holds the current session results and drives the polling loop.
/// Used by ResultsScreen to show real AI-analyzed numbers.
class SessionResultsProvider extends ChangeNotifier {
  final _repo = SessionRepository.instance;

  SessionResult? _result;
  ResultsLoadState _state = ResultsLoadState.loading;
  String? _errorMessage;
  Timer? _pollTimer;
  int _pollAttempts = 0;

  SessionResult? get result => _result;
  ResultsLoadState get state => _state;
  String? get errorMessage => _errorMessage;

  /// Called by ResultsScreen when it receives a session_id.
  void loadSession(String sessionId) {
    _state = ResultsLoadState.loading;
    _pollAttempts = 0;
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
    _pollTimer = Timer.periodic(AppConfig.resultsPollInterval, (_) async {
      _pollAttempts++;
      if (_pollAttempts > AppConfig.resultsPollMaxAttempts) {
        _pollTimer?.cancel();
        _state = ResultsLoadState.error;
        _errorMessage = 'Analysis timed out. Please try again later.';
        notifyListeners();
        return;
      }

      try {
        final session = await _repo.getSession(sessionId);
        _result = session;

        if (session.isAnalyzed) {
          _pollTimer?.cancel();
          _state = session.analysisFailed
              ? ResultsLoadState.failed
              : ResultsLoadState.ready;
        } else {
          _state = ResultsLoadState.analyzing;
        }
        notifyListeners();
      } catch (e) {
        // Don't bail on transient errors — keep polling
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
