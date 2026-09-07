import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/ai_extractor.dart';
import '../../ai/platform_from_url.dart';
import '../../app_scope.dart';
import '../../data/daos/settings_dao.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_text_field.dart';
import '../../widgets/platform_badge.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromClipboard());
  }

  /// "Paste detection" in Settings: if the clipboard already holds a link,
  /// put it in the field so the screen is one tap from analysing.
  Future<void> _prefillFromClipboard() async {
    final settings = AppScope.of(context).settings;
    if (!await settings.isEnabled(NookSettings.pasteDetection)) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final uri = Uri.tryParse(text);
      final isLink = uri != null && uri.hasScheme && uri.host.isNotEmpty;
      if (!mounted || !isLink || _url.text.isNotEmpty) return;
      _url.text = text;
    } catch (_) {
      // Browsers can refuse clipboard reads without a user gesture. Not being
      // able to prefill is not an error worth showing.
    }
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

    final scope = AppScope.of(context);
    final extractor = scope.extractor;

    // "Auto-categorize saves" off means no extraction at all: straight to the
    // fields with nothing filled in, for anyone who would rather type it.
    if (!await scope.settings.isEnabled(NookSettings.autoCategorize)) {
      if (!mounted) return;
      setState(() => _busy = false);
      _enterManually();
      return;
    }

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
              children: [
                // Equal shares rather than natural widths: the labels are
                // wider than the circles, so a plain Row overflows on a narrow
                // screen.
                for (final platform in NookPlatform.supported)
                  Expanded(
                    child: _PlatformBadge(
                      platform: platform,
                      active: NookPlatform.fromUrl(_url.text) == platform,
                    ),
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
            style: NookType.caption,
          ),
        ),
      ],
    );
  }
}

/// The four circles under the field, each with its platform's mark.
///
/// The one matching what has been pasted lights up, so the app confirms it
/// recognised the link before you commit.
class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.platform, required this.active});

  final String platform;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlatformAvatar(platform: platform, active: active),
        const SizedBox(height: NookSpacing.tight),
        Text(
          NookPlatform.label(platform),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: NookType.caption.copyWith(
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
                  style: NookType.body,
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
