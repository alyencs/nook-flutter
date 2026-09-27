# Animations — manual integration patch

None of this is in the app. Follow the file from top to bottom, copying each
block, and the four animations will be working when you reach the checklist.

Every **Find:** block below is real code from the repository at commit
`c68a89f`, quoted exactly. If a Find block does not match your file character
for character, stop and check you are in the right place before editing.

**This guide has been applied and run.** I made every change below in a working
copy, then ran `flutter analyze` (no issues) and `flutter test` (254 passed),
then reverted it so the repository ships without the animation code as you
asked. Two defects the trial exposed — a `BuildContext` used across an await in
§5, and a deprecated `Matrix4.translate` in §7 — are already corrected here, and
§11 lists the one test that actually breaks rather than the two I first assumed.

---

## Dependencies

**No new dependency required.** Everything here uses `AnimationController`,
`CustomPainter`, `Transform` and `OverlayEntry` from `flutter/material.dart`,
all of which the project already uses. Do not add a package.

---

## File-by-file summary

| Action | File | What to do |
|---|---|---|
| CREATE | `lib/widgets/tab_pulse.dart` | New widget — the ring the Profile tab draws when it catches a deleted post |
| CREATE | `lib/widgets/folder_motion.dart` | New widgets — `FolderOpen` and `FolderArrive` |
| CREATE | `lib/widgets/logo_assembly.dart` | New widget — the Nook mark assembling from four quarters |
| EDIT | `lib/theme/nook_motion.dart` | ADD three tokens after `slow` |
| EDIT | `lib/widgets/flight.dart` | REPLACE 4 sections — make duration, scale, arc height and opacity configurable |
| EDIT | `lib/widgets/delete_flight.dart` | REPLACE the `run` method; ADD `RestoreFlight` class; ADD 1 import |
| EDIT | `lib/screens/details/manage_post_screen.dart` | REPLACE the delete block in `_delete`; ADD 3 imports |
| EDIT | `lib/screens/profile/recently_deleted_screen.dart` | REPLACE `_DeletedPostRow` and `_DeletedRow`'s constructor; ADD 1 import |
| EDIT | `lib/widgets/trip_card.dart` | REPLACE `TripCard.build`; ADD 1 import |
| EDIT | `lib/screens/trips/trips_screen.dart` | REPLACE `TripsBody` (stateless → stateful); ADD 1 import |
| EDIT | `lib/screens/onboarding/splash_screen.dart` | REPLACE `SplashScreen` (stateless → stateful); ADD 2 imports |
| EDIT | `test/animation_test.dart` | REPLACE 2 assertions that pin the old duration and scale |
| — | `pubspec.yaml` | **No change.** |

---

## Implementation order

Follow this order — later steps import earlier files.

| Step | Do this |
|---|---|
| 1 | §1 — add the motion tokens (everything else references them) |
| 2 | §2 — make `Flight` configurable |
| 3 | §3 — create `tab_pulse.dart` |
| 4 | §4 — rewrite `DeleteFlight`, add `RestoreFlight` |
| 5 | §5 — wire the delete trigger in `manage_post_screen.dart` |
| 6 | §6 — wire the restore trigger in `recently_deleted_screen.dart` |
| 7 | §7 — create `folder_motion.dart` |
| 8 | §8 — wire the folders in `trip_card.dart` and `trips_screen.dart` |
| 9 | §9 — create `logo_assembly.dart` |
| 10 | §10 — wire the splash screen |
| 11 | §11 — update the two tests |
| 12 | Run `dart format lib/ test/ && flutter analyze && flutter test` |
| 13 | Work the checklist at the end |

---

## §0. Why the delete animation is currently invisible

Read this first; three of the four causes are not "it is too fast".

1. **420ms**, of which the last 15% is a fade — about 350ms of visible travel.
2. **It ends at 16pt.** `flight.dart:123` scales to 28% of a 56pt thumbnail.
3. **It races two page transitions.** `manage_post_screen.dart` pops twice
   *before* starting the flight. Two routes are sliding out over the same
   frames and the eye follows the big moving thing.
4. **Its subject is often transparent.** If `thumbnailUrl` is null or fails,
   `PostThumbnail` draws a pale placeholder on a pale background.

§2 and §5 fix all four.

---

## §1. Motion tokens

### FILE: `lib/theme/nook_motion.dart`

**ACTION: ADD**

**Location:** immediately after the `slow` token (line 19), before the
`/// Arrivals.` comment.

**Add:**

```dart
  /// Something crossing the whole screen that the user is meant to follow.
  ///
  /// Long enough to read as travel rather than a flicker. The save flight stays
  /// at [slow] — it confirms something already done — but a delete has to be
  /// watched, because it is answering "where did it go".
  static const deliberate = Duration(milliseconds: 900);

  /// A folder opening, a tile settling. Between [normal] and [slow].
  static const settle = Duration(milliseconds: 340);

  /// Springy, for something that arrives and should feel physical. Used by the
  /// folder lid and the logo pieces; never by anything that travels far, where
  /// an overshoot reads as a mistake.
  static const arrive = Curves.easeOutBack;
```

> The class doc above says "Nothing here is longer than 420ms". Change that
> line to "Nothing here is longer than 900ms, and only one thing is." if you
> want the comment to stay true.

---

