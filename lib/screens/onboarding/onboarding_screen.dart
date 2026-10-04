import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_motion.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_rule.dart';
import '../../widgets/nook_scaffold.dart';
import 'get_started_screen.dart';

/// The four onboarding pages, laid out as an editorial spread rather than
/// centred cards.
///
/// * A numbered index, so four screens read as a sequence.
/// * An overline and a rule to the margin — the same section mark used
///   everywhere else in the app.
/// * A tall photograph, full-bleed to the right edge, with the text hanging off
///   its left. The asymmetry is what stops a page looking like a form.
/// * One headline with one emphasised phrase, and nothing else competing.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  /// `*…*` marks the phrase that becomes the editorial italic.
  static const _pages = [
    (
      overline: 'Save',
      headline: 'Everything you find,\n*in one place*',
      body:
          'Tips, itineraries and recommendations from TikTok, Instagram, '
          'Facebook and YouTube.',
      image: 'assets/images/onboarding_1.jpg',
      alignment: Alignment.center,
      tint: Color(0xFFF7E7BE),
    ),
    (
      overline: 'Read',
      headline: 'Nook reads the post\n*so you do not have to*',
      body:
          'Destinations, places and prices are pulled out of the content '
          'itself — not just the title.',
      image: 'assets/images/onboarding_2.jpg',
      alignment: Alignment.center,
      tint: Color(0xFFD7E6F2),
    ),
    (
      overline: 'Plan',
      headline: 'One trip,\n*one folder*',
      body:
          'Group what you save into trips — Japan 2027, a weekend in Porto, '
          'someday.',
      image: 'assets/images/onboarding_3.jpg',
      alignment: Alignment.center,
      tint: Color(0xFFD9E8DA),
    ),
    (
      overline: 'Return',
      headline: 'Find it again\n*in a second*',
      body:
          'Search everything you have saved, by place, by creator, by the '
          'note you left yourself.',
      image: 'assets/images/onboarding_4.jpg',
      alignment: Alignment.center,
      tint: Color(0xFFF6DEDE),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      );
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() => Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const GetStartedScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return NookScaffold(
      padHorizontal: false,
      bottomBar: Row(
        children: [
          Expanded(
            child: NookPrimaryButton(
              label: isLast ? 'Enter Nook' : 'Next',
              icon: Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
          ),
          if (!isLast) ...[
            const SizedBox(width: NookSpacing.tight),
            TextButton(
              onPressed: _skip,
              child: Text(
                'Skip',
                style: NookType.body.copyWith(color: NookColors.textMuted),
              ),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                final page = _pages[index];
                return _OnboardingPage(
                  index: index,
                  total: _pages.length,
                  overline: page.overline,
                  headline: page.headline,
                  body: page.body,
                  image: page.image,
                  alignment: page.alignment,
                  tint: page.tint,
                );
              },
            ),
          ),
          // Four segments, filled as far as you have come. A counted line
          // rather than dots: the numbers above already say where you are.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NookSpacing.screenEdge,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _pages.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      height: 2,
                      color: i <= _page
                          ? NookColors.primary
                          : NookColors.border,
                    ),
                  ),
                  if (i != _pages.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.index,
    required this.total,
    required this.overline,
    required this.headline,
    required this.body,
    required this.image,
    required this.alignment,
    required this.tint,
  });

  final int index;
  final int total;
  final String overline;
  final String headline;
  final String body;
  final String image;
  final Alignment alignment;
  final Color tint;

  String get _number => (index + 1).toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The photograph takes the upper half and runs off the right edge;
        // the words sit under it, left-aligned. On a short screen the image
        // gives way first, because the headline is the thing that has to read.
        final imageHeight = (constraints.maxHeight * 0.44).clamp(140.0, 320.0);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: NookSpacing.tight),

              // 01 — SAVE ────────────────────
              Padding(
                padding: const EdgeInsets.only(left: NookSpacing.screenEdge),
                child: Row(
                  children: [
                    Text(
                      _number,
                      style: NookType.overline.copyWith(
                        color: NookColors.primary,
                      ),
                    ),
                    const SizedBox(width: NookSpacing.tight),
                    Text(overline.toUpperCase(), style: NookType.overline),
                    const SizedBox(width: NookSpacing.section),
                    const Expanded(child: NookRule(opacity: 0.7)),
                    const SizedBox(width: NookSpacing.screenEdge),
                  ],
                ),
              ),
              const SizedBox(height: NookSpacing.block),

              // The photograph, bleeding off the right edge.
              Padding(
                padding: const EdgeInsets.only(left: NookSpacing.screenEdge),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(NookRadius.md),
                    bottomLeft: Radius.circular(NookRadius.md),
                  ),
                  child: SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: _Photo(name: image, alignment: alignment, tint: tint),
                  ),
                ),
              ),
              const SizedBox(height: NookSpacing.block),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NookSpacing.screenEdge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NookHeadline(headline, style: NookType.display),
                    const SizedBox(height: NookSpacing.section),
                    Text(
                      body,
                      style: NookType.body.copyWith(
                        color: NookColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: NookSpacing.block),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A destination photograph, with a coloured ground underneath it.
///
/// The tint is what the page looks like while the photograph loads, and what it
/// keeps looking like if the image never arrives. Each page uses one of the
/// five folder colours, so onboarding and trips share a palette.
class _Photo extends StatelessWidget {
  const _Photo({
    required this.name, 
    required this.alignment,
    required this.tint
    });

  final String name;
  final Alignment alignment;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: tint),
        Image.asset(
          name,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          // Fades in rather than snapping, so a decode on a slow device
          // arrives instead of flashing.
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: NookMotion.slow,
              curve: NookMotion.enter,
              child: child,
            );
          },
          // Kept: a missing or corrupt file falls back to the tint rather
          // than throwing a grey error box into the layout.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        // A hairline grid, borrowed from the section marks used through the
        // app, so the photograph reads as part of a laid-out page.
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: const _GridMarks())),
        ),
      ],
    );
  }
}

class _GridMarks extends CustomPainter {
  const _GridMarks();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    // One vertical at a third, one horizontal at two thirds: enough to imply
    // a grid, not enough to become a pattern.
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.68),
      Offset(size.width, size.height * 0.68),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GridMarks oldDelegate) => false;
}
