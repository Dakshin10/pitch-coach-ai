import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/slide_coach_models.dart';
import '../providers/settings_provider.dart';
import '../repositories/slide_coach_repository.dart';
import '../services/notification_service.dart';

/// Immutable state for Slide Coach presentations, rehearsal, and Q&A.
class SlideCoachState extends Equatable {
  final SlideDeckModel? deck;
  final int currentSlideIndex;
  final bool isLoadingDeck;
  final bool isUploading;
  final double uploadProgress;
  final String? uploadError;
  final String? activeDeckId;
  final SlideDeckStatusModel? status;
  final bool isPolling;
  final String? pollError;
  final SlideDeckModel? completedDeckToAnnounce;
  final List<SlideDeckModel> savedDecks;
  final bool isLoadingSavedDecks;
  final String? savedDecksError;
  final bool isRehearsing;
  final bool isAnalyzingRehearsal;
  final DeckRehearsalResponseModel? latestRehearsalResult;
  final String? rehearsalError;
  final List<QaQuestionModel> qaQuestions;
  final int currentQaIndex;
  final bool isLoadingQuestions;
  final bool isEvaluatingAnswer;
  final QaEvaluationModel? latestQaEvaluation;
  final String? qaError;

  const SlideCoachState({
    this.deck,
    this.currentSlideIndex = 0,
    this.isLoadingDeck = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.uploadError,
    this.activeDeckId,
    this.status,
    this.isPolling = false,
    this.pollError,
    this.completedDeckToAnnounce,
    this.savedDecks = const [],
    this.isLoadingSavedDecks = false,
    this.savedDecksError,
    this.isRehearsing = false,
    this.isAnalyzingRehearsal = false,
    this.latestRehearsalResult,
    this.rehearsalError,
    this.qaQuestions = const [],
    this.currentQaIndex = 0,
    this.isLoadingQuestions = false,
    this.isEvaluatingAnswer = false,
    this.latestQaEvaluation,
    this.qaError,
  });

  bool get hasActiveBackgroundProcessing =>
      isPolling || (status != null && status!.isProcessing);

  SlideCoachingModel? get currentSlide {
    if (deck == null || deck!.slides.isEmpty) return null;
    if (currentSlideIndex < 0 || currentSlideIndex >= deck!.slides.length) {
      return deck!.slides.first;
    }
    return deck!.slides[currentSlideIndex];
  }

  QaQuestionModel? get currentQuestion {
    if (qaQuestions.isEmpty) return null;
    if (currentQaIndex < 0 || currentQaIndex >= qaQuestions.length) {
      return qaQuestions.first;
    }
    return qaQuestions[currentQaIndex];
  }

  SlideCoachState copyWith({
    SlideDeckModel? deck,
    int? currentSlideIndex,
    bool? isLoadingDeck,
    bool? isUploading,
    double? uploadProgress,
    String? uploadError,
    String? activeDeckId,
    SlideDeckStatusModel? status,
    bool? isPolling,
    String? pollError,
    SlideDeckModel? completedDeckToAnnounce,
    List<SlideDeckModel>? savedDecks,
    bool? isLoadingSavedDecks,
    String? savedDecksError,
    bool? isRehearsing,
    bool? isAnalyzingRehearsal,
    DeckRehearsalResponseModel? latestRehearsalResult,
    String? rehearsalError,
    List<QaQuestionModel>? qaQuestions,
    int? currentQaIndex,
    bool? isLoadingQuestions,
    bool? isEvaluatingAnswer,
    QaEvaluationModel? latestQaEvaluation,
    String? qaError,
  }) {
    return SlideCoachState(
      deck: deck ?? this.deck,
      currentSlideIndex: currentSlideIndex ?? this.currentSlideIndex,
      isLoadingDeck: isLoadingDeck ?? this.isLoadingDeck,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadError: uploadError,
      activeDeckId: activeDeckId ?? this.activeDeckId,
      status: status ?? this.status,
      isPolling: isPolling ?? this.isPolling,
      pollError: pollError,
      completedDeckToAnnounce: completedDeckToAnnounce,
      savedDecks: savedDecks ?? this.savedDecks,
      isLoadingSavedDecks: isLoadingSavedDecks ?? this.isLoadingSavedDecks,
      savedDecksError: savedDecksError,
      isRehearsing: isRehearsing ?? this.isRehearsing,
      isAnalyzingRehearsal: isAnalyzingRehearsal ?? this.isAnalyzingRehearsal,
      latestRehearsalResult:
          latestRehearsalResult ?? this.latestRehearsalResult,
      rehearsalError: rehearsalError,
      qaQuestions: qaQuestions ?? this.qaQuestions,
      currentQaIndex: currentQaIndex ?? this.currentQaIndex,
      isLoadingQuestions: isLoadingQuestions ?? this.isLoadingQuestions,
      isEvaluatingAnswer: isEvaluatingAnswer ?? this.isEvaluatingAnswer,
      latestQaEvaluation: latestQaEvaluation ?? this.latestQaEvaluation,
      qaError: qaError,
    );
  }

