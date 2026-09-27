import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';

/// The Nook mark assembling from its own four quarters.
///
/// The mark is a 2×2 grid of tiles, so it takes itself apart along lines that
/// are already there — no pieces are invented for the sake of the animation.
/// Each quarter flies in from the direction it belongs to (the top-left one
/// from the top left, and so on), so the motion reads as things returning to
/// where they go rather than swirling.
///
/// They arrive 90ms apart. Simultaneous would be a scale-up wearing a costume;
/// the stagger is what makes it four objects instead of one.
///
/// Plays once, on mount. [onComplete] fires when the mark is whole, so the
/// screen underneath can bring in its own content afterwards.
class LogoAssembly extends StatefulWidget {
  const LogoAssembly({super.key, this.size = 116, this.onComplete});

  final double size;
  final VoidCallback? onComplete;

  /// The whole sequence, from first piece leaving to last piece landing.
  static const duration = Duration(milliseconds: 1500);

  @override
  State<LogoAssembly> createState() => _LogoAssemblyState();
}

class _LogoAssemblyState extends State<LogoAssembly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LogoAssembly.duration,
  );

  /// Where each quarter starts, in multiples of the mark's own size, which beat
  /// it arrives on, and the letter it carries.
  ///
  /// Order is reading order: top-left, top-right, bottom-left, bottom-right.
  static const _pieces = [
    (dx: -2.4, dy: -1.6, delay: 0.00, glyph: 'N'),
    (dx: 2.4, dy: -1.9, delay: 0.09, glyph: 'O'),
    (dx: -2.1, dy: 2.2, delay: 0.18, glyph: 'O'),
    (dx: 2.6, dy: 1.7, delay: 0.27, glyph: 'K'),
  ];

  /// The share of the timeline each piece gets. 0.27 + 0.55 < 1, so the last
  /// piece lands before the controller finishes.
  static const _span = 0.55;

  @override
  void initState() {
    super.initState();
    // catchError, because a controller disposed mid-flight completes this
    // future with TickerCanceled, which is otherwise an unhandled rejection.
    _controller
        .forward()
        .whenComplete(() {
          if (mounted) widget.onComplete?.call();
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          children: [
            for (var i = 0; i < _pieces.length; i++) _quarter(i),
          ],
        ),
      ),
    );
  }

  Widget _quarter(int index) {
    final piece = _pieces[index];
    final half = widget.size / 2;
    final gap = widget.size * 0.05;
    final tile = half - gap / 2;

    // Each piece runs over its own slice of the timeline, starting on its beat.
    final t = ((_controller.value - piece.delay) / _span).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);

    final dx = piece.dx * widget.size * (1 - eased);
    final dy = piece.dy * widget.size * (1 - eased);
    // A part-turn that unwinds as it lands, so the pieces tumble rather than
    // slide. Alternating direction stops them looking like one rotating body.
    final spin = (1 - eased) * (index.isEven ? 0.5 : -0.5);

    final left = index.isOdd ? half + gap / 2 : 0.0;
    final top = index > 1 ? half + gap / 2 : 0.0;

    return Positioned(
      left: left + dx,
      top: top + dy,
      child: Transform.rotate(
        angle: spin,
        child: Opacity(
          opacity: eased.clamp(0.0, 1.0),
          child: Container(
            width: tile,
            height: tile,
            decoration: BoxDecoration(
              color: NookColors.textPrimary,
              // Only the outer corner of each quarter is round, so the four
              // together read as one rounded square rather than four tiles.
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(index == 0 ? 12 : 3),
                topRight: Radius.circular(index == 1 ? 12 : 3),
                bottomLeft: Radius.circular(index == 2 ? 12 : 3),
                bottomRight: Radius.circular(index == 3 ? 12 : 3),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              piece.glyph,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: tile * 0.52,
                color: NookColors.surface,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}