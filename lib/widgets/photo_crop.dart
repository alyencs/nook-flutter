import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';
import 'nook_buttons.dart';
import 'nook_rule.dart';

/// Lets someone choose which part of their photograph is their profile picture.
///
/// Returns a `data:` URI for a square PNG, or null if the sheet was dismissed.
///
/// The crop is baked into the stored image rather than kept beside it as an
/// offset and a zoom: that would be a second piece of state every avatar has to
/// apply, and the first screen that forgets is a bug nobody notices.
/// `users.profilePicture` stays the single source of truth.
///
/// No new dependency — pan and zoom are a `GestureDetector` and a `Transform`,
/// and the crop is `dart:ui` drawing one rectangle of the image into another.
Future<String?> showPhotoCrop(BuildContext context, Uint8List bytes) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: false,
    builder: (context) => _PhotoCropSheet(bytes: bytes),
  );
}

class _PhotoCropSheet extends StatefulWidget {
  const _PhotoCropSheet({required this.bytes});

  final Uint8List bytes;

  @override
  State<_PhotoCropSheet> createState() => _PhotoCropSheetState();
}

class _PhotoCropSheetState extends State<_PhotoCropSheet> {
  /// The side of the round window the photograph is positioned inside.
  static const _frame = 280.0;

  /// What the saved square is rendered at. Comfortably above the 96pt the
  /// largest avatar draws, even on a 3x screen.
  static const _output = 512;

  ui.Image? _image;
  bool _saving = false;

  /// How far the photograph has been dragged from centred, in logical pixels.
  Offset _offset = Offset.zero;

  /// Zoom on top of the scale that just fills the window. 1 is "as small as it
  /// can be and still cover", which is where it starts.
  double _scale = 1;

  double _startScale = 1;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Logical pixels per image pixel at zoom 1: the scale that exactly covers
  /// the window, so there is never a gap at the edge.
  double _baseScale(ui.Image image) =>
      _frame / math.min(image.width, image.height);

  /// Keeps the photograph covering the window, however it was dragged.
  Offset _clamp(Offset offset, ui.Image image) {
    final effective = _baseScale(image) * _scale;
    final slackX = math.max(0.0, (image.width * effective - _frame) / 2);
    final slackY = math.max(0.0, (image.height * effective - _frame) / 2);
    return Offset(
      offset.dx.clamp(-slackX, slackX),
      offset.dy.clamp(-slackY, slackY),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final image = _image;
    if (image == null) return;
    setState(() {
      _scale = (_startScale * details.scale).clamp(1.0, 5.0);
      _offset = _clamp(_offset + details.focalPointDelta, image);
    });
  }

  /// The part of the photograph the window is showing, in image pixels — the
  /// inverse of what the preview draws.
  Rect _sourceRect(ui.Image image) {
    final effective = _baseScale(image) * _scale;
    final side = _frame / effective;
    final centre = Offset(
      image.width / 2 - _offset.dx / effective,
      image.height / 2 - _offset.dy / effective,
    );
    return Rect.fromCenter(center: centre, width: side, height: side);
  }

  Future<void> _use() async {
    final image = _image;
    if (image == null || _saving) return;
    setState(() => _saving = true);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      _sourceRect(image),
      Rect.fromLTWH(0, 0, _output.toDouble(), _output.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(_output, _output);
    picture.dispose();
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();

    if (!mounted) return;
    if (data == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(
      context,
    ).pop('data:image/png;base64,${base64Encode(data.buffer.asUint8List())}');
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return Container(
      padding: const EdgeInsets.all(NookSpacing.screenEdge),
      decoration: const BoxDecoration(
        color: NookColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NookRadius.md),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RuledLabel('Position your photo'),
            const SizedBox(height: NookSpacing.tight),
            Text(
              'Drag to move it, pinch or scroll to zoom. What you see in the '
              'circle is what everyone sees.',
              style: NookType.caption.copyWith(color: NookColors.textMuted),
            ),
            const SizedBox(height: NookSpacing.block),
            Center(
              child: SizedBox(
                width: _frame,
                height: _frame,
                child: image == null
                    ? const Center(child: CircularProgressIndicator())
                    : GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: ClipOval(
                          child: Container(
                            color: NookColors.placeholder,
                            child: Transform.translate(
                              offset: _offset,
                              child: Transform.scale(
                                scale: _scale,
                                child: SizedBox.expand(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: image.width.toDouble(),
                                      height: image.height.toDouble(),
                                      child: RawImage(
                                        image: image,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: NookSpacing.block),
            // A slider as well as the pinch: a mouse has no second finger, and
            // this screen is opened in a browser as often as not.
            Row(
              children: [
                const Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: NookColors.textMuted,
                ),
                Expanded(
                  child: Slider(
                    value: _scale,
                    min: 1,
                    max: 5,
                    onChanged: image == null
                        ? null
                        : (value) => setState(() {
                            _scale = value;
                            _offset = _clamp(_offset, image);
                          }),
                  ),
                ),
                const Icon(
                  Icons.zoom_in_rounded,
                  size: 22,
                  color: NookColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: NookSpacing.tight),
            NookPrimaryButton(
              label: 'Use Photo',
              onPressed: image == null || _saving ? null : _use,
            ),
            const SizedBox(height: NookSpacing.tight),
            NookSecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
