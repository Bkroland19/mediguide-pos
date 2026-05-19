import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_spacing.dart';
import '../routes/app_pages.dart';

class CopyrightTermsWidget extends StatelessWidget {
  const CopyrightTermsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '© ${DateTime.now().year} By Gother Technologies(U) Ltd',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Get.toNamed(AppRoutes.termsAndConditions),
              style: TextButton.styleFrom(
                padding: AppSpacing.hPaddingSm,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'termsOfService'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            Text(
              ' • ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: () => Get.toNamed(AppRoutes.termsAndConditions),
              style: TextButton.styleFrom(
                padding: AppSpacing.hPaddingSm,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'privacyPolicy'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
