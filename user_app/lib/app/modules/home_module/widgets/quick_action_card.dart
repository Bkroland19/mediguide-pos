import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/responsive.dart';
import '../../../widgets/glass_card.dart';

/// A card widget for displaying quick action buttons on the home page
class QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isEnabled;
  final bool useSolidBackground;

  const QuickActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.textColor,
    this.isEnabled = true,
    this.useSolidBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? context.theme.colorScheme.primary;

    final cardPadding = EdgeInsets.symmetric(
      horizontal: Responsive.horizontalPadding(context) * 0.75,
      vertical: Responsive.doubleValue(
        context,
        mobile: AppSpacing.xs,
        tablet: AppSpacing.sm,
        desktop: AppSpacing.sm,
      ),
    );

    final cardContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon container
        Container(
          padding: EdgeInsets.all(
            Responsive.doubleValue(
              context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            ),
          ),
          decoration: BoxDecoration(
            color: effectiveIconColor == Colors.white
                ? Colors.white.withValues(alpha: 0.2)
                : effectiveIconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              Responsive.doubleValue(
                context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: Responsive.iconSize(
              context,
              mobile: 20.0,
              tablet: 22.0,
              desktop: 24.0,
            ),
            color: effectiveIconColor,
          ),
        ),

        AppSpacing.sm.gap,
        // Title and description column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.fontSize(
                    context,
                    mobile: 14.0,
                    tablet: 15.0,
                    desktop: 16.0,
                  ),
                  color: isEnabled
                      ? (textColor ?? context.theme.colorScheme.onSurface)
                      : (textColor ?? context.theme.colorScheme.onSurface)
                            .withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              AppSpacing.xs.gap,
              // Description
              Flexible(
                child: Text(
                  subtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontSize: Responsive.fontSize(
                      context,
                      mobile: 12.0,
                      tablet: 13.0,
                      desktop: 14.0,
                    ),
                    color: isEnabled
                        ? (textColor?.withValues(alpha: 0.8) ??
                              context.theme.colorScheme.onSurfaceVariant)
                        : (textColor ?? context.theme.colorScheme.onSurface)
                              .withValues(alpha: 0.4),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: useSolidBackground
          ? Container(
              padding: cardPadding,
              decoration: BoxDecoration(
                color:
                    backgroundColor ??
                    context.theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: cardContent,
            )
          : GlassCard.compact(
              baseColor:
                  backgroundColor ?? context.theme.colorScheme.primaryContainer,
              padding: cardPadding,
              child: cardContent,
            ),
    );
  }
}

/// Specialized quick action cards for different actions
class QuickActionCards {
  /// Chat with consultant card
  static Widget consultant({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return QuickActionCard(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.messageCircle,
      onTap: onTap,
      isEnabled: isEnabled,
    );
  }

  /// Health infrastructure card
  static Widget healthInfrastructure({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return QuickActionCard(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.mapPin,
      onTap: onTap,
      isEnabled: isEnabled,
    );
  }

  /// Emergency contacts card
  static Widget emergencyContacts({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return QuickActionCard(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.phone,
      onTap: onTap,
      isEnabled: isEnabled,
    );
  }

  /// Drug index card
  static Widget drugIndex({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return QuickActionCard(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.pill,
      onTap: onTap,
      isEnabled: isEnabled,
    );
  }

  /// Blue Channel card (Primary guidelines)
  static Widget blueChannel({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return QuickActionCard(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.bookOpen,
      onTap: onTap,
      isEnabled: isEnabled,
      iconColor: Colors.white, // White icon
      textColor: Colors.white, // White text
      backgroundColor: const Color(0xFF1E3A8A), // Deep vibrant blue
      useSolidBackground: true, // Use solid background instead of glass effect
    );
  }

  /// Red Channel card (Emergency protocols)
  static Widget redChannel({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return QuickActionCard(
      title: title,
      subtitle: subtitle,
      icon: LucideIcons.bookOpen,
      onTap: onTap,
      isEnabled: isEnabled,
      iconColor: Colors.white, // White icon
      textColor: Colors.white, // White text
      backgroundColor: const Color(0xFFB91C1C), // Deep vibrant red
      useSolidBackground: true, // Use solid background instead of glass effect
    );
  }
}
