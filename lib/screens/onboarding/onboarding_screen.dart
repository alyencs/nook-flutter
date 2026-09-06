import 'package:flutter/material.dart';

import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import 'get_started_screen.dart';

/// LA2–LA5. Four pages, copy verbatim from the mockup.
///
/// The revision brief asked that this speak to travellers specifically rather
/// than to "saving posts" in general, which is what these four say.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      title: 'Save travel finds',
      body: 'Save travel tips, itineraries, and recommendations from TikTok, '
          'Instagram, and YouTube — all in one place.',
      icon: Icons.bookmark_add_outlined,
    ),
    (
      title: 'AI organizes your trips',
      body: 'Nook detects destinations and categories from your saved travel '
          'content automatically.',
      icon: Icons.auto_awesome_outlined,
    ),
    (
      title: 'Organize by trip',
      body: 'Group your saved travel content into trips — Japan 2027, Weekend '
          'in Paris, and more.',
      icon: Icons.folder_copy_outlined,
    ),
    (
      title: 'Rediscover anything',
      body: 'Search across all your saved travel content instantly. Never lose '
          'a great find again.',
      icon: Icons.search_rounded,
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
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return NookScaffold(
      padHorizontal: false,
      bottomBar: NookPrimaryButton(
        label: isLast ? 'Get Started' : 'Next',
        onPressed: _next,
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NookSpacing.screenEdge,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: NookColors.placeholder,
                          borderRadius: BorderRadius.circular(NookRadius.md),
                        ),
                        child: Icon(
                          page.icon,
                          size: 72,
                          color: NookColors.primary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        page.title,
                        style: NookType.display.copyWith(fontSize: 30),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: NookSpacing.section),
                      Text(
                        page.body,
                        style: NookType.body.copyWith(
                          color: NookColors.textMuted,
                          fontSize: 17,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? NookColors.primary
                        : NookColors.border,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
