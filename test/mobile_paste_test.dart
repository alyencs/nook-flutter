import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/widgets/nook_text_field.dart';
import 'package:nook/widgets/tap_keeps_focus.dart';

/// Pasting on a phone, which is how most links arrive.
///
/// [TapKeepsFocus] repairs a caret placement that only goes wrong under the
/// preview's scale, and it repairs it by dropping focus and taking it back. On
/// a desktop pointer that is invisible. On a phone it is the whole experience:
/// dropping focus closes the soft keyboard and dismisses the native selection
/// toolbar, so a tap reads as a keyboard that flickers shut and a long press
/// never reaches Paste.
///
/// These tests hold the line at the pointer kind. A finger must pass through
/// untouched; a mouse must still get the repair it was written for.
void main() {
  /// Counts focus changes, which is what the keyboard and the paste menu
  /// actually react to. Asserting the node ends up focused would miss the bug
  /// entirely: the repair unfocuses and refocuses, so it ends focused either
  /// way. What breaks a phone is the transition in the middle.
  Future<int> focusChangesAfterTapOn(
    WidgetTester tester,
    PointerDeviceKind kind,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var changes = 0;
    focus.addListener(() => changes++);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TapKeepsFocus(
            focusNode: focus,
            child: TextField(focusNode: focus),
          ),
        ),
      ),
    );

    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue, reason: 'the field starts focused');
    changes = 0;

    // A tap on the field it already holds — the case the repair watches for.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TextField)),
      kind: kind,
    );
    await gesture.up();

    // Past both of the repair's checks (120ms and 360ms).
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    return changes;
  }

  testWidgets('a finger on a focused field never disturbs its focus', (
    tester,
  ) async {
    final changes = await focusChangesAfterTapOn(tester, PointerDeviceKind.touch);

    expect(
      changes,
      0,
      reason:
          'any focus change here closes the keyboard and dismisses the paste '
          'menu, which is the reported bug',
    );
  });

  testWidgets('a stylus is treated as a finger', (tester) async {
    final changes = await focusChangesAfterTapOn(
      tester,
      PointerDeviceKind.stylus,
    );

    expect(changes, 0);
  });

  testWidgets('a mouse still gets the repair the preview needs', (
    tester,
  ) async {
    final changes = await focusChangesAfterTapOn(tester, PointerDeviceKind.mouse);

    expect(
      changes,
      greaterThan(0),
      reason: 'the desktop fix must not have been removed along with the bug',
    );
  });

  testWidgets('the field keeps its focus and its text through a touch tap', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NookTextField(controller: controller, hint: 'Paste a link'),
        ),
      ),
    );

    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pumpAndSettle();

    // What a paste does, as far as the field is concerned.
    controller.text = 'https://www.tiktok.com/@u/video/7311234567890';
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(
      state.widget.focusNode.hasFocus,
      isTrue,
      reason: 'the keyboard must still be up after text arrives',
    );
    expect(controller.text, contains('tiktok.com'));

    // Typing on top of it, then clearing, both have to work.
    await tester.enterText(field, 'https://youtu.be/dQw4w9WgXcQ');
    await tester.pumpAndSettle();
    expect(controller.text, 'https://youtu.be/dQw4w9WgXcQ');

    controller.clear();
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
  });

  testWidgets('selection stays enabled, which is what carries Paste', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'https://youtu.be/abc');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NookTextField(controller: controller, hint: 'Paste a link'),
        ),
      ),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(
      editable.enableInteractiveSelection,
      isTrue,
      reason: 'the native long-press menu is where Paste lives',
    );
    expect(editable.readOnly, isFalse);
  });
}
