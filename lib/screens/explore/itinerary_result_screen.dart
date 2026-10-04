import 'dart:async';

import 'package:flutter/material.dart';

import '../../ai/ai_extractor.dart';
import '../../ai/itinerary.dart';
import '../../ai/itinerary_generator.dart';
import '../../app_scope.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/analysing_indicator.dart';
import '../../widgets/metadata_chip.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_card.dart';
import '../../widgets/nook_rule.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/screen_title.dart';

/// The itinerary, once there is one.
///
/// Generation runs here rather than on the screen before it, so the wait has
/// somewhere to live and the result has somewhere to come back to. Three
/// states and nothing else: working, a failure with a way out, or the days.
class ItineraryResultScreen extends StatefulWidget {
  const ItineraryResultScreen({super.key, required this.request});

  final ItineraryRequest request;

  @override
  State<ItineraryResultScreen> createState() => _ItineraryResultScreenState();
}

class _ItineraryResultScreenState extends State<ItineraryResultScreen> {
  GeneratedItinerary? _itinerary;
  String? _error;
  bool _busy = false;

  /// Which of the three phases the generator last reported.
  ItineraryPhase _phase = ItineraryPhase.readingSaves;

  Timer? _ticker;
  int _elapsed = 0;

  /// Bumped on every run, so a reply from a run the traveller has already
  /// moved past is dropped rather than painted over the newer one.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
  }

  Future<void> _run() async {
    // Covers the button, a second tap on Regenerate, and the error card's own
    // retry: one plan is never built twice at once.
    if (_busy) return;
    if (!mounted) return;

    final attempt = ++_attempt;
    setState(() {
      _busy = true;
      _error = null;
      _phase = ItineraryPhase.readingSaves;
      _startProgress();
    });

    final generator = AppScope.of(context).itinerary;

    try {
      final itinerary = await generator.generate(
        widget.request,
        onStage: (phase) {
          if (mounted && attempt == _attempt) setState(() => _phase = phase);
        },
      );
      // The traveller can leave, or ask again, during a generation that takes
      // seconds. Both are checked before anything is painted.
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _busy = false;
        _itinerary = itinerary;
        _stopProgress();
      });
    } on ItineraryException catch (e) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _busy = false;
        _error = e.message;
        _stopProgress();
      });
    } catch (_) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _busy = false;
        _error =
            "We couldn't build an itinerary right now. Please try again, or "
            'change the number of days.';
        _stopProgress();
      });
    }
  }

  /// Abandons the run on screen. The request itself cannot be recalled, but its
  /// result is discarded and the screen becomes usable again at once.
  void _cancel() {
    setState(() {
      _attempt++;
      _busy = false;
      _stopProgress();
      _error ??= 'Planning cancelled.';
    });
  }

  String get _label => switch (_phase) {
    ItineraryPhase.readingSaves => 'Reading your saved posts…',
    ItineraryPhase.planning => 'Planning your days…',
    ItineraryPhase.finishing => 'Almost there…',
  };

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final itinerary = _itinerary;

    return NookScaffold(
      bottomBar: itinerary == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NookPrimaryButton(
                  label: 'Regenerate',
                  icon: Icons.refresh_rounded,
                  busy: _busy,
                  onPressed: _run,
                ),
                const SizedBox(height: NookSpacing.tight),
                NookSecondaryButton(
                  label: 'Change number of days',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
      child: ListView(
        children: [
          const NookAppBar(title: 'Itinerary'),
          const SizedBox(height: NookSpacing.section),
          ScreenTitle(request.destination),
          const SizedBox(height: NookSpacing.tight),
          Wrap(
            spacing: NookSpacing.tight,
            runSpacing: NookSpacing.tight,
            children: [
              MetadataChip(
                '${request.days} ${request.days == 1 ? 'day' : 'days'}',
                icon: Icons.schedule_rounded,
              ),
              MetadataChip(
                'from ${request.sources.length} saved',
                icon: Icons.bookmark_outline_rounded,
              ),
              if (itinerary != null)
                MetadataChip(
                  '${itinerary.activityCount} things to do',
                  icon: Icons.place_outlined,
                ),
            ],
          ),
          const SizedBox(height: NookSpacing.block),

          if (_busy)
            AnalysingIndicator(
              phase: ExtractionPhase.analysing,
              label: _label,
              seconds: _elapsed,
              onCancel: _cancel,
            ),

          if (!_busy && _error != null) _PlanError(message: _error!, onRetry: _run),

          if (itinerary != null) ...[
            if (itinerary.overview != null) ...[
              Text(
                itinerary.overview!,
                style: NookType.body.copyWith(
                  color: NookColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: NookSpacing.block),
            ],
            if (itinerary.isSample) ...[
              const _SampleNotice(),
              const SizedBox(height: NookSpacing.block),
            ],
            for (final day in itinerary.days) ...[
              RuledLabel('Day ${day.day}'),
              const SizedBox(height: NookSpacing.tight),
              Text(
                day.title,
                style: NookType.title,
              ),
              const SizedBox(height: NookSpacing.section),
              for (final activity in day.activities) ...[
                _ActivityCard(activity: activity),
                const SizedBox(height: NookSpacing.tight),
              ],
              const SizedBox(height: NookSpacing.section),
            ],
          ],

          const SizedBox(height: NookSpacing.section),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final ItineraryActivity activity;

  @override
  Widget build(BuildContext context) {
    return NookCard(
      padding: const EdgeInsets.all(NookSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3, right: 10),
                child: SizedBox(width: 14, child: NookRule(opacity: 0.9)),
              ),
              Expanded(
                child: Text(activity.title, style: NookType.bodyStrong),
              ),
            ],
          ),
          if (activity.description.isNotEmpty) ...[
            const SizedBox(height: NookSpacing.tight),
            Text(
              activity.description,
              style: NookType.body.copyWith(
                color: NookColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
          if (activity.location != null || activity.timing != null) ...[
            const SizedBox(height: NookSpacing.tight),
            Wrap(
              spacing: NookSpacing.tight,
              runSpacing: 6,
              children: [
                if (activity.location != null)
                  MetadataChip(
                    activity.location!,
                    icon: Icons.place_outlined,
                  ),
                if (activity.timing != null)
                  MetadataChip(
                    activity.timing!,
                    icon: Icons.schedule_rounded,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when the plan was arranged locally rather than written by a model.
class _SampleNotice extends StatelessWidget {
  const _SampleNotice();

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
            'This build has no AI key, so Nook ordered your saved posts into '
            'days itself rather than writing them up. Running Nook locally '
            'with a key plans the trip for real.',
            style: NookType.caption,
          ),
        ),
      ],
    );
  }
}

/// A failure with both ways out: ask again, or go back and ask for a different
/// number of days.
class _PlanError extends StatelessWidget {
  const _PlanError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              Expanded(child: Text(message, style: NookType.body)),
            ],
          ),
          const SizedBox(height: NookSpacing.section),
          NookSecondaryButton(label: 'Try Again', onPressed: onRetry),
          const SizedBox(height: NookSpacing.tight),
          NookSecondaryButton(
            label: 'Change number of days',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
