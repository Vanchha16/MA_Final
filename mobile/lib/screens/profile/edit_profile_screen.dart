import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/menu_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_text_field.dart';
import '../../widgets/user_avatar.dart';
import 'change_password_screen.dart';

/// Edit name, phone and photo (Figma: "29 - Edit Profile").
class EditProfileScreen extends StatefulWidget {
  final ProfileService? service;

  const EditProfileScreen({super.key, this.service});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static final _phoneRe = RegExp(r'^(\+855|0)\d{8,9}$');

  late final _service = widget.service ?? ProfileService();
  final _formKey = GlobalKey<FormState>();
  late final _user = context.read<AuthProvider>().user!;
  late final _name = TextEditingController(text: _user.fullName);
  late final _email = TextEditingController(text: _user.email);
  late final _phone = TextEditingController(text: formatPhone(_user.phone));
  bool _saving = false;
  bool _uploading = false;
  String? _error;
  Map<String, dynamic> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  static String _normalizePhone(String v) => v.replaceAll(RegExp(r'[\s\-().]'), '');

  /// "012345678" -> "012 345 678", "0961234567" -> "096 123 4567", "+85512345678" -> "+855 12 345 678".
  static String formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    var local = phone;
    var prefix = '';
    if (phone.startsWith('+855')) {
      prefix = '+855 ';
      local = phone.substring(4);
    }
    final head = prefix.isEmpty ? 3 : 2;
    if (local.length < head + 6) return phone;
    return '$prefix${local.substring(0, head)} ${local.substring(head, head + 3)} ${local.substring(head + 3)}';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final user = await _service.uploadAvatar(file);
      if (!mounted) return;
      context.read<AuthProvider>().updateUser(user);
      _toast('Photo updated');
    } on ApiException catch (e) {
      if (mounted) _toast(e.errors?['file'] as String? ?? e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final phone = _normalizePhone(_phone.text);
      final user = await _service.update(fullName: _name.text.trim(), phone: phone.isEmpty ? null : phone);
      if (!mounted) return;
      context.read<AuthProvider>().updateUser(user);
      _toast('Profile updated');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.errors ?? {};
        _error = _fieldErrors.isNotEmpty ? 'Please fix the highlighted fields' : e.message;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? _user;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FadeSlideIn(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const CircleBackButton(),
                      const SizedBox(width: 14),
                      Text('Edit profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: _uploading ? null : _changePhoto,
                      child: UserAvatar(user: user, size: 108, cameraBadge: true, busy: _uploading),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      key: const Key('change_photo'),
                      onPressed: _uploading ? null : _changePhoto,
                      child: const Text('Change photo', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PillTextField(
                    fieldKey: const Key('edit_name'),
                    maxLength: 100,
                    controller: _name,
                    label: 'Full name',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    errorText: _fieldErrors['full_name'] as String?,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Please enter your name';
                      if (value.length < 2) return 'Name is too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  PillTextField(controller: _email, label: 'Email', icon: Icons.email_outlined, enabled: false),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text("Email can't be changed", style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  PillTextField(
                    fieldKey: const Key('edit_phone'),
                    maxLength: 30,
                    controller: _phone,
                    label: 'Phone (optional)',
                    hint: '012 345 678',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    errorText: _fieldErrors['phone'] as String?,
                    onFieldSubmitted: (_) => _save(),
                    validator: (v) {
                      final value = _normalizePhone(v ?? '');
                      if (value.isEmpty) return null;
                      if (!_phoneRe.hasMatch(value)) return 'Enter a valid phone, e.g. 012 345 678';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  MenuCard(items: [
                    MenuItemData(
                      icon: Icons.lock_rounded,
                      label: 'Change password',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ChangePasswordScreen(service: _service)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    ErrorBanner(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  PillButton(key: const Key('edit_save'), label: 'Save changes', loading: _saving, onPressed: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
