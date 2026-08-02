import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile',
                    style: AppTextStyles.headingXL.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Profile Header Card
              _buildProfileHeaderCard(),

              const SizedBox(height: 16),

              // 3. Stats Row
              _buildStatsRow(),

              const SizedBox(height: 24),

              // 4. Account Section
              _buildSectionTitle('Account'),
              const SizedBox(height: 10),
              _buildSettingsCard([
                _buildListRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Personal Information',
                  onTap: () {},
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
                  onTap: () {},
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

              // 5. Preferences Section
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
                          const Icon(Icons.dark_mode_outlined, color: AppColors.primaryPurple, size: 22),
                          const SizedBox(width: 14),
                          Text('Dark Mode', style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Switch(
                        value: _darkModeEnabled,
                        activeThumbColor: AppColors.primaryPurple,
                        activeTrackColor: AppColors.primaryPurple.withValues(alpha: 0.4),
                        onChanged: (val) {
                          setState(() {
                            _darkModeEnabled = val;
                          });
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

  Widget _buildProfileHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'NS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dakshin',
            style: AppTextStyles.headingL,
          ),
          const SizedBox(height: 4),
          Text(
            'Computer Science Student',
            style: AppTextStyles.bodyM,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 140,
            height: 38,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryPurple.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                'Edit Profile',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildProfileStatTile('Sessions', '42')),
        const SizedBox(width: 8),
        Expanded(child: _buildProfileStatTile('Avg Score', '78%')),
        const SizedBox(width: 8),
        Expanded(child: _buildProfileStatTile('Member Since', 'Jan 2025')),
      ],
    );
  }

  Widget _buildProfileStatTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headingM.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.5,
              color: AppColors.textSecondary,
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
      style: AppTextStyles.headingM.copyWith(fontSize: 16),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
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
            Icon(icon, color: AppColors.primaryPurple, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
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
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of Pitch Coach?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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
}
