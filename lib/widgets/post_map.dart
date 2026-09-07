import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
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
                // A thumbnail map, not an atlas: panning and rotating it inside
                // a scrolling page fights the scroll.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nook.app',
                  tileProvider: NetworkTileProvider(),
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
                  '© OpenStreetMap contributors',
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

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_on,
      size: 40,
      color: NookColors.primary,
      shadows: [
        Shadow(color: Color(0x552E2E2E), blurRadius: 6, offset: Offset(0, 2)),
      ],
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
