import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_buttons.dart';
import '../../ai/geocoder.dart';
import '../../ai/location_scope.dart';
import '../../ai/post_place.dart';
import '../../widgets/nook_rule.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/section_header.dart';
import '../../widgets/post_map.dart';
import 'map_screen.dart';
import '../explore/explore_itineraries_screen.dart';
import '../explore/itinerary_plan_screen.dart';
import '../../widgets/post_thumbnail.dart';

/// S2. The screen the whole proposal is built around.
///
/// Location, Country, Best Time to Visit and Budget are all extraction results.
/// Any of them can be absent — a link that never named a place cannot produce a
/// budget — and an em dash is the honest answer when that happens.
class TravelDetailsScreen extends StatelessWidget {
  const TravelDetailsScreen({super.key, required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<SavedPost?>(
      stream: scope.posts.watchPost(postId),
      builder: (context, snapshot) {
        final post = snapshot.data;
        if (post == null) return const NookScaffold(child: SizedBox.shrink());

        return NookScaffold(
          bottomBar: _ExploreItineraryButton(tripId: post.tripId),
          child: ListView(
            children: [
              const NookAppBar(title: 'Travel Details'),
              const SizedBox(height: NookSpacing.section),
              Row(
                children: [
                  PostThumbnail(
                    url: post.thumbnailUrl,
                    width: 64,
                    height: 64,
                    showGlyph: false,
                  ),
                  const SizedBox(width: NookSpacing.section),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.title, style: NookType.bodyStrong),
                        const SizedBox(height: 2),
                        Text(
                          post.creator ?? '—',
                          style: NookType.body.copyWith(
                            color: NookColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NookSpacing.block),
              const Divider(),
              _MetaRow(
                icon: Icons.place_outlined,
                label: 'Location',
                value: post.aiPlaceName ?? _cityOf(post.aiDestination),
              ),
              const Divider(),
              // The specific parts, each shown only when extraction actually
              // found it. A post that says nothing more than "Japan" still
              // shows Country alone, exactly as before.
              if (post.aiPlaceName != null && post.aiAddress != null)
                _MetaRow(
                  icon: Icons.signpost_outlined,
                  label: 'Address',
                  value: post.aiAddress,
                ),
              if (post.aiNeighbourhood != null)
                _MetaRow(
                  icon: Icons.explore_outlined,
                  label: 'Area',
                  value: post.aiNeighbourhood,
                ),
              if (post.aiCity != null)
                _MetaRow(
                  icon: Icons.location_city_rounded,
                  label: 'City',
                  value: post.aiCity,
                ),
              if (post.aiRegion != null)
                _MetaRow(
                  icon: Icons.map_outlined,
                  label: 'Region',
                  value: post.aiRegion,
                ),
              // Every venue the post named, as a list. This is what "5 Cafes
              // in Kyoto" actually is, and before there was nowhere to put it.
              if (PostPlace.decode(post.aiPlaces).isNotEmpty) ...[
                const SizedBox(height: NookSpacing.block),
                RuledLabel(
                  '${PostPlace.decode(post.aiPlaces).length} places mentioned',
                ),
                const SizedBox(height: NookSpacing.tight),
                for (final place in PostPlace.decode(post.aiPlaces))
                  _PlaceRow(place: place),
                const SizedBox(height: NookSpacing.tight),
              ],
              if (PostHighlights.decode(post.aiHighlights).isNotEmpty) ...[
                const SizedBox(height: NookSpacing.block),
                const RuledLabel('Worth knowing'),
                const SizedBox(height: NookSpacing.tight),
                for (final line in PostHighlights.decode(post.aiHighlights))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7, right: 10),
                          child: SizedBox(
                            width: 14,
                            child: NookRule(opacity: 0.9),
                          ),
                        ),
                        Expanded(child: Text(line, style: NookType.body)),
                      ],
                    ),
                  ),
                const SizedBox(height: NookSpacing.tight),
              ],
              _MetaRow(
                icon: Icons.public_rounded,
                label: 'Country',
                value: post.aiCountry ?? _countryOf(post.aiDestination),
              ),
              const SizedBox(height: NookSpacing.block),
              const OverlineLabel('Map location'),
              const SizedBox(height: NookSpacing.tight),
              _MapSection(post: post),
              const SizedBox(height: NookSpacing.block),
              const Divider(),
              _MetaRow(
                icon: Icons.calendar_today_outlined,
                label: 'Best Time to Visit',
                value: post.aiBestTime,
              ),
              const Divider(),
              _MetaRow(
                icon: Icons.credit_card_rounded,
                label: 'Budget',
                value: post.aiBudgetNote,
              ),
              const Divider(),
              const SizedBox(height: NookSpacing.section),
            ],
          ),
        );
      },
    );
  }

  /// "Kyoto, Japan" splits into a location and a country when the model gave
  /// the pair but not the parts.
  static String? _cityOf(String? destination) {
    if (destination == null) return null;
    final parts = destination.split(',');
    return parts.first.trim().isEmpty ? null : parts.first.trim();
  }

  static String? _countryOf(String? destination) {
    if (destination == null) return null;
    final parts = destination.split(',');
    return parts.length < 2 ? null : parts.last.trim();
  }
}

/// The map for one post, and the lookup that places a post saved without
/// coordinates.
///
/// Every post that names anywhere gets a map; how specific that place is
/// decides how far the map is zoomed out, not whether there is one. A post
/// whose extraction returned a place but no point — or one saved before
/// coordinates were kept for broad places — is looked up once, and the answer
/// is written back onto the row so the question is not asked again.
class _MapSection extends StatefulWidget {
  const _MapSection({required this.post});

