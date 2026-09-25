import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_motion.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'metadata_chip.dart';
import 'thumb_placeholder.dart';

/// How much of the map the gestures may drive.
enum MapInteraction {
  /// Inside a scrolling page: the map takes no pointers, and a tap on it opens
  /// the full screen one.
  ///
  /// This is the whole reason the map felt dead in the card. `FlutterMap`
  /// always registers a `ScaleGestureRecognizer` and makes it the captain of
  /// its gesture arena team, whatever `InteractiveFlag`s are set — and a
  /// one-finger drag is a one-pointer scale. So the map claimed every drag
  /// that started on it: the enclosing `ListView` could not scroll, and with
  /// `drag` turned off the map did not pan either. A dead rectangle.
  ///
  /// Turning flags off cannot fix that, because the recognizer is not behind a
  /// flag. Not receiving the pointer can. The page scrolls normally, and every
  /// gesture the map wants lives one tap away in [full].
  preview,

  /// Filling the screen, with nothing to compete for gestures: drag, pinch,
  /// double tap, fling and wheel all work.
  full,
}

/// The map on Travel Details, and the map behind it.
///
/// `flutter_map` with OpenStreetMap tiles: no API key, no billing account, no
/// Google Cloud project, and it runs on the web. Attribution is required by the
/// tile usage policy and is drawn in the corner.
///
/// A post only reaches this widget when extraction returned coordinates. A
/// destination that is missing, or too broad to have a single point, gets
/// [PostMapPlaceholder] instead — the panel the mockup draws.
class PostMap extends StatefulWidget {
  const PostMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.label,
    this.zoom = 14,
    this.aspectRatio = 1.6,
    this.interaction = MapInteraction.preview,
    this.onTap,
    this.tileProvider,
  });

  final double latitude;
  final double longitude;
  final String label;
  final double zoom;

  /// Ignored when [interaction] is [MapInteraction.full], which fills its box.
  final double aspectRatio;

  final MapInteraction interaction;

  /// Tapping the preview. Null leaves taps to the map itself.
  final VoidCallback? onTap;

  /// Where tiles come from. Defaults to the network.
  ///
  /// A seam rather than a hard-coded provider: the default wraps a
  /// `RetryClient`, which retries on real timers, so the failure path is
  /// otherwise untestable in fake time.
  final TileProvider? tileProvider;

  @override
  State<PostMap> createState() => _PostMapState();
}

class _PostMapState extends State<PostMap> {
  /// Set when the tile server refuses or cannot be reached.
  ///
  /// Without this a failed tile leaves the layer's own grey behind and the map
  /// looks broken with no explanation — which is exactly what a blocked or
  /// key-gated tile host produces. Saying so beats a grey rectangle.
  bool _tilesFailed = false;

  /// Built once. `NetworkTileProvider()` opens an HTTP client, so creating one
  /// per build would leak a client per frame.
  late final TileProvider _tiles = widget.tileProvider ?? NetworkTileProvider();

  @override
  void dispose() {
    _tiles.dispose();
    super.dispose();
  }

  /// Tiles retry as you pan, so one failure should not condemn the map
  /// forever; the message clears as soon as anything loads.
  void _noteTileError() {
    if (!_tilesFailed && mounted) setState(() => _tilesFailed = true);
  }

  void _noteTileLoaded() {
    if (_tilesFailed && mounted) setState(() => _tilesFailed = false);
  }

  int get _flags => switch (widget.interaction) {
    // Belt and braces: the IgnorePointer below is what actually frees the
    // page's scroll, but a map that cannot be reached should not claim to
    // handle anything either.
    MapInteraction.preview => InteractiveFlag.none,
    // Everything except rotation: a tilted map is disorienting with no compass
    // to straighten it.
    MapInteraction.full => InteractiveFlag.all & ~InteractiveFlag.rotate,
  };

  /// The preview takes no pointers; the full screen map takes all of them.
  Widget _maybeIgnoring({required Widget child}) => IgnorePointer(
    ignoring: widget.interaction == MapInteraction.preview,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.latitude, widget.longitude);
    final full = widget.interaction == MapInteraction.full;

    final map = Stack(
      children: [
        Positioned.fill(
          child: _maybeIgnoring(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: widget.zoom,
                minZoom: 2,
                maxZoom: 18,
                interactionOptions: InteractionOptions(
                  flags: _flags,
                  scrollWheelVelocity: 0.004,
                ),
              ),
              children: [
                TileLayer(
                  // The standard OpenStreetMap style: the one tile source that
                  // needs no key, sends CORS headers so it works in a browser,
                  // and is what `flutter_map`'s own examples use.
                  //
                  // CARTO's Positron was here before, for Latin-script labels.
                  // It now watermarks every tile with "API KEY REQUIRED", and
                  // because it serves that as a normal 200 response, `fallbackUrl`
                  // never fired — the map looked like it was working and was not.
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.nook.app',
                  tileProvider: _tiles,
                  maxNativeZoom: 19,
                  errorTileCallback: (_, _, _) => _noteTileError(),
                  tileBuilder: (context, widget, tile) {
                    // `tileBuilder` runs for every tile, including ones still in
                    // flight, so building is not evidence of anything. A finish
                    // time with no error is.
                    if (!tile.loadError && tile.loadFinishedAt != null) {
                      _noteTileLoaded();
                    }
                    return widget;
                  },
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      // The point is the pin's tip, not its middle.
                      alignment: Alignment.topCenter,
                      child: const _Pin(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Above the map, so the tap lands here rather than in the arena the
        // map would otherwise win.
        if (!full && widget.onTap != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        Positioned(
          left: NookSpacing.tight,
          top: NookSpacing.tight,
          child: IgnorePointer(
            child: MetadataChip(widget.label, icon: Icons.place_outlined),
          ),
        ),
        if (!full && widget.onTap != null)
          Positioned(
            right: NookSpacing.tight,
            top: NookSpacing.tight,
            child: IgnorePointer(
              child: MetadataChip('Tap to open', icon: Icons.open_in_full),
            ),
          ),
        if (_tilesFailed)
          Positioned(
            left: NookSpacing.tight,
            right: NookSpacing.tight,
            bottom: 22,
            child: IgnorePointer(child: _TileError(full: full)),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: const Color(0xCCFFFFFF),
              child: Text(
                '© OpenStreetMap contributors',
                style: NookType.caption.copyWith(fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );

    if (full) return map;

    return ClipRRect(
      borderRadius: BorderRadius.circular(NookRadius.md),
      child: AspectRatio(aspectRatio: widget.aspectRatio, child: map),
    );
  }
}

/// Says the tiles did not arrive, rather than leaving a grey box.
class _TileError extends StatelessWidget {
  const _TileError({required this.full});

  final bool full;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NookSpacing.tight,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(NookRadius.sm),
        border: Border.all(color: NookColors.border),
      ),
      child: Text(
        full
            ? 'Map tiles could not be loaded. The pin is still in the right '
                  'place — open in a map app to see it.'
            : 'Map tiles could not be loaded.',
        style: NookType.caption.copyWith(fontSize: 11),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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

  /// The fade runs off its own curve rather than [_drop]: elasticOut
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
