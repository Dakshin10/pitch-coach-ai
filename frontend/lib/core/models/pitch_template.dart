/// Pitch templates and section structure definitions.
library;

class TemplateSection {
  final String id;
  final String name;
  final String description;
  final double weight;
  final List<String> keywords;

  const TemplateSection({
    required this.id,
    required this.name,
    required this.description,
    required this.weight,
    this.keywords = const [],
  });

  factory TemplateSection.fromJson(Map<String, dynamic> j) => TemplateSection(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '',
    weight: (j['weight'] as num?)?.toDouble() ?? 0.0,
    keywords: (j['keywords'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'weight': weight,
    'keywords': keywords,
  };
}

class PitchTemplate {
  final String id;
  final String title;
  final String description;
  final int targetDurationSeconds;
  final List<TemplateSection> sections;
  final Map<String, String> rubric;
  final String coachingFocus;

  const PitchTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.targetDurationSeconds,
    required this.sections,
    required this.rubric,
    required this.coachingFocus,
  });

  factory PitchTemplate.fromJson(Map<String, dynamic> j) => PitchTemplate(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    targetDurationSeconds: (j['target_duration_seconds'] as num?)?.toInt() ?? 120,
    sections: (j['sections'] as List<dynamic>? ?? [])
        .map((e) => TemplateSection.fromJson(e as Map<String, dynamic>))
        .toList(),
    rubric: (j['rubric'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v.toString()),
    ),
    coachingFocus: j['coaching_focus'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'target_duration_seconds': targetDurationSeconds,
    'sections': sections.map((s) => s.toJson()).toList(),
    'rubric': rubric,
    'coaching_focus': coachingFocus,
  };

  /// Static default fallback templates available offline
  static const List<PitchTemplate> defaultTemplates = [
    PitchTemplate(
      id: 'investor_pitch',
      title: 'Investor Pitch',
      description: 'Raise capital with problem, solution, traction, business model, and the ask.',
      targetDurationSeconds: 180,
      sections: [
        TemplateSection(
          id: 'hook_problem',
          name: 'Hook & Problem',
          description: 'Painful customer problem and market timing.',
          weight: 20.0,
          keywords: ['problem', 'pain', 'market', 'customers'],
        ),
        TemplateSection(
          id: 'solution_product',
          name: 'Solution & Product',
          description: 'Unique value proposition and technical advantage.',
          weight: 25.0,
          keywords: ['solution', 'platform', 'product', 'advantage'],
        ),
        TemplateSection(
          id: 'traction_market',
          name: 'Traction & TAM',
          description: 'Revenue, users, ARR, growth rate, and market size.',
          weight: 25.0,
          keywords: ['traction', 'revenue', 'growth', 'users', 'arr', 'tam'],
        ),
        TemplateSection(
          id: 'business_model',
          name: 'Business Model',
          description: 'Monetization, pricing, and unit economics.',
          weight: 15.0,
          keywords: ['pricing', 'subscription', 'business model', 'margins'],
        ),
        TemplateSection(
          id: 'the_ask',
          name: 'The Ask & Use of Funds',
          description: 'Capital required, milestones, and hiring.',
          weight: 15.0,
          keywords: ['raising', 'ask', 'capital', 'milestones', 'funds'],
        ),
      ],
      rubric: {
        'hook_problem': 'Does the speaker clearly articulate who feels the pain?',
        'solution_product': 'Is the solution intuitive and defensible?',
        'traction_market': 'Are metrics quantifiable rather than vague?',
        'business_model': 'Is unit economics logic sound?',
        'the_ask': 'Is there an explicit monetary figure and milestone timeline?',
      },
      coachingFocus: 'Urgency, defensible unit economics, quantifiable traction, and specific capital allocation.',
    ),
    PitchTemplate(
      id: 'hackathon_demo',
      title: 'Hackathon Demo',
      description: '2-minute demo emphasizing technical innovation and working execution.',
      targetDurationSeconds: 120,
      sections: [
        TemplateSection(
          id: 'problem_statement',
          name: 'Problem Statement',
          description: 'Snappy problem definition in under 20 seconds.',
          weight: 20.0,
          keywords: ['problem', 'why', 'built', 'challenge'],
        ),
        TemplateSection(
          id: 'live_demo',
          name: 'Live Working Demo',
          description: 'Step-by-step user journey showing core feature.',
          weight: 40.0,
          keywords: ['demo', 'works', 'here', 'show', 'user'],
        ),
        TemplateSection(
          id: 'architecture_tech',
          name: 'Architecture & Tech Stack',
          description: 'APIs, frameworks, databases, and LLM orchestration.',
          weight: 25.0,
          keywords: ['built with', 'stack', 'backend', 'api', 'model'],
        ),
        TemplateSection(
          id: 'next_steps',
          name: 'Next Steps & Future Roadmap',
          description: 'What would be built over the next 30 days.',
          weight: 15.0,
          keywords: ['next', 'future', 'roadmap', 'ship'],
        ),
      ],
      rubric: {
        'problem_statement': 'Was the hook fast and understandable?',
        'live_demo': 'Did the speaker show real value rather than just talking?',
        'architecture_tech': 'Did they highlight technical complexity?',
        'next_steps': 'Is the future roadmap realistic?',
      },
      coachingFocus: 'Crisp demonstration, architectural clarity, and stage presence.',
    ),
    PitchTemplate(
      id: 'elevator_pitch',
      title: 'Elevator Pitch',
      description: '60-second high-impact summary to hook a listener and secure follow-up.',
      targetDurationSeconds: 60,
      sections: [
        TemplateSection(
          id: 'hook',
          name: 'The Hook',
          description: 'Provocative question or surprising industry statistic.',
          weight: 30.0,
          keywords: ['imagine', 'did you know', 'every year', 'problem'],
        ),
        TemplateSection(
          id: 'value_prop',
          name: 'Value Proposition',
          description: 'What you do and who benefits.',
          weight: 40.0,
          keywords: ['we help', 'our product', 'enables', 'platform'],
        ),
        TemplateSection(
          id: 'call_to_action',
          name: 'Call to Action',
          description: 'Specific low-friction next step or contact exchange.',
          weight: 30.0,
          keywords: ['love to chat', 'follow up', 'coffee', 'card', 'connect'],
        ),
      ],
      rubric: {
        'hook': 'Did it grab attention in under 10 seconds?',
        'value_prop': 'Can a 10-year-old understand what it does?',
        'call_to_action': 'Is the next step specific and low friction?',
      },
      coachingFocus: 'Brevity, memorability, cadence, and clear next step.',
    ),
    PitchTemplate(
      id: 'viva',
      title: 'Academic Viva / Defense',
      description: '5-minute research defense explaining contributions, benchmarks, and limitations.',
      targetDurationSeconds: 300,
      sections: [
        TemplateSection(
          id: 'research_gap',
          name: 'Research Gap & Problem Statement',
          description: 'Scholarly context and novel thesis contribution.',
          weight: 20.0,
          keywords: ['contribution', 'novel', 'literature', 'gap', 'hypothesis'],
        ),
        TemplateSection(
          id: 'methodology',
          name: 'Proposed Methodology',
          description: 'Formulations, model architectures, and experimental design.',
          weight: 30.0,
          keywords: ['methodology', 'framework', 'pipeline', 'architecture', 'design'],
        ),
        TemplateSection(
          id: 'results_benchmarks',
          name: 'Empirical Results & Benchmarks',
          description: 'Comparative benchmarks, metrics, and error analysis.',
          weight: 35.0,
          keywords: ['results', 'benchmark', 'accuracy', 'baseline', 'metrics'],
        ),
        TemplateSection(
          id: 'limitations_critique',
          name: 'Limitations & Future Work',
          description: 'Honest appraisal of constraints and edge cases.',
          weight: 15.0,
          keywords: ['limitations', 'constraints', 'future work', 'scope'],
        ),
      ],
      rubric: {
        'research_gap': 'Is the scholarly gap distinguished from prior work?',
        'methodology': 'Is the experimental protocol justified?',
        'results_benchmarks': 'Are quantitative results backed by baselines?',
        'limitations_critique': 'Is there academic honesty regarding limitations?',
      },
      coachingFocus: 'Methodological rigor, baseline benchmarking, and objective defense.',
    ),
  ];
}