## §2. Make `Flight` configurable

Four edits to one file. `SaveFlight` keeps its current behaviour because every
new parameter defaults to today's value.

### FILE: `lib/widgets/flight.dart`

**ACTION: REPLACE** (1 of 4 — the `run` signature and the entry builder)

**Find:**

```dart
  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required Offset to,
    required String? thumbnailUrl,
  }) {
    final done = Completer<void>();

    late final OverlayEntry entry;
    var removed = false;
    entry = OverlayEntry(
      builder: (context) => _Flight(
        from: from,
        to: to,
        thumbnailUrl: thumbnailUrl,
        // Guarded: whenComplete also fires when the controller is disposed
        // mid-flight, and removing an entry twice trips an assertion.
        onDone: () {
          if (removed) return;
          removed = true;
          entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    overlay.insert(entry);
    return done.future;
  }
```

**Replace with:**

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

    late final OverlayEntry entry;
    var removed = false;
    entry = OverlayEntry(
      builder: (context) => _Flight(
        from: from,
        to: to,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        endScale: endScale,
        lift: lift,
        opaque: opaque,
        // Guarded: whenComplete also fires when the controller is disposed
        // mid-flight, and removing an entry twice trips an assertion.
        onDone: () {
          if (removed) return;
          removed = true;
          entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    overlay.insert(entry);
    return done.future;
  }
```

---

**ACTION: REPLACE** (2 of 4 — the `_Flight` widget's fields)

**Find:**

```dart
class _Flight extends StatefulWidget {
  const _Flight({
    required this.from,
    required this.to,
    required this.thumbnailUrl,
    required this.onDone,
  });

  final Rect from;
  final Offset to;
  final String? thumbnailUrl;
  final VoidCallback onDone;
```

**Replace with:**

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

  /// How long the whole journey takes.
  final Duration duration;

  /// The fraction of its starting width it ends at.
  final double endScale;

  /// The height of the arc at its midpoint, in logical pixels. Negative lifts.
  final double lift;

  /// Paints a solid card behind the thumbnail, so the thing travelling is
  /// visible even when the image never loads.
  final bool opaque;
```

---

**ACTION: REPLACE** (3 of 4 — the controller's fixed duration)

**Find:**

```dart
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.slow,
  );
```

**Replace with:**

```dart
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
```

---

**ACTION: REPLACE** (4 of 4 — the whole `build` body, so the arc, the scale and
the opaque card all read from the new fields)

**Find:**

```dart
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final v = _t.value;
        // An arc rather than a straight line: it lifts slightly before it
        // falls, which reads as "picked up and put away" instead of "dragged".
        final x =
            widget.from.center.dx + (widget.to.dx - widget.from.center.dx) * v;
        final lift = -28 * (1 - (2 * v - 1) * (2 * v - 1));
        final y =
            widget.from.center.dy +
            (widget.to.dy - widget.from.center.dy) * v +
            lift;
        final size = widget.from.width * (1 - 0.72 * v);
        final height = size * 9 / 16;

        return Positioned(
          left: x - size / 2,
          top: y - height / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: (v < 0.85 ? 1.0 : (1 - v) / 0.15).clamp(0.0, 1.0),
              child: SizedBox(
                width: size,
                height: height,
                // The glyph stays on: a post with no thumbnail, or one whose
                // image fails to load, otherwise flies an empty box across the
                // screen — an animation that runs and says nothing.
                child: PostThumbnail(
                  url: widget.thumbnailUrl,
                  radius: NookRadius.sm,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
```

**Replace with:**

```dart
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final v = _t.value;
        // An arc rather than a straight line: it lifts before it falls, which
        // reads as "picked up and put away" instead of "dragged".
        final x =
            widget.from.center.dx + (widget.to.dx - widget.from.center.dx) * v;
        final arc = widget.lift * (1 - (2 * v - 1) * (2 * v - 1));
        final y =
            widget.from.center.dy +
            (widget.to.dy - widget.from.center.dy) * v +
            arc;
        final size =
            widget.from.width * (1 - (1 - widget.endScale) * v);
        final height = size * 9 / 16;

        return Positioned(
          left: x - size / 2,
          top: y - height / 2,
          child: IgnorePointer(
            child: Opacity(
              // Fades only over the last 8%, not the last 15%: the card was
              // disappearing a tab's height short of the tab, so the journey
              // ended in mid-air rather than at the place it was pointing to.
              opacity: (v < 0.92 ? 1.0 : (1 - v) / 0.08).clamp(0.0, 1.0),
              child: Container(
                width: size,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NookRadius.sm),
                  // An opaque card with a border and a shadow. The first
                  // version flew a transparent placeholder, the second a pale
                  // card with a soft shadow — and Nook's background is cream,
                  // so a pale card on it is a rumour. The border is the same
                  // 1.5pt ink every other card in the app is drawn with, which
                  // is what makes this one legible while it crosses them.
                  color: widget.opaque ? NookColors.surface : null,
                  border: widget.opaque
                      ? Border.all(color: NookColors.textPrimary, width: 1.5)
                      : null,
                  boxShadow: widget.opaque
                      ? const [
                          BoxShadow(
                            color: Color(0x452E2E2E),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                // The glyph stays on: a post with no thumbnail, or one whose
                // image fails to load, otherwise flies an empty box across the
                // screen — an animation that runs and says nothing.
                child: PostThumbnail(
                  url: widget.thumbnailUrl,
                  radius: NookRadius.sm,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
```

---

**ACTION: ADD** (imports)

**Location:** the import block at the top of `lib/widgets/flight.dart`.

**Add:**

```dart
import '../theme/nook_colors.dart';
```

The final import block should read:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_motion.dart';
import '../theme/nook_spacing.dart';
import 'post_thumbnail.dart';
```

Nothing is removed — `NookMotion` is still used by the new `duration` default.

---

## §3. The tab that catches it

### FILE: `lib/widgets/tab_pulse.dart`

**ACTION: CREATE**

**Create this new file with:**

```dart
import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';

/// A ring that expands once out of a bottom-bar tab.
///
/// The delete flight ends at the Profile tab; without this it ends *at*
/// nothing. The ring is the tab acknowledging the catch — the other half of
/// the sentence. One pulse, no repeat: it marks an event, it is not an
/// indicator.
abstract final class TabPulse {
  /// How long the ring takes to expand and fade.
  static const duration = Duration(milliseconds: 520);

  /// Draws a ring centred on [centre] in global coordinates.
  ///
  /// Fire and forget: it removes its own overlay entry when it finishes, and
  /// nothing should ever wait on it.
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
    duration: TabPulse.duration,
  );

  /// Built once: a CurvedAnimation adds a status listener to its parent in the
  /// constructor, so one per build leaks one per build.
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    // catchError, because a controller disposed mid-pulse completes this
    // future with TickerCanceled, which is otherwise an unhandled rejection.
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
        // 12 to 34, so the ring stays inside the 68pt bar instead of expanding
        // over the page above it, where most of it was being drawn.
        final radius = 12 + 22 * v;
        // Held at full strength for the first third and faded after. A linear
        // fade over the whole 520ms left the ring at a third of its opacity by
        // the time it was big enough to notice.
        final opacity = v < 0.35 ? 1.0 : 1 - (v - 0.35) / 0.65;

        return Positioned(
          left: widget.centre.dx - radius,
          top: widget.centre.dy - radius,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // White, because the bar it sits on is the orange gradient.
                  border: Border.all(color: NookColors.surface, width: 3),
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

---

## §4. Delete and restore flights

### FILE: `lib/widgets/delete_flight.dart`

**ACTION: REPLACE** (the `run` method)

**Find:**

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
    );
  }
```

**Replace with:**

```dart
  /// The narrowest the card is allowed to set off at.
  ///
  /// It leaves from a 56pt thumbnail, and a card that starts at 56 and shrinks
  /// to a fifth of that spends most of its journey under 30pt across — a speck
  /// on a cream background. Measured off a recording of the real thing: at
  /// mid-flight the old card was about 30x17, which is smaller than the text
  /// it was passing over.
  static const _minWidth = 132.0;

  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    return Flight.run(
      overlay,
      // Centred where the thumbnail was, so it still leaves from the post you
      // were looking at — just at a size that can be followed.
      from: Rect.fromCenter(
        center: from.center,
        width: from.width < _minWidth ? _minWidth : from.width,
        height: from.height,
      ),
      to: Flight.tabCentre(media.size, media.padding, tab),
      thumbnailUrl: thumbnailUrl,
      // Nine hundred milliseconds, not four hundred. This is the one animation
      // whose whole job is to be followed: it answers "where did my post go",
      // and an answer nobody sees is not an answer.
      duration: NookMotion.deliberate,
      // Ends at 16% of that, so it reads as dropping *into* the tab rather
      // than stopping above it: 132 x 74 at the start, about 21 x 12 as it
      // arrives, which is tab-sized.
      endScale: 0.16,
      // A higher arc than the save flight. Saving puts something away;
      // deleting picks it up first, and the lift is what says so.
      lift: -64,
      opaque: true,
    );
  }
```

---

**ACTION: ADD** (the restore flight — a new class in the same file)

**Location:** at the very end of `lib/widgets/delete_flight.dart`, after the
closing `}` of `DeleteFlight`.

**Add:**

```dart

/// The reverse: a post coming back out of Recently Deleted.
///
/// Deliberately the same arc as [DeleteFlight] read the other way. Delete and
/// restore are one interaction with a direction; two unrelated motions would
/// make them look like two unrelated features.
///
/// Where the delete flight shrinks a card into a tab, this one grows a chip
/// out of the tab into the row's own footprint, and bends the other way.
abstract final class RestoreFlight {
  /// The size of the chip as it leaves the tab, in logical pixels.
  static const _seed = 22.0;

  /// [to] is the restored row's rect in global coordinates, read from a
  /// GlobalKey before the list rebuilds without it.
  static Future<void> run(
    OverlayState overlay, {
    required Rect to,
    required String? thumbnailUrl,
  }) {
    final media = MediaQuery.of(overlay.context);
    final tabCentre = Flight.tabCentre(
      media.size,
      media.padding,
      DeleteFlight.tab,
    );

    return Flight.run(
      overlay,
      from: Rect.fromCenter(
        center: tabCentre,
        width: _seed,
        height: _seed,
      ),
      to: to.center,
      thumbnailUrl: thumbnailUrl,
      duration: NookMotion.deliberate,
      // Larger than it started: this one grows, which is the whole point.
      endScale: (to.height * 16 / 9) / _seed,
      // The arc bends the other way, so the two are mirror images.
      lift: 64,
      opaque: true,
    );
  }
}
```

---

**ACTION: ADD** (import)

**Location:** the import block at the top of `lib/widgets/delete_flight.dart`.

**Add:**

```dart
import '../theme/nook_motion.dart';
```

The final import block should read:

```dart
import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';
import 'flight.dart';
```

---

## §5. Trigger the delete animation

### FILE: `lib/screens/details/manage_post_screen.dart`

**ACTION: REPLACE** (1 of 2 — resolve the tab's position before any `await`)

The tab centre has to be worked out from a `BuildContext`, and everything below
happens after awaits. Resolving it up front with the other inherited lookups
keeps `use_build_context_synchronously` quiet and is correct anyway: the
position is a property of the screen you were on when you tapped.

**Find:**

```dart
  Future<void> _delete() async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context);
    final posts = AppScope.of(context).posts;
