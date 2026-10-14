/// Data model for Resume & Job Description interview question generation.
class ResumeQuestionsResult {
  final List<String> candidateProjects;
  final List<String> candidateSkills;
  final List<String> behavioralQuestions;
  final List<String> technicalQuestions;
  final String? sanitizedSnippet;

  const ResumeQuestionsResult({
    this.candidateProjects = const [],
    this.candidateSkills = const [],
    this.behavioralQuestions = const [],
    this.technicalQuestions = const [],
    this.sanitizedSnippet,
  });

  factory ResumeQuestionsResult.fromJson(Map<String, dynamic> j) {
    return ResumeQuestionsResult(
      candidateProjects: (j['candidate_projects'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      candidateSkills: (j['candidate_skills'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      behavioralQuestions: (j['behavioral_questions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      technicalQuestions: (j['technical_questions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      sanitizedSnippet: j['sanitized_snippet'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'candidate_projects': candidateProjects,
    'candidate_skills': candidateSkills,
    'behavioral_questions': behavioralQuestions,
    'technical_questions': technicalQuestions,
    'sanitized_snippet': sanitizedSnippet,
  };

  /// All 10 questions ordered logically (technical then behavioral)
  List<String> get allQuestions => [
    ...technicalQuestions,
    ...behavioralQuestions,
  ];
}
