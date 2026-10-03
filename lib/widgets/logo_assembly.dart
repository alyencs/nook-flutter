import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_motion.dart';

/// The Nook mark assembling from its own four quarters.
///
/// The mark is a 2×2 grid of tiles, so it takes itself apart along lines that
/// are already there — no pieces are invented for the sake of the animation.
/// Each quarter flies in from the direction it belongs to (the top-left one
/// from the top left, and so on), so the motion reads as things returning to
/// where they go rather than swirling.
///
/// ---
///
/// **The pieces are the real artwork.** An earlier version drew four rounded
/// charcoal squares and set a Manrope letter in each. That was a text
/// approximation of the logo, not the logo: Nook's mark carries its letters as
/// *counters* cut out of solid tiles, and the two O tiles read as a check or a
/// V rather than as a round O. Describing it in a font could never have been
/// right, and the glyphs it chose were wrong as well.
///
/// What ships now are [NookMarkPiece.values] — four transparent PNGs cut from
/// the supplied `nook_logo.png` along its own gutters, at its own resolution.
/// Laid out at [columnSplit] and [rowSplit] they reassemble that file pixel for
/// pixel, which is checked rather than asserted: the four crops were composited
/// back together and differenced against the original, and nothing differed.
///
/// Nothing here redraws, re-traces or re-spaces the logo. The only numbers are
/// where the artwork's own gutters fall.
class LogoAssembly extends StatefulWidget {
  const LogoAssembly({super.key, this.size = 116, this.onComplete});

  /// The width of the finished mark. Height follows from [aspect].
  final double size;
  final VoidCallback? onComplete;

  /// The whole sequence, from the first piece leaving to the last one landing.
  ///
  /// Longer than it was. At 1500ms each quarter crossed its distance in about
  /// 800ms behind a curve that spends most of its travel in the first third,
  /// which is quick enough that the mark looked like it faded in rather than
  /// assembled. The point of this animation is to be watched once.
  static const duration = Duration(milliseconds: 2400);

  /// The mark is 852 × 846 in the supplied artwork — near square, not square.
  static const aspect = 852 / 846;

  /// Where the artwork's vertical gutter falls, as a fraction of its width.
  /// The left column is 427 of 852.
  static const columnSplit = 427 / 852;

  /// Where the horizontal gutter falls. Both rows are 423 of 846.
  static const rowSplit = 423 / 846;

  @override
  State<LogoAssembly> createState() => _LogoAssemblyState();
}

/// One quarter of the mark: its asset, and where it belongs.
enum NookMarkPiece {
  n('assets/images/nook_mark_n.png', column: 0, row: 0, dx: -2.4, dy: -1.6),
  o1('assets/images/nook_mark_o1.png', column: 1, row: 0, dx: 2.4, dy: -1.9),
  o2('assets/images/nook_mark_o2.png', column: 0, row: 1, dx: -2.1, dy: 2.2),
  k('assets/images/nook_mark_k.png', column: 1, row: 1, dx: 2.6, dy: 1.7);

  const NookMarkPiece(
    this.asset, {
    required this.column,
    required this.row,
    required this.dx,
    required this.dy,
  });

  final String asset;
  final int column;
  final int row;

  /// Where this piece starts, in multiples of the mark's own width — out past
  /// the corner it belongs to.
  final double dx;
  final double dy;
}

class _LogoAssemblyState extends State<LogoAssembly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LogoAssembly.duration,
  );

  /// The beat each piece arrives on, as a fraction of the timeline.
  ///
  /// Wider spacing than before. The pieces used to land 90ms apart at 1500ms,
  /// which at speed read as one event; at 2400ms these are about 260ms apart,
  /// far enough to count four arrivals.
  static const _delays = [0.00, 0.11, 0.22, 0.33];

  /// The share of the timeline each piece gets for its own journey.
  ///
  /// 0.33 + 0.52 = 0.85, so the last piece is home with a beat to spare before
  /// the controller finishes and the wordmark is called in.
  static const _span = 0.52;

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
    final height = widget.size / LogoAssembly.aspect;
    return SizedBox(
      width: widget.size,
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < NookMarkPiece.values.length; i++)
              _quarter(NookMarkPiece.values[i], _delays[i], i),
          ],
        ),
      ),
    );
  }

  Widget _quarter(NookMarkPiece piece, double delay, int index) {
    final width = widget.size;
    final height = width / LogoAssembly.aspect;

    // The cell this piece occupies, straight off the artwork's own gutters.
    final left = piece.column == 0 ? 0.0 : width * LogoAssembly.columnSplit;
    final top = piece.row == 0 ? 0.0 : height * LogoAssembly.rowSplit;
    final cellWidth = piece.column == 0
        ? width * LogoAssembly.columnSplit
        : width * (1 - LogoAssembly.columnSplit);
    final cellHeight = piece.row == 0
        ? height * LogoAssembly.rowSplit
        : height * (1 - LogoAssembly.rowSplit);

    // Each piece runs over its own slice of the timeline, starting on its beat.
    final t = ((_controller.value - delay) / _span).clamp(0.0, 1.0);
    final eased = NookMotion.enter.transform(t);

    final dx = piece.dx * width * (1 - eased);
    final dy = piece.dy * width * (1 - eased);
    // A part-turn that unwinds as it lands, so the pieces tumble rather than
    // slide. Alternating direction stops them looking like one rotating body.
    final spin = (1 - eased) * (index.isEven ? 0.5 : -0.5);

    return Positioned(
      left: left + dx,
      top: top + dy,
      width: cellWidth,
      height: cellHeight,
      child: Transform.rotate(
        angle: spin,
        child: Opacity(
          opacity: eased.clamp(0.0, 1.0),
          // The artwork is a flat black glyph on transparency, so srcIn swaps
          // the colour and keeps the alpha: the letter counters stay cut out
          // and the edges stay anti-aliased. Nothing in the PNGs changes.
          child: Image.asset(
            piece.asset,
            color: NookColors.primary,
            colorBlendMode: BlendMode.srcIn,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

/// The finished mark, with no animation.
///
/// The same four assets in the same cells, for the places that want the logo
/// rather than the performance — About, an empty state, a header.
class NookLogo extends StatelessWidget {
  const NookLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final height = size / LogoAssembly.aspect;
    return SizedBox(
      width: size,
      height: height,
      child: Stack(
        children: [
          for (final piece in NookMarkPiece.values)
            Positioned(
              left: piece.column == 0 ? 0.0 : size * LogoAssembly.columnSplit,
              top: piece.row == 0 ? 0.0 : height * LogoAssembly.rowSplit,
              width: piece.column == 0
                  ? size * LogoAssembly.columnSplit
                  : size * (1 - LogoAssembly.columnSplit),
              height: piece.row == 0
                  ? height * LogoAssembly.rowSplit
                  : height * (1 - LogoAssembly.rowSplit),
              child: Image.asset(
                piece.asset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
        ],
      ),
    );
  }
}