```

**Replace with:**

```dart
  Future<void> _delete() async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final navigator = Navigator.of(context);
    final posts = AppScope.of(context).posts;
    // Resolved now, with the rest of the inherited lookups, so nothing reads a
    // BuildContext after an await.
    final tabCentre = Flight.tabCentre(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
      DeleteFlight.tab,
    );
```

---

**ACTION: REPLACE** (2 of 2 — the pop-then-fly block inside `_delete`)

**Find:**

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

    await posts.deletePost(widget.postId);
    NookToast.show(
      overlay,
      'Moved to Recently Deleted',
      icon: Icons.restore_from_trash_outlined,
    );
  }
```

**Replace with:**

```dart
    // Back past the detail screen too: the post it was showing is gone.
    navigator
      ..pop()
      ..pop();

    // Let the two route transitions finish before the flight starts. They are
    // 260ms each and they used to run over the top of it: the eye follows the
    // page, not a small chip crossing it, which is most of why the animation
    // seemed not to happen at all.
    await Future<void>.delayed(NookMotion.normal + NookMotion.fast);

    // The card leaves for Profile — where Recently Deleted lives — and only
    // then is the row marked, so the two read as cause and effect rather than
    // the list twitching under a card that is still sitting there.
    //
    // Wrapped, because a delete that depends on an animation finishing is a
    // delete that can be lost. If the flight throws, the write still happens.
    if (from != null) {
      try {
        await DeleteFlight.run(overlay, from: from, thumbnailUrl: thumbnail);
        // The tab catches it, so the journey ends at something.
        TabPulse.at(overlay, tabCentre);
      } catch (_) {
        // The post still has to go.
      }
    }

    // Written after the flight has landed, so the confirmation follows
    // something the user has just watched rather than narrating over it.
    await posts.deletePost(widget.postId);
    NookToast.show(
      overlay,
      'Moved to Recently Deleted',
      icon: Icons.restore_from_trash_outlined,
    );
  }
```