  final SavedPost post;

  @override
  State<_MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<_MapSection> {
  /// True while a lookup is running, so the panel says it is working rather
  /// than claiming the post cannot be placed.
  bool _looking = false;

  /// Set when a lookup finished and found nothing. The stream behind this
  /// screen ticks on every write, and without this the same dead query would
  /// be sent on every tick.
  bool _unresolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void didUpdateWidget(covariant _MapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The destination was edited, so a query that failed before is worth asking
    // again.
    if (oldWidget.post.aiDestination != widget.post.aiDestination) {
      _unresolved = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (!mounted || _looking || _unresolved) return;

    final post = widget.post;
    if (post.aiLatitude != null && post.aiLongitude != null) return;

    final query = GeocodeQuery.forPost(
      placeName: post.aiPlaceName,
      address: post.aiAddress,
      neighbourhood: post.aiNeighbourhood,
      city: post.aiCity,
      region: post.aiRegion,
      country: post.aiCountry,
      destination: post.aiDestination,
    );
    if (query == null) return;

    // Both resolved before the await, so nothing reads a BuildContext across
    // one.
    final geocoder = AppScope.of(context).geocoder;
    final posts = AppScope.of(context).posts;

    setState(() => _looking = true);
    final point = await geocoder.lookup(query);
    if (!mounted) return;

    if (point == null) {
      setState(() {
        _looking = false;
        _unresolved = true;
      });
      return;
    }

    await posts.updateCoordinates(post.id, point.latitude, point.longitude);
    if (mounted) setState(() => _looking = false);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final scope = LocationScope.of(
      placeName: post.aiPlaceName,
      address: post.aiAddress,
      neighbourhood: post.aiNeighbourhood,
      city: post.aiCity,
      region: post.aiRegion,
      country: post.aiCountry,
      destination: post.aiDestination,
    );

    // Most specific first, so the chip over the pin names the thing the map is
    // framed on: the cafe before its district, the country before "somewhere".
    final label =
        post.aiPlaceName ??
        post.aiNeighbourhood ??
        post.aiCity ??
        post.aiRegion ??
        post.aiCountry ??
        TravelDetailsScreen._cityOf(post.aiDestination) ??
        post.aiDestination ??
        'Saved location';

    if (post.aiLatitude != null && post.aiLongitude != null) {
      return PostMap(
        latitude: post.aiLatitude!,
        longitude: post.aiLongitude!,
        label: label,
        zoom: scope.zoom,
        onTap: () => MapScreen.open(
          context,
          latitude: post.aiLatitude!,
          longitude: post.aiLongitude!,
          label: label,
          zoom: scope.zoom,
        ),
      );
    }

    if (_looking) {
      return const PostMapPlaceholder(
        reason: 'Looking up where this is…',
      );
    }

    if (!scope.isMappable) {
      return const PostMapPlaceholder(
        reason: 'No destination was detected for this post, so there is '
            'nothing to place yet. Add one from the post to put it on the map.',
      );
    }

    return PostMapPlaceholder(
      reason: 'We could not find "$label" on the map. It may be spelt '
          'differently, or be somewhere the map data does not name.',
    );
  }
}

/// One named venue: what it is called, and what the post said about it.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final PostPlace place;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NookSpacing.row),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              _iconFor(place.kind),
              size: 16,
              color: NookColors.primary,
            ),
          ),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.summary, style: NookType.bodyStrong),
                if (place.note != null) ...[
                  const SizedBox(height: 2),
                  Text(place.note!, style: NookType.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String? kind) => switch (kind) {
    'cafe' => Icons.local_cafe_outlined,
    'restaurant' => Icons.restaurant_outlined,
    'bar' => Icons.wine_bar_outlined,
    'hotel' => Icons.hotel_outlined,
    'shop' => Icons.shopping_bag_outlined,
    'viewpoint' => Icons.landscape_outlined,
    _ => Icons.place_outlined,
  };
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: NookColors.textPrimary),
          const SizedBox(width: NookSpacing.tight),
          // Both sides are flex, so the two boxes tile the whole row and the
          // value box always ends at the right edge.
          //
          // With a loose Flexible label the value box was only half the free
          // space and sat wherever the label happened to end — so short labels
          // like "Location" left their value floating in the middle, while long
          // ones like "Best Time to Visit" looked correctly right-aligned.
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: NookType.body,
            ),
          ),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            flex: 6,
            child: Text(
              value ?? '—',
              textAlign: TextAlign.right,
              style: NookType.bodyStrong.copyWith(
                color: value == null
                    ? NookColors.textMuted
                    : NookColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the planner on the trip this post belongs to.
///
/// A post already filed into a trip goes straight to that trip's planner,
/// because the posts beside it are what the plan would be built from. One that
/// has not been filed yet goes to the trip list instead.
class _ExploreItineraryButton extends StatelessWidget {
  const _ExploreItineraryButton({this.tripId});

  final int? tripId;

  @override
  Widget build(BuildContext context) {
    return NookPrimaryButton(
      label: 'Explore Itinerary',
      icon: Icons.near_me_outlined,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => tripId == null
              ? const ExploreItinerariesScreen()
              : ItineraryPlanScreen(tripId: tripId!),
        ),
      ),
    );
  }
}
