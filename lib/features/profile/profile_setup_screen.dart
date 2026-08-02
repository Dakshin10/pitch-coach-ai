import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_button.dart';

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

  String _selectedGoal = 'Technical Interviews & Pitch Presentations';
  String _selectedLevel = 'Intermediate';
  String _selectedIndustry = 'Software & Technology';
  String _selectedTone = 'Encouraging & Constructive';

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
    _nameController = TextEditingController(text: user.name);
    _roleController = TextEditingController(text: user.role);
    _emailController = TextEditingController(text: user.email);

    if (_goals.contains(user.targetGoal)) _selectedGoal = user.targetGoal;
    if (_levels.contains(user.experienceLevel)) _selectedLevel = user.experienceLevel;
    if (_industries.contains(user.targetIndustry)) _selectedIndustry = user.targetIndustry;
    if (_tones.contains(user.feedbackTone)) _selectedTone = user.feedbackTone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      Provider.of<UserProvider>(context, listen: false).updateProfile(
        name: _nameController.text.trim(),
        role: _roleController.text.trim(),
        email: _emailController.text.trim(),
        targetGoal: _selectedGoal,
        experienceLevel: _selectedLevel,
        targetIndustry: _selectedIndustry,
        feedbackTone: _selectedTone,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile details updated successfully!'),
          backgroundColor: AppColors.primaryPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        title: Text(
          'Profile Details',
          style: AppTextStyles.headingM.copyWith(color: AppColors.textPrimaryDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryPurple.withValues(alpha: 0.1),
                        AppColors.primaryPurpleLight.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalize Your Pitch Coach',
                              style: AppTextStyles.bodyM.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tailor your pitch practice sessions and feedback AI.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Basic Info Section
                _buildSectionHeader('Basic Information', Icons.person_outline_rounded),
                const SizedBox(height: 12),

                _buildTextFieldLabel('Full Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('e.g. Dakshin', Icons.badge_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                ),

                const SizedBox(height: 14),

                _buildTextFieldLabel('Current Role / Occupation'),
                TextFormField(
                  controller: _roleController,
                  decoration: _buildInputDecoration('e.g. Computer Science Student', Icons.work_outline_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your role' : null,
                ),

                const SizedBox(height: 14),

                _buildTextFieldLabel('Email Address'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildInputDecoration('e.g. dakshin@example.com', Icons.email_outlined),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Please enter a valid email' : null,
                ),

                const SizedBox(height: 24),

                // 2. Pitch Goals & Experience
                _buildSectionHeader('Pitch Goals & Target', Icons.ads_click_rounded),
                const SizedBox(height: 12),

                _buildTextFieldLabel('Primary Objective'),
                _buildDropdown(
                  value: _selectedGoal,
                  items: _goals,
                  onChanged: (val) => setState(() => _selectedGoal = val!),
                ),

                const SizedBox(height: 14),

                _buildTextFieldLabel('Target Industry'),
                _buildDropdown(
                  value: _selectedIndustry,
                  items: _industries,
                  onChanged: (val) => setState(() => _selectedIndustry = val!),
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
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimaryDark,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: selected ? AppColors.primaryPurple : AppColors.divider,
                        ),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedLevel = level);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // 3. AI Coaching Feedback Style
                _buildSectionHeader('AI Feedback Preference', Icons.psychology_outlined),
                const SizedBox(height: 12),

                _buildTextFieldLabel('Preferred Feedback Style'),
                Column(
                  children: _tones.map((tone) {
                    final selected = _selectedTone == tone;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AppColors.primaryPurple : AppColors.divider,
                          width: selected ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => setState(() => _selectedTone = tone),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: selected ? AppColors.primaryPurple : AppColors.textSecondary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tone,
                                  style: AppTextStyles.bodyM.copyWith(
                                    color: AppColors.textPrimaryDark,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

                // Save Profile Button
                GradientButton(
                  text: 'Save Profile Details',
                  variant: GradientButtonVariant.primary,
                  height: 54,
                  onPressed: _saveProfile,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.headingM.copyWith(fontSize: 16),
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
          color: AppColors.textPrimaryDark.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primaryPurple, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryPurple),
          style: AppTextStyles.bodyM.copyWith(color: AppColors.textPrimaryDark),
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