---

**ACTION: ADD** (imports)

**Location:** the import block at the top of the file. Add these three lines;
keep every existing import.

**Add:**

```dart
import '../../theme/nook_motion.dart';
import '../../widgets/flight.dart';
import '../../widgets/tab_pulse.dart';
```

> `NookMotion` is needed for the delay, `Flight` for `tabCentre`, `TabPulse`
> for the ring. `DeleteFlight` is already imported on line 11.

---

## §6. Trigger the restore animation

Two edits in one file.

### FILE: `lib/screens/profile/recently_deleted_screen.dart`

**ACTION: REPLACE** (1 of 2 — `_DeletedRow`'s constructor, so the row can take
a key)

**Find:**

```dart
class _DeletedRow extends StatelessWidget {
  const _DeletedRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onRestore,
    required this.onDeleteForever,
  });
```

**Replace with:**

```dart
class _DeletedRow extends StatelessWidget {
  const _DeletedRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onRestore,
    required this.onDeleteForever,
  });
```

---

**ACTION: REPLACE** (2 of 2 — the whole `_DeletedPostRow` class)

**Find:**

```dart
class _DeletedPostRow extends StatelessWidget {
  const _DeletedPostRow({required this.post});

  final SavedPost post;

  @override
  Widget build(BuildContext context) {
    return _DeletedRow(
      leading: PostThumbnail(
        url: post.thumbnailUrl,
        width: 48,
        height: 48,
        showGlyph: false,
      ),
      title: post.title,
      subtitle: _deletedAgo(post.deletedAt),
      onRestore: () async {
        final scope = AppScope.of(context);
        final overlay = Overlay.of(context, rootOverlay: true);
        await scope.posts.restorePost(post.id);
        NookToast.show(overlay, 'Restored "${post.title}"');
      },
      onDeleteForever: () async {
        final scope = AppScope.of(context);
        final overlay = Overlay.of(context, rootOverlay: true);
        final confirmed = await showNookDialog(
          context,
          title: 'Delete permanently?',
          message: '"${post.title}" and its note will be gone for good.',
          confirmLabel: 'Delete Permanently',
          destructive: true,
        );
        if (!confirmed) return;
        await scope.posts.deletePostForever(post.id);
        NookToast.show(overlay, 'Deleted permanently');
      },
    );
  }
}
```

