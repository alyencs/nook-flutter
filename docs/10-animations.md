# Animations — manual integration guide

Nothing in this file is in the app. It is written to be applied by hand, in
order, and each section says exactly which file to open, what to replace and
what to delete.

Everything here is built from Nook's existing pieces: the `Flight` overlay that
already carries the save animation, the `NookMotion` tokens, the hairline rule,
the folder tile and the four-tab bar. No new packages.

## Contents

| § | Animation | New files | Files to edit |
|---|---|---|---|
| 0 | *Why the delete flight is invisible* | — | — |
| 1 | Motion tokens | — | `lib/theme/nook_motion.dart` |
| 2 | Delete — the card leaves for Profile | `lib/widgets/tab_pulse.dart` | `lib/widgets/flight.dart`, `lib/widgets/delete_flight.dart`, `lib/screens/details/manage_post_screen.dart`, `lib/widgets/nook_bottom_nav.dart` |
| 3 | Restore — the mirror | — | `lib/widgets/delete_flight.dart`, `lib/screens/profile/recently_deleted_screen.dart` |
| 4 | Trip folders | `lib/widgets/folder_motion.dart` | `lib/widgets/trip_card.dart`, `lib/screens/trips/trips_screen.dart` |
| 5 | Landing — the logo assembles | `lib/widgets/logo_assembly.dart` | `lib/screens/onboarding/splash_screen.dart` |
| — | After integrating | — | — |

---

## 0. Why the delete flight is invisible

Worth reading before changing anything, because three of the four causes are
not "it is too fast".

**It is too fast.** `NookMotion.slow` is 420ms and the last 15% of that is a
fade, so the chip is actually travelling for about 350ms.

**It is too small.** It starts at the thumbnail's 56pt and ends at 28% of that
— roughly 16pt. A 16pt pale square crossing a pale background is not something
the eye catches.

**It is racing two page transitions.** In `_delete`, this happens first:

```dart
navigator
  ..pop()
  ..pop();
```

and only then does the flight start. Two routes are sliding and fading out over
the same frames. The eye follows the big moving thing — the page — not the
small one.

**Its subject may not be there.** If `thumbnailUrl` is null or fails to load,
`PostThumbnail` draws the pale placeholder, and a pale placeholder on a pale
background is close to invisible even when everything else is right.

§2 fixes all four: it runs longer, starts bigger, waits for the pops to finish
before it launches, and paints an opaque tile so there is always something to
watch.

---

## 1. Motion tokens

**Edit `lib/theme/nook_motion.dart`.** Add two durations after `slow`:

```dart
  /// Something crossing the whole screen, that the user is meant to follow.
  ///
  /// Long enough to read as travel rather than a flicker. The save flight can
  /// stay at [slow] — it is a confirmation of something already done — but a
  /// delete has to be watched, because it is answering "where did it go".
  static const deliberate = Duration(milliseconds: 900);

  /// A folder opening, a tile settling. Between [normal] and [slow].
  static const settle = Duration(milliseconds: 340);

  /// Springy, for something that arrives and has to feel physical. Used by the
  /// folder lid and the restore landing; not by anything that travels far,
  /// where an overshoot reads as a mistake.
  static const arrive = Curves.easeOutBack;
```

---

## 2. Delete — the card leaves for Profile

### 2a. Let a flight be configured

**Edit `lib/widgets/flight.dart`.**

Replace the `Flight.run` signature and body:

```dart
  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required Offset to,
    required String? thumbnailUrl,
  }) {
    final done = Completer<void>();
```

with:

```dart
  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required Offset to,
    required String? thumbnailUrl,
    Duration duration = NookMotion.slow,
    double endScale = 0.28,
    double lift = -28,
    bool opaque = false,
  }) {
    final done = Completer<void>();
```

and pass them through to `_Flight` — change the `OverlayEntry` builder:

```dart
      builder: (context) => _Flight(
        from: from,
        to: to,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        endScale: endScale,
        lift: lift,
        opaque: opaque,
        onDone: () { ... },   // leave the existing onDone exactly as it is
      ),
```

Then in `_Flight`, add the four fields:

```dart
class _Flight extends StatefulWidget {
  const _Flight({
    required this.from,
    required this.to,
    required this.thumbnailUrl,
    required this.onDone,
    required this.duration,
    required this.endScale,
    required this.lift,
    required this.opaque,
  });

  final Rect from;
  final Offset to;
  final String? thumbnailUrl;
  final VoidCallback onDone;
  final Duration duration;
  final double endScale;
  final double lift;
  final bool opaque;
```

