/// Native builds: nothing yet.
///
/// Receiving a share needs platform plumbing that cannot be added from Dart —
/// an `ACTION_SEND` intent-filter on Android, a Share Extension on iOS — and
/// this project builds for the web. Until then a native launch simply has no
/// shared link, which is the same state as an ordinary one.
String? initialSharedLink() => null;

void consumeSharedLink() {}
