import 'package:device_preview/device_preview.dart';
import 'package:flutter/widgets.dart' show Orientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/preview/preview_storage.dart';

/// The preview panel must never come back from a reload unusable.
///
/// Both flags below are one click away in the panel, both are written to the
/// browser's local storage, and both leave the panel on screen but inert —
/// which is indistinguishable from the app having broken, and survives a
/// reload and a cache clear.
class _FakeStorage implements DevicePreviewStorage {
  _FakeStorage(this.stored);

  DevicePreviewData? stored;
  DevicePreviewData? saved;

  @override
  Future<DevicePreviewData?> load() async => stored;

  @override
  Future<void> save(DevicePreviewData data) async => saved = data;
}

void main() {
  const device = 'targetplatform.ios_devicetype.phone_iphone-12-mini';

  test('a preview switched off comes back on', () async {
    final inner = _FakeStorage(
      const DevicePreviewData(isEnabled: false, deviceIdentifier: device),
    );

    final loaded = await RecoverablePreviewStorage(inner).load();

    expect(loaded!.isEnabled, isTrue);
    expect(
      loaded.deviceIdentifier,
      device,
      reason: 'the chosen device is a preference, not a trap',
    );
  });

  test('a drawn-on keyboard does not cover the tab bar again', () async {
    final inner = _FakeStorage(
      const DevicePreviewData(isVirtualKeyboardVisible: true),
    );

    expect(
      (await RecoverablePreviewStorage(inner).load())!.isVirtualKeyboardVisible,
      isFalse,
      reason: 'it sits exactly where Home, Trips, Add and Profile are',
    );
  });

  test('text scaled past the phone comes back to normal', () async {
    final inner = _FakeStorage(const DevicePreviewData(textScaleFactor: 3));

    expect(
      (await RecoverablePreviewStorage(inner).load())!.textScaleFactor,
      1,
    );
  });

  test('a hidden toolbar comes back', () async {
    final inner = _FakeStorage(
      const DevicePreviewData(isToolbarVisible: false),
    );

    expect((await RecoverablePreviewStorage(inner).load())!.isToolbarVisible, isTrue);
  });

  test('everything else is restored untouched', () async {
    const stored = DevicePreviewData(
      deviceIdentifier: device,
      orientation: Orientation.landscape,
      isFrameVisible: false,
      isDarkMode: true,
      boldText: true,
      highContrast: true,
      invertColors: true,
      accessibleNavigation: true,
      locale: 'fr_FR',
    );
    final inner = _FakeStorage(stored);

    final loaded = await RecoverablePreviewStorage(inner).load();

    expect(loaded!.orientation, Orientation.landscape);
    expect(loaded.isFrameVisible, isFalse);
    expect(loaded.isDarkMode, isTrue);
    expect(loaded.boldText, isTrue);
    expect(loaded.highContrast, isTrue);
    expect(loaded.invertColors, isTrue);
    expect(loaded.accessibleNavigation, isTrue);
    expect(loaded.locale, 'fr_FR');
  });

  test('nothing saved yet stays nothing', () async {
    expect(await RecoverablePreviewStorage(_FakeStorage(null)).load(), isNull);
  });

  test('saving is passed straight through, so the session still obeys', () async {
    final inner = _FakeStorage(null);
    const off = DevicePreviewData(isEnabled: false);

    await RecoverablePreviewStorage(inner).save(off);

    expect(
      inner.saved!.isEnabled,
      isFalse,
      reason: 'only the reading is corrected; the page keeps what it was told',
    );
  });
}
