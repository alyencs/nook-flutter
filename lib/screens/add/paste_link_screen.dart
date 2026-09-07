import 'dart:async';

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

  /// What extraction is doing right now, and for how long, so a slow call is
  /// visibly working rather than indistinguishable from a frozen screen.
  String? _stage;
  Timer? _ticker;
  int _elapsed = 0;

  /// Bumped on cancel so a late result from an abandoned run is ignored.
  int _attempt = 0;

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
    _ticker?.cancel();
    _url.dispose();
    super.dispose();
  }

  void _startProgress() {
    _elapsed = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  void _stopProgress() {
    _ticker?.cancel();
    _ticker = null;
    _stage = null;
  }

  /// Abandons the current run. The request itself cannot be recalled, but its
  /// result is discarded and the screen becomes usable again immediately. A
  /// fresh Analyze for the same link joins the request already in flight rather
  /// than starting a second one — see `GeminiExtractor.extract`.
  void _cancel() {
    setState(() {
      _attempt++;
      _busy = false;
      _stopProgress();
    });
  }

  Future<void> _analyze() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    // Enter in the field and the Analyze button both land here, and the error
    // card adds a third way in. The button disables itself while busy; this
    // covers the other two, so one link is never analysed twice at once.
    if (_busy) return;

    final attempt = ++_attempt;
    setState(() {
      _busy = true;
      _error = null;
      _stage = 'Starting';
      _startProgress();
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
      final result = await extractor.extract(
        url,
        onStage: (message) {
          if (mounted && attempt == _attempt) setState(() => _stage = message);
        },
      );
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _busy = false;
        _stopProgress();
      });
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetectedScreen(
            draft: PostDraft.fromLink(url: url, result: result),
          ),
        ),
      );
    } on ExtractionException catch (e) {
      // The guards matter: extraction takes seconds, and in that time the user
      // can leave the screen or cancel the run.
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _busy = false;
        _stopProgress();
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _busy = false;
        _stopProgress();
        _error = 'Something went wrong reading that link: $e';
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
            if (_busy) ...[
              const SizedBox(height: NookSpacing.section),
              _AnalysisProgress(
                stage: _stage ?? 'Working',
                seconds: _elapsed,
                onCancel: _cancel,
              ),
            ],
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
            const SizedBox(height: NookSpacing.block),
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

/// What extraction is doing, and for how long.
///
/// A bare spinner cannot be told apart from a frozen screen, and neither can be
/// escaped. This names the step, counts the seconds, and offers a way out.
class _AnalysisProgress extends StatelessWidget {
  const _AnalysisProgress({
    required this.stage,
    required this.seconds,
    required this.onCancel,
  });

  final String stage;
  final int seconds;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NookSpacing.section),
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: NookColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(NookColors.primary),
                ),
              ),
              const SizedBox(width: NookSpacing.tight),
              Expanded(
                child: Text('$stage…', style: NookType.bodyStrong),
              ),
              Text('${seconds}s', style: NookType.caption),
            ],
          ),
          const SizedBox(height: NookSpacing.tight),
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: NookColors.placeholder,
              valueColor: AlwaysStoppedAnimation(NookColors.primary),
            ),
          ),
          const SizedBox(height: NookSpacing.tight),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCancel,
              child: Text(
                'Cancel',
                style: NookType.body.copyWith(color: NookColors.primary),
              ),
            ),
          ),
        ],
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
