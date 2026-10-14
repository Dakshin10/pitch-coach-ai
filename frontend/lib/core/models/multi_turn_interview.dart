/// Role for each message in a multi-turn interview dialogue.
enum TurnRole { interviewer, candidate }

class TurnMessage {
  final TurnRole role;
  final String content;

  const TurnMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {
    'role': role == TurnRole.interviewer ? 'interviewer' : 'candidate',
    'content': content,
  };

  factory TurnMessage.fromJson(Map<String, dynamic> json) {
    final r = json['role'] as String? ?? 'candidate';
    return TurnMessage(
      role: r == 'interviewer' ? TurnRole.interviewer : TurnRole.candidate,
      content: json['content'] as String? ?? '',
    );
  }
}

class TurnEvaluateResponse {
  final String? followUp;
  final bool moveOn;
  final String reason;
  final bool isVague;
  final double? latencyMs;
  final String? transcription;

  const TurnEvaluateResponse({
    this.followUp,
    required this.moveOn,
    required this.reason,
    this.isVague = false,
    this.latencyMs,
    this.transcription,
  });

  factory TurnEvaluateResponse.fromJson(Map<String, dynamic> json) {
    return TurnEvaluateResponse(
      followUp: json['follow_up'] as String?,
      moveOn: json['move_on'] as bool? ?? true,
      reason: json['reason'] as String? ?? '',
      isVague: json['is_vague'] as bool? ?? false,
      latencyMs: (json['latency_ms'] as num?)?.toDouble(),
      transcription: json['transcription'] as String?,
    );
  }
}

class ExchangeScoreResponse {
  final double clarityScore;
  final double confidenceScore;
  final double overallScore;
  final String feedbackSummary;
  final List<String> strengths;
  final List<String> improvements;
  final Map<String, String>? starAssessment;
  final double? latencyMs;

  const ExchangeScoreResponse({
    required this.clarityScore,
    required this.confidenceScore,
    required this.overallScore,
    required this.feedbackSummary,
    this.strengths = const [],
    this.improvements = const [],
    this.starAssessment,
    this.latencyMs,
  });

  factory ExchangeScoreResponse.fromJson(Map<String, dynamic> json) {
    final rawStar = json['star_assessment'] as Map<String, dynamic>?;
    Map<String, String>? star;
    if (rawStar != null) {
      star = rawStar.map((k, v) => MapEntry(k, v.toString()));
    }

    return ExchangeScoreResponse(
      clarityScore: (json['clarity_score'] as num?)?.toDouble() ?? 70.0,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 70.0,
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 70.0,
      feedbackSummary: json['feedback_summary'] as String? ?? '',
      strengths:
          (json['strengths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      improvements:
          (json['improvements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      starAssessment: star,
      latencyMs: (json['latency_ms'] as num?)?.toDouble(),
    );
  }
}