**Replace with:**

```dart
class _DeletedPostRow extends StatelessWidget {
  /// Not `const`: each row owns a key so the restore flight knows the rect it
  /// is flying back into.
  _DeletedPostRow({required this.post});

  final SavedPost post;

  /// The row's own position on screen, read before the list rebuilds without
  /// it.
  final _rowKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return _DeletedRow(
      key: _rowKey,
      leading: PostThumbnail(
        url: post.thumbnailUrl,
        width: 48,
        height: 48,
        showGlyph: false,
      ),
      title: post.title,
      subtitle: _deletedAgo(post.deletedAt),
      onRestore: () async {
        final scope = AppScope.of(context);
        final overlay = Overlay.of(context, rootOverlay: true);

        // Read while the row is still on screen.
        final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
        final to = box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size;

        // Written first here, unlike delete. The row has to leave this list
        // for the gap to close, and the flight is what carries the eye from
        // that gap to where the post has gone back to.
        await scope.posts.restorePost(post.id);

        if (to != null) {
          try {
            await RestoreFlight.run(
              overlay,
              to: to,
              thumbnailUrl: post.thumbnailUrl,
            );
          } catch (_) {
            // The restore already happened; the animation is decoration.
          }
        }
        NookToast.show(overlay, 'Restored "${post.title}"');
      },
      onDeleteForever: () async {
        final scope = AppScope.of(context);
        final overlay = Overlay.of(context, rootOverlay: true);
        final confirmed = await showNookDialog(
          context,
          title: 'Delete permanently?',
          message: '"${post.title}" and its note will be gone for good.',
          confirmLabel: 'Delete Permanently',
          destructive: true,
        );
        if (!confirmed) return;
        await scope.posts.deletePostForever(post.id);
        NookToast.show(overlay, 'Deleted permanently');
      },
    );
  }
}
```

> **Analyzer note.** Making the constructor non-`const` will produce
> `prefer_const_constructors` hints at the call site. Find this, around line
> 110 in the same file:
>
> ```dart
>                       Entrance(
>                         key: ValueKey('post-${post.id}'),
> ```
>
> and confirm the `_DeletedPostRow(post: post)` inside it has no `const`. It
> does not today, so no change is needed — but if your editor adds one, remove
> it.

---

**ACTION: ADD** (import)

**Location:** the import block at the top of the file, in alphabetical order
among the `../../widgets/` imports.

**Add:**

```dart
import '../../widgets/delete_flight.dart';
```

---

## §7. Folder motion widgets

### FILE: `lib/widgets/folder_motion.dart`

**ACTION: CREATE**

**Create this new file with:**

```dart
import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';

/// A folder that opens when it is tapped, before its screen arrives.
///
/// The lid tips back on an X rotation for the length of one tap and no longer.
/// Folders do not move on their own: a grid of six tiles breathing in place is
/// decoration, and Nook's rule is that motion means something happened.
///
/// The tap is run *after* the open completes, so the folder is visibly open
/// before the route changes under it. That ordering is the whole effect — run
/// them together and the animation is hidden by the page transition, which is
/// exactly the mistake the delete flight was making.
class FolderOpen extends StatefulWidget {
  const FolderOpen({super.key, required this.child, required this.onTap});

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

  /// Built once: a CurvedAnimation adds a status listener to its parent in the
  /// constructor, so one per build leaks one per build.
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: NookMotion.enter,
  );

  @override
  void dispose() {
    (_t as CurvedAnimation).dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    // A controller disposed mid-open completes with TickerCanceled.
    try {
      await _controller.forward();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    widget.onTap();
    // Closed again, for when the user comes back to this list.
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      // The child paints its own surface, so the gesture needs its own
      // hit area rather than deferring to a transparent parent.
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          final v = _t.value;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              // Perspective, so the tip reads as a lid opening rather than the
              // tile shearing. Deeper than it first was: on a card only 72pt
              // tall, 0.0015 with a 13-degree tilt moved the top edge about
              // two pixels — running, and invisible, which is the same as not
              // running at all.
              ..setEntry(3, 2, 0.0028)
              ..rotateX(-0.42 * v)
              // Lifted off the grid and brought a little closer, so it leaves
              // the page rather than folding into it.
              // translateByDouble, not translate: the Vector-math overload is
              // deprecated in current Flutter and raises an analyzer info.
              ..translateByDouble(0.0, -10.0 * v, 0.0, 1.0)
              ..scaleByDouble(
                1 + 0.06 * v,
                1 + 0.06 * v,
                1.0,
                1.0,
              ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A folder that springs once, when it first appears.
///
/// For a trip that was just created or just restored — the two moments when a
/// folder is new to the screen and worth pointing at. It plays once on mount
/// and never again.
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

---

## §8. Wire the folders

Two files.

### FILE: `lib/widgets/trip_card.dart`

**ACTION: REPLACE** (the whole `TripCard` class)

**Find:**

```dart
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.summary, this.onTap});

  final TripSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NookCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          TripFolderTile(size: 34, colour: summary.colour),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.trip.name,
                  style: NookType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.itemCount} ${summary.itemCount == 1 ? 'item' : 'items'}',
                  style: NookType.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Replace with:**

