import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:user_app/features/guidelines/data/models/guideline_publication.dart';
import 'package:user_app/features/guidelines/presentation/widgets/publication_guideline_page_empty_section.dart';

void main() {
  Widget subject({
    required bool hasOriginal,
    List<PublicationSection> descendants = const [],
  }) => MaterialApp(
    home: Scaffold(
      body: PublicationEmptyReviewedSection(
        hasOriginalDocument: hasOriginal,
        reviewedDescendants: descendants,
        onSection: (_) {},
        onOpenOriginal: () {},
      ),
    ),
  );

  testWidgets('empty leaf does not offer an unavailable original', (
    tester,
  ) async {
    await tester.pumpWidget(subject(hasOriginal: false));
    expect(find.text('0 reviewed blocks'), findsOneWidget);
    expect(
      find.text('This section has not yet been published as reviewed content.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-original-document')), findsNothing);
  });

  testWidgets('empty leaf offers an available original document', (
    tester,
  ) async {
    await tester.pumpWidget(subject(hasOriginal: true));
    expect(
      find.text(
        'No approved structured content is available for this section.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('open-original-document')), findsOneWidget);
  });

  testWidgets('empty parent with reviewed descendants is a container', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        hasOriginal: false,
        descendants: const [
          PublicationSection(id: 'child', title: 'Reviewed child'),
        ],
      ),
    );
    expect(find.text('Reviewed content in this chapter'), findsOneWidget);
    expect(find.text('Reviewed child'), findsOneWidget);
    expect(find.text('0 reviewed blocks'), findsNothing);
  });
}
