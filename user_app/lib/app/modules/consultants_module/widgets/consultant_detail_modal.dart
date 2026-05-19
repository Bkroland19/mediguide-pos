import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/models/consultant.dart';
import '../../../data/extensions/enum_extensions.dart';
import '../../../utils/app_spacing.dart';
import '../../../utils/common.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/user_avatar.dart';
import '../../../widgets/section_group.dart';
import '../../../routes/app_pages.dart';
import '../../../data/services/backend_service.dart';

/// Clean full-screen consultant profile — Messenger-style header + grouped info sections.
class ConsultantDetailModal extends StatelessWidget {
  final Consultant consultant;

  const ConsultantDetailModal({super.key, required this.consultant});

  static Future<void> show(BuildContext context, Consultant consultant) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: ConsultantDetailModal(consultant: consultant),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final isActive = consultant.status.name == 'active';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('consultantDetails'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          // ── Profile header ──
          AppSpacing.gapMd,
          Center(
            child: Stack(
              children: [
                UserAvatar(name: consultant.name, radius: 40),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : cs.outlineVariant,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  consultant.name,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (consultant.isVerified) ...[
                  const SizedBox(width: 6),
                  Icon(LucideIcons.badgeCheck, size: 20, color: cs.primary),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              consultant.specialty?.displayName ?? 'General Practice',
              style: context.textTheme.bodyMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (consultant.organization.isNotEmpty) ...[
            const SizedBox(height: 2),
            Center(
              child: Text(
                consultant.organization,
                style: context.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],

          // ── Quick stats row ──
          AppSpacing.gapLg,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(
                label: '${consultant.yearsOfExperience.toStringAsFixed(0)} yrs',
                icon: LucideIcons.briefcase,
              ),
              if (consultant.rating > 0) ...[
                AppSpacing.hGapSm,
                _StatPill(
                  label: '${consultant.rating.toStringAsFixed(1)} ★',
                  icon: LucideIcons.star,
                ),
              ],
              AppSpacing.hGapSm,
              _StatPill(
                label: isActive ? 'Available' : 'Offline',
                icon: isActive ? LucideIcons.circle : LucideIcons.circleOff,
                color: isActive ? Colors.green : cs.error,
              ),
            ],
          ),

          // ── Start chat button ──
          AppSpacing.gapLg,
          AppButton(
            text: 'startChat'.tr,
            icon: LucideIcons.messageSquare,
            width: double.infinity,
            onPressed: () {
              Navigator.of(context).pop();
              _startChatWithConsultant();
            },
          ),

          // ── Contact & Location ──
          if (consultant.phone.isNotEmpty ||
              consultant.email.isNotEmpty ||
              consultant.city.isNotEmpty) ...[
            AppSpacing.gapLg,
            SectionGroup(
              title: 'contactLocation'.tr,
              items: [
                if (consultant.phone.isNotEmpty)
                  _InfoRow(
                    icon: LucideIcons.phone,
                    label: 'phone'.tr,
                    value: consultant.phone,
                  ),
                if (consultant.email.isNotEmpty)
                  _InfoRow(
                    icon: LucideIcons.mail,
                    label: 'email'.tr,
                    value: consultant.email,
                  ),
                if (consultant.city.isNotEmpty)
                  _InfoRow(
                    icon: LucideIcons.mapPin,
                    label: 'location'.tr,
                    value:
                        '${consultant.city}${consultant.region.isNotEmpty ? ', ${consultant.region}' : ''}, ${consultant.country}',
                  ),
              ],
            ),
          ],

          // ── Professional details ──
          if (consultant.licenseNumber.isNotEmpty ||
              consultant.certifications.isNotEmpty ||
              consultant.preferredLanguage != null) ...[
            AppSpacing.gapMd,
            SectionGroup(
              title: 'professionalInfo'.tr,
              items: [
                if (consultant.licenseNumber.isNotEmpty)
                  _InfoRow(
                    icon: LucideIcons.award,
                    label: 'licenseNumber'.tr,
                    value: consultant.licenseNumber,
                  ),
                if (consultant.certifications.isNotEmpty)
                  _InfoRow(
                    icon: LucideIcons.graduationCap,
                    label: 'certifications'.tr,
                    value: consultant.certifications,
                  ),
                if (consultant.preferredLanguage != null)
                  _InfoRow(
                    icon: LucideIcons.globe,
                    label: 'preferredLanguage'.tr,
                    value:
                        consultant.preferredLanguage?.displayName ?? 'English',
                  ),
              ],
            ),
          ],

          AppSpacing.gapXl,
        ],
      ),
    );
  }

  void _startChatWithConsultant() {
    if (!BackendService.to.supportsMessaging) {
      Common.quickToast(
        title: 'Chat Unavailable',
        description: BackendService.to.unsupportedCollectionWriteMessage(
          'messages',
        ),
      );
      return;
    }
    if (consultant.userAccount == null) {
      Common.quickToast(
        title: 'Chat Unavailable',
        description: 'This consultant is not available for chat at the moment.',
      );
      return;
    }
    Get.toNamed(AppRoutes.chatInterface, arguments: consultant.userAccount);
  }
}

/// Small stat pill for the quick stats row.
class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _StatPill({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label-value row inside SectionGroup.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          AppSpacing.hGapSm,
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
