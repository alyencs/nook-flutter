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
import '../../widgets/nook_scaffold.dart';
import '../../widgets/nook_text_field.dart';
import '../onboarding/profile_setup_screen.dart';

/// P2.
///
/// No "Change Password" row: there is no password, because there is no server.
/// Edits save when a field loses focus rather than behind a button, since the
/// frame does not draw one.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _loaded = false;
  int? _userId;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _saveField() async {
    final id = _userId;
    if (id == null) return;
    await AppScope.of(context).users.updateProfile(
          id,
          name: _name.text.trim(),
          email: _email.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
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
          _email.text = user.email;
          _userId = user.id;
          _loaded = true;
        }

        return NookScaffold(
          child: ListView(
            children: [
              const NookAppBar(title: 'Account'),
              const SizedBox(height: NookSpacing.screenEdge),
              Row(
                children: [
                  ProfileAvatar(picture: user.profilePicture, size: 72),
                  const SizedBox(width: NookSpacing.section),
                  InkWell(
                    onTap: _changePhoto,
                    child: Text(
                      'Change Photo',
                      style: NookType.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NookSpacing.screenEdge),
              Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) _saveField();
                },
                child: NookTextField(
                  controller: _name,
                  hint: 'Full Name',
                  label: 'Full Name',
                ),
              ),
              const SizedBox(height: NookSpacing.section),
              Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) _saveField();
                },
                child: NookTextField(
                  controller: _email,
                  hint: 'Email',
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 40),
              Text('Danger Zone', style: NookType.title),
              const SizedBox(height: NookSpacing.section),
              InkWell(
                onTap: _deleteAccount,
                child: Text(
                  'Delete my account',
                  style: NookType.body.copyWith(
                    fontSize: 18,
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
