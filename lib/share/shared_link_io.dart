/// Native builds: nothing yet.
///
/// Receiving a share on Android and iOS needs platform plumbing that a web
/// build has no equivalent for — an intent-filter and a `MainActivity` that
/// forwards `ACTION_SEND`, or an iOS Share Extension target with an app group.
/// Neither can be added from Dart, and neither can be exercised by this
/// project's test or deploy path, which is the web.
///
/// `docs/09-share-to-nook.md` records exactly what to add when Nook is built
/// for a device. Until then a native build simply has no shared link, which is
/// the same state as an ordinary launch.
String? initialSharedLink() => null;

void consumeSharedLink() {}
