import 'package:device_preview/device_preview.dart';

/// Preview preferences that cannot come back switched off.
///
/// The preview panel keeps its settings in the browser's local storage and
/// restores them on the next load. Two of those settings can make the panel
/// itself unusable, and neither announces that it has:
///
/// * `isEnabled` false — the panel draws a scrim over its own contents and
///   stops passing them pointers. It is still on screen, and nothing in it
///   responds except the small switch in its title bar.
/// * `isToolbarVisible` false — the panel is not built at all, and there is
///   no control left anywhere to bring it back.
///
/// Either is one stray click away, and because the flag is persisted, a reload
/// restores the dead state rather than clearing it. Local storage is not the
/// browser cache either, so clearing the cache does not help. From the other
/// side of the screen that reads as a panel that has stopped working.
///
/// So both are forced back on as the settings are loaded. Everything the panel
/// is actually used for — the device, its size and orientation, the frame, the
/// locale, the theme, the accessibility settings — is kept exactly as it was
/// left. Switching the preview off still works for as long as the page is
/// open; it just does not outlive a reload.
class RecoverablePreviewStorage implements DevicePreviewStorage {
  RecoverablePreviewStorage([DevicePreviewStorage? inner])
    : _inner = inner ?? DevicePreviewStorage.preferences();

  final DevicePreviewStorage _inner;

  @override
  Future<DevicePreviewData?> load() async {
    final saved = await _inner.load();
    if (saved == null) return null;
    return saved.copyWith(isEnabled: true, isToolbarVisible: true);
  }

  /// Saved as-is. Only the reading of it is corrected, so a session that
  /// switches the preview off behaves normally until the page is reloaded.
  @override
  Future<void> save(DevicePreviewData data) => _inner.save(data);
}