In `_FlightState`, replace the controller's fixed duration:

```dart
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.slow,
  );
```

with:

```dart
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
```

and in `build`, replace these three lines:

```dart
        final lift = -28 * (1 - (2 * v - 1) * (2 * v - 1));
        ...
        final size = widget.from.width * (1 - 0.72 * v);
```

with:

```dart
        final lift = widget.lift * (1 - (2 * v - 1) * (2 * v - 1));
        ...
        final size = widget.from.width * (1 - (1 - widget.endScale) * v);
```

Finally, make the travelling tile opaque when asked. Replace the `SizedBox`
that wraps `PostThumbnail`:

```dart
              child: SizedBox(
                width: size,
                height: height,
                child: PostThumbnail(
                  url: widget.thumbnailUrl,
                  radius: NookRadius.sm,
                ),
              ),
```

with:

```dart
              child: Container(
                width: size,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NookRadius.sm),
                  // An opaque card with a shadow, so the thing travelling is
                  // visible even when the thumbnail never loads. The old
                  // version flew a transparent placeholder across a pale
                  // background, which is most of why nobody saw it.
                  color: widget.opaque ? NookColors.surface : null,
                  boxShadow: widget.opaque
                      ? const [
                          BoxShadow(
                            color: Color(0x332E2E2E),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: PostThumbnail(
                  url: widget.thumbnailUrl,
                  radius: NookRadius.sm,
                ),
              ),
```

Add the import if it is not there:

```dart
import '../theme/nook_colors.dart';
```

### 2b. The delete flight itself

**Edit `lib/widgets/delete_flight.dart`.** Replace the whole `run` method:

```dart
  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    return Flight.run(
      overlay,
      from: from,
      to: Flight.tabCentre(media.size, media.padding, tab),
      thumbnailUrl: thumbnailUrl,
      // Nine hundred milliseconds, not four hundred. This is the one animation
      // whose whole job is to be followed: it is answering "where did my post
      // go", and an answer nobody sees is not an answer.
      duration: NookMotion.deliberate,
      // It ends at 18% rather than 28%, so it reads as dropping *into* the
      // tab rather than stopping above it.
      endScale: 0.18,
      // A higher arc than the save flight. Saving puts something away;
      // deleting picks it up first, and the lift is what says so.
      lift: -64,
      opaque: true,
    );
  }
```

Add:

```dart
import '../theme/nook_motion.dart';
```

### 2c. The tab has to catch it

**Create `lib/widgets/tab_pulse.dart`:**

```dart
import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_motion.dart';

/// A ring that expands once out of a bottom-bar tab.
///
/// The flight ends at the Profile tab; without this, it ends *at* nothing. The
/// ring is the tab acknowledging the catch — the other half of the sentence.
/// One pulse, no repeat: it marks an event, it is not an indicator.
abstract final class TabPulse {
  static void at(OverlayState overlay, Offset centre) {
    late final OverlayEntry entry;
    var removed = false;
    entry = OverlayEntry(
      builder: (context) => _Pulse(
        centre: centre,
        onDone: () {
          if (removed) return;
          removed = true;
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.centre, required this.onDone});

  final Offset centre;
  final VoidCallback onDone;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone).catchError((_) {});
  }

  @override
  void dispose() {
    (_t as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final v = _t.value;
        final radius = 14 + 34 * v;
        return Positioned(
          left: widget.centre.dx - radius,
          top: widget.centre.dy - radius,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: NookColors.surface, width: 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

`NookMotion` is imported for consistency with the other widgets; if your linter
objects that it is unused, drop that import.

### 2d. Trigger it after the pops, not during them

**Edit `lib/screens/details/manage_post_screen.dart`.** In `_delete`, replace:

```dart
    // Back past the detail screen too: the post it was showing is gone.
    navigator
      ..pop()
      ..pop();

    // The card leaves for Profile — where Recently Deleted lives — and only
    // then is the row marked, so the two read as cause and effect rather than
    // the list twitching under a card that is still sitting there.
    //
    // Wrapped, because a delete that depends on an animation finishing is a
    // delete that can be lost. If the flight throws, the write still happens.
    if (from != null) {
      try {
        await DeleteFlight.run(overlay, from: from, thumbnailUrl: thumbnail);
      } catch (_) {
        // The post still has to go.
      }
    }
