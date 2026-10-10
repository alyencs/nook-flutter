import 'package:device_preview/device_preview.dart';

/// Preview preferences that cannot come back in a state the app is unusable in.
///
/// The preview panel keeps its settings in the browser's local storage and
/// restores them on the next load. Four of them can leave the app looking
/// finished and answering nothing, and none of them says so:
///
/// * `isEnabled` false — the panel draws a scrim over its own contents and
///   stops passing them pointers. It is still on screen, and nothing in it
///   responds except the small switch in its title bar.
/// * `isToolbarVisible` false — the panel is not built at all, and there is
///   no control left anywhere to bring it back.
/// * `isVirtualKeyboardVisible` true — a drawn-on keyboard covers the bottom
///   of the simulated phone, which is where Nook's tab bar lives. Home, Trips,
///   Add and Profile are all underneath it and cannot be reached.
/// * `textScaleFactor` above 1 — at the top of its range the text no longer
///   fits the phone, and controls are pushed off it.
///
/// Each is one stray click away in the panel, and because the flag is
/// persisted, a reload restores the state rather than clearing it. Local
/// storage is not the browser cache either, so clearing the cache does not
/// help, and the same link in a private window — which has no local storage —
/// behaves perfectly. That asymmetry is the whole signature of this bug.
///
/// So the four are reset as the settings are loaded. They are simulations
/// rather than preferences: worth switching on to see what happens, not worth
/// outliving the page. Everything the panel is genuinely used for — the
/// device, its size and orientation, the frame, the locale, dark mode, bold
/// text, high contrast, inverted colours, accessible navigation — is kept
/// exactly as it was left.
class RecoverablePreviewStorage implements DevicePreviewStorage {
  RecoverablePreviewStorage([DevicePreviewStorage? inner])
    : _inner = inner ?? DevicePreviewStorage.preferences();

  final DevicePreviewStorage _inner;

  @override
  Future<DevicePreviewData?> load() async {
    final saved = await _inner.load();
    if (saved == null) return null;
    return saved.copyWith(
      isEnabled: true,
      isToolbarVisible: true,
      isVirtualKeyboardVisible: false,
      textScaleFactor: 1,
    );
  }

  /// Saved as-is. Only the reading of it is corrected, so a session that turns
  /// the keyboard on, scales the text up or switches the preview off behaves
  /// normally until the page is reloaded.
  @override
  Future<void> save(DevicePreviewData data) => _inner.save(data);
}
