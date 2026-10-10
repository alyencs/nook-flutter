import 'package:device_preview/device_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/ai/sample_extractor.dart';
import 'package:nook/app_scope.dart';
import 'package:nook/data/database.dart';
import 'package:nook/screens/onboarding/profile_setup_screen.dart';
import 'package:nook/theme/nook_theme.dart';

/// Every form in Nook must survive being tapped.
///
/// The app is drawn inside the preview, which scales it to fit the window. A
/// tap on a field that already holds focus is resolved through that scale to
/// place the caret, and under the scale it resolves to nothing: the field
/// loses focus and typing is dropped. Tapping again does not recover it. So a
/// field that focuses itself on arrival is one that the first tap kills — and
/// the first tap is what everybody does.
///
/// The screens therefore leave their fields unfocused. These tests hold that
/// line: the field must not arrive focused, and a tap must focus it.
void main() {
  late NookDatabase db;

  setUp(() => db = NookDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1440, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        db: db,
        tab: ValueNotifier<int>(0),
        extractor: const SampleExtractor(),
        child: DevicePreview(
          enabled: true,
          storage: DevicePreviewStorage.none(),
          // A widget of our own, exactly as `main()` hands it `NookApp`.
          // Returning a MaterialApp straight from the builder trips the
          // package's `useInheritedMediaQuery` assert, which no current
          // MaterialApp can satisfy.
          builder: (context) => _HostApp(screen: screen),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  bool fieldHasFocus(WidgetTester tester) => tester
      .state<EditableTextState>(find.byType(EditableText).first)
      .widget
      .focusNode
      .hasFocus;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('Set Up Profile does not grab focus on arrival', (tester) async {
    await pump(tester, const ProfileSetupScreen());

    expect(
      fieldHasFocus(tester),
      isFalse,
      reason: 'a field that focuses itself is killed by the first tap on it',
    );
    await unmount(tester);
  });

  testWidgets('tapping the name field focuses it', (tester) async {
    await pump(tester, const ProfileSetupScreen());

    await tester.tapAt(tester.getCenter(find.byType(EditableText).first));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fieldHasFocus(tester), isTrue);
    await unmount(tester);
  });

  testWidgets('and then it accepts text', (tester) async {
    await pump(tester, const ProfileSetupScreen());

    await tester.tapAt(tester.getCenter(find.byType(EditableText).first));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(EditableText).first, 'Alya');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Alya'), findsOneWidget);
    await unmount(tester);
  });
}

/// Stands in for `NookApp`: the app under the preview, wired the same way.
class _HostApp extends StatelessWidget {
  const _HostApp({required this.screen});

  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: NookTheme.theme,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      home: screen,
    );
  }
}
