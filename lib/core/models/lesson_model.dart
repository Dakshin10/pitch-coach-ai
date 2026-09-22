/// Data model for a communication lesson in the Learn section.
class Lesson {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String duration;
  final String category; // 'interview' | 'presentation' | 'speaking'
  final List<String> takeaways;
  final String weakAreaTag; // maps to session result categories

  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.duration,
    required this.category,
    required this.takeaways,
    required this.weakAreaTag,
  });
}

/// Curated local lesson catalog for Pitch Coach.
abstract class LessonCatalog {
  static const List<Lesson> all = [
    Lesson(
      id: 'l001',
      title: 'Reduce Filler Words',
      description:
          'Learn how to speak clearly without relying on unnecessary filler words like "um", "uh", or "like".',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      duration: '4 min',
      category: 'speaking',
      weakAreaTag: 'filler_words',
      takeaways: [
        'Pause instead of saying "um"',
        'Prepare smooth transitions between ideas',
        'Slow down naturally — pauses are powerful',
        'Record yourself to identify your filler patterns',
      ],
    ),
    Lesson(
      id: 'l002',
      title: 'Control Your Speaking Pace',
      description:
          'Discover how to maintain a natural, confident speaking rhythm that engages your audience.',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      duration: '5 min',
      category: 'speaking',
      weakAreaTag: 'pacing',
      takeaways: [
        'Aim for 120–150 words per minute',
        'Vary your pace for emphasis',
        'Breathe between key points',
        'Practice reading aloud daily',
      ],
    ),
    Lesson(
      id: 'l003',
      title: 'Pause for Emphasis',
      description:
          'Master the art of strategic pausing to add impact, clarity, and confidence to your speech.',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      duration: '3 min',
      category: 'speaking',
      weakAreaTag: 'pacing',
      takeaways: [
        'A pause signals confidence, not weakness',
        'Pause before key statements for impact',
        'Use 1–2 second pauses after transitions',
        'Silence allows your audience to process ideas',
      ],
    ),
    Lesson(
      id: 'l004',
      title: 'Answer "Tell Me About Yourself"',
      description:
          'Craft a compelling, structured 2-minute answer to the most common interview opener.',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      duration: '6 min',
      category: 'interview',
      weakAreaTag: 'confidence',
      takeaways: [
        'Use the Present–Past–Future structure',
        'Connect your background to the role',
        'Keep it to under 2 minutes',
        'End with enthusiasm about this opportunity',
      ],
    ),
    Lesson(
      id: 'l005',
      title: 'Presentation Body Language',
      description:
          'Learn how posture, eye contact, and gestures amplify your message and boost your confidence.',
      videoUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      duration: '5 min',
      category: 'presentation',
      weakAreaTag: 'confidence',
      takeaways: [
        'Maintain eye contact with different audience members',
        'Use open gestures — avoid crossed arms',
        'Stand tall — posture projects confidence',
        'Smile naturally — it builds rapport instantly',
      ],
    ),
  ];

  /// Returns the most relevant lesson for a weak area tag.
  static Lesson? forWeakArea(String tag) {
    try {
      return all.firstWhere((l) => l.weakAreaTag == tag);
    } catch (_) {
      return null;
    }
  }

  static List<Lesson> byCategory(String category) =>
      all.where((l) => l.category == category).toList();
}
