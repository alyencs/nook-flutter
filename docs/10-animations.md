# Animations — manual integration guide

Everything in this file is **not** in the repository. You asked for the
animation work as instructions rather than commits, so this is the whole of it:
what to create, what to change, and what to paste.

No new dependencies. Every animation below uses `flutter/animation.dart`, which
is already available through `package:flutter/material.dart`.

Read the first section before the rest — it defines the durations and curves the
others use, and it is the only file you must add for the others to compile.

---

## Contents

| # | Animation | New file? | Files to edit |
|---|---|---|---|
| 1 | Motion tokens | **Create** `lib/theme/nook_motion.dart` | — |
| 2 | Button press | **Create** `lib/widgets/press_effect.dart` | `lib/widgets/nook_buttons.dart` |
| 3 | Card entrance | **Create** `lib/widgets/entrance.dart` | `lib/screens/home/home_screen.dart` |
| 4 | Save → flies to Trips | **Create** `lib/widgets/save_flight.dart` | `lib/screens/add/review_save_screen.dart` |
| 5 | Page transitions | — | `lib/theme/nook_theme.dart` |
| 6 | Map pin drop | — | `lib/widgets/post_map.dart` |
| 7 | Toggle | — | `lib/screens/profile/settings_screen.dart` |
| 8 | Thumbnail fade-in | — | `lib/widgets/post_thumbnail.dart` |
| 9 | Analysis progress | — | `lib/screens/add/paste_link_screen.dart` |

---

## 1. Motion tokens

Create **`lib/theme/nook_motion.dart`**. Every other section imports this, so add
it first.

```dart
import 'package:flutter/widgets.dart';

/// Durations and curves, in one place.
///
/// The same reasoning as `NookSpacing` and `NookType`: a dozen screens each
/// picking their own 180ms-ish easing is how motion stops reading as one system.
///
/// Nook's motion is quick and slightly eased-out — things arrive and settle
/// rather than bounce. Nothing here is longer than 420ms, because an animation
/// you notice waiting for is a slower app.
abstract final class NookMotion {
  /// A press, a toggle, a ripple. Barely perceived.
  static const fast = Duration(milliseconds: 140);

  /// The default: entrances, fades, a page change.
  static const normal = Duration(milliseconds: 260);

  /// Something travelling across the screen.
  static const slow = Duration(milliseconds: 420);

  /// Arrivals. Fast at the start, settling at the end.
  static const enter = Curves.easeOutCubic;

  /// Departures.
  static const exit = Curves.easeInCubic;

  /// A press going down and coming back.
  static const press = Curves.easeOut;

  /// The gap between consecutive items in a staggered list.
  static const stagger = Duration(milliseconds: 45);

  /// How far a card travels as it fades in, in logical pixels.
  static const enterOffset = 14.0;
}
```

---

## 2. Button press

**Create `lib/widgets/press_effect.dart`:**

```dart
import 'package:flutter/widgets.dart';

import '../theme/nook_motion.dart';

/// Scales its child down while it is held.
///
/// Wraps rather than replaces the gesture handling underneath: the child keeps
/// its own `InkWell`, its own `onTap`, and its own semantics. This only listens.
class PressEffect extends StatefulWidget {
  const PressEffect({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
  });

  final Widget child;
  final bool enabled;

  /// 0.97 for a full-width button. Go no lower than 0.94 or it reads as a
  /// wobble rather than a press.
  final double scale;

  @override
  State<PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<PressEffect> {
  bool _down = false;

  void _set(bool value) {
    if (!widget.enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Listener, not GestureDetector: it observes the pointer without
      // entering the gesture arena, so the InkWell inside still wins the tap.
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: NookMotion.fast,
        curve: NookMotion.press,
        child: widget.child,
      ),
    );
  }
}
```

**Edit `lib/widgets/nook_buttons.dart`.**

Add the import at the top:

```dart
import 'press_effect.dart';
```

In `NookPrimaryButton.build`, find the `return Semantics(` and the `child:
DecoratedBox(` immediately under it:

```dart
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: DecoratedBox(
```

Replace those five lines with:

```dart
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: PressEffect(
        enabled: enabled,
        child: DecoratedBox(
```

Then find the closing of that widget — the tail of the method reads:

