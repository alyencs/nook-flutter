import '../database.dart';

/// The four switches drawn on the Settings screen, and what each one does.
abstract final class NookSettings {
  /// Off means a pasted link skips extraction and goes straight to the fields
  /// for you to fill in yourself.
  static const autoCategorize = 'auto_categorize_saves';

  /// Off hides the alternative category chips on Destination & Category, and
  /// the suggestion chips on Search.
  static const categorySuggestions = 'show_category_suggestions';

  /// On fills the link field from the clipboard when Paste Link opens.
  static const pasteDetection = 'paste_detection';

  /// On asks before writing a post, for anyone who would rather confirm.
  static const saveConfirmation = 'save_confirmation';

  /// What the mockup draws: the first three on, the last off.
  static const defaults = <String, bool>{
    autoCategorize: true,
    categorySuggestions: true,
    pasteDetection: true,
    saveConfirmation: false,
  };

  static const labels = <String, String>{
    autoCategorize: 'Auto-categorize saves',
    categorySuggestions: 'Show category suggestions',
    pasteDetection: 'Paste detection',
    saveConfirmation: 'Save confirmation',
  };
}

class SettingsDao {
  SettingsDao(this._db);

  final NookDatabase _db;

  Stream<Map<String, bool>> watchAll() {
    return _db.select(_db.appSettings).watch().map((rows) {
      final values = Map<String, bool>.from(NookSettings.defaults);
      for (final row in rows) {
        values[row.name] = row.enabled;
      }
      return values;
    });
  }

  Future<Map<String, bool>> current() async {
    final rows = await _db.select(_db.appSettings).get();
    final values = Map<String, bool>.from(NookSettings.defaults);
    for (final row in rows) {
      values[row.name] = row.enabled;
    }
    return values;
  }

  Future<bool> isEnabled(String name) async => (await current())[name] ?? false;

  Future<void> set(String name, bool enabled) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(name: name, enabled: enabled),
        );
  }
}
