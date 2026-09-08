part of '../screens/publication_guideline_page.dart';

class _GuidelineOverview extends StatefulWidget {
  const _GuidelineOverview({
    required this.content,
    required this.isBookmarked,
    required this.currentSectionId,
    required this.readingProgress,
    required this.onRead,
    required this.onSection,
    required this.onOriginal,
  });

  final GuidelinePublicationContent content;

  final bool isBookmarked;

  final String? currentSectionId;

  final double? readingProgress;

  final VoidCallback onRead;

  final ValueChanged<String> onSection;

  final VoidCallback onOriginal;

  @override
  State<_GuidelineOverview> createState() => _GuidelineOverviewState();
}
