import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class BottomNavBarItemData {
  final IconData icon;
  final String label;

  const BottomNavBarItemData({
    required this.icon,
    required this.label,
  });
}

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onMicTap;

  static const List<BottomNavBarItemData> items = [
    BottomNavBarItemData(icon: Icons.home_rounded, label: 'Home'),
    BottomNavBarItemData(icon: Icons.history_rounded, label: 'History'),
    BottomNavBarItemData(icon: Icons.mic_rounded, label: 'Practice'), // Center slot placeholder
    BottomNavBarItemData(icon: Icons.insights_rounded, label: 'Progress'),
    BottomNavBarItemData(icon: Icons.person_rounded, label: 'Profile'),
  ];

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Main Navigation Bar container
        Container(
          height: 76,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardDark.withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.cardLightBorder,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? AppColors.primaryPurple.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, items[0]),
              _buildNavItem(1, items[1]),
              // Center spacing for elevated FAB
              const SizedBox(width: 56),
              _buildNavItem(3, items[3]),
              _buildNavItem(4, items[4]),
            ],
          ),
        ),

        // Floating Center Mic FAB
        Positioned(
          top: -24,
          child: GestureDetector(
            onTap: onMicTap ?? () => onTap(2),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: AppColors.textOnDark,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, BottomNavBarItemData item) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primaryPurple : AppColors.textSecondary;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