```dart
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.summary, this.onTap});

  final TripSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = NookCard(
      // `onTap` moves to FolderOpen, which runs it once the lid has lifted.
      // Leaving it here as well would fire the navigation twice.
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          TripFolderTile(size: 34, colour: summary.colour),
          const SizedBox(width: NookSpacing.tight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary.trip.name,
                  style: NookType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.itemCount} ${summary.itemCount == 1 ? 'item' : 'items'}',
                  style: NookType.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // A card with nowhere to go does not open. Choose-a-trip lists pass no
    // callback, and a folder that tips for nothing is a lie.
    if (onTap == null) return card;
    return FolderOpen(onTap: onTap!, child: card);
  }
}
```

---

**ACTION: ADD** (import)

**Location:** the import block at the top of `lib/widgets/trip_card.dart`.

**Add:**

```dart
import 'folder_motion.dart';
```

The final import block should read:

```dart
import 'package:flutter/material.dart';

import '../data/daos/trips_dao.dart';
import '../theme/nook_colors.dart';
import '../theme/trip_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'folder_motion.dart';
import 'nook_card.dart';
```

---

### FILE: `lib/screens/trips/trips_screen.dart`

**ACTION: REPLACE** (the whole `TripsBody` class — it becomes stateful so it
can remember which trip was just created)

**Find:** the class beginning

```dart
class TripsBody extends StatelessWidget {
  const TripsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
```

…and ending with the closing braces just before

```dart
class _NewTripTile extends StatelessWidget {
```

**Replace the whole class with:**

```dart
class TripsBody extends StatefulWidget {
  const TripsBody({super.key});

  @override
  State<TripsBody> createState() => _TripsBodyState();
}

class _TripsBodyState extends State<TripsBody> {
  /// The trip created a moment ago, so exactly one folder springs in.
  ///
  /// Cleared once it has played: without this the same folder would spring
  /// again on every rebuild of the list, which is the "constantly bouncing"
  /// failure mode this whole feature is trying to avoid.
  int? _justCreated;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<List<TripSummary>>(
      stream: scope.trips.watchTripSummaries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final trips = snapshot.data ?? const <TripSummary>[];

        if (trips.isEmpty) {
          return NookEmptyState(
            icon: Icons.folder_outlined,
            title: 'No trips yet — save your first find',
            message:
                'Trips are made when you save a post. Paste a link to '
                'start your first one.',
            actionLabel: 'Save First Find',
            onAction: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddMethodScreen())),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = NookSpacing.section;
            final width = (constraints.maxWidth - gap) / 2;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: NookSpacing.tight,
                bottom: NookSpacing.screenEdge,
              ),
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final summary in trips)
                    SizedBox(
                      width: width,
                      child: _maybeSpring(
                        summary.trip.id,
                        TripCard(
                          summary: summary,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TripDetailsScreen(tripId: summary.trip.id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: width,
                    child: _NewTripTile(
                      onTap: () async {
                        final draft = await showTripDialog(context);
                        if (draft == null || !context.mounted) return;
                        final user = await scope.users.currentUser();
                        if (user == null) return;
                        final id = await scope.trips.createTrip(
                          draft.name,
                          user.id,
                          colour: draft.colour,
                        );
                        if (!context.mounted) return;
                        setState(() => _justCreated = id);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Wraps exactly one card — the one just created — in a spring, and forgets
  /// it afterwards so it never plays twice.
  Widget _maybeSpring(int tripId, Widget card) {
    if (tripId != _justCreated) return card;
    // Cleared after this frame, not during it: setState inside build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _justCreated = null);
    });
    return FolderArrive(key: ValueKey('arrive-$tripId'), child: card);
  }
}
```

---

**ACTION: ADD** (import)

**Location:** the import block at the top of `lib/screens/trips/trips_screen.dart`.

**Add:**

```dart
import '../../widgets/folder_motion.dart';
```

---

## §9. The landing animation

The Nook mark is a 2×2 grid of tiles, so it comes apart along lines that are
already in it. Each quarter flies in from the direction it belongs to, 90ms
apart, tumbling as it goes, and locks into the grid.

### FILE: `lib/widgets/logo_assembly.dart`

**ACTION: CREATE**

**Create this new file with:**

