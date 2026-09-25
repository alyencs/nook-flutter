import 'package:flutter/material.dart';

import '../../theme/nook_spacing.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/open_in_maps.dart';
import '../../widgets/post_map.dart';

/// The saved location, filling the screen.
///
/// The preview on Travel Details deliberately gives single-finger drags to the
/// list it sits in, which leaves it unable to pan. This is where that
/// restriction is lifted: nothing here competes for gestures, so drag, pinch,
/// double tap, fling and the scroll wheel all reach the map.
class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;

  /// Pushes the screen. Kept here so callers do not each rebuild the route.
  static Future<void> open(
    BuildContext context, {
    required double latitude,
    required double longitude,
    required String label,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MapScreen(latitude: latitude, longitude: longitude, label: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      padHorizontal: false,
      bottomBar: Builder(
        builder: (context) => NookSecondaryButton(
          label: 'Open in Maps',
          icon: Icons.near_me_outlined,
          onPressed: () => OpenInMaps.open(
            Overlay.of(context, rootOverlay: true),
            latitude: latitude,
            longitude: longitude,
            label: label,
          ),
        ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: NookSpacing.screenEdge),
            child: NookAppBar(title: 'Location'),
          ),
          const SizedBox(height: NookSpacing.tight),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NookSpacing.screenEdge,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NookRadius.md),
                child: PostMap(
                  latitude: latitude,
                  longitude: longitude,
                  label: label,
                  interaction: MapInteraction.full,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
