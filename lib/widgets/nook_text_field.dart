import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// Rounded white field, light grey border, warm charcoal text.
class NookTextField extends StatelessWidget {
  const NookTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.errorText,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: NookType.caption.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: NookSpacing.tight),
        ],
        Container(
          decoration: BoxDecoration(
            color: NookColors.surface,
            borderRadius: BorderRadius.circular(NookRadius.md),
            border: Border.all(
              color: errorText == null ? NookColors.border : NookColors.error,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            autofocus: autofocus,
            style: NookType.body,
            cursorColor: NookColors.primary,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: NookType.body.copyWith(color: NookColors.textMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: NookSpacing.section,
                vertical: 18,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: NookSpacing.tight),
          Text(
            errorText!,
            style: NookType.caption.copyWith(color: NookColors.error, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// The multiline note field, with the character counter the mockup draws in its
/// bottom-right corner.
///
/// Sized by [minLines] rather than by an [Expanded] inside a fixed-height box.
/// The earlier version put an `Expanded` in a Column with no bounded height —
/// these fields live inside scroll views — so the field collapsed to nothing and
/// the note could not be typed at all. Growing with its content is also the
/// right behaviour: a long note pushes the counter down instead of scrolling
/// inside a cramped box.
class NookNoteField extends StatelessWidget {
  const NookNoteField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLength = 500,
    this.minLines = 7,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int minLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: NookColors.border),
      ),
      padding: const EdgeInsets.all(NookSpacing.section),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: null,
            minLines: minLines,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: onChanged,
            style: NookType.body,
            cursorColor: NookColors.primary,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: NookType.body.copyWith(color: NookColors.textMuted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              // The design system's own counter is drawn below, so Material's
              // is switched off rather than shown twice.
              counterText: '',
            ),
          ),
          const SizedBox(height: NookSpacing.tight),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Text(
              '${value.text.characters.length}/$maxLength',
              style: NookType.caption.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded white pill with a search icon, and a clear button once typing starts.
class NookSearchBar extends StatelessWidget {
  const NookSearchBar({
    super.key,
    required this.controller,
    this.hint = 'Search saved posts...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.pill),
        border: Border.all(color: NookColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: NookSpacing.section),
          const Icon(Icons.search_rounded, size: 24, color: NookColors.textPrimary),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              autofocus: autofocus,
              readOnly: readOnly,
              onTap: onTap,
              style: NookType.body,
              cursorColor: NookColors.primary,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: NookType.body.copyWith(color: NookColors.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox(width: NookSpacing.section)
                : Padding(
                    padding: const EdgeInsets.only(right: NookSpacing.tight),
                    child: IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.cancel, size: 22),
                      color: NookColors.textMuted,
                      tooltip: 'Clear search',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
