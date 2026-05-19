import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/models/models.dart';
import '../../utils/app_spacing.dart';
import '../../widgets/section_group.dart';

class HealthFacilityDetailPage extends StatelessWidget {
  const HealthFacilityDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final HealthFacility facility = Get.arguments as HealthFacility;
    final cs = context.theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(facility.name)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        children: [
          // Quick info chips
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _InfoChip(
                icon: LucideIcons.building2,
                label: facility.facilityLevelName.isEmpty
                    ? 'Unknown Level'
                    : facility.facilityLevelName,
                color: cs.primary,
              ),
              _InfoChip(
                icon: LucideIcons.users,
                label: facility.ownershipDisplay,
                color: cs.secondary,
              ),
              if (facility.authorityName.isNotEmpty)
                _InfoChip(
                  icon: LucideIcons.shield,
                  label: facility.authorityName,
                  color: cs.tertiary,
                ),
            ],
          ),

          AppSpacing.gapLg,

          // Location section
          if (_hasLocationData(facility))
            SectionGroup(
              title: 'Location',
              items: [
                if (facility.regionName.isNotEmpty)
                  _DetailRow(label: 'Region', value: facility.regionName),
                if (facility.districtName.isNotEmpty)
                  _DetailRow(label: 'District', value: facility.districtName),
                if (facility.countyName.isNotEmpty)
                  _DetailRow(label: 'County', value: facility.countyName),
                if (facility.subcountyName.isNotEmpty)
                  _DetailRow(
                    label: 'Sub-county',
                    value: facility.subcountyName,
                  ),
                if (facility.parishName.isNotEmpty)
                  _DetailRow(label: 'Parish', value: facility.parishName),
              ],
            ),

          if (_hasLocationData(facility)) AppSpacing.gapMd,

          // Facility codes section
          if (facility.nhpiCode.isNotEmpty || facility.hsdtCode.isNotEmpty)
            SectionGroup(
              title: 'Facility Codes',
              items: [
                if (facility.nhpiCode.isNotEmpty)
                  _DetailRow(
                    label: 'NHPI Code',
                    value: facility.nhpiCode,
                    mono: true,
                  ),
                if (facility.hsdtCode.isNotEmpty)
                  _DetailRow(
                    label: 'HSDT Code',
                    value: facility.hsdtCode,
                    mono: true,
                  ),
              ],
            ),

          if (facility.nhpiCode.isNotEmpty || facility.hsdtCode.isNotEmpty)
            AppSpacing.gapMd,

          // Admin info
          SectionGroup(
            title: 'Administrative Info',
            items: [
              _DetailRow(
                label: 'Created',
                value: _formatDate(facility.created),
              ),
              _DetailRow(
                label: 'Updated',
                value: _formatDate(facility.updated),
              ),
            ],
          ),

          AppSpacing.gapLg,
        ],
      ),
    );
  }

  bool _hasLocationData(HealthFacility facility) =>
      facility.regionName.isNotEmpty ||
      facility.districtName.isNotEmpty ||
      facility.countyName.isNotEmpty ||
      facility.subcountyName.isNotEmpty ||
      facility.parishName.isNotEmpty;

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}

/// Small colored chip for quick info display.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label-value row for detail sections inside SectionGroup.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
