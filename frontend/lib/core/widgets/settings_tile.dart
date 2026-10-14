import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

enum SettingsTileTrailing { chevron, toggle, value, badge, none }

/// Reusable settings row widget conforming to accessibility and design tokens.
class SettingsTile extends StatelessWidget {
  final String iconName;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final String? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDisabled;
  final bool showChevron;
  final Color? iconColor;
  final SettingsTileTrailing trailingType;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;

  const SettingsTile({
    super.key,
    String? iconName,
    String? leadingIcon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.badge,
    this.trailing,
    this.onTap,
    this.isLoading = false,
    this.isDisabled = false,
    this.showChevron = true,
    this.iconColor,
    this.trailingType = SettingsTileTrailing.chevron,
    this.toggleValue,
    this.onToggle,
  }) : iconName = iconName ?? leadingIcon ?? AppIcons.settings;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final effectiveIconColor =
        iconColor ??
        (isDark ? AppColors.primaryPurpleLight : AppColors.primaryPurple);

    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null) {
      if (trailingType == SettingsTileTrailing.toggle) {
        effectiveTrailing = Switch(
          value: toggleValue ?? false,
          activeThumbColor: AppColors.primaryPurple,
          activeTrackColor: AppColors.primaryPurple.withValues(alpha: 0.4),
          onChanged: isDisabled || isLoading ? null : onToggle,
        );
      }
    }

    return Semantics(
      button: onTap != null || onToggle != null,
      enabled: !isDisabled,
      label: '$title ${subtitle ?? ''}',
      child: InkWell(
        onTap: isDisabled || isLoading
            ? null
            : (trailingType == SettingsTileTrailing.toggle && onToggle != null
                  ? () => onToggle!(!(toggleValue ?? false))
                  : onTap),
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Box
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: AppIcon(
                      iconName,
                      size: 20,
                      color: isDisabled
                          ? AppColors.textSecondaryOf(context)
                          : effectiveIconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title + Subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyM.copyWith(
                                color: isDisabled
                                    ? AppColors.textSecondaryOf(
                                        context,
                                      ).withValues(alpha: 0.6)
                                    : AppColors.textPrimaryOf(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing slot
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.primaryPurple,
                      ),
                    ),
                  )
                else if (effectiveTrailing != null)
                  effectiveTrailing
                else ...[
                  if (trailingText != null)
                    Flexible(
                      child: Text(
                        trailingText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (showChevron &&
                      trailingType == SettingsTileTrailing.chevron &&
                      onTap != null) ...[
                    const SizedBox(width: 4),
                    AppIcon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: AppColors.textSecondaryOf(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
