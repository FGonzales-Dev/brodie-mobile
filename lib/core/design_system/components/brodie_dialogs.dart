import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';
import 'brodie_button.dart';

/// Asks the user to confirm an action. Resolves to false when dismissed.
Future<bool> showBrodieConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title.toUpperCase()),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(BrodieSpace.lg, 0, BrodieSpace.lg, BrodieSpace.lg),
      actions: [
        Row(
          children: [
            Expanded(
              child: BrodieButton.secondary(
                label: 'Cancel',
                compact: true,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ),
            const SizedBox(width: BrodieSpace.sm),
            Expanded(
              child: BrodieButton(
                label: confirmLabel,
                compact: true,
                variant: destructive ? BrodieButtonVariant.danger : BrodieButtonVariant.primary,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<T?> showBrodieSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: true, builder: builder);
}

/// Bottom-sheet form with a title and a save button. Saving validates the
/// fields, then closes the sheet with [onSave]'s result.
class BrodieFormSheet<T> extends StatefulWidget {
  const BrodieFormSheet({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.saveLabel = 'Save',
  });

  final String title;
  final List<Widget> fields;
  final T Function() onSave;
  final String saveLabel;

  @override
  State<BrodieFormSheet<T>> createState() => _BrodieFormSheetState<T>();
}

class _BrodieFormSheetState<T> extends State<BrodieFormSheet<T>> {
  final _formKey = GlobalKey<FormState>();

  void _save() {
    if (_formKey.currentState!.validate()) Navigator.of(context).pop(widget.onSave());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BrodieSpace.md, BrodieSpace.sm, BrodieSpace.md, BrodieSpace.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: BrodieType.headline.copyWith(color: context.colors.textPrimary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              for (final field in widget.fields) ...[const SizedBox(height: BrodieSpace.sm), field],
              const SizedBox(height: BrodieSpace.lg),
              BrodieButton(label: widget.saveLabel, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
