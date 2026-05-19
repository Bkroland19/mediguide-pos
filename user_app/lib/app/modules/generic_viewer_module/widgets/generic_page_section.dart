import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/generic_page.dart';
import '../../../utils/app_spacing.dart';
import '../../../widgets/html_styles.dart';

class GenericPageSectionWidget extends StatelessWidget {
  final GenericPageSection section;

  const GenericPageSectionWidget({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    if (section.content.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.fileText,
              size: 20,
              color: context.theme.colorScheme.primary,
            ),
            AppSpacing.sm.gap,
            Expanded(
              child: Text(
                section.title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.md.gap,
        Html(data: section.content, style: HtmlStyles.content(context)),
        AppSpacing.lg.gap,
      ],
    );
  }
}
