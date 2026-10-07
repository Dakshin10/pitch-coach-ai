/// Data models that map directly to the backend API responses for sessions.
library;

// ─────────────────────────────────────────────────────────────────────────────
// FeedbackItem
// ─────────────────────────────────────────────────────────────────────────────

class FeedbackItem {
  final String category;  // filler_words / pacing / clarity / structure / confidence
  final String message;
  final String severity;  // positive / warning / tip
  final String? example;

  const FeedbackItem({
    required this.category,
    required this.message,
    required this.severity,
    this.example,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        category: j['category'] as String? ?? 'clarity',
        message: j['message'] as String? ?? '',
        severity: j['severity'] as String? ?? 'tip',
        example: j['example'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionResult  (GET /sessions/{id})
// ─────────────────────────────────────────────────────────────────────────────

class SessionResult {
  final String id;
  final String mode;
  final String topicOrQuestion;
  final double durationSeconds;
  final String? transcript;
  final double wpm;
  final int fillerWordCount;
  final Map<String, int> fillerWordBreakdown;
  final int pauseCount;
  final double avgPauseLength;
  final double clarityScore;
  final double confidenceScore;
  final double overallScore;
  final List<FeedbackItem> aiFeedback;
  final DateTime createdAt;
  final bool isAnalyzed;
  /// True when the server-side AI analysis failed (scores are placeholders).
  final bool analysisFailed;
  /// Local path to the recorded audio file, populated by SessionRepository after upload.
  final String? audioPath;

  const SessionResult({
    required this.id,
    required this.mode,
    required this.topicOrQuestion,
    required this.durationSeconds,
    this.transcript,
    required this.wpm,
    required this.fillerWordCount,
    required this.fillerWordBreakdown,
    required this.pauseCount,
    required this.avgPauseLength,
    required this.clarityScore,
    required this.confidenceScore,
    required this.overallScore,
    required this.aiFeedback,
    required this.createdAt,
    required this.isAnalyzed,
    this.analysisFailed = false,
    this.audioPath,
  });

  factory SessionResult.fromJson(Map<String, dynamic> j) => SessionResult(
        id: j['id'] as String,
        mode: j['mode'] as String? ?? 'interview',
        topicOrQuestion: j['topic_or_question'] as String? ?? '',
        durationSeconds: (j['duration_seconds'] as num?)?.toDouble() ?? 0,
        transcript: j['transcript'] as String?,
        wpm: (j['wpm'] as num?)?.toDouble() ?? 0,
        fillerWordCount: (j['filler_word_count'] as num?)?.toInt() ?? 0,
        fillerWordBreakdown: (j['filler_word_breakdown'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        pauseCount: (j['pause_count'] as num?)?.toInt() ?? 0,
        avgPauseLength: (j['avg_pause_length'] as num?)?.toDouble() ?? 0,
        clarityScore: (j['clarity_score'] as num?)?.toDouble() ?? 0,
        confidenceScore: (j['confidence_score'] as num?)?.toDouble() ?? 0,
        overallScore: (j['overall_score'] as num?)?.toDouble() ?? 0,
        aiFeedback: (j['ai_feedback'] as List<dynamic>? ?? [])
            .map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
        isAnalyzed: j['is_analyzed'] as bool? ?? false,
        analysisFailed: j['analysis_failed'] as bool? ?? false,
      );

  SessionResult copyWith({
    String? id,
    String? mode,
    String? topicOrQuestion,
    double? durationSeconds,
    String? transcript,
    double? wpm,
    int? fillerWordCount,
    Map<String, int>? fillerWordBreakdown,
    int? pauseCount,
    double? avgPauseLength,
    double? clarityScore,
    double? confidenceScore,
    double? overallScore,
    List<FeedbackItem>? aiFeedback,
    DateTime? createdAt,
    bool? isAnalyzed,
    bool? analysisFailed,
    String? audioPath,
  }) {
    return SessionResult(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      topicOrQuestion: topicOrQuestion ?? this.topicOrQuestion,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      transcript: transcript ?? this.transcript,
      wpm: wpm ?? this.wpm,
      fillerWordCount: fillerWordCount ?? this.fillerWordCount,
      fillerWordBreakdown: fillerWordBreakdown ?? this.fillerWordBreakdown,
      pauseCount: pauseCount ?? this.pauseCount,
      avgPauseLength: avgPauseLength ?? this.avgPauseLength,
      clarityScore: clarityScore ?? this.clarityScore,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      overallScore: overallScore ?? this.overallScore,
      aiFeedback: aiFeedback ?? this.aiFeedback,
      createdAt: createdAt ?? this.createdAt,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
      analysisFailed: analysisFailed ?? this.analysisFailed,
      audioPath: audioPath ?? this.audioPath,
    );
  }

  /// Duration formatted as "mm:ss"
  String get durationFormatted {
    final total = durationSeconds.toInt();
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionSummary  (GET /sessions list)
// ─────────────────────────────────────────────────────────────────────────────

class SessionSummary {
  final String id;
  final String mode;
  final String topicOrQuestion;
  final double durationSeconds;
  final double overallScore;
  final double confidenceScore;
  final DateTime createdAt;
  final bool isAnalyzed;
  final bool analysisFailed;

  const SessionSummary({
    required this.id,
    required this.mode,
    required this.topicOrQuestion,
    required this.durationSeconds,
    required this.overallScore,
    required this.confidenceScore,
    required this.createdAt,
    required this.isAnalyzed,
    this.analysisFailed = false,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> j) => SessionSummary(
        id: j['id'] as String,
        mode: j['mode'] as String? ?? 'interview',
        topicOrQuestion: j['topic_or_question'] as String? ?? '',
        durationSeconds: (j['duration_seconds'] as num?)?.toDouble() ?? 0,
        overallScore: (j['overall_score'] as num?)?.toDouble() ?? 0,
        confidenceScore: (j['confidence_score'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
        isAnalyzed: j['is_analyzed'] as bool? ?? false,
        analysisFailed: j['analysis_failed'] as bool? ?? false,
      );

  String get durationFormatted {
    final total = durationSeconds.toInt();
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Pretty date: "Mon, Sep 22"
  String get dateFormatted {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final d = createdAt.toLocal();
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  /// Mode label for display
  String get modeLabel {
    switch (mode) {
      case 'presentation': return 'Presentation';
      case 'free_talk': return 'Free Talk';
      default: return 'Interview';
    }
  }
}
