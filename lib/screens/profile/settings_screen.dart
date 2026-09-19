import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/daos/settings_dao.dart';
import '../../data/export_service.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/sub_screen_nav.dart';

/// P3.
///
/// The four switches are real and persisted — each one changes how saving
/// behaves — and the Data section acts on the database rather than describing
/// it.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return NookScaffold(
      bottomNav: const SubScreenNav(),
      child: StreamBuilder<Map<String, bool>>(
        stream: scope.settings.watchAll(),
        builder: (context, snapshot) {
          final values = snapshot.data ?? NookSettings.defaults;

          return ListView(
            children: [
              const NookAppBar(title: 'Settings'),
              const SizedBox(height: NookSpacing.tight),
              for (final entry in NookSettings.labels.entries) ...[
                _SwitchRow(
                  label: entry.value,
                  value: values[entry.key] ?? false,
                  onChanged: (enabled) => scope.settings.set(entry.key, enabled),
                ),
                const Divider(),
              ],
              const SizedBox(height: NookSpacing.block),
              Text('Data', style: NookType.title),
              const SizedBox(height: NookSpacing.tight),
              _DataRow(label: 'Export Data', onTap: () => _export(context)),
              _DataRow(
                label: 'Clear Search History',
                onTap: () => _clearSearches(context),
              ),
              _DataRow(label: 'Clear Cache', onTap: () => _clearCache(context)),
              const SizedBox(height: NookSpacing.section),
            ],
          );
        },
      ),
    );
  }

  /// Writes every row Nook holds to a JSON file. On the web the browser
  /// downloads it; on a device it lands in the app's documents directory.
  static Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = AppScope.of(context).db;

    try {
      final destination = await NookExport.run(db);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb ? 'Exported $destination' : 'Exported to $destination',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  static Future<void> _clearSearches(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await AppScope.of(context).searches.clear();
    messenger.showSnackBar(
      const SnackBar(content: Text('Search history cleared')),
    );
  }

  /// Thumbnails are fetched from each platform and held in Flutter's image
  /// cache. Emptying it is what "Clear Cache" can honestly mean here: your
  /// saved posts are not touched.
  static Future<void> _clearCache(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showNookDialog(
      context,
      title: 'Clear cached images?',
      message: 'Thumbnails will be fetched again next time they are shown. '
          'Your saved posts, trips and notes are not affected.',
      confirmLabel: 'Clear Cache',
    );
    if (!confirmed) return;

    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    messenger.showSnackBar(const SnackBar(content: Text('Cache cleared')));
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: NookType.body)),
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
            padding: const EdgeInsets.symmetric(vertical: NookSpacing.row),
            child: Row(
              children: [
                Expanded(child: Text(label, style: NookType.body)),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
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
