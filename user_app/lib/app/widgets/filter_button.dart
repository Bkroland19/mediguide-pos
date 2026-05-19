import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Reusable filter button that shows different icons based on filter state
/// Displays search icon when no filters are active, filter icon when active
/// Optionally shows a reset (X) button when filters are active and onReset is provided
class FilterButton extends StatelessWidget {
  /// Reactive boolean indicating if filters are currently active
  final RxBool hasActiveFilters;

  /// Callback when button is pressed
  final VoidCallback onPressed;

  /// Optional callback to reset filters
  final VoidCallback? onReset;

  /// Tooltip text for the button
  final String? tooltip;

  const FilterButton({
    super.key,
    required this.hasActiveFilters,
    required this.onPressed,
    this.onReset,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(LucideIcons.search),
            onPressed: onPressed,
            tooltip: tooltip,
          ),
          if (hasActiveFilters.value && onReset != null)
            IconButton(
              icon: Icon(LucideIcons.x, color: context.theme.colorScheme.error),
              onPressed: onReset,
              tooltip: 'Reset filters',
            ),
        ],
      ),
    );
  }
}
