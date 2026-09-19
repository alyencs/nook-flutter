import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/database.dart';
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
class _LaunchGate extends StatelessWidget {
  const _LaunchGate();

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
        return needsSetup ? const SplashScreen() : const RootShell();
      },
    );
  }
}
