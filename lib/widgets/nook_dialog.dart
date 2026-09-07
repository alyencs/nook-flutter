import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'nook_buttons.dart';

/// White rounded modal. Destructive confirmations use Soft Red; everything else
/// uses Burnt Orange.
Future<bool> showNookDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: NookColors.surface,
      insetPadding: const EdgeInsets.all(NookSpacing.screenEdge),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NookRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NookSpacing.screenEdge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: NookType.title),
            const SizedBox(height: NookSpacing.tight),
            Text(
              message,
              style: NookType.body.copyWith(color: NookColors.textMuted),
            ),
            const SizedBox(height: NookSpacing.screenEdge),
            if (destructive)
              NookSecondaryButton(
                label: confirmLabel,
                destructive: true,
                icon: Icons.delete_outline_rounded,
                onPressed: () => Navigator.of(context).pop(true),
              )
            else
              NookPrimaryButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            const SizedBox(height: NookSpacing.tight),
            NookSecondaryButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// The "Create New Trip" prompt on the Choose Trip screen.
Future<String?> showCreateTripDialog(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: NookColors.surface,
      insetPadding: const EdgeInsets.all(NookSpacing.screenEdge),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NookRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NookSpacing.screenEdge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create New Trip', style: NookType.title),
            const SizedBox(height: NookSpacing.section),
            Container(
              decoration: BoxDecoration(
                color: NookColors.surface,
                borderRadius: BorderRadius.circular(NookRadius.md),
                border: Border.all(color: NookColors.border),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                style: NookType.body,
                cursorColor: NookColors.primary,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (value) =>
                    Navigator.of(context).pop(value.trim().isEmpty ? null : value.trim()),
                decoration: InputDecoration(
                  hintText: 'e.g. Japan 2027',
                  hintStyle: NookType.body.copyWith(color: NookColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: NookSpacing.section,
                    vertical: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: NookSpacing.screenEdge),
            NookPrimaryButton(
              label: 'Create Trip',
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(context).pop(value.isEmpty ? null : value);
              },
            ),
            const SizedBox(height: NookSpacing.tight),
            NookSecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
  return name;
}

/// Shows a confirmation once the current route transition has finished.
///
/// A SnackBar raised in the same frame as a pop is briefly parented by both the
/// leaving and the arriving Scaffold, and Flutter asserts on the duplicate hero
/// tag that creates. The messenger is app-level, so waiting costs nothing.
Future<void> showSnackBarAfterPop(
  ScaffoldMessengerState messenger,
  String message,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
