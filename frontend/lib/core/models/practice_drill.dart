/// Models for Personalized Practice Plan (Feature 6).
class PracticeDrill {
  final String id;
  final String title;
  final String description;
  final String targetMetric;
  final int targetDurationSeconds;
  final Map<String, dynamic> successCriteria;
  final bool isCompleted;
  final DateTime? completedAt;
  final String reason;

  const PracticeDrill({
    required this.id,
    required this.title,
    required this.description,
    required this.targetMetric,
    required this.targetDurationSeconds,
    required this.successCriteria,
    this.isCompleted = false,
    this.completedAt,
    required this.reason,
  });

  factory PracticeDrill.fromJson(Map<String, dynamic> json) {
    return PracticeDrill(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetMetric: json['target_metric'] as String? ?? 'clarity',
      targetDurationSeconds: (json['target_duration_seconds'] as num?)?.toInt() ?? 30,
      successCriteria: (json['success_criteria'] as Map<String, dynamic>?) ?? {},
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'target_metric': targetMetric,
    'target_duration_seconds': targetDurationSeconds,
    'success_criteria': successCriteria,
    'is_completed': isCompleted,
    if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    'reason': reason,
  };

  PracticeDrill copyWith({
    String? id,
    String? title,
    String? description,
    String? targetMetric,
    int? targetDurationSeconds,
    Map<String, dynamic>? successCriteria,
    bool? isCompleted,
    DateTime? completedAt,
    String? reason,
  }) {
    return PracticeDrill(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetMetric: targetMetric ?? this.targetMetric,
      targetDurationSeconds: targetDurationSeconds ?? this.targetDurationSeconds,
      successCriteria: successCriteria ?? this.successCriteria,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      reason: reason ?? this.reason,
    );
  }
}

class MetricDiagnosis {
  final String weakestMetric;
  final double avgWpm;
  final double avgFillersPer100;
  final double avgPauseCount;
  final int sessionsAnalyzed;
  final String scoreTrend;
  final String diagnosticsSummary;

  const MetricDiagnosis({
    required this.weakestMetric,
    required this.avgWpm,
    required this.avgFillersPer100,
    required this.avgPauseCount,
    required this.sessionsAnalyzed,
    required this.scoreTrend,
    required this.diagnosticsSummary,
  });

  factory MetricDiagnosis.fromJson(Map<String, dynamic> json) {
    return MetricDiagnosis(
      weakestMetric: json['weakest_metric'] as String? ?? 'onboarding',
      avgWpm: (json['avg_wpm'] as num?)?.toDouble() ?? 0.0,
      avgFillersPer100: (json['avg_fillers_per_100'] as num?)?.toDouble() ?? 0.0,
      avgPauseCount: (json['avg_pause_count'] as num?)?.toDouble() ?? 0.0,
      sessionsAnalyzed: (json['sessions_analyzed'] as num?)?.toInt() ?? 0,
      scoreTrend: json['score_trend'] as String? ?? 'insufficient_data',
      diagnosticsSummary: json['diagnostics_summary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'weakest_metric': weakestMetric,
    'avg_wpm': avgWpm,
    'avg_fillers_per_100': avgFillersPer100,
    'avg_pause_count': avgPauseCount,
    'sessions_analyzed': sessionsAnalyzed,
    'score_trend': scoreTrend,
    'diagnostics_summary': diagnosticsSummary,
  };
}

class PracticePlan {
  final MetricDiagnosis diagnosis;
  final List<PracticeDrill> drills;
  final DateTime generatedAt;
  final bool isDefaultPlan;

  const PracticePlan({
    required this.diagnosis,
    required this.drills,
    required this.generatedAt,
    this.isDefaultPlan = false,
  });

  factory PracticePlan.fromJson(Map<String, dynamic> json) {
    return PracticePlan(
      diagnosis: MetricDiagnosis.fromJson(
        (json['diagnosis'] as Map<String, dynamic>?) ?? {},
      ),
      drills: ((json['drills'] as List<dynamic>?) ?? [])
          .map((d) => PracticeDrill.fromJson(d as Map<String, dynamic>))
          .toList(),
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isDefaultPlan: json['is_default_plan'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'diagnosis': diagnosis.toJson(),
    'drills': drills.map((d) => d.toJson()).toList(),
    'generated_at': generatedAt.toIso8601String(),
    'is_default_plan': isDefaultPlan,
  };
}
