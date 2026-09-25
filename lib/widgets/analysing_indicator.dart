import 'package:flutter/material.dart';

import '../ai/ai_extractor.dart';
import '../theme/nook_colors.dart';
import '../theme/nook_motion.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// What Nook shows while it is working out what a link is.
///
/// The old version narrated the machinery: "Asking gemini-flash-latest",
/// "Gemini is busy — retrying in 4s (attempt 2 of 4)". That is a stack trace
/// with manners. Nobody pasting a TikTok link needs a vendor's name, a model
/// id or an HTTP retry schedule, and none of it helps them decide anything.
///
/// What it shows instead is three dots travelling along a line, left to right,
/// and one sentence. The line is Nook's own motif — the hairline under every
/// section heading — so the wait looks like part of the app rather than a
/// borrowed spinner. It is honest about progress in the only way it can be:
/// it does not pretend to know a percentage it cannot know.
class AnalysingIndicator extends StatefulWidget {
  const AnalysingIndicator({
    super.key,
    required this.phase,
    required this.seconds,
    this.onCancel,
  });

  final ExtractionPhase phase;

  /// Counted up so a slow analysis is visibly still running, rather than
  /// indistinguishable from a frozen screen.
  final int seconds;

  final VoidCallback? onCancel;

  /// One sentence per phase, in the user's terms.
  static String labelFor(ExtractionPhase phase) => switch (phase) {
    ExtractionPhase.readingPost => 'Reading the post…',
    ExtractionPhase.analysing => 'Analysing your post…',
    ExtractionPhase.finishing => 'Almost there…',
  };

  @override
  State<AnalysingIndicator> createState() => _AnalysingIndicatorState();
}

class _AnalysingIndicatorState extends State<AnalysingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              Expanded(
                child: AnimatedSwitcher(
                  duration: NookMotion.normal,
                  // Keyed on the phase, so the sentence cross-fades when the
                  // work moves on rather than changing under you.
                  child: Text(
                    AnalysingIndicator.labelFor(widget.phase),
                    key: ValueKey(widget.phase),
                    style: NookType.bodyStrong,
                  ),
                ),
              ),
              // Seconds, not a fake percentage. It is the one honest number
              // available: nothing here knows how long the model will take.
              Text('${widget.seconds}s', style: NookType.caption),
            ],
          ),
          const SizedBox(height: NookSpacing.section),
          SizedBox(
            height: 10,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _TravellingDots(progress: _controller.value),
                size: Size.infinite,
              ),
            ),
          ),
          if (widget.onCancel != null) ...[
            const SizedBox(height: NookSpacing.tight),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  'Cancel',
                  style: NookType.body.copyWith(color: NookColors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three dots crossing a hairline, one after another.
///
/// The hairline is the same one `NookRule` draws under every section heading,
/// which is what ties this to the rest of the app. The dots are spaced a third
/// of a cycle apart and fade in and out at the ends, so nothing pops.
class _TravellingDots extends CustomPainter {
  const _TravellingDots({required this.progress});

  final double progress;

  static const _dots = 3;
  static const _radius = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final midline = size.height / 2;

    canvas.drawLine(
      Offset(0, midline),
      Offset(size.width, midline),
      Paint()
        ..color = NookColors.border
        ..strokeWidth = 1,
    );

    final travel = size.width - _radius * 2;
    for (var i = 0; i < _dots; i++) {
      final t = (progress + i / _dots) % 1.0;
      // Fade at both ends so a dot arrives and leaves rather than appearing.
      final fade = (t < 0.12)
          ? t / 0.12
          : (t > 0.88)
          ? (1 - t) / 0.12
          : 1.0;

      canvas.drawCircle(
        Offset(_radius + travel * t, midline),
        _radius,
        Paint()..color = NookColors.primary.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_TravellingDots oldDelegate) =>
      oldDelegate.progress != progress;
}
