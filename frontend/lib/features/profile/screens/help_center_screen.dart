import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_atmosphere.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _faqData = const [
    {
      'topic': 'Getting started',
      'items': [
        {
          'q': 'How does Pitch Coach work?',
          'a':
              'Pitch Coach uses acoustic analysis and large language models to assess your voice cadence, filler words, clarity, and message structure in real time.',
        },
        {
          'q': 'What equipment do I need for speech recording?',
          'a':
              'Your phone microphone is sufficient. For best results, speak in a quiet room at a distance of 1 to 2 feet from your device.',
        },
      ],
    },
    {
      'topic': 'Recording and scoring',
      'items': [
        {
          'q': 'How is my overall delivery score calculated?',
          'a':
              'Your score (0-100) weighs speaking pace (optimal 130-160 WPM), filler word frequency, clarity, volume consistency, and articulation.',
        },
        {
          'q': 'What is an optimal speaking pace?',
          'a':
              'An ideal conversational pace for presentations and interviews is 130 to 160 words per minute. Above 175 WPM sounds rushed, while below 110 WPM feels sluggish.',
        },
        {
          'q': 'How does filler word detection work?',
          'a':
              'Our audio processing engine transcribes phonemes and flags hesitations such as "um", "uh", "like", "you know", and repetitive discourse markers.',
        },
      ],
    },
    {
      'topic': 'Slide Coach',
      'items': [
        {
          'q': 'What presentation slide formats are supported?',
          'a':
              'You can upload PDF slide decks up to 50MB. PPTX export to PDF is recommended before uploading.',
        },
        {
          'q': 'How long does slide processing take?',
          'a':
              'Analysis generally finishes in 15 to 45 seconds depending on deck size. You can leave the app; you will be notified when ready.',
        },
        {
          'q': 'Can I practice Q&A defense on my slides?',
          'a':
              'Yes! The Slide Coach Q&A mode simulates audience questions and evaluates your spoken answers on each slide.',
        },
      ],
    },
    {
      'topic': 'Notifications',
      'items': [
        {
          'q': 'How do I change practice reminder schedules?',
          'a':
              'Navigate to Profile > Practice Goals and Reminders to customize days of the week, reminder time, and weekly session targets.',
        },
        {
          'q': 'Why am I not receiving slide processing notifications?',
          'a':
              'Make sure "Slide Deck Ready Alerts" is enabled in Profile > Notification Preferences, and notification permissions are allowed in system settings.',
        },
      ],
    },
    {
      'topic': 'Account and privacy',
      'items': [
        {
          'q': 'Is my voice recording stored or shared?',
          'a':
              'Your voice is processed securely for acoustic and speech scoring only. Recordings are never shared with third parties or used for ad targeting.',
        },
        {
          'q': 'How can I delete my profile data?',
          'a':
              'You can permanently delete your account and all associated practice history at the bottom of the Profile page via "Delete Account".',
        },
      ],
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();

    final filteredFaqs = _faqData.map((group) {
      final topic = group['topic'] as String;
      final items = (group['items'] as List<Map<String, String>>).where((item) {
        if (query.isEmpty) return true;
        return item['q']!.toLowerCase().contains(query) ||
            item['a']!.toLowerCase().contains(query) ||
            topic.toLowerCase().contains(query);
      }).toList();
      return {'topic': topic, 'items': items};
    }).where((group) => (group['items'] as List).isNotEmpty).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.pop(),
                      icon: RotatedBox(
                        quarterTurns: 2,
                        child: AppIcon(
                          AppIcons.chevronRight,
                          size: 20,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Help Center & FAQ',
                        style: AppTextStyles.headingM.copyWith(
                          fontSize: 18,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    const ThemeToggleButton(size: 38, compact: true),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: AppColors.textPrimaryOf(context)),
                    decoration: InputDecoration(
                      hintText: 'Search answers (e.g. WPM, slides, audio)',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondaryOf(context)
                            .withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: AppIcon(
                          AppIcons.search,
                          color: AppColors.primaryPurpleLight,
                          size: 20,
                        ),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // FAQs List
              Expanded(
                child: filteredFaqs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIcon(
                              AppIcons.help,
                              size: 40,
                              color: AppColors.primaryPurpleLight,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No matching questions found',
                              style: AppTextStyles.bodyM.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        itemCount: filteredFaqs.length,
                        itemBuilder: (context, index) {
                          final group = filteredFaqs[index];
                          final topic = group['topic'] as String;
                          final items =
                              group['items'] as List<Map<String, String>>;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 4, bottom: 8),
                                  child: Text(
                                    topic,
                                    style: AppTextStyles.headingM.copyWith(
                                      fontSize: 15,
                                      color: AppColors.primaryPurpleLight,
                                    ),
                                  ),
                                ),
                                GlassSurface(
                                  borderRadius: BorderRadius.circular(16),
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: items.map((item) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 2),
                                          childrenPadding:
                                              const EdgeInsets.fromLTRB(
                                                  16, 0, 16, 16),
                                          title: Text(
                                            item['q']!,
                                            style: AppTextStyles.bodyM.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: AppColors.textPrimaryOf(
                                                  context),
                                            ),
                                          ),
                                          children: [
                                            Text(
                                              item['a']!,
                                              style: AppTextStyles.bodyM
                                                  .copyWith(
                                                fontSize: 13,
                                                color: AppColors.textSecondaryOf(
                                                    context),
                                                height: 1.45,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Support CTA
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GlassSurface(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    children: [
                      const AppIcon(
                        AppIcons.chat,
                        color: AppColors.primaryPurpleLight,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Still need help?',
                              style: AppTextStyles.bodyM.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            Text(
                              'Send our engineering team direct feedback.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          context.push('/profile/feedback');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryPurpleLight,
                          side: const BorderSide(
                              color: AppColors.primaryPurple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Contact Us'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
