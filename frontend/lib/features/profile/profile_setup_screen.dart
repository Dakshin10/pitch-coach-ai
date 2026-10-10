import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/theme_toggle_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _emailController;

  late String _initialName;
  late String _initialRole;
  late String _initialEmail;
  late String _initialGoal;
  late String _initialLevel;
  late String _initialIndustry;
  late String _initialTone;

  String _selectedGoal = 'Technical Interviews & Pitch Presentations';
  String _selectedLevel = 'Intermediate';
  String _selectedIndustry = 'Software & Technology';
  String _selectedTone = 'Encouraging & Constructive';

  bool _isSaving = false;

  final List<String> _goals = [
    'Technical Interviews & Pitch Presentations',
    'Elevator Pitch & Startup Demos',
    'Public Speaking & Keynotes',
    'Sales & Client Presentations',
  ];

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced / Executive',
  ];

  final List<String> _industries = [
    'Software & Technology',
    'Finance & Banking',
    'Healthcare & Biotech',
    'Business & Consulting',
    'Creative & Design',
    'Education & Research',
  ];

  final List<String> _tones = [
    'Encouraging & Constructive',
    'Direct & Strict',
    'Analytical & Data-Focused',
  ];

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).user;
    _initialName = user.name;
    _initialRole = user.role;
    _initialEmail = user.email;

    _nameController = TextEditingController(text: _initialName);
    _roleController = TextEditingController(text: _initialRole);
    _emailController = TextEditingController(text: _initialEmail);

    if (_goals.contains(user.targetGoal)) _selectedGoal = user.targetGoal;
    if (_levels.contains(user.experienceLevel)) _selectedLevel = user.experienceLevel;
    if (_industries.contains(user.targetIndustry)) {
      _selectedIndustry = user.targetIndustry;
    }
    if (_tones.contains(user.feedbackTone)) _selectedTone = user.feedbackTone;

    _initialGoal = _selectedGoal;
    _initialLevel = _selectedLevel;
    _initialIndustry = _selectedIndustry;
    _initialTone = _selectedTone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    return _nameController.text.trim() != _initialName.trim() ||
        _roleController.text.trim() != _initialRole.trim() ||
        _emailController.text.trim() != _initialEmail.trim() ||
        _selectedGoal != _initialGoal ||
        _selectedLevel != _initialLevel ||
        _selectedIndustry != _initialIndustry ||
        _selectedTone != _initialTone;
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty || _isSaving) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevatedCardOf(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Discard changes?',
          style: AppTextStyles.headingM.copyWith(
            color: AppColors.textPrimaryOf(ctx),
          ),
        ),
        content: Text(
          'You have unsaved edits. Are you sure you want to discard them?',
          style: AppTextStyles.bodyM.copyWith(
            color: AppColors.textSecondaryOf(ctx),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep Editing',
              style: TextStyle(color: AppColors.textSecondaryOf(ctx)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Discard',
              style: TextStyle(
                color: AppColors.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await Provider.of<UserProvider>(context, listen: false).updateProfile(
        name: _nameController.text.trim(),
        role: _roleController.text.trim(),
        email: _emailController.text.trim(),
        targetGoal: _selectedGoal,
        experienceLevel: _selectedLevel,
        targetIndustry: _selectedIndustry,
        feedbackTone: _selectedTone,
      );

      if (mounted) {
        AppToast.success(context, 'Profile details updated successfully');
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/profile');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to update profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleBackPress() async {
    final canLeave = await _onWillPop();
    if (canLeave && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/profile');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AppAtmosphere(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          'Edit Profile',
                          style: AppTextStyles.headingM.copyWith(
                            color: AppColors.textPrimaryOf(context),
                            fontSize: 18,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _handleBackPress,
                              icon: RotatedBox(
                                quarterTurns: 2,
                                child: AppIcon(
                                  AppIcons.chevronRight,
                                  color: AppColors.textPrimaryOf(context),
                                  size: 20,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const ThemeToggleButton(size: 40, compact: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 8.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GlassSurface(
                            padding: const EdgeInsets.all(16),
                            borderRadius: BorderRadius.circular(18),
                            gradient: isDark
                                ? LinearGradient(
                                    colors: [
                                      AppColors.primaryPurple
                                          .withValues(alpha: 0.22),
                                      AppColors.cardDark,
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      AppColors.primaryPurple
                                          .withValues(alpha: 0.1),
                                      AppColors.primaryPurpleLight
                                          .withValues(alpha: 0.05),
                                    ],
                                  ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const AppIcon(
                                    AppIcons.sparkles,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Personalize Your Pitch Coach',
                                        style: AppTextStyles.bodyM.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimaryOf(
                                              context),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tailor speech prompts, metrics, and coaching AI.',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondaryOf(
                                              context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          _buildSectionHeader(
                            'Basic Information',
                            AppIcons.person,
                          ),
                          const SizedBox(height: 12),

                          _buildTextFieldLabel('Full Name *'),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context)),
                            decoration: _buildInputDecoration(
                              'e.g. Dakshin',
                              AppIcons.person,
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Name is required'
                                    : null,
                          ),

                          const SizedBox(height: 14),

                          _buildTextFieldLabel('Current Role / Occupation'),
                          TextFormField(
                            controller: _roleController,
                            maxLength: 80,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context)),
                            decoration: _buildInputDecoration(
                              'e.g. Computer Science Student',
                              AppIcons.star,
                            ),
                            validator: (v) {
                              if (v != null && v.length > 80) {
                                return 'Role must be under 80 characters';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildTextFieldLabel('Email Address *'),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context)),
                            decoration: _buildInputDecoration(
                              'e.g. dakshin@example.com',
                              AppIcons.chat,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email is required';
                              }
                              final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(v.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          _buildSectionHeader(
                            'Pitch Goals & Target',
                            AppIcons.award,
                          ),
                          const SizedBox(height: 12),

                          _buildTextFieldLabel('Primary Objective'),
                          _buildDropdown(
                            value: _selectedGoal,
                            items: _goals,
                            onChanged: (val) =>
                                setState(() => _selectedGoal = val!),
                          ),

                          const SizedBox(height: 14),

                          _buildTextFieldLabel('Target Industry'),
                          _buildDropdown(
                            value: _selectedIndustry,
                            items: _industries,
                            onChanged: (val) =>
                                setState(() => _selectedIndustry = val!),
                          ),

                          const SizedBox(height: 14),

                          _buildTextFieldLabel('Speaking Experience Level'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _levels.map((level) {
                              final selected = _selectedLevel == level;
                              return ChoiceChip(
                                label: Text(level),
                                selected: selected,
                                selectedColor: AppColors.primaryPurple,
                                backgroundColor: AppColors.cardOf(context),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimaryOf(context),
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
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
                                    setState(() => _selectedLevel = level);
                                  }
                                },
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          _buildSectionHeader(
                            'AI Feedback Style',
                            AppIcons.mic,
                          ),
                          const SizedBox(height: 12),

                          _buildTextFieldLabel('Preferred Feedback Style'),
                          Column(
                            children: _tones.map((tone) {
                              final selected = _selectedTone == tone;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primaryPurple
                                          .withValues(alpha: isDark ? 0.18 : 0.08)
                                      : AppColors.cardOf(context),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primaryPurple
                                        : AppColors.borderOf(context),
                                    width: selected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _selectedTone = tone),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: selected
                                                  ? AppColors.primaryPurpleLight
                                                  : AppColors.textSecondaryOf(
                                                      context),
                                              width: 2,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(3),
                                          child: selected
                                              ? Container(
                                                  decoration: const BoxDecoration(
                                                    color: AppColors
                                                        .primaryPurpleLight,
                                                    shape: BoxShape.circle,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            tone,
                                            style: AppTextStyles.bodyM.copyWith(
                                              color: AppColors.textPrimaryOf(
                                                  context),
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 28),

                          GradientButton(
                            text: _isSaving ? 'Saving Changes...' : 'Save Profile Details',
                            variant: GradientButtonVariant.primary,
                            height: 54,
                            onPressed: _isSaving ? null : _saveProfile,
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, String iconName) {
    return Row(
      children: [
        AppIcon(iconName, color: AppColors.primaryPurpleLight, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.headingM.copyWith(
            fontSize: 16,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textPrimaryOf(context).withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, String iconName) {
    final border = AppColors.borderOf(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textSecondaryOf(context).withValues(alpha: 0.7),
        fontSize: 14,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(12.0),
        child: AppIcon(iconName, color: AppColors.primaryPurpleLight, size: 20),
      ),
      filled: true,
      fillColor: AppColors.cardOf(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.elevatedCardOf(context),
          icon: RotatedBox(
            quarterTurns: 1,
            child: AppIcon(
              AppIcons.chevronRight,
              color: AppColors.primaryPurpleLight,
              size: 18,
            ),
          ),
          style: AppTextStyles.bodyM.copyWith(
            color: AppColors.textPrimaryOf(context),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
