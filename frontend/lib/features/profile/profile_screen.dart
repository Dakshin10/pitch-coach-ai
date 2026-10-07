import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_atmosphere.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/theme_toggle_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  TimeOfDay? _reminderTime; // TimePicker (Unit 2)

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppAtmosphere(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Row — centered title
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Profile',
                      style: AppTextStyles.headingXL.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const ThemeToggleButton(size: 40, compact: true),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.push('/profile-setup'),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.glassOf(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderOf(context)),
                            ),
                            child: Icon(
                              Icons.settings_outlined,
                              size: 20,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Profile Header Card (Dynamic)
              _buildProfileHeaderCard(user),

              const SizedBox(height: 16),

              // 3. Stats Row
              _buildStatsRow(user),

              const SizedBox(height: 24),

              // 4. Account Section
              _buildSectionTitle('Account'),
              const SizedBox(height: 10),
              _buildSettingsCard([
                _buildListRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Personal Information',
                  trailingText: user.name,
                  onTap: () => context.push('/profile-setup'),
                ),
                const Divider(height: 1),
                _buildListRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notification Preferences',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _buildListRow(
                  icon: Icons.flag_outlined,
                  label: 'Practice Goals & Reminders',
                  // TimePicker-powered reminder row
                  trailingText: _reminderTime?.format(context),
                  onTap: _handleReminderTap,
                ),
                const Divider(height: 1),
                _buildListRow(
                  icon: Icons.star_outline_rounded,
                  label: 'Subscription / Upgrade to Pro',
                  badge: 'PRO',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 20),

              // 5.5. Learn Section — navigate to lesson library
              _buildSectionTitle('Learn'),
              const SizedBox(height: 10),
              _buildSettingsCard([
                _buildListRow(
                  icon: Icons.school_rounded,
                  label: 'Communication Lessons',
                  trailingText: '5 lessons',
                  onTap: () => context.push('/lessons'),
                ),
                const Divider(height: 1),
                _buildListRow(
                  icon: Icons.video_library_rounded,
                  label: 'Watch: Filler Word Reduction',
                  onTap: () => context.push('/lessons'),
                ),
              ]),

              const SizedBox(height: 20),

              // 6. Preferences Section
              _buildSectionTitle('Preferences'),
              const SizedBox(height: 10),
              _buildSettingsCard([
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dark_mode_outlined,
                            color: AppColors.primaryPurpleLight,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Dark Mode',
                            style: AppTextStyles.bodyM.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: userProvider.user.darkMode,
                        activeThumbColor: AppColors.primaryPurple,
                        activeTrackColor: AppColors.primaryPurple.withValues(alpha: 0.4),
                        onChanged: (val) {
                          userProvider.setDarkMode(val);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _buildListRow(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  trailingText: 'English',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 20),

              // 6. Support Section
              _buildSectionTitle('Support'),
              const SizedBox(height: 10),
              _buildSettingsCard([
                _buildListRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Help Center',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _buildListRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Send Feedback',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _buildListRow(
                  icon: Icons.thumb_up_alt_outlined,
                  label: 'Rate the App',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _buildListRow(
                  icon: Icons.info_outline_rounded,
                  label: 'About Pitch Coach',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 28),

              // 7. Log Out Button
              GradientButton(
                text: 'Log Out',
                variant: GradientButtonVariant.tertiary,
                borderColor: AppColors.dangerRed.withValues(alpha: 0.5),
                textColor: AppColors.dangerRed,
                height: 52,
                onPressed: () => _confirmLogout(context),
              ),

              const SizedBox(height: 16),

              // App Version Text
              Center(
                child: Text(
                  'Pitch Coach v1.4.2',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: 4, // Profile active
        onTap: (index) => _handleNavigation(context, index),
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  Widget _buildProfileHeaderCard(UserProfile user) {
    return GlassSurface(
      elevated: true,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      borderRadius: BorderRadius.circular(24),
      gradient: AppColors.isDark(context)
          ? LinearGradient(
              colors: [
                AppColors.primaryPurple.withValues(alpha: 0.22),
                AppColors.cardDarkElevated,
                AppColors.cardDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.auroraGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.4),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.name,
              style: AppTextStyles.headingL.copyWith(
                color: AppColors.textPrimaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              user.role.isEmpty ? 'Pitch Coach member' : user.role,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                width: 150,
                height: 40,
                child: OutlinedButton(
                  onPressed: () => context.push('/profile-setup'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.primaryPurple.withValues(alpha: 0.55),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Edit Profile',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryPurpleLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(UserProfile user) {
    return Row(
      children: [
        Expanded(child: _buildProfileStatTile('Sessions', '${user.sessionsCompleted}')),
        const SizedBox(width: 8),
        Expanded(child: _buildProfileStatTile('Avg Score', '${user.avgScore.toInt()}%')),
        const SizedBox(width: 8),
        Expanded(child: _buildProfileStatTile('Member Since', user.memberSince)),
      ],
    );
  }

  Widget _buildProfileStatTile(String label, String value) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headingM.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.5,
              color: AppColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.headingM.copyWith(
        fontSize: 16,
        color: AppColors.textPrimaryOf(context),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(18),
      child: Column(children: children),
    );
  }

  Widget _buildListRow({
    required IconData icon,
    required String label,
    String? badge,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(
                  alpha: AppColors.isDark(context) ? 0.2 : 0.1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryPurpleLight, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: AppTextStyles.bodyM.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryOf(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of Pitch Coach?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Provider.of<UserProvider>(context, listen: false).logout();
              context.go('/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/history');
        break;
      case 2:
        context.push('/interview');
        break;
      case 3:
        context.go('/progress');
        break;
      case 4:
        // Already on Profile
        break;
    }
  }

  /// Manage practice reminder: change time or disable (Unit 2).
  Future<void> _handleReminderTap() async {
    if (_reminderTime != null) {
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Practice Reminder',
                  style: AppTextStyles.headingM.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Currently set for ${_reminderTime!.format(context)} daily.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.access_time_rounded, color: AppColors.primaryPurple),
                  title: const Text('Change Reminder Time'),
                  onTap: () => Navigator.pop(ctx, 'change'),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined, color: AppColors.dangerRed),
                  title: const Text('Disable Reminder', style: TextStyle(color: AppColors.dangerRed)),
                  onTap: () => Navigator.pop(ctx, 'disable'),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted) return;
      if (action == 'disable') {
        await NotificationService.instance.cancelDailyReminder();
        if (!mounted) return;
        setState(() => _reminderTime = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Daily practice reminder disabled.'),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      } else if (action != 'change') {
        return;
      }
    }

    await _pickReminderTime();
  }

  /// Show TimePicker and schedule daily practice reminder (Unit 2).
  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimaryDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
    if (picked != null) {
      final formattedTime = picked.format(context);
      setState(() => _reminderTime = picked);
      // Schedule the daily notification
      await NotificationService.instance.scheduleDailyReminder(picked);
      // Confirm to the user with an instant notification
      await NotificationService.instance.showInstantNotification(
        '🔔 Reminder Set!',
        'You will be reminded to practice at $formattedTime daily.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Daily reminder set for $formattedTime ✅',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.primaryPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}