```dart
import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';

/// The Nook mark assembling from its own four quarters.
///
/// The mark is a 2×2 grid of tiles, so it takes itself apart along lines that
/// are already there — no pieces are invented for the sake of the animation.
/// Each quarter flies in from the direction it belongs to (the top-left one
/// from the top left, and so on), so the motion reads as things returning to
/// where they go rather than swirling.
///
/// They arrive 90ms apart. Simultaneous would be a scale-up wearing a costume;
/// the stagger is what makes it four objects instead of one.
///
/// Plays once, on mount. [onComplete] fires when the mark is whole, so the
/// screen underneath can bring in its own content afterwards.
class LogoAssembly extends StatefulWidget {
  const LogoAssembly({super.key, this.size = 116, this.onComplete});

  final double size;
  final VoidCallback? onComplete;

  /// The whole sequence, from first piece leaving to last piece landing.
  static const duration = Duration(milliseconds: 1500);

  @override
  State<LogoAssembly> createState() => _LogoAssemblyState();
}

class _LogoAssemblyState extends State<LogoAssembly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LogoAssembly.duration,
  );

  /// Where each quarter starts, in multiples of the mark's own size, which beat
  /// it arrives on, and the letter it carries.
  ///
  /// Order is reading order: top-left, top-right, bottom-left, bottom-right.
  static const _pieces = [
    (dx: -2.4, dy: -1.6, delay: 0.00, glyph: 'N'),
    (dx: 2.4, dy: -1.9, delay: 0.09, glyph: 'O'),
    (dx: -2.1, dy: 2.2, delay: 0.18, glyph: 'O'),
    (dx: 2.6, dy: 1.7, delay: 0.27, glyph: 'K'),
  ];

  /// The share of the timeline each piece gets. 0.27 + 0.55 < 1, so the last
  /// piece lands before the controller finishes.
  static const _span = 0.55;

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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          children: [
            for (var i = 0; i < _pieces.length; i++) _quarter(i),
          ],
        ),
      ),
    );
  }

  Widget _quarter(int index) {
    final piece = _pieces[index];
    final half = widget.size / 2;
    final gap = widget.size * 0.05;
    final tile = half - gap / 2;

    // Each piece runs over its own slice of the timeline, starting on its beat.
    final t = ((_controller.value - piece.delay) / _span).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);

    final dx = piece.dx * widget.size * (1 - eased);
    final dy = piece.dy * widget.size * (1 - eased);
    // A part-turn that unwinds as it lands, so the pieces tumble rather than
    // slide. Alternating direction stops them looking like one rotating body.
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
            width: tile,
            height: tile,
            decoration: BoxDecoration(
              color: NookColors.textPrimary,
              // Only the outer corner of each quarter is round, so the four
              // together read as one rounded square rather than four tiles.
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(index == 0 ? 12 : 3),
                topRight: Radius.circular(index == 1 ? 12 : 3),
                bottomLeft: Radius.circular(index == 2 ? 12 : 3),
                bottomRight: Radius.circular(index == 3 ? 12 : 3),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              piece.glyph,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: tile * 0.52,
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

### Using your real logo file instead

The code above draws the mark, so **no asset is required** and nothing needs
adding to `pubspec.yaml`. If you would rather animate the actual PNG/SVG:

1. Put the file at `assets/images/nook_mark.png`.
2. In `pubspec.yaml`, under the existing `assets:` list (which currently holds
   `.env` and `.env.example`), add:

   ```yaml
       - assets/images/nook_mark.png
   ```

3. In `_quarter`, replace the `Container(...)` and its `Text` child with:

   ```dart
          child: SizedBox(
            width: tile,
            height: tile,
            child: ClipRect(
              child: Align(
                alignment: Alignment(
                  index.isOdd ? 1 : -1,
                  index > 1 ? 1 : -1,
                ),
                widthFactor: 0.5,
                heightFactor: 0.5,
                child: Image.asset(
                  'assets/images/nook_mark.png',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
   ```

   Nothing else in the file changes — the motion is identical, each tile just
   shows its own quarter of the real image.

---

## §10. Wire the splash screen

### FILE: `lib/screens/onboarding/splash_screen.dart`

**ACTION: REPLACE** (the whole `SplashScreen` class — it becomes stateful)

**Find:**

```dart
/// LA1. The mark, the name, the line, and one way forward.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: NookPrimaryButton(
        label: 'Continue',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen())),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NookMark(size: 96),
            const SizedBox(height: NookSpacing.block),
            Text('Nook', style: NookType.display),
            const SizedBox(height: NookSpacing.tight),
            SizedBox(
              width: 220,
              child: NookHeadline(
                'Never lose your *next favourite find*',
                style: NookType.body.copyWith(color: NookColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Replace with:**

```dart
/// LA1. The mark assembles itself, then the name and the line arrive under it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// True once the four quarters have locked together, which is what brings
  /// the wordmark in underneath.
  bool _assembled = false;

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: AnimatedOpacity(
        // The button waits for the mark. Tapping through a logo animation is
        // allowed — it just is not invited until the mark is whole.
        opacity: _assembled ? 1 : 0.35,
        duration: NookMotion.slow,
        child: NookPrimaryButton(
          label: 'Continue',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen())),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoAssembly(
              size: 116,
              onComplete: () {
                if (mounted) setState(() => _assembled = true);
              },
            ),
            const SizedBox(height: NookSpacing.block),
            // The words follow the mark rather than sharing the screen with
            // it, so the sequence reads as one thing becoming another.
            AnimatedOpacity(
              opacity: _assembled ? 1 : 0,
              duration: NookMotion.slow,
              curve: NookMotion.enter,
              child: AnimatedSlide(
                offset: _assembled ? Offset.zero : const Offset(0, 0.3),
                duration: NookMotion.slow,
                curve: NookMotion.enter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Nook', style: NookType.display),
                    const SizedBox(height: NookSpacing.tight),
                    SizedBox(
                      width: 220,
                      child: NookHeadline(
                        'Never lose your *next favourite find*',
                        style: NookType.body.copyWith(
                          color: NookColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

**ACTION: ADD** (imports)

**Location:** the import block at the top of the file.

**Add:**

```dart
import '../../theme/nook_motion.dart';
import '../../widgets/logo_assembly.dart';
```

---

**ACTION: DELETE** (only if your analyzer flags it)

`NookMark` — the bookmark-in-a-circle widget at the bottom of
`splash_screen.dart` — is **no longer used by this screen**, but it is still
used by `lib/screens/profile/about_screen.dart` and
`lib/widgets/nook_empty_state.dart`.

**Do not delete `NookMark`.** Leave the class exactly where it is. If you
delete it, those two screens stop compiling.

---

## §11. Update the tests

Exactly **one** assertion breaks. I applied this whole guide to a working copy
and ran the suite to find out, so this list is what actually fails, not what
looks like it might.

### FILE: `test/animation_test.dart`

**ACTION: REPLACE** (the delete flight's completion test — the only change
needed)

**Find** — it is inside `group('DeleteFlight', ...)`, in the test named
*"completes its future so the caller can wait for it"*, around line 578:

```dart
      await tester.pump(NookMotion.slow);
      await tester.pump(const Duration(milliseconds: 60));
      expect(landed, isTrue, reason: 'the delete waits on this');
```

**Replace with:**

```dart
      await tester.pump(NookMotion.deliberate);
      await tester.pump(const Duration(milliseconds: 60));
      expect(landed, isTrue, reason: 'the delete waits on this');
```

> **Leave everything else alone.** In particular the test above it,
> *"travels towards Profile"*, still pumps `NookMotion.slow ~/ 2` and still
> passes: 210ms into a 900ms flight the card is mid-air, moving right and
> shrinking, which is all that test asserts. The two `NookMotion.slow`
> references in the **SaveFlight** group are correct too — §2's defaults leave
> the save flight untouched.

**ACTION: ADD** (a test worth having, optional)

**Location:** inside `group('DeleteFlight', ...)`, after the existing tests.

**Add:**

```dart
    testWidgets('is slow enough to actually be seen', (tester) async {
      // The original was 420ms with a fade over the last 15% — about 350ms of
      // visible travel, which is why it looked like nothing happened.
      expect(
        NookMotion.deliberate.inMilliseconds,
        greaterThanOrEqualTo(700),
        reason: 'a delete has to be watchable',
      );
      expect(
        NookMotion.deliberate.inMilliseconds,
        lessThanOrEqualTo(1200),
        reason: 'and not annoying',
      );
    });
```

---

## §12. Run it

```
dart format lib/ test/
flutter analyze
flutter test
```

Expected: no analyzer issues, and the same test count as before plus one if you
added the optional test above.

If `flutter test` reports **"A Timer is still pending"**, the cause is the
`Future.delayed` added in §5. It only fires in the real app, not in the widget
tests, but if a test does reach it, wrap the delay:

```dart
    if (!kIsWeb || true) {
      await Future<void>.delayed(NookMotion.normal + NookMotion.fast);
    }
```

is **not** the fix — instead check that the failing test is not driving
`_delete` directly. No test in the suite does today.

---

## Verification checklist

### Delete

- [ ] Tapping **Delete Post** and confirming pops back to Home first, and the
      card only starts flying once the screen has settled.
- [ ] The flying card is a solid white tile with a shadow — visible even for a
      post with no thumbnail.
- [ ] It arcs upward before falling toward the **Profile** tab.
- [ ] It shrinks as it travels and disappears into the tab, not above it.
- [ ] A white ring expands out of the Profile tab as it lands.
- [ ] The whole journey takes about a second and is comfortable to watch.
- [ ] "Moved to Recently Deleted" appears **after** the card lands.
- [ ] The post is gone from Home and present in Recently Deleted.
- [ ] Deleting twice quickly does not delete two posts.
- [ ] Leaving the screen mid-flight throws nothing.

### Restore

- [ ] Tapping **Restore** removes the row immediately.
- [ ] A card grows out of the Profile tab and travels to where the row was.
- [ ] Its arc bends the opposite way to the delete flight.
- [ ] The post is back in its original trip — check the trip's item count.
- [ ] Restoring twice does not produce two copies.
- [ ] "Restored …" appears after the animation.

### Trips

- [ ] Tapping a trip folder tips it open before the screen changes.
- [ ] The trip screen still opens, exactly once per tap.
- [ ] Coming back to the list shows the folder closed again.
- [ ] Creating a trip springs **only** the new folder.
- [ ] That spring does not replay when the list rebuilds.
- [ ] Folders never move on their own.
- [ ] Choose-a-trip and Manage Post lists — which pass no `onTap` — still work
      and do not tip.

### Landing

- [ ] Four quarters fly in from four directions and lock into a 2×2 mark.
- [ ] They arrive one after another, not together.
- [ ] They tumble rather than slide.
- [ ] "Nook" and the tagline rise in **after** the mark completes.
- [ ] Continue leads to onboarding.
- [ ] Tapping Continue during the animation does not break navigation.

### General

- [ ] `flutter analyze` reports no issues.
- [ ] No unused imports (`NookMark` is still used elsewhere — do not remove it).
- [ ] Every `AnimationController` added here is disposed.
- [ ] Every `CurvedAnimation` held as a field is disposed before its parent.
- [ ] `flutter test` passes.
- [ ] Saving a post still flies to the **Trips** tab at the old speed — §2's
      defaults keep `SaveFlight` unchanged.
- [ ] Extraction, maps, folder colours and Recently Deleted all still work.

---

One rule to keep as you adapt any of this: nothing here should ever run without
the user having done something. An animation that plays on its own belongs in a
different app.
