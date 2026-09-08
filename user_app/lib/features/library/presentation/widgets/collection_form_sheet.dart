import 'package:flutter/material.dart';
import 'package:user_app/core/constants/app_spacing.dart';

final class CollectionFormValue {
  const CollectionFormValue({required this.name, required this.description});

  final String name;
  final String description;
}

Future<CollectionFormValue?> showCollectionFormSheet(
  BuildContext context, {
  String initialName = '',
  String initialDescription = '',
}) {
  return showModalBottomSheet<CollectionFormValue>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _CollectionFormSheet(
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}

class _CollectionFormSheet extends StatefulWidget {
  const _CollectionFormSheet({
    required this.initialName,
    required this.initialDescription,
  });

  final String initialName;
  final String initialDescription;

  @override
  State<_CollectionFormSheet> createState() => _CollectionFormSheetState();
}

class _CollectionFormSheetState extends State<_CollectionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialName.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit collection' : 'Create collection',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            AppSpacing.gapMd,
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'For example: Diabetes care',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a collection name.'
                  : null,
            ),
            AppSpacing.gapSm,
            TextFormField(
              controller: _descriptionController,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What belongs in this collection?',
              ),
            ),
            AppSpacing.gapMd,
            FilledButton(
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(
                  context,
                  CollectionFormValue(
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim(),
                  ),
                );
              },
              child: Text(editing ? 'Save changes' : 'Create collection'),
            ),
          ],
        ),
      ),
    );
  }
}