```

with:

```dart
    // Back past the detail screen too: the post it was showing is gone.
    navigator
      ..pop()
      ..pop();

    // Let the two route transitions finish before the flight starts. They are
    // 260ms each and they were running over the top of it: the eye follows the
    // page, not a small chip crossing it, which is most of why the animation
    // seemed not to happen at all.
    await Future<void>.delayed(NookMotion.normal + NookMotion.fast);

    if (from != null) {
      try {
        await DeleteFlight.run(overlay, from: from, thumbnailUrl: thumbnail);
        // The tab catches it.
        final media = MediaQuery.of(overlay.context);
        TabPulse.at(
          overlay,
          Flight.tabCentre(media.size, media.padding, DeleteFlight.tab),
        );
      } catch (_) {
        // The post still has to go.
      }
    }
```

Add:

```dart
import '../../theme/nook_motion.dart';
import '../../widgets/flight.dart';
import '../../widgets/tab_pulse.dart';
```

**Delay the toast too**, or it appears while the card is still in the air.
Replace:

```dart
    await posts.deletePost(widget.postId);
    NookToast.show(
      overlay,
      'Moved to Recently Deleted',
      icon: Icons.restore_from_trash_outlined,
    );
```

with:

```dart
    await posts.deletePost(widget.postId);
    // After the flight has landed, so the message confirms something the user
    // has just watched rather than narrating it over the top.
    NookToast.show(
      overlay,
      'Moved to Recently Deleted',
      icon: Icons.restore_from_trash_outlined,
    );
