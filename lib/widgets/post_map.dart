import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import '../theme/nook_motion.dart';
import 'metadata_chip.dart';
import 'thumb_placeholder.dart';

/// The map on Travel Details.
///
/// `flutter_map` with OpenStreetMap tiles, which is what the proposal chose and
/// why: no API key, no billing account, no Google Cloud project, and it runs on
/// the web. Attribution is required by the tile usage policy and is drawn in the
/// corner.
///
/// A post only reaches this widget when extraction returned coordinates. A
/// destination that is missing, or too broad to have a single point, gets
/// [PostMapPlaceholder] instead — the panel the mockup draws.
class PostMap extends StatelessWidget {
  const PostMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.label,
    this.zoom = 11,
    this.aspectRatio = 1.6,
  });

  final double latitude;
  final double longitude;
  final String label;
  final double zoom;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(NookRadius.md),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: zoom,
                // A real map: drag, pinch, double-tap and scroll-wheel zoom.
                // Rotation stays off — a tilted map is disorienting in a card
                // and there is no compass to straighten it with.
                //
                // `drag` inside a scrolling page needs the gesture to be won
                // rather than shared, which is what the eager recogniser below
                // does: a pan that starts on the map belongs to the map.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  scrollWheelVelocity: 0.004,
                ),
              ),
              children: [
                TileLayer(
                  // CARTO Positron, for two reasons.
                  //
                  // Labels: the standard `tile.openstreetmap.org` style renders
                  // every place in its own local script, so a pin in Osaka came
                  // back labelled in Japanese and one in Bangkok in Thai.
                  // Positron's label layer is Latin-script, so the map reads in
                  // English wherever the pin lands.
                  //
                  // Looks: it is a quiet grey-and-white basemap rather than the
                  // green-and-yellow default, which lets the orange pin be the
                  // only saturated thing in the card.
                  //
                  // Same OpenStreetMap data, so the attribution names both.
                  urlTemplate:
                      'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nook.app',
                  tileProvider: NetworkTileProvider(),
                  retinaMode: false,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const _Pin(),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: NookSpacing.tight,
              top: NookSpacing.tight,
              child: MetadataChip(label, icon: Icons.place_outlined),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: const Color(0xCCFFFFFF),
                child: Text(
                  '© OpenStreetMap · CARTO',
                  style: NookType.caption.copyWith(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatefulWidget {
  const _Pin();

  @override
  State<_Pin> createState() => _PinState();
}

class _PinState extends State<_Pin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.slow,
  );

  /// elasticOut on the way down only: the pin falls in and settles, which
  /// draws the eye to the location without the map itself moving.
  ///
  /// Built once, not per build: CurvedAnimation registers a status listener on
  /// its parent in the constructor, so rebuilding one every frame leaks a
  /// listener each time.
  late final Animation<double> _drop = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  /// The fade runs off the raw controller rather than [_drop]: elasticOut
  /// overshoots past 1, and an opacity above 1 asserts.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.enter,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    // Both curves hold a listener on the controller; drop them before it goes.
    (_drop as CurvedAnimation).dispose();
    (_fade as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -26 * (1 - _drop.value)),
        child: Opacity(opacity: _fade.value.clamp(0.0, 1.0), child: child),
      ),
      child: const Icon(
        Icons.location_on,
        size: 40,
        color: NookColors.primary,
        shadows: [
          Shadow(color: Color(0x552E2E2E), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

/// What the mockup draws, shown when a post has no coordinates to pin.
///
/// Labelled rather than left blank: an unexplained grey panel reads as broken.
class PostMapPlaceholder extends StatelessWidget {
  const PostMapPlaceholder({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            const ThumbPlaceholder(aspectRatio: 1.6, showGlyph: false),
            const Positioned(
              top: NookSpacing.tight,
              left: NookSpacing.tight,
              child: MetadataChip('Map View Placeholder'),
            ),
          ],
        ),
        if (reason != null) ...[
          const SizedBox(height: NookSpacing.tight),
          Text(reason!, style: NookType.caption.copyWith(fontSize: 13)),
        ],
      ],
    );
  }
}
