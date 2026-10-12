import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_atmosphere.dart';

class LanguagePickerSheet extends StatelessWidget {
  const LanguagePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LanguagePickerSheet(),
    );
  }

  static const List<Map<String, dynamic>> languages = [
    {
      'code': 'en',
      'name': 'English',
      'nativeName': 'English',
      'isAvailable': true,
    },
    {
      'code': 'ta',
      'name': 'Tamil',
      'nativeName': 'தமிழ்',
      'isAvailable': false,
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'nativeName': 'हिन्दी',
      'isAvailable': false,
    },
    {
      'code': 'es',
      'name': 'Spanish',
      'nativeName': 'Español',
      'isAvailable': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currentLocale = settings.locale;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondaryOf(
                      context,
                    ).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select App Language',
                    style: AppTextStyles.headingM.copyWith(
                      fontSize: 18,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const AppIcon(
                    AppIcons.globe,
                    color: AppColors.primaryPurpleLight,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pitch Coach AI models transcribe and analyze multi-dialect speech.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 16),

              ...languages.map((lang) {
                final code = lang['code'] as String;
                final name = lang['name'] as String;
                final nativeName = lang['nativeName'] as String;
                final isAvailable = lang['isAvailable'] as bool;
                final isSelected = currentLocale == code;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      if (isAvailable) {
                        await settings.setLocale(code);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          AppToast.success(context, 'Language set to $name');
                        }
                      } else {
                        AppToast.info(
                          context,
                          '$nativeName ($name) translation is coming soon in the next update.',
                        );
                      }
                    },
                    child: GlassSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nativeName,
                                style: AppTextStyles.bodyM.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              Text(
                                name,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (!isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.textSecondaryOf(
                                  context,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Coming Soon',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryOf(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else if (isSelected)
                            const AppIcon(
                              AppIcons.award,
                              color: AppColors.primaryPurpleLight,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
