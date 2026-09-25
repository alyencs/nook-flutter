import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/nook_colors.dart';
import '../../theme/nook_spacing.dart';
import '../../theme/nook_typography.dart';
import '../../widgets/nook_app_bar.dart';
import '../../widgets/nook_dialog.dart';
import '../../widgets/nook_rule.dart';
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_toast.dart';
import '../../widgets/sub_screen_nav.dart';
import '../../widgets/nook_text_field.dart';
import '../onboarding/profile_setup_screen.dart';

/// P2.
///
/// No password and no email. Nook keeps everything on the device and talks to
/// no server, so there was never an account for either to belong to — what is
/// here is a name to be greeted by and a picture to go with it.
///
/// Edits save when the field loses focus rather than behind a button, since the
/// frame does not draw one.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _name = TextEditingController();
  bool _loaded = false;
  int? _userId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveField() async {
    final id = _userId;
    if (id == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await AppScope.of(context).users.updateProfile(id, name: name);
    if (!mounted) return;
    NookToast.of(context, 'Saved');
  }

  Future<void> _changePhoto() async {
    final id = _userId;
    if (id == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await AppScope.of(context).users.updateProfile(
          id,
          profilePicture: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showNookDialog(
      context,
      title: 'Delete your profile?',
      message: 'This erases your profile, every saved post and every trip from '
          'this device. Nothing is stored anywhere else, so it cannot be '
          'recovered.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    // The launch gate watches the users table, so emptying it returns the app
    // to onboarding on its own.
    await AppScope.of(context).db.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StreamBuilder<User?>(
      stream: scope.users.watchCurrentUser(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const NookScaffold(child: SizedBox.shrink());

        if (!_loaded) {
          _name.text = user.name;
          _userId = user.id;
          _loaded = true;
        }

        return NookScaffold(
          bottomNav: const SubScreenNav(),
          child: ListView(
            children: [
              const NookAppBar(title: 'Account'),
              const SizedBox(height: NookSpacing.block),
              Row(
                children: [
                  ProfileAvatar(picture: user.profilePicture, size: 72),
                  const SizedBox(width: NookSpacing.section),
                  InkWell(
                    onTap: _changePhoto,
                    child: Text(
                      'Change Photo',
                      style: NookType.body.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NookSpacing.block),
              const RuledLabel('What we call you'),
              const SizedBox(height: NookSpacing.tight),
              Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) _saveField();
                },
                child: NookTextField(
                  controller: _name,
                  hint: 'Your name',

                ),
              ),
              const SizedBox(height: NookSpacing.tight),
              Text(
                'Only used to greet you. It stays on this device.',
                style: NookType.caption,
              ),
              const SizedBox(height: 36),
              const RuledLabel('Danger zone'),
              const SizedBox(height: NookSpacing.section),
              InkWell(
                onTap: _deleteAccount,
                child: Text(
                  'Delete my profile',
                  style: NookType.body.copyWith(
                    color: NookColors.error,
                    decoration: TextDecoration.underline,
                    decorationColor: NookColors.error,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
