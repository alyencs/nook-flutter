import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_buttons.dart';
import '../../widgets/nook_rule.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_text_field.dart';

/// LO1. Personalisation, not registration.
///
/// This writes the single row in the `users` table, and it asks for one thing:
/// what to call you. There is no email and no password, because Nook keeps
/// everything on this device and talks to no server — there is no account for
/// either to identify, and asking for them only made a local app feel like a
/// sign-up form.
///
/// A photo is optional, and can be added later from Account.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  String? _picture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refresh);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _canContinue => _name.text.trim().isNotEmpty;

  Future<void> _pickPicture() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (file == null) return;
    // Stored as a data URI rather than a path: on the web there is no file path
    // to keep, and either way the image never leaves the device.
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _picture = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _continue() async {
    setState(() => _saving = true);

    await AppScope.of(context).users.saveProfile(
          name: _name.text.trim(),
          profilePicture: _picture,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    // The launch gate swaps the app's home route once a profile exists, but
    // the onboarding screens were pushed on top of it and would stay there,
    // leaving the user looking at this screen after saving. Clearing the stack
    // reveals Home underneath.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return NookScaffold(
      bottomBar: NookPrimaryButton(
        label: 'Enter Nook',
        busy: _saving,
        onPressed: _canContinue ? _continue : null,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 56),
            const NookHeadline('What should we *call you?*'),
            const SizedBox(height: NookSpacing.tight),
            Text(
              'A first name, a nickname, anything you like. It stays on this '
              'device — Nook has no account to sign in to.',
              style: NookType.body.copyWith(color: NookColors.textMuted),
            ),
            const SizedBox(height: 36),
            NookTextField(
              controller: _name,
              hint: 'Your name',
              autofocus: true,
              onSubmitted: (_) {
                if (_canContinue) _continue();
              },
            ),
            const SizedBox(height: NookSpacing.block),
            const RuledLabel('Add a photo — optional'),
            const SizedBox(height: NookSpacing.section),
            ProfilePicturePicker(picture: _picture, onTap: _pickPicture),
          ],
        ),
      ),
    );
  }
}

/// The small "Profile Picture" control, shared with the Account screen.
class ProfilePicturePicker extends StatelessWidget {
  const ProfilePicturePicker({
    super.key,
    required this.picture,
    required this.onTap,
  });

  final String? picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NookRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NookSpacing.section,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: NookColors.surface,
          borderRadius: BorderRadius.circular(NookRadius.md),
          border: Border.all(color: NookColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (picture != null) ...[
              ProfileAvatar(picture: picture, size: 24),
              const SizedBox(width: NookSpacing.tight),
            ],
            Text(
              picture == null ? 'Profile Picture' : 'Change Picture',
              style: NookType.body.copyWith(
                color: picture == null
                    ? NookColors.textMuted
                    : NookColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the stored data URI, or a neutral circle when there is none.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.picture, this.size = 96});

  final String? picture;
  final double size;

  @override
  Widget build(BuildContext context) {
    final data = picture;
    if (data == null || !data.contains(',')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: NookColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: NookColors.border),
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: size * 0.45,
          color: NookColors.textMuted,
        ),
      );
    }

    return ClipOval(
      child: Image.memory(
        base64Decode(data.split(',').last),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => Container(
          width: size,
          height: size,
          color: NookColors.placeholder,
        ),
      ),
    );
  }
}
