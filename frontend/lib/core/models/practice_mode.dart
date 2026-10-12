import 'package:flutter/material.dart';

/// Practice mode configuration and question bank.
class PracticePrompt {
  final String id;
  final String text;
  final String category;
  final String hint;
  final int targetDurationSeconds;

  const PracticePrompt({
    required this.id,
    required this.text,
    required this.category,
    required this.hint,
    this.targetDurationSeconds = 60,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'category': category,
    'hint': hint,
    'target_duration_seconds': targetDurationSeconds,
  };

  factory PracticePrompt.fromJson(Map<String, dynamic> json) => PracticePrompt(
    id: json['id'] as String,
    text: json['text'] as String,
    category: json['category'] as String? ?? 'General',
    hint: json['hint'] as String? ?? '',
    targetDurationSeconds: json['target_duration_seconds'] as int? ?? 60,
  );
}

class PracticeMode {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<PracticePrompt> prompts;
  final int defaultTargetSeconds;

  const PracticeMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.prompts,
    this.defaultTargetSeconds = 60,
  });

  static const String interviewId = 'interview';
  static const String presentationId = 'presentation';
  static const String freeTalkId = 'free_talk';

  static const List<PracticeMode> allModes = [
    PracticeMode(
      id: interviewId,
      title: 'Interview Practice',
      subtitle: 'Behavioral, situational, and classic interview questions',
      icon: Icons.event_seat_rounded,
      defaultTargetSeconds: 90,
      prompts: [
        PracticePrompt(
          id: 'int-1',
          text: 'Tell me about yourself and your professional journey.',
          category: 'Icebreaker',
          hint:
              'Structure with Present, Past, and Future. Highlight core strengths.',
          targetDurationSeconds: 90,
        ),
        PracticePrompt(
          id: 'int-2',
          text:
              'Describe a challenging conflict you faced in a team and how you resolved it.',
          category: 'STAR Method',
          hint:
              'Focus on Situation, Task, Action you took, and positive Result achieved.',
          targetDurationSeconds: 120,
        ),
        PracticePrompt(
          id: 'int-3',
          text:
              'Why are you interested in this position and what makes you a strong fit?',
          category: 'Motivation',
          hint:
              'Align your personal values and accomplishments with company goals.',
          targetDurationSeconds: 75,
        ),
        PracticePrompt(
          id: 'int-4',
          text:
              'Tell me about a project where things did not go as planned. What did you learn?',
          category: 'Resilience',
          hint: 'Take accountability, reflect on lessons, and show growth.',
          targetDurationSeconds: 90,
        ),
        PracticePrompt(
          id: 'int-5',
          text:
              'How do you prioritize competing deadlines under tight pressure?',
          category: 'Prioritization',
          hint:
              'Mention frameworks like Eisenhower matrix or transparent team triage.',
          targetDurationSeconds: 75,
        ),
        PracticePrompt(
          id: 'int-6',
          text:
              'Describe an initiative where you demonstrated leadership without formal authority.',
          category: 'Leadership',
          hint:
              'Demonstrate initiative, empathy, and how you persuaded colleagues.',
          targetDurationSeconds: 100,
        ),
      ],
    ),
    PracticeMode(
      id: presentationId,
      title: 'Presentation Practice',
      subtitle: 'Pitches, slide transitions, and keynote delivery',
      icon: Icons.bar_chart_rounded,
      defaultTargetSeconds: 120,
      prompts: [
        PracticePrompt(
          id: 'pres-1',
          text:
              'Deliver a 60-second elevator pitch for an innovative product idea.',
          category: 'Elevator Pitch',
          hint: 'State the Hook, Problem, Solution, Unique Advantage, and Ask.',
          targetDurationSeconds: 60,
        ),
        PracticePrompt(
          id: 'pres-2',
          text:
              'Brief executive stakeholders on a major quarterly milestone update.',
          category: 'Executive Briefing',
          hint:
              'Start with the bottom line first (BLUF): status, metrics, and risks.',
          targetDurationSeconds: 120,
        ),
        PracticePrompt(
          id: 'pres-3',
          text:
              'Introduce a new technical proposal and persuade senior leadership to adopt it.',
          category: 'Technical Pitch',
          hint: 'Highlight ROI, architecture advantages, and migration safety.',
          targetDurationSeconds: 150,
        ),
        PracticePrompt(
          id: 'pres-4',
          text:
              'Deliver an engaging opening hook for an all-hands company presentation.',
          category: 'Storytelling',
          hint:
              'Use a provocative question, personal anecdote, or surprising statistic.',
          targetDurationSeconds: 90,
        ),
        PracticePrompt(
          id: 'pres-5',
          text: 'Close a keynote presentation with a memorable call to action.',
          category: 'Keynote Close',
          hint:
              'Inspire your audience with conviction, pacing, and clear vision.',
          targetDurationSeconds: 90,
        ),
      ],
    ),
    PracticeMode(
      id: freeTalkId,
      title: 'Free Talk',
      subtitle: 'Spontaneous speech, storytelling, and impromptu challenges',
      icon: Icons.mic_rounded,
      defaultTargetSeconds: 90,
      prompts: [
        PracticePrompt(
          id: 'free-1',
          text:
              'Explain a complex concept so simply a 10-year-old would understand.',
          category: 'Clarity & Analogy',
          hint: 'Avoid jargon. Use everyday analogies and tangible imagery.',
          targetDurationSeconds: 90,
        ),
        PracticePrompt(
          id: 'free-2',
          text:
              'Share a personal hobby or obsession that shaped how you view the world.',
          category: 'Personal Narrative',
          hint:
              'Let your natural enthusiasm show while keeping a coherent narrative.',
          targetDurationSeconds: 90,
        ),
        PracticePrompt(
          id: 'free-3',
          text:
              'Should AI tools be integrated directly into school exams? Defend your view.',
          category: 'Persuasive Speech',
          hint:
              'Structure your argument with a clear premise, 2 supporting points, and conclusion.',
          targetDurationSeconds: 100,
        ),
        PracticePrompt(
          id: 'free-4',
          text:
              'What is the best piece of advice you have ever received, and how has it guided you?',
          category: 'Reflection',
          hint:
              'Connect the advice to a concrete inflection point in your life.',
          targetDurationSeconds: 90,
        ),
        PracticePrompt(
          id: 'free-5',
          text:
              'Describe what your dream workplace culture looks like in practice.',
          category: 'Impromptu',
          hint:
              'Focus on communication patterns, psychological safety, and execution.',
          targetDurationSeconds: 90,
        ),
      ],
    ),
  ];

  static PracticeMode fromId(String? id) {
    if (id == null) return allModes.first;
    return allModes.firstWhere((m) => m.id == id, orElse: () => allModes.first);
  }
}

/// Configuration passed to the recording screen.
class PracticeSessionConfig {
  final String modeId;
  final PracticePrompt prompt;

  const PracticeSessionConfig({required this.modeId, required this.prompt});

  PracticeMode get mode => PracticeMode.fromId(modeId);

  factory PracticeSessionConfig.defaultFor(String? modeId) {
    final mode = PracticeMode.fromId(modeId);
    return PracticeSessionConfig(modeId: mode.id, prompt: mode.prompts.first);
  }
}
