import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_scaffold.dart';

/// P3.
///
/// The four switches are drawn as the mockup draws them and do not change
/// behaviour — they describe features this build does not have. The Data
/// section underneath is real: clearing search history and resetting the demo
/// library both act on the database.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _switches = <String, bool>{
    'Auto-categorize saves': true,
    'Show category suggestions': true,
    'Paste detection': true,
    'Save confirmation': false,
  };

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return NookScaffold(
      child: ListView(
        children: [
          const NookAppBar(title: 'Settings'),
          const SizedBox(height: NookSpacing.section),
          const _AiStatusCard(),
          const SizedBox(height: NookSpacing.screenEdge),
          for (final entry in _switches.entries) ...[
            _SwitchRow(
              label: entry.key,
              value: entry.value,
              onChanged: (value) =>
                  setState(() => _switches[entry.key] = value),
            ),
            const Divider(),
          ],
          const SizedBox(height: NookSpacing.screenEdge),
          Text('Data', style: NookType.title),
          const SizedBox(height: NookSpacing.tight),
          _DataRow(
            label: 'Clear Search History',
            onTap: () async {
              await scope.searches.clear();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search history cleared')),
              );
            },
          ),
          _DataRow(
            label: 'Reset Demo Data',
            onTap: () async {
              final confirmed = await showNookDialog(
                context,
                title: 'Reset to the demo library?',
                message: 'Everything you have saved on this device is replaced '
                    'with the sample trips and posts Nook ships with.',
                confirmLabel: 'Reset',
                destructive: true,
              );
              if (!confirmed || !context.mounted) return;
              await scope.db.resetToSeed();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Demo data restored')),
              );
            },
          ),
          _DataRow(
            label: 'Clear All Data',
            onTap: () async {
              final confirmed = await showNookDialog(
                context,
                title: 'Clear everything?',
                message: 'Your profile, posts and trips are erased from this '
                    'device. Nothing is stored anywhere else.',
                confirmLabel: 'Clear everything',
                destructive: true,
              );
              if (!confirmed || !context.mounted) return;
              await scope.db.clearAll();
            },
          ),
        ],
      ),
    );
  }
}

/// Whether destination detection is running on Gemini or on sample data.
///
/// Worth a place on screen rather than only in the README: the difference is
/// invisible until you save something, and "why is it giving me Kyoto for an
/// Osaka link" has exactly one answer.
class _AiStatusCard extends StatelessWidget {
  const _AiStatusCard();

  @override
  Widget build(BuildContext context) {
    final live = AppScope.of(context).extractor.isLive;

    return Container(
      padding: const EdgeInsets.all(NookSpacing.section),
      decoration: BoxDecoration(
        color: live ? NookColors.surface : NookColors.secondary,
        borderRadius: BorderRadius.circular(NookRadius.md),
        border: Border.all(color: live ? NookColors.border : NookColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                live ? Icons.auto_awesome : Icons.science_outlined,
                size: 20,
                color: NookColors.primary,
              ),
              const SizedBox(width: NookSpacing.tight),
              Expanded(
                child: Text(
                  live ? 'Detection: Gemini' : 'Detection: sample data',
                  style: NookType.bodyStrong.copyWith(fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            live
                ? 'Saved links are read by Gemini using the key in your .env '
                    'file. Destinations, categories, summaries and coordinates '
                    'come back from the model.'
                : 'No GEMINI_API_KEY was found, so saved links get illustrative '
                    'details instead. To use the real thing, put your key in a '
                    '.env file at the root of the project and restart the app.',
            style: NookType.body.copyWith(
              fontSize: 14,
              color: NookColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NookSpacing.tight),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: NookType.body.copyWith(fontSize: 18)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: NookColors.surface,
            activeTrackColor: NookColors.textPrimary,
            inactiveThumbColor: NookColors.surface,
            inactiveTrackColor: NookColors.border,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: NookType.body.copyWith(fontSize: 18)),
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
