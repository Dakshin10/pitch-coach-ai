import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_atmosphere.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class SendFeedbackScreen extends StatefulWidget {
  const SendFeedbackScreen({super.key});

  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();

  String _category = 'Bug';
  final List<String> _categories = const ['Bug', 'Idea', 'Other'];

  bool _includeDeviceInfo = true;
  XFile? _attachedImage;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _submittedSuccess = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _attachedImage = picked);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not select image: $e');
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> metadata = {};
      if (_includeDeviceInfo) {
        final pkg = await PackageInfo.fromPlatform();
        metadata = {
          'version': pkg.version,
          'build_number': pkg.buildNumber,
          'platform': defaultTargetPlatform.name,
          'is_web': kIsWeb,
        };
      }

      await AuthRepository.instance.submitFeedback(
        category: _category.toLowerCase(),
        message: _messageController.text.trim(),
        metadata: metadata,
      );

      setState(() => _submittedSuccess = true);
      if (mounted) {
        AppToast.success(
          context,
          'Thank you! Your feedback has been received.',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to submit feedback. Check connection or send via email.';
      });
      if (mounted) {
        AppToast.error(context, 'Network error submitting feedback');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendViaEmail() async {
    final body = Uri.encodeComponent(
      'Feedback Category: $_category\n\n${_messageController.text.trim()}',
    );
    final subject = Uri.encodeComponent('Pitch Coach Feedback - $_category');
    final uri = Uri.parse(
      'mailto:support@pitchcoach.app?subject=$subject&body=$body',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppToast.error(context, 'No email client installed on this device');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not open email app: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppAtmosphere(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                        'Send Feedback',
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

              Expanded(
                child: _submittedSuccess
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.successGreen.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const AppIcon(
                                  AppIcons.award,
                                  color: AppColors.successGreen,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Feedback Submitted!',
                                style: AppTextStyles.headingL.copyWith(
                                  fontSize: 20,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Thank you for helping us make Pitch Coach better. Our engineering team reviews all incoming logs and suggestions.',
                                style: AppTextStyles.bodyM.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              GradientButton(
                                text: 'Done',
                                variant: GradientButtonVariant.primary,
                                width: 140,
                                height: 44,
                                onPressed: () => context.pop(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Chips
                              Text(
                                'What kind of feedback?',
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: _categories.map((cat) {
                                  final selected = _category == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(cat),
                                      selected: selected,
                                      selectedColor: AppColors.primaryPurple,
                                      backgroundColor: AppColors.cardOf(
                                        context,
                                      ),
                                      labelStyle: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : AppColors.textPrimaryOf(context),
                                        fontWeight: selected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: selected
                                              ? AppColors.primaryPurple
                                              : AppColors.borderOf(context),
                                        ),
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() => _category = cat);
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 20),

                              // Message Field
                              Text(
                                'Your Message (min 10 characters)',
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _messageController,
                                maxLines: 5,
                                maxLength: 1000,
                                style: TextStyle(
                                  color: AppColors.textPrimaryOf(context),
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Describe the bug, idea, or issue in detail...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondaryOf(
                                      context,
                                    ).withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.cardOf(context),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: AppColors.borderOf(context),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: AppColors.borderOf(context),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.primaryPurple,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().length < 10) {
                                    return 'Please enter at least 10 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // Screenshot Attachment
                              Text(
                                'Screenshot (Optional)',
                                style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_attachedImage == null)
                                OutlinedButton.icon(
                                  onPressed: _pickScreenshot,
                                  icon: const AppIcon(
                                    AppIcons.camera,
                                    color: AppColors.primaryPurpleLight,
                                    size: 18,
                                  ),
                                  label: const Text('Attach Screenshot'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        AppColors.primaryPurpleLight,
                                    side: BorderSide(
                                      color: AppColors.borderOf(context),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                )
                              else
                                GlassSurface(
                                  padding: const EdgeInsets.all(10),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: kIsWeb
                                              ? Image.network(
                                                  _attachedImage!.path,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.file(
                                                  File(_attachedImage!.path),
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _attachedImage!.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textPrimaryOf(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () => setState(
                                          () => _attachedImage = null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Device info opt-in
                              GlassSurface(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Include App & Device Diagnostics',
                                            style: AppTextStyles.bodyM.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: AppColors.textPrimaryOf(
                                                context,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'Helps us reproduce bugs faster',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondaryOf(
                                                        context,
                                                      ),
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _includeDeviceInfo,
                                      activeThumbColor: AppColors.primaryPurple,
                                      onChanged: (val) => setState(
                                        () => _includeDeviceInfo = val,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorRed.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.errorRed.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const AppIcon(
                                        AppIcons.info,
                                        color: AppColors.errorRed,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.errorRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _sendViaEmail,
                                  icon: const AppIcon(
                                    AppIcons.chat,
                                    size: 16,
                                    color: AppColors.primaryPurpleLight,
                                  ),
                                  label: const Text('Email Support Directly'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        AppColors.primaryPurpleLight,
                                    side: const BorderSide(
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              GradientButton(
                                text: _isSubmitting
                                    ? 'Submitting...'
                                    : 'Send Feedback',
                                variant: GradientButtonVariant.primary,
                                height: 50,
                                onPressed: _isSubmitting
                                    ? null
                                    : _submitFeedback,
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
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
