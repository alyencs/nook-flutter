import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import '../theme/trip_colors.dart';
import 'nook_buttons.dart';
import 'trip_color_picker.dart';
import 'nook_toast.dart';

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
            const SizedBox(height: NookSpacing.block),
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
/// What a trip was named and coloured.
class TripDraft {
  const TripDraft(this.name, this.colour);

  final String name;
  final TripColor colour;
}

/// Names a trip and picks its folder colour in one step.
///
/// The colour is chosen here rather than afterwards because choosing it is the
/// point: a trip you have to go back and recolour is one you will leave the
/// default. [initialName] and [initialColour] turn the same dialog into the
/// edit sheet, so there is one place that knows what a trip is made of.
Future<TripDraft?> showTripDialog(
  BuildContext context, {
  String? initialName,
  TripColor? initialColour,
}) async {
  final controller = TextEditingController(text: initialName ?? '');
  var colour = initialColour ?? TripColor.fallback;
  final editing = initialName != null;

  final draft = await showDialog<TripDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
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
              Text(editing ? 'Edit trip' : 'New trip', style: NookType.title),
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
                  onSubmitted: (value) => Navigator.of(context).pop(
                    value.trim().isEmpty
                        ? null
                        : TripDraft(value.trim(), colour),
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Japan 2027',
                    hintStyle: NookType.body.copyWith(
                      color: NookColors.textMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: NookSpacing.section,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NookSpacing.section),
              Text('Folder colour', style: NookType.caption),
              const SizedBox(height: NookSpacing.tight),
              TripColorPicker(
                selected: colour,
                onSelected: (next) => setState(() => colour = next),
              ),
              const SizedBox(height: NookSpacing.block),
              NookPrimaryButton(
                label: editing ? 'Save trip' : 'Create trip',
                onPressed: () {
                  final value = controller.text.trim();
                  Navigator.of(
                    context,
                  ).pop(value.isEmpty ? null : TripDraft(value, colour));
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
    ),
  );
  controller.dispose();
  return draft;
}

/// Shows a confirmation after the current route has been popped.
///
/// Takes an [OverlayState] resolved before the pop. The old version took a
/// `ScaffoldMessengerState` and waited 350ms, because a SnackBar raised in the
/// same frame as a pop is briefly parented by both the leaving and the arriving
/// Scaffold and Flutter asserts on the duplicate hero tag. [NookToast] lives in
/// the root overlay and belongs to no Scaffold, so there is nothing to collide
/// with and nothing to wait for.
void showToastAfterPop(OverlayState overlay, String message) {
  NookToast.show(overlay, message);
}
