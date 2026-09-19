import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../ai/platform_from_url.dart';
import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// One place that knows what each platform looks like.
///
/// Everything that shows a platform — the chips on a card, the circles on Paste
/// Link, the Connected Platforms rows — reads from here, so a post's platform
/// decides its mark rather than any screen hardcoding one.
///
/// Marks are Font Awesome's brand icons (CC BY 4.0, credited in About Nook).
/// The colours are each platform's own, used only to identify it.
abstract final class PlatformBranding {
  /// Null for a link from anywhere else, which falls back to a plain link
  /// glyph rather than pretending to be a platform it is not.
  static FaIconData? brandIcon(String platform) => switch (platform) {
        NookPlatform.tiktok => FontAwesomeIcons.tiktok,
        NookPlatform.instagram => FontAwesomeIcons.instagram,
        NookPlatform.facebook => FontAwesomeIcons.facebook,
        NookPlatform.youtube => FontAwesomeIcons.youtube,
        _ => null,
      };

  static Color colour(String platform) => switch (platform) {
        NookPlatform.tiktok => const Color(0xFF010101),
        NookPlatform.instagram => const Color(0xFFC13584),
        NookPlatform.facebook => const Color(0xFF1877F2),
        NookPlatform.youtube => const Color(0xFFFF0000),
        _ => NookColors.textMuted,
      };
}

/// The mark for one platform, at any size.
///
/// Brand icons are not square, so they need [FaIcon] rather than [Icon] — the
/// latter wraps them in a square box and clips them.
class PlatformIcon extends StatelessWidget {
  const PlatformIcon(this.platform, {super.key, required this.size, this.color});

  final String platform;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brand = PlatformBranding.brandIcon(platform);
    final colour = color ?? PlatformBranding.colour(platform);

    if (brand == null) {
      return Icon(Icons.link_rounded, size: size, color: colour);
    }
    return FaIcon(brand, size: size, color: colour);
  }
}

/// The Soft Butter chip on a card, now carrying the platform's own mark.
class PlatformChip extends StatelessWidget {
  const PlatformChip(this.platform, {super.key});

  final String platform;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: NookColors.secondary,
        borderRadius: BorderRadius.circular(NookRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlatformIcon(platform, size: 12),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              NookPlatform.label(platform),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NookType.caption.copyWith(
                color: NookColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The circles under the Paste Link field, and the rows on Connected Platforms.
///
/// [active] lights up the platform matching whatever has been pasted, so the
/// app confirms it recognised the link before you commit to it.
class PlatformAvatar extends StatelessWidget {
  const PlatformAvatar({
    super.key,
    required this.platform,
    this.active = false,
    this.size = 52,
  });

  final String platform;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colour = PlatformBranding.colour(platform);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active ? NookColors.secondary : NookColors.placeholder,
        shape: BoxShape.circle,
        border: active ? Border.all(color: NookColors.primary, width: 2) : null,
      ),
      child: Center(
        child: PlatformIcon(
          platform,
          size: size * 0.42,
          color: active ? colour : colour.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
