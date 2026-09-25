import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/database.dart';
import 'share/shared_link.dart';
import 'screens/add/paste_link_screen.dart';
import 'screens/onboarding/splash_screen.dart';
import 'screens/root_shell.dart';
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
/// There is no sign-in to perform — the storage decision means there is no
/// server to sign in to. The only question is whether this device has a local
/// profile yet: if it does, straight to Home; if not, the onboarding run
/// (LA1-LA6) followed by Set Up Profile (LO1).
///
/// "Has a profile" means a row with a name in it. The seeded demo library needs
/// a user row for its trips to point at, so a row exists from first launch; if
/// its presence alone counted, onboarding would never be reachable.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  /// A link another app shared into Nook, waiting for the shell to exist.
  ///
  /// Read once, at launch, and cleared from the address bar immediately so a
  /// reload cannot save the same post twice. It is opened after the first
  /// frame, because the add flow is a pushed route and there is no Navigator
  /// to push onto until the shell is mounted.
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PasteLinkScreen(sharedUrl: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<User?>(
      stream: scope.users.watchCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final user = snapshot.data;
        final needsSetup = user == null || user.name.trim().isEmpty;
        if (needsSetup) return const SplashScreen();

        // Only once there is a profile and a shell: a share that arrives on a
        // first-ever launch waits behind onboarding rather than dropping the
        // person into a save flow before they have told Nook their name.
        if (_shared != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => mounted ? _openShared() : null);
        }
        return const RootShell();
      },
    );
  }
}
