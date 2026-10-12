import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/session_result.dart';
import '../providers/session_results_provider.dart' show ResultsLoadState;
import '../repositories/session_repository.dart';
import '../services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Events
// ─────────────────────────────────────────────────────────────────────────────

abstract class SessionResultsEvent extends Equatable {
  const SessionResultsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSessionResultsEvent extends SessionResultsEvent {
  final String sessionId;

  const LoadSessionResultsEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class StartBackgroundProcessingEvent extends SessionResultsEvent {
  final String sessionId;
  final String? topic;
  final String? mode;

  const StartBackgroundProcessingEvent({
    required this.sessionId,
    this.topic,
    this.mode,
  });

  @override
  List<Object?> get props => [sessionId, topic, mode];
}

class DismissAnnouncementEvent extends SessionResultsEvent {
  const DismissAnnouncementEvent();
}

class RestoreActiveSessionEvent extends SessionResultsEvent {
  const RestoreActiveSessionEvent();
}

class RetrySessionAnalysisEvent extends SessionResultsEvent {
  final String sessionId;

  const RetrySessionAnalysisEvent(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class SessionResultsState extends Equatable {
  final SessionResult? result;
  final ResultsLoadState status;
  final String? errorMessage;
  final String? activeSessionId;
  final String? activeTopic;
  final String? activeMode;
  final bool isBackgroundProcessing;
  final SessionResult? completedSessionToAnnounce;

  const SessionResultsState({
    this.result,
    this.status = ResultsLoadState.loading,
    this.errorMessage,
    this.activeSessionId,
    this.activeTopic,
    this.activeMode,
    this.isBackgroundProcessing = false,
    this.completedSessionToAnnounce,
  });

  bool get hasActiveBackgroundProcessing =>
      isBackgroundProcessing &&
      activeSessionId != null &&
      (status == ResultsLoadState.analyzing ||
          status == ResultsLoadState.loading);

  SessionResultsState copyWith({
    SessionResult? result,
    ResultsLoadState? status,
    String? errorMessage,
    String? activeSessionId,
    String? activeTopic,
    String? activeMode,
    bool? isBackgroundProcessing,
    SessionResult? completedSessionToAnnounce,
  }) {
    return SessionResultsState(
      result: result ?? this.result,
      status: status ?? this.status,
      errorMessage: errorMessage,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      activeTopic: activeTopic ?? this.activeTopic,
      activeMode: activeMode ?? this.activeMode,
      isBackgroundProcessing:
          isBackgroundProcessing ?? this.isBackgroundProcessing,
      completedSessionToAnnounce: completedSessionToAnnounce,
    );
  }

  @override
  List<Object?> get props => [
    result?.id,
    status,
    errorMessage,
    activeSessionId,
    activeTopic,
    activeMode,
    isBackgroundProcessing,
    completedSessionToAnnounce?.id,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// BLoC
// ─────────────────────────────────────────────────────────────────────────────

class SessionResultsBloc
    extends Bloc<SessionResultsEvent, SessionResultsState> {
  final SessionRepository _repo;
  final FlutterSecureStorage _storage;
  static const String _storageActiveSessionKey = 'active_processing_session_id';

  SessionResultsBloc({
    SessionRepository? repository,
    FlutterSecureStorage? storage,
  }) : _repo = repository ?? SessionRepository.instance,
       _storage = storage ?? const FlutterSecureStorage(),
       super(const SessionResultsState()) {
    on<LoadSessionResultsEvent>(_onLoadSessionResults);
    on<StartBackgroundProcessingEvent>(_onStartBackgroundProcessing);
    on<DismissAnnouncementEvent>(_onDismissAnnouncement);
    on<RestoreActiveSessionEvent>(_onRestoreActiveSession);
    on<RetrySessionAnalysisEvent>(_onRetrySessionAnalysis);
  }

  Future<void> _onRetrySessionAnalysis(
    RetrySessionAnalysisEvent event,
    Emitter<SessionResultsState> emit,
  ) async {
    try {
      await _repo.retryAnalysis(event.sessionId);
    } catch (_) {}
    add(LoadSessionResultsEvent(event.sessionId));
  }

  Future<void> _onLoadSessionResults(
    LoadSessionResultsEvent event,
    Emitter<SessionResultsState> emit,
  ) async {
    emit(state.copyWith(status: ResultsLoadState.loading));
    try {
      final session = await _repo.getSession(event.sessionId);
      if (session.isAnalyzed) {
        emit(state.copyWith(result: session, status: ResultsLoadState.ready));
      } else {
        emit(
          state.copyWith(result: session, status: ResultsLoadState.analyzing),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: ResultsLoadState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onStartBackgroundProcessing(
    StartBackgroundProcessingEvent event,
    Emitter<SessionResultsState> emit,
  ) async {
    try {
      final payload = jsonEncode({
        'id': event.sessionId,
        'topic': event.topic,
        'mode': event.mode,
      });
      await _storage.write(key: _storageActiveSessionKey, value: payload);
    } catch (_) {}

    emit(
      state.copyWith(
        activeSessionId: event.sessionId,
        activeTopic: event.topic,
        activeMode: event.mode,
        isBackgroundProcessing: true,
        status: ResultsLoadState.analyzing,
      ),
    );
  }

  void _onDismissAnnouncement(
    DismissAnnouncementEvent event,
    Emitter<SessionResultsState> emit,
  ) {
    emit(state.copyWith(completedSessionToAnnounce: null));
  }

  Future<void> _onRestoreActiveSession(
    RestoreActiveSessionEvent event,
    Emitter<SessionResultsState> emit,
  ) async {
    try {
      final storedData = await _storage.read(key: _storageActiveSessionKey);
      if (storedData == null || storedData.trim().isEmpty) return;

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(storedData) as Map<String, dynamic>;
      } catch (_) {
        parsed = {'id': storedData};
      }

      final sessionId = parsed['id'] as String?;
      if (sessionId == null || sessionId.isEmpty) return;

      emit(
        state.copyWith(
          activeSessionId: sessionId,
          activeTopic: parsed['topic'] as String?,
          activeMode: parsed['mode'] as String?,
          isBackgroundProcessing: true,
        ),
      );

      final session = await _repo.getSession(sessionId);
      if (session.isAnalyzed) {
        await _storage.delete(key: _storageActiveSessionKey);
        emit(
          state.copyWith(
            result: session,
            isBackgroundProcessing: false,
            status: ResultsLoadState.ready,
            completedSessionToAnnounce: session,
          ),
        );
        try {
          await NotificationService.instance.showInstantNotification(
            'Practice Session Ready',
            'Your analysis for ${session.topicOrQuestion} is complete!',
          );
        } catch (_) {}
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: ResultsLoadState.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