  @override
  List<Object?> get props => [
    deck?.id,
    currentSlideIndex,
    isLoadingDeck,
    isUploading,
    uploadProgress,
    uploadError,
    activeDeckId,
    status?.status,
    isPolling,
    pollError,
    completedDeckToAnnounce?.id,
    savedDecks.length,
    isLoadingSavedDecks,
    savedDecksError,
    isRehearsing,
    isAnalyzingRehearsal,
    latestRehearsalResult?.rehearsalId,
    rehearsalError,
    qaQuestions.length,
    currentQaIndex,
    isLoadingQuestions,
    isEvaluatingAnswer,
    latestQaEvaluation?.questionId,
    qaError,
  ];
}

/// Cubit managing presentation slides, coaching tips, rehearsals, and Q&A.
class SlideCoachCubit extends Cubit<SlideCoachState> {
  final SlideCoachRepository _repo;
  final FlutterSecureStorage _storage;
  static const String _storageActiveDeckKey = 'active_processing_deck_id';

  Timer? _pollTimer;
  Timer? _patchDebounce;
  final List<Map<String, dynamic>> _rehearsalTimestamps = [];
  DateTime? _rehearsalStartTime;

  SlideCoachCubit({
    SlideCoachRepository? repository,
    FlutterSecureStorage? storage,
  }) : _repo = repository ?? SlideCoachRepository.instance,
       _storage = storage ?? const FlutterSecureStorage(),
       super(const SlideCoachState());

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    _patchDebounce?.cancel();
    return super.close();
  }

  void dismissCompletedAnnouncement() {
    emit(state.copyWith(completedDeckToAnnounce: null));
  }

  void selectSlide(int index) {
    if (state.deck == null || state.deck!.slides.isEmpty) return;
    final clamped = index.clamp(0, state.deck!.slides.length - 1);
    emit(state.copyWith(currentSlideIndex: clamped));
  }

  void nextSlide() {
    if (state.deck == null || state.deck!.slides.isEmpty) return;
    if (state.currentSlideIndex < state.deck!.slides.length - 1) {
      emit(state.copyWith(currentSlideIndex: state.currentSlideIndex + 1));
    }
  }

  void previousSlide() {
    if (state.deck == null || state.deck!.slides.isEmpty) return;
    if (state.currentSlideIndex > 0) {
      emit(state.copyWith(currentSlideIndex: state.currentSlideIndex - 1));
    }
  }

  void setDeck(SlideDeckModel deck) {
    emit(
      state.copyWith(
        deck: deck,
        activeDeckId: deck.id,
        currentSlideIndex: 0,
        isLoadingDeck: false,
      ),
    );
  }

  Future<void> loadDeck(String deckId) async {
    emit(
      state.copyWith(
        isLoadingDeck: true,
        activeDeckId: deckId,
        pollError: null,
      ),
    );
    try {
      final deck = await _repo.getDeck(deckId);
      emit(
        state.copyWith(deck: deck, currentSlideIndex: 0, isLoadingDeck: false),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingDeck: false, pollError: e.toString()));
    }
  }

  Future<void> loadSavedDecks({bool forceRefresh = false}) async {
    emit(state.copyWith(isLoadingSavedDecks: true, savedDecksError: null));
    try {
      final decks = await _repo.listDecks();
      emit(state.copyWith(savedDecks: decks, isLoadingSavedDecks: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingSavedDecks: false,
          savedDecksError: e.toString(),
        ),
      );
    }
  }

  Future<String?> uploadAndStartAnalysis({
    required String filePath,
    required String fileName,
    required String audience,
    required int timeLimitSeconds,
    required String goal,
  }) async {
    emit(
      state.copyWith(isUploading: true, uploadProgress: 0.0, uploadError: null),
    );

    try {
      final res = await _repo.uploadDeck(
        filePath: filePath,
        fileName: fileName,
        audience: audience,
        timeLimitSeconds: timeLimitSeconds,
        goal: goal,
        onProgress: (sent, total) {
          if (total > 0) {
            emit(state.copyWith(uploadProgress: sent / total));
          }
        },
      );

      final deckId = res['deck_id'] as String;
      await _storage.write(key: _storageActiveDeckKey, value: deckId);
      emit(state.copyWith(activeDeckId: deckId, isUploading: false));

      startPolling(deckId);
      return deckId;
    } catch (e) {
      emit(state.copyWith(isUploading: false, uploadError: e.toString()));
      return null;
    }
  }

  void startPolling(String deckId) {
    _pollTimer?.cancel();
    _storage.write(key: _storageActiveDeckKey, value: deckId);
    emit(
      state.copyWith(activeDeckId: deckId, isPolling: true, pollError: null),
    );

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final st = await _repo.getStatus(deckId);
        emit(state.copyWith(status: st));

        if (st.status == 'done') {
          timer.cancel();
          await _storage.delete(key: _storageActiveDeckKey);
          final loadedDeck = await _repo.getDeck(deckId);
          emit(
            state.copyWith(
              deck: loadedDeck,
              isPolling: false,
              completedDeckToAnnounce: loadedDeck,
            ),
          );

          final alertEnabled =
              await SettingsProvider.isSlideDeckReadyAlertEnabled();
          if (alertEnabled) {
            try {
              await NotificationService.instance.showInstantNotification(
                'Slide Deck Ready',
                'Your presentation "${loadedDeck.fileName}" has been analyzed and is ready for rehearsal.',
              );
            } catch (_) {}
          }
        } else if (st.status == 'failed') {
          timer.cancel();
          await _storage.delete(key: _storageActiveDeckKey);
          emit(
            state.copyWith(
              isPolling: false,
              pollError: st.error ?? 'Analysis failed',
            ),
          );
        }
      } catch (e) {
        emit(state.copyWith(pollError: e.toString()));
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    emit(state.copyWith(isPolling: false));
  }

  Future<void> restoreActiveDeckIfProcessing() async {
    try {
      final storedId = await _storage.read(key: _storageActiveDeckKey);
      if (storedId == null || storedId.trim().isEmpty) return;
      if (state.isPolling && state.activeDeckId == storedId) return;

      emit(state.copyWith(activeDeckId: storedId));
      final st = await _repo.getStatus(storedId);
      emit(state.copyWith(status: st));

      if (st.status == 'done') {
        await _storage.delete(key: _storageActiveDeckKey);
        final loadedDeck = await _repo.getDeck(storedId);
        emit(
          state.copyWith(deck: loadedDeck, completedDeckToAnnounce: loadedDeck),
        );
      } else if (st.status == 'failed') {
        await _storage.delete(key: _storageActiveDeckKey);
        emit(state.copyWith(pollError: st.error ?? 'Analysis failed'));
      } else {
        startPolling(storedId);
      }
    } catch (_) {}
  }

  Future<void> triggerReanalysis(String deckId) async {
    try {
      await _repo.reanalyzeDeck(deckId);
      startPolling(deckId);
    } catch (e) {
      emit(state.copyWith(pollError: e.toString()));
    }
  }

  // ── Rehearsal Mode Lifecycle ──

  void startRehearsal() {
    _rehearsalTimestamps.clear();
    _rehearsalStartTime = DateTime.now();
    _rehearsalTimestamps.add({
      'slide_number': state.deck?.slides.first.slideNumber ?? 1,
      'entered_at_ms': 0,
    });
    emit(
      state.copyWith(
        isRehearsing: true,
        latestRehearsalResult: null,
        rehearsalError: null,
      ),
    );
  }

  void recordSlideTransition(int nextSlideNumber) {
    if (!state.isRehearsing || _rehearsalStartTime == null) return;
    final elapsedMs = DateTime.now()
        .difference(_rehearsalStartTime!)
        .inMilliseconds;
    _rehearsalTimestamps.add({
      'slide_number': nextSlideNumber,
      'entered_at_ms': elapsedMs,
    });
  }

  Future<DeckRehearsalResponseModel?> finishRehearsal(String audioPath) async {
    if (state.activeDeckId == null) return null;
    emit(
      state.copyWith(
        isRehearsing: false,
        isAnalyzingRehearsal: true,
        rehearsalError: null,
      ),
    );

    try {
      final res = await _repo.rehearse(
        deckId: state.activeDeckId!,
        audioPath: audioPath,
        slideTimestamps: _rehearsalTimestamps,
      );
      emit(
        state.copyWith(latestRehearsalResult: res, isAnalyzingRehearsal: false),
      );
      return res;
    } catch (e) {
      emit(
        state.copyWith(
          isAnalyzingRehearsal: false,
          rehearsalError: e.toString(),
        ),
      );
      return null;
    }
  }

  // ── Q&A Mode Lifecycle ──

  Future<void> loadQaQuestions() async {
    if (state.activeDeckId == null) return;
    emit(
      state.copyWith(
        isLoadingQuestions: true,
        qaError: null,
        latestQaEvaluation: null,
      ),
    );

    try {
      final questions = await _repo.getQaQuestions(state.activeDeckId!);
      emit(
        state.copyWith(
          qaQuestions: questions,
          currentQaIndex: 0,
          isLoadingQuestions: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingQuestions: false, qaError: e.toString()));
    }
  }

  void nextQuestion() {
    if (state.currentQaIndex < state.qaQuestions.length - 1) {
      emit(
        state.copyWith(
          currentQaIndex: state.currentQaIndex + 1,
          latestQaEvaluation: null,
        ),
      );
    }
  }

  void prevQuestion() {
    if (state.currentQaIndex > 0) {
      emit(
        state.copyWith(
          currentQaIndex: state.currentQaIndex - 1,
          latestQaEvaluation: null,
        ),
      );
    }
  }

  Future<QaEvaluationModel?> submitAnswer(String audioPath) async {
    final q = state.currentQuestion;
    if (state.activeDeckId == null || q == null) return null;

    emit(state.copyWith(isEvaluatingAnswer: true, qaError: null));

    try {
      final res = await _repo.submitQaAnswer(
        deckId: state.activeDeckId!,
        questionId: q.id,
        audioPath: audioPath,
      );
      emit(state.copyWith(latestQaEvaluation: res, isEvaluatingAnswer: false));
      return res;
    } catch (e) {
      emit(state.copyWith(isEvaluatingAnswer: false, qaError: e.toString()));
      return null;
    }
  }
}
