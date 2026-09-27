/// Native builds: nothing yet.
///
/// Receiving a share on Android and iOS needs platform plumbing that a web
/// build has no equivalent for — an intent-filter and a `MainActivity` that
/// forwards `ACTION_SEND`, or an iOS Share Extension target with an app group.
/// Neither can be added from Dart, and neither can be exercised by this
/// project's test or deploy path, which is the web.
///
/// Adding it later means an `<intent-filter>` for `ACTION_SEND` with
/// `text/plain` plus a `MainActivity` that forwards the extra, or an iOS Share
/// Extension sharing an app group container — and then returning the received
/// link from here. Until then a native build simply has no shared link, which
/// is the same state as an ordinary launch.
String? initialSharedLink() => null;

void consumeSharedLink() {}