```

(The ordering is already correct once the `await` above is in place — no change
is needed beyond the comment. Included so the diff is unambiguous.)

---

## 3. Restore — the mirror

The same journey, run backwards: out of the Profile tab, up to where the row
sits in the list, and the row expands into place beneath it.

**Edit `lib/widgets/delete_flight.dart`.** Add a second entry point:

```dart
/// The reverse: a post coming back out of Recently Deleted.
///
/// Deliberately the same arc as [DeleteFlight], read the other way. Delete and
/// restore are one interaction with a direction, and using two unrelated
/// motions would make them look like two unrelated features.
abstract final class RestoreFlight {
  static Future<void> run(
    OverlayState overlay, {
    required Rect to,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    final from = Flight.tabCentre(
      media.size,
      media.padding,
      DeleteFlight.tab,
    );

    return Flight.run(
      overlay,
      // A small square at the tab, growing into the row's own rect.
      from: Rect.fromCenter(center: from, width: 22, height: 22),
      to: to.center,
      thumbnailUrl: thumbnailUrl,
      duration: NookMotion.deliberate,
      // Larger than it started: this one grows, which is the whole point.
      endScale: to.width / 22,
      // The arc bends the other way, so the two are mirror images.
      lift: 64,
      opaque: true,
    );
  }
}
```

**Edit `lib/screens/profile/recently_deleted_screen.dart`.**

Give the row a key so the flight knows where to land. In `_DeletedPostRow`,
change the class to a `StatefulWidget` — or, simpler, hold a `GlobalKey` on the
`_DeletedRow` container. Add to `_DeletedRow`:

```dart
  const _DeletedRow({
    super.key,                      // ← add
    required this.leading,
    ...
```

and in `_DeletedPostRow.build`, give it one:

```dart
class _DeletedPostRow extends StatelessWidget {
  _DeletedPostRow({required this.post});      // note: no longer const

  final SavedPost post;
  final _rowKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return _DeletedRow(
      key: _rowKey,
      ...
```

Then replace the `onRestore` body:

```dart
      onRestore: () async {
        final scope = AppScope.of(context);
        final overlay = Overlay.of(context, rootOverlay: true);
        await scope.posts.restorePost(post.id);
        NookToast.show(overlay, 'Restored "${post.title}"');
      },
```

with:

```dart
      onRestore: () async {
        final scope = AppScope.of(context);
        final overlay = Overlay.of(context, rootOverlay: true);

        // The row's rect, read before the list rebuilds without it.
        final box =
            _rowKey.currentContext?.findRenderObject() as RenderBox?;
        final to = box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size;

        // Write first here, unlike delete: the row has to leave this list for
        // the space to close up, and the flight is what carries the eye from
        // the gap it leaves to where the post has gone.
        await scope.posts.restorePost(post.id);

        if (to != null) {
          try {
            await RestoreFlight.run(
              overlay,
              to: to,
              thumbnailUrl: post.thumbnailUrl,
            );
          } catch (_) {
            // Restoring already happened; the animation is decoration.
          }
        }
        NookToast.show(overlay, 'Restored "${post.title}"');
      },
```

Add:

```dart
import '../../widgets/delete_flight.dart';
```

---

## 4. Trip folders

Three moments, no idling: the folder opens when you tap it, springs when it is
created, and takes a nudge when a post lands in it.

**Create `lib/widgets/folder_motion.dart`:**

```dart
import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';

/// A folder that opens when it is tapped.
///
/// The lid lifts and the whole tile tips a few degrees, for the length of the
/// tap and no longer. Folders do not move on their own: a grid of six tiles
/// breathing in place is decoration, and Nook's rule is that motion means
/// something happened.
class FolderOpen extends StatefulWidget {
  const FolderOpen({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<FolderOpen> createState() => _FolderOpenState();
}

class _FolderOpenState extends State<FolderOpen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.settle,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    (_t as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Opens, then runs the tap. The delay is the animation's length, so the
  /// folder is visibly open before the screen changes under it.
  Future<void> _open() async {
    await _controller.forward();
    if (!mounted) return;
    widget.onTap();
    // Closed again for when the user comes back to this list.
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final v = _t.value;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              // A little perspective, so the tip reads as a lid opening
              // rather than the tile shearing.
              ..setEntry(3, 2, 0.0015)
              ..rotateX(-0.22 * v)
              ..translate(0.0, -4.0 * v),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A folder that springs once when it first appears.
///
/// For a trip that was just created or just restored — the two moments when a
/// folder is new to the screen and worth pointing at.
class FolderArrive extends StatefulWidget {
  const FolderArrive({super.key, required this.child});

  final Widget child;

  @override
  State<FolderArrive> createState() => _FolderArriveState();
}

class _FolderArriveState extends State<FolderArrive>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.settle,
  )..forward();

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.arrive,
  );

  @override
  void dispose() {
    (_t as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _t, child: widget.child);
  }
}
```

**Edit `lib/widgets/trip_card.dart`.** Wrap the card's contents. Replace:

```dart
    return NookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
```

with:

```dart
    return FolderOpen(
      onTap: onTap ?? () {},
      child: NookCard(
        // onTap moves to FolderOpen, which runs it after the lid has lifted.
        padding: const EdgeInsets.all(10),
        child: Row(
```

and close the extra bracket at the end of the widget. Add:

```dart
import 'folder_motion.dart';
```

**Edit `lib/screens/trips/trips_screen.dart`** to spring a newly created trip.
Hold the new id in state:

```dart
  int? _justCreated;
```

set it after creating:

```dart
                        final id = await scope.trips.createTrip(
                          draft.name,
                          user.id,
                          colour: draft.colour,
                        );
                        if (context.mounted) {
                          setState(() => _justCreated = id);
                        }
```

(`TripsScreen` must be a `StatefulWidget` for this; if it is currently
stateless, convert it — nothing else in the file changes.)

and wrap that one card:

```dart
                    SizedBox(
                      width: width,
                      child: summary.trip.id == _justCreated
                          ? FolderArrive(child: TripCard(...))
                          : TripCard(...),
                    ),
```

---

## 5. Landing — the logo assembles

The Nook mark is a 2×2 grid of four tiles. That is the animation: the four
pieces arrive from four directions, off-beat, and lock into the grid.

**Create `lib/widgets/logo_assembly.dart`:**

```dart
import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';

/// The Nook mark assembling from its own four quarters.
///
/// The logo is a 2×2 grid of tiles, so it takes itself apart along lines that
/// are already there — no pieces are invented for the sake of the animation.
/// Each quarter flies in from the direction it belongs to (the top-left one
/// from the top left, and so on), so the motion reads as things returning to
/// where they go rather than swirling.
///
/// They arrive 90ms apart. Simultaneous would be a scale-up wearing a costume;
/// the stagger is what makes it four objects instead of one.
class LogoAssembly extends StatefulWidget {
  const LogoAssembly({
    super.key,
    this.size = 116,
    this.onComplete,
  });

  final double size;

  /// Called once the mark is whole, so the splash can move on.
  final VoidCallback? onComplete;

  @override
  State<LogoAssembly> createState() => _LogoAssemblyState();
}

class _LogoAssemblyState extends State<LogoAssembly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  /// Where each quarter starts, in multiples of the logo's own size, and the
  /// beat it arrives on.
  static const _pieces = [
    (offset: Offset(-2.4, -1.6), delay: 0.00, glyph: 'N'),
    (offset: Offset(2.4, -1.9), delay: 0.09, glyph: 'V'),
    (offset: Offset(-2.1, 2.2), delay: 0.18, glyph: 'V'),
    (offset: Offset(2.6, 1.7), delay: 0.27, glyph: 'K'),
  ];

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onComplete?.call();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final half = widget.size / 2;
    final gap = widget.size * 0.05;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              for (var i = 0; i < _pieces.length; i++)
                _quarter(i, half, gap),
            ],
          );
        },
      ),
    );
  }

  Widget _quarter(int index, double half, double gap) {
    final piece = _pieces[index];

    // Each piece runs over its own 55% of the timeline, starting on its beat.
    final t = ((_controller.value - piece.delay) / 0.55).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);

    final dx = piece.offset.dx * widget.size * (1 - eased);
    final dy = piece.offset.dy * widget.size * (1 - eased);
    // A quarter turn that unwinds as it lands, so the pieces tumble rather
    // than slide.
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
            width: half - gap / 2,
            height: half - gap / 2,
            decoration: BoxDecoration(
              color: NookColors.textPrimary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(index == 0 ? 10 : 2),
                topRight: Radius.circular(index == 1 ? 10 : 2),
                bottomLeft: Radius.circular(index == 2 ? 10 : 2),
                bottomRight: Radius.circular(index == 3 ? 10 : 2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              piece.glyph,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: half * 0.5,
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
```

> **If you have the logo as an SVG or PNG**, replace the `Container` + `Text`
> with a clipped `Image.asset` of the whole mark, offset so each tile shows its
> own quarter — wrap the image in `ClipRect` + `Align` with
> `widthFactor: 0.5, heightFactor: 0.5` and `alignment` set to the matching
> corner. The motion code above does not change.

**Edit `lib/screens/onboarding/splash_screen.dart`.** Replace the static
bookmark circle with the assembly, and let it drive the entrance of the
wordmark underneath it:

```dart
            LogoAssembly(
              size: 116,
              onComplete: () => setState(() => _assembled = true),
            ),
            const SizedBox(height: NookSpacing.block),
            AnimatedOpacity(
              opacity: _assembled ? 1 : 0,
              duration: NookMotion.slow,
              curve: NookMotion.enter,
              child: AnimatedSlide(
                offset: _assembled ? Offset.zero : const Offset(0, 0.25),
                duration: NookMotion.slow,
                curve: NookMotion.enter,
                child: Column(
                  children: [
                    // …the existing 'Nook' text and tagline, unchanged…
                  ],
                ),
              ),
            ),
```

`SplashScreen` needs to be a `StatefulWidget` with:

```dart
  bool _assembled = false;
```

Nothing else on the screen changes. The Continue button can stay where it is;
if you want it to wait, gate it on `_assembled` too.

---

## After integrating

Run these, in order:

```
dart format lib/
flutter analyze
flutter test
```

Three things in the suite will need attention:

1. **`test/animation_test.dart`** asserts the flight's geometry and its
   `NookMotion.slow` duration. §2 changes both for the delete flight — update
   the expectations to `NookMotion.deliberate` and `endScale: 0.18`. The save
   flight's tests are unaffected.

2. **`test/layout_test.dart`** calls a bounded `settle()` rather than
   `pumpAndSettle`. The logo assembly runs for 1.5s and the folder lid for
   340ms, so any test that mounts them needs enough pumps or it will assert on
   a frame mid-animation.

3. **Pending timers.** Every controller added here is disposed in the state's
   `dispose`, and every `CurvedAnimation` built as a field is disposed before
   its parent — keep both if you adapt the code. `Future.delayed` in
   `_delete` (§2d) is deliberately unguarded because it is awaited inside a
   method that has already captured its overlay, but if a test complains about
   a pending timer at teardown, that is the one to look at.

Finally: none of these animations should run on their own. If you find yourself
adding one that plays without the user having done something, it belongs in a
different app.
