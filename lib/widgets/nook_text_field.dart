import 'package:flutter/material.dart';

import 'tap_keeps_focus.dart';
import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// Rounded white field, light grey border, warm charcoal text.
///
/// A note on [autofocus], which no screen in Nook passes any more. The app is
/// drawn inside the preview, which scales it to fit the window, and a tap on a
/// field that *already* holds focus is resolved through that scale to place
/// the caret. Under the scale it resolves to nothing: the field loses focus,
/// typing goes nowhere, and tapping again does not bring it back — only
/// tapping somewhere else first does. A field that focuses itself on arrival
/// is therefore a field that the first, most natural tap kills, and every
/// form in the app worked that way. Left unfocused, the first tap focuses it
/// and everything behaves.
class NookTextField extends StatefulWidget {
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
  State<NookTextField> createState() => _NookTextFieldState();
}

class _NookTextFieldState extends State<NookTextField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final errorText = widget.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: NookType.caption.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: NookSpacing.tight),
        ],
        TapKeepsFocus(
          focusNode: _focus,
          child: Container(
            decoration: BoxDecoration(
              color: NookColors.surface,
              borderRadius: BorderRadius.circular(NookRadius.md),
              border: Border.all(
                color: errorText == null ? NookColors.border : NookColors.error,
              ),
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: widget.keyboardType,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              autofocus: widget.autofocus,
              style: NookType.body,
              cursorColor: NookColors.primary,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: NookType.body.copyWith(color: NookColors.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: NookSpacing.section,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: NookSpacing.tight),
          Text(
            errorText,
            style: NookType.caption.copyWith(color: NookColors.error),
          ),
        ],
      ],
    );
  }
}

/// The multiline note field, with the character counter the mockup draws in its
/// bottom-right corner.
///
/// Sized by [minLines], not by an [Expanded]: these fields live inside scroll
/// views, where a Column has no bounded height and the field would collapse to
/// nothing. Growing with its content is the right behaviour anyway — a long
/// note pushes the counter down instead of scrolling inside a cramped box.
class NookNoteField extends StatefulWidget {
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
  State<NookNoteField> createState() => _NookNoteFieldState();
}

class _NookNoteFieldState extends State<NookNoteField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapKeepsFocus(
      focusNode: _focus,
      child: Container(
        decoration: BoxDecoration(
          color: NookColors.surface,
          borderRadius: BorderRadius.circular(NookRadius.md),
          border: Border.all(color: NookColors.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: widget.controller,
              focusNode: _focus,
              maxLength: widget.maxLength,
              maxLines: null,
              minLines: widget.minLines,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: widget.onChanged,
              style: NookType.body,
              cursorColor: NookColors.primary,
              decoration: InputDecoration(
                hintText: widget.hint,
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
              valueListenable: widget.controller,
              builder: (context, value, _) => Text(
                '${value.text.characters.length}/${widget.maxLength}',
                style: NookType.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded white pill with a search icon, and a clear button once typing starts.
class NookSearchBar extends StatefulWidget {
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
  State<NookSearchBar> createState() => _NookSearchBarState();
}

class _NookSearchBarState extends State<NookSearchBar> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapKeepsFocus(
      focusNode: _focus,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: NookColors.surface,
          borderRadius: BorderRadius.circular(NookRadius.pill),
          border: Border.all(color: NookColors.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: NookSpacing.section),
            const Icon(
              Icons.search_rounded,
              size: 24,
              color: NookColors.textPrimary,
            ),
            const SizedBox(width: NookSpacing.tight),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                autofocus: widget.autofocus,
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                style: NookType.body,
                cursorColor: NookColors.primary,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: NookType.body.copyWith(
                    color: NookColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox(width: NookSpacing.section)
                  : Padding(
                      padding: const EdgeInsets.only(right: NookSpacing.tight),
                      child: IconButton(
                        onPressed: widget.onClear,
                        icon: const Icon(Icons.cancel, size: 22),
                        color: NookColors.textMuted,
                        tooltip: 'Clear search',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
