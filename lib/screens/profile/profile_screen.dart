import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_scaffold.dart';
import '../onboarding/profile_setup_screen.dart';
import 'about_screen.dart';
import 'account_screen.dart';
import 'connected_platforms_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

/// P1.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.nav});

  final Widget nav;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return NookScaffold(
      bottomNav: nav,
      child: StreamBuilder<User?>(
        stream: scope.users.watchCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          return ListView(
            children: [
              const SizedBox(height: NookSpacing.section),
              Text('Profile', style: NookType.title),
              const SizedBox(height: NookSpacing.block),
              Center(child: ProfileAvatar(picture: user?.profilePicture)),
              const SizedBox(height: NookSpacing.section),
              Center(
                child: Text(
                  user?.name ?? '',
                  style: NookType.display,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  user?.email ?? '',
                  style: NookType.body.copyWith(color: NookColors.textMuted),
                ),
              ),
              const SizedBox(height: NookSpacing.block),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      stream: scope.posts.watchPostCount(),
                      label: 'Saved Posts',
                    ),
                  ),
                  const SizedBox(width: NookSpacing.section),
                  Expanded(
                    child: _StatTile(
                      stream: scope.trips.watchTripCount(),
                      // Relabelled from "collections" with the Trips reframing.
                      label: 'Trips',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NookSpacing.block),
              _ProfileRow(
                label: 'Account',
                onTap: () => _open(context, const AccountScreen()),
              ),
              _ProfileRow(
                label: 'Settings',
                onTap: () => _open(context, const SettingsScreen()),
              ),
              _ProfileRow(
                label: 'Connected Platforms',
                onTap: () => _open(context, const ConnectedPlatformsScreen()),
              ),
              _ProfileRow(
                label: 'About Nook',
                onTap: () => _open(context, const AboutScreen()),
              ),
              _ProfileRow(
                label: 'Help & Support',
                onTap: () => _open(context, const HelpScreen()),
              ),
            ],
          );
        },
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stream, required this.label});

  final Stream<int> stream;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: NookSpacing.section),
      decoration: BoxDecoration(
        color: NookColors.surface,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: NookColors.border),
      ),
      child: Column(
        children: [
          StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) => Text(
              '${snapshot.data ?? 0}',
              style: NookType.display,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: NookType.body.copyWith(color: NookColors.textMuted)),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: NookSpacing.row),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: NookType.body),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NookColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
