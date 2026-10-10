import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/database.dart';
import 'share/shared_link.dart';
import 'screens/add/paste_link_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/root_shell.dart';
import 'widgets/logo_assembly.dart';
import 'theme/nook_colors.dart';
import 'theme/nook_theme.dart';

class NookApp extends StatelessWidget {
  const NookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nook',
      debugShowCheckedModeBanner: false,
      theme: NookTheme.theme,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      home: const _LaunchGate(),
    );
  }
}

/// Decides where launch lands.
///
/// There is no sign-in: storage is on the device, so there is no server to sign
/// in to. The only question is whether this device has a local profile — if it
/// does, straight to Home; if not, onboarding and then Set Up Profile.
///
/// "Has a profile" means a row with a *name* in it. The seeded demo library
/// needs a user row for its trips to point at, so a row exists from first
/// launch and its presence alone cannot be the test.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  /// A link another app shared into Nook, waiting for the shell to exist.
  ///
  /// Read once and cleared from the address bar immediately, so a reload cannot
  /// save the same post twice. Opened after the first frame, because there is
  /// no Navigator to push the add flow onto until the shell is mounted.
  String? _shared;

  @override
  void initState() {
    super.initState();
    _shared = SharedLink.initial();
    if (_shared != null) SharedLink.consume();
  }

  void _openShared() {
    final url = _shared;
    if (url == null) return;
    _shared = null;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PasteLinkScreen(sharedUrl: url)));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<User?>(
      stream: scope.users.watchCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Opening();
        }
        if (snapshot.hasError) return _StorageUnavailable(error: snapshot.error);
        final user = snapshot.data;
        final needsSetup = user == null || user.name.trim().isEmpty;
        if (needsSetup) return const SplashScreen();

        // Only once there is a profile and a shell: a share that arrives on a
        // first-ever launch waits behind onboarding rather than dropping the
        // person into a save flow before they have told Nook their name.
        if (_shared != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => mounted ? _openShared() : null,
          );
        }
        return const RootShell();
      },
    );
  }
}

/// The moment before the first query answers.
///
/// It used to be an empty [Scaffold]. On a desktop that is a plain coloured
/// rectangle, and on a browser that will not open the database — a second tab
/// already holding the lock, or storage refused outright — it is where the app
/// stays, which reads as a page that loaded and then ignored every click. The
/// mark says the app is alive, and [_StorageUnavailable] says so in words if
/// the wait turns out to be permanent.
class _Opening extends StatefulWidget {
  const _Opening();

  @override
  State<_Opening> createState() => _OpeningState();
}

class _OpeningState extends State<_Opening> {
  /// Long enough that nobody sees it on a working browser, short enough to
  /// beat the patience of someone who thinks the app has died.
  static const _patience = Duration(seconds: 8);

  Timer? _giveUp;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _giveUp = Timer(_patience, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_slow) return const _StorageUnavailable();
    return const _LaunchBackdrop(child: LogoAssembly(size: 96));
  }
}

/// Shown when the device's storage cannot be opened.
///
/// Nook keeps everything on the device, so there is no version of the app that
/// runs without it. Saying that plainly is better than a screen that looks
/// finished and answers nothing.
class _StorageUnavailable extends StatelessWidget {
  const _StorageUnavailable({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return _LaunchBackdrop(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoAssembly(size: 72),
            const SizedBox(height: 24),
            Text(
              'Nook cannot reach this device\u2019s storage.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Everything Nook saves lives on the device, so it needs storage '
              'to start. Close any other tab with Nook open and reload. In a '
              'private window, allow site data.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NookColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaunchBackdrop extends StatelessWidget {
  const _LaunchBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: NookColors.screenGradient),
        child: Center(child: child),
      ),
    );
  }
}
