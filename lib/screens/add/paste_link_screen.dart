import 'package:flutter/material.dart';

import '../../ai/ai_extractor.dart';
import '../../ai/platform_from_url.dart';
import '../../app_scope.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_text_field.dart';
import '../../widgets/section_header.dart';
import 'detected_screen.dart';
import 'post_draft.dart';

/// A2. Feature #1: paste a link, and the one call that reads it.
class PasteLinkScreen extends StatefulWidget {
  const PasteLinkScreen({super.key});

  @override
  State<PasteLinkScreen> createState() => _PasteLinkScreenState();
}

class _PasteLinkScreenState extends State<PasteLinkScreen> {
  final _url = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final extractor = AppScope.of(context).extractor;

    try {
      final result = await extractor.extract(url);
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetectedScreen(
            draft: PostDraft.fromLink(url: url, result: result),
          ),
        ),
      );
    } on ExtractionException catch (e) {
      // The guard matters: extraction takes seconds, and the user can leave.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong reading that link.';
      });
    }
  }

  void _enterManually() {
    final url = _url.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetectedScreen(
          draft: PostDraft.manual(url: url, title: _titleFromUrl(url)),
        ),
      ),
    );
  }

  static String _titleFromUrl(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    for (final segment in segments.reversed) {
      if (segment.contains('-')) {
        return segment
            .split('-')
            .where((word) => word.isNotEmpty)
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
      }
    }
    return 'Saved link';
  }

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: NookPrimaryButton(
        label: 'Analyze',
        busy: _busy,
        onPressed: _url.text.trim().isEmpty ? null : _analyze,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NookAppBar(title: 'Paste Link'),
            const SizedBox(height: NookSpacing.section),
            NookTextField(
              controller: _url,
              hint: 'Paste your link here...',
              keyboardType: TextInputType.url,
              autofocus: true,
              onSubmitted: (_) => _analyze(),
            ),
            if (_error != null) ...[
              const SizedBox(height: NookSpacing.section),
              _ExtractionError(
                message: _error!,
                onRetry: _analyze,
                onManual: _enterManually,
              ),
            ],
            if (!AppScope.of(context).extractor.isLive) ...[
              const SizedBox(height: NookSpacing.section),
              const _SampleModeNote(),
            ],
            const SizedBox(height: NookSpacing.screenEdge),
            const OverlineLabel('Supported platforms'),
            const SizedBox(height: NookSpacing.section),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final platform in NookPlatform.supported)
                  _PlatformBadge(
                    label: NookPlatform.label(platform),
                    active: NookPlatform.fromUrl(_url.text) == platform,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Says which extractor will run, before a link is spent finding out.
class _SampleModeNote extends StatelessWidget {
  const _SampleModeNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.science_outlined,
          size: 18,
          color: NookColors.textMuted,
        ),
        const SizedBox(width: NookSpacing.tight),
        Expanded(
          child: Text(
            'No API key found, so this will use sample details. Add '
            'GEMINI_API_KEY to .env for real extraction.',
            style: NookType.caption.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// The four circles under the field. The one matching what has been pasted
/// lights up, so the app confirms it recognised the link before you commit.
class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: active ? NookColors.secondary : NookColors.placeholder,
            shape: BoxShape.circle,
            border: active
                ? Border.all(color: NookColors.primary, width: 2)
                : null,
          ),
          child: active
              ? const Icon(Icons.check_rounded, color: NookColors.primary)
              : null,
        ),
        const SizedBox(height: NookSpacing.tight),
        Text(
          label,
          style: NookType.caption.copyWith(
            fontSize: 13,
            color: active ? NookColors.primary : NookColors.textMuted,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Extraction can fail — no network, a rejected key, an unreadable reply. When
/// it does, the flow is not a dead end: retry, or fill it in yourself.
class _ExtractionError extends StatelessWidget {
  const _ExtractionError({
    required this.message,
    required this.onRetry,
    required this.onManual,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NookSpacing.section),
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: NookColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: NookColors.error,
                size: 20,
              ),
              const SizedBox(width: NookSpacing.tight),
              Expanded(
                child: Text(
                  message,
                  style: NookType.body.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: NookSpacing.section),
          Row(
            children: [
              Expanded(
                child: NookSecondaryButton(label: 'Retry', onPressed: onRetry),
              ),
              const SizedBox(width: NookSpacing.tight),
              Expanded(
                child: NookSecondaryButton(
                  label: 'Enter manually',
                  onPressed: onManual,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