```dart
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Add one more `),` before the final `);` so the parentheses balance:

```dart
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
```

> If the analyzer complains about brackets, the rule is simply: `PressEffect`
> adds one level of nesting, so it needs one extra closing paren.

Do the same in `NookSecondaryButton.build`: wrap its `child: Material(` in
`PressEffect(child: …)` and add the matching paren.

---

## 3. Card entrance

**Create `lib/widgets/entrance.dart`:**

```dart
import 'package:flutter/widgets.dart';

import '../theme/nook_motion.dart';

/// Fades and lifts its child in, once, when it first appears.
///
/// [index] staggers a list: pass the item's position and each one starts a
/// beat after the one before. Cap the stagger — past about six items the last
/// card arrives long after the screen looks finished.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStaggered = 6,
  });

  final Widget child;
  final int index;
  final int maxStaggered;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.normal,
  );

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, widget.maxStaggered);
    Future<void>.delayed(NookMotion.stagger * steps, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: NookMotion.enter,
    );
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, NookMotion.enterOffset * (1 - curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
```

**Edit `lib/screens/home/home_screen.dart`.**

Import it:

```dart
import '../../widgets/entrance.dart';
```

Find the Recent Saves carousel — the `ListView.separated` (or `ListView`) whose
`itemBuilder` returns a `SavedPostCard`. Its builder currently looks roughly
like:

```dart
itemBuilder: (context, index) => SavedPostCard(
  post: posts[index],
  onTap: () => ...,
),
```

Wrap the returned card:

```dart
itemBuilder: (context, index) => Entrance(
  index: index,
  child: SavedPostCard(
    post: posts[index],
    onTap: () => ...,
  ),
),
```

Do the same for the Your Trips grid and the Recently Viewed list if you want
them to stagger too. **Do not** wrap every widget on the screen — the greeting
and the search bar should be there the instant the screen is.

---

## 4. Save → the post flies to Trips

This is the one you singled out. When a post is saved, its thumbnail lifts off
the Review screen and travels down to the Trips tab in the bottom bar, shrinking
as it goes, and the tab pulses when it lands.

**Create `lib/widgets/save_flight.dart`:**

```dart
import 'package:flutter/material.dart';

import '../theme/nook_motion.dart';
import '../theme/nook_spacing.dart';
import 'post_thumbnail.dart';

/// Flies a post's thumbnail from where it sits to the Trips tab.
///
/// Runs in the root overlay, above everything, so it survives the route being
/// popped underneath it — which is exactly what happens on save. Nothing waits
/// for it: the save has already been written by the time this starts, and the
/// flight is a statement about what happened, not part of doing it.
abstract final class SaveFlight {
  /// The Trips tab's centre on a 390pt-wide phone, measured from the bottom.
  /// The bottom bar is 68pt tall plus the safe area; the second of four tabs
  /// sits at three eighths of the width.
  static Offset _destination(Size screen, EdgeInsets padding) => Offset(
        screen.width * 0.375,
        screen.height - padding.bottom - 34,
      );

  /// [from] is the thumbnail's rect in global coordinates. Get it with a
  /// GlobalKey on the thumbnail — see the integration note below.
  static Future<void> run(
    OverlayState overlay, {
    required Rect from,
    required String? thumbnailUrl,
  }) async {
    final media = MediaQuery.of(overlay.context);
    final to = _destination(media.size, media.padding);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Flight(
        from: from,
        to: to,
        thumbnailUrl: thumbnailUrl,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

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

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.slow,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _controller, curve: NookMotion.enter);

    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        // An arc rather than a straight line: it lifts slightly before it
        // falls, which reads as "picked up and put away" instead of "dragged".
        final x = widget.from.center.dx +
            (widget.to.dx - widget.from.center.dx) * v;
        final lift = -28 * (1 - (2 * v - 1) * (2 * v - 1));
        final y = widget.from.center.dy +
            (widget.to.dy - widget.from.center.dy) * v +
            lift;
        final size = widget.from.width * (1 - 0.72 * v);

        return Positioned(
          left: x - size / 2,
          top: y - size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: v < 0.85 ? 1 : (1 - v) / 0.15,
              child: SizedBox(
                width: size,
                height: size * 9 / 16,
                child: PostThumbnail(
                  url: widget.thumbnailUrl,
                  radius: NookRadius.sm,
                  showGlyph: false,
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

**Edit `lib/screens/add/review_save_screen.dart`.**

Imports:

```dart
import '../../widgets/save_flight.dart';
```

Add a key field to `_ReviewSaveScreenState`, just under `bool _saving = false;`:

```dart
  /// The thumbnail's position, so the flight knows where to start.
  final _thumbKey = GlobalKey();
```

Attach it to the thumbnail. Find:

```dart
                      PostThumbnail(
                        url: draft.thumbnailUrl,
                        width: 72,
                        height: 72,
                        showGlyph: false,
                      ),
```

and replace with:

```dart
                      PostThumbnail(
                        key: _thumbKey,
                        url: draft.thumbnailUrl,
                        width: 72,
                        height: 72,
                        showGlyph: false,
                      ),
```

Then in `_save()`, find these two lines near the end:

```dart
    navigator.popUntil((route) => route.isFirst);
    showToastAfterPop(overlay, 'Saved "${draft.title}"');
```

and replace them with:

```dart
    // The rect is read before the pop, while the widget is still on screen.
    final box = _thumbKey.currentContext?.findRenderObject() as RenderBox?;
    final from = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    navigator.popUntil((route) => route.isFirst);

    if (from != null) {
      SaveFlight.run(overlay, from: from, thumbnailUrl: draft.thumbnailUrl);
    }
    showToastAfterPop(overlay, 'Saved "${draft.title}"');
```

**How it connects to what is already there:** `overlay` is the
`OverlayState` the save flow already captures before its awaits (added when the
toasts moved to the top of the screen), so there is nothing new to resolve and
no new lifecycle risk. The save itself is already committed by this point — the
flight is decoration over a finished action, and if it never runs the post is
still saved.

---

## 5. Page transitions

**Edit `lib/theme/nook_theme.dart`.** Inside the `ThemeData(...)`, add:

```dart
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // One transition on every platform, so the app moves the same way in
          // a browser as it does on a phone. The default on web is no
          // transition at all, which is what makes the flow feel like a slide
          // deck rather than an app.
          TargetPlatform.android: _NookPageTransition(),
          TargetPlatform.iOS: _NookPageTransition(),
          TargetPlatform.macOS: _NookPageTransition(),
          TargetPlatform.windows: _NookPageTransition(),
          TargetPlatform.linux: _NookPageTransition(),
          TargetPlatform.fuchsia: _NookPageTransition(),
        },
      ),
```

and at the bottom of the same file:

```dart
/// A short slide-and-fade from the right.
class _NookPageTransition extends PageTransitionsBuilder {
  const _NookPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: NookMotion.enter,
      reverseCurve: NookMotion.exit,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}
```

Add `import 'nook_motion.dart';` to that file.

---

## 6. Map pin drop

**Edit `lib/widgets/post_map.dart`.** Find `class _Pin extends StatelessWidget`
and change it to a `StatefulWidget` that drops in:

```dart
class _Pin extends StatefulWidget {
  const _Pin();

  @override
  State<_Pin> createState() => _PinState();
}

class _PinState extends State<_Pin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NookMotion.slow,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // elasticOut on the way down only: the pin falls in and settles, which
    // draws the eye to the location without the map itself moving.
    final drop = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    return AnimatedBuilder(
      animation: drop,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -26 * (1 - drop.value)),
        child: Opacity(
          opacity: _controller.value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: /* the existing _Pin build() body goes here, unchanged */,
    );
  }
}
```

Copy the body of the old `_Pin.build` into the `child:` slot. Add
`import '../theme/nook_motion.dart';` at the top.

---

## 7. Settings toggles

**Edit `lib/screens/profile/settings_screen.dart`.** In `_SwitchRow.build`, wrap
the `Switch` so the whole row responds, not just the thumb:

```dart
          AnimatedContainer(
            duration: NookMotion.fast,
            curve: NookMotion.press,
            child: Switch(
              value: value,
              onChanged: onChanged,
              // ...keep every existing colour argument exactly as it is...
            ),
          ),
```

Flutter's `Switch` already animates its thumb; what this adds is the row
settling with it. Add `import '../../theme/nook_motion.dart';`.

---

## 8. Thumbnail fade-in

**Edit `lib/widgets/post_thumbnail.dart`.** Find:

```dart
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
```

Replace with:

```dart
      // Fades from the placeholder to the image rather than snapping. A grid of
      // cards popping in one by one is the most visible jank on Home.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: NookMotion.normal,
          curve: NookMotion.enter,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
```

Add `import '../theme/nook_motion.dart';`.

---

## 9. Analysis progress

**Edit `lib/screens/add/paste_link_screen.dart`.** In `_AnalysisProgress.build`,
find the stage `Text`:

```dart
              Expanded(
                child: Text('$stage…', style: NookType.bodyStrong),
              ),
```

and replace with:

```dart
              Expanded(
                child: AnimatedSwitcher(
                  duration: NookMotion.fast,
                  // Keyed on the text, so each new stage cross-fades with the
                  // one before instead of the label changing under you.
                  child: Text(
                    '$stage…',
                    key: ValueKey(stage),
                    style: NookType.bodyStrong,
                  ),
                ),
              ),
```

Add `import '../../theme/nook_motion.dart';`.

---

## After integrating

```bash
flutter analyze
flutter test
```

The existing suite is the guard here. Three things to watch for, because they
are what animation work usually breaks:

- **Pending timers.** Any `Timer` or delayed `Future` must be cancelled in
  `dispose()`. `Entrance` uses a delayed future guarded by `mounted`; a
  controller you forget to dispose will fail a test with "A Ticker was being
  disposed".
- **`test/layout_test.dart`** draws every screen at 390×844 and fails on an
  overflow. A `Transform.scale` does not change layout, so `PressEffect` is
  safe; anything that changes a size is not.
- **`test/save_flow_race_test.dart`** leaves and re-enters screens mid-flight.
  If you add a controller to a screen in that flow, it must survive being
  disposed while its animation is running.

For the save flight specifically, `pumpAndSettle` in a widget test will wait for
the 420ms flight. That is fine — it is the reason the flight is bounded and
short.
