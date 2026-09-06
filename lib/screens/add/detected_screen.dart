import 'package:flutter/material.dart';

import '../../ai/categories.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/section_header.dart';
import 'choose_trip_screen.dart';
import 'post_draft.dart';

/// A3. Feature #2's result, and the chance to correct it.
///
/// The destination is a text field rather than a label on purpose: the
/// proposal's second risk is that extraction comes back with a country instead
/// of a city, or nothing at all. Typing over it is a normal thing to do here,
/// not an error path.
class DetectedScreen extends StatefulWidget {
  const DetectedScreen({super.key, required this.draft});

  final PostDraft draft;

  @override
  State<DetectedScreen> createState() => _DetectedScreenState();
}

class _DetectedScreenState extends State<DetectedScreen> {
  late final TextEditingController _destination =
      TextEditingController(text: widget.draft.destination ?? '');
  late String _category = widget.draft.category ?? NookCategories.fallback;

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  void _continue() {
    final typed = _destination.text.trim();
    widget.draft
      ..destination = typed.isEmpty ? null : typed
      ..category = _category;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChooseTripScreen(draft: widget.draft)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final others =
        NookCategories.all.where((c) => c != _category).toList(growable: false);

    return NookScaffold(
      bottomBar: NookPrimaryButton(label: 'Continue', onPressed: _continue),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NookAppBar(title: 'Destination & Category'),
            const SizedBox(height: NookSpacing.section),
            const OverlineLabel('Detected destination'),
            const SizedBox(height: NookSpacing.tight),
            _DestinationField(controller: _destination),
            const SizedBox(height: NookSpacing.tight),
            Text(
              'Category: $_category',
              style: NookType.body.copyWith(color: NookColors.textMuted),
            ),
            if (widget.draft.fromSample) ...[
              const SizedBox(height: NookSpacing.section),
              const _SampleNotice(),
            ],
            const SizedBox(height: NookSpacing.screenEdge),
            const OverlineLabel('Or choose another:'),
            const SizedBox(height: NookSpacing.section),
            Wrap(
              spacing: NookSpacing.tight,
              runSpacing: NookSpacing.tight,
              children: [
                for (final category in others)
                  SelectableChip(
                    label: category,
                    selected: false,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationField extends StatelessWidget {
  const _DestinationField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: NookColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: NookSpacing.section),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: NookType.bodyStrong.copyWith(fontSize: 18),
              cursorColor: NookColors.primary,
              decoration: InputDecoration(
                hintText: 'No destination detected — add one',
                hintStyle: NookType.body.copyWith(color: NookColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Icon(
              value.text.trim().isEmpty
                  ? Icons.edit_outlined
                  : Icons.check_rounded,
              color: value.text.trim().isEmpty
                  ? NookColors.textMuted
                  : NookColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the values came from the sample extractor.
///
/// The deployed build has no Gemini key — a billable key must never ship in a
/// public web app — so it says so here rather than passing invented metadata
/// off as a real extraction.
class _SampleNotice extends StatelessWidget {
  const _SampleNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NookSpacing.section),
      decoration: BoxDecoration(
        color: NookColors.secondary,
        borderRadius: BorderRadius.circular(NookRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: NookColors.primary,
          ),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: Text(
              'Sample data — this build ships without an AI key, so the '
              'details above are illustrative. Running Nook locally with a '
              'Gemini key extracts them for real.',
              style: NookType.caption.copyWith(
                fontSize: 13,
                color: NookColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
