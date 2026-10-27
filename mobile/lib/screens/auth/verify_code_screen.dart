import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/otp_input.dart';
import '../../widgets/pill_button.dart';
import 'reset_password_screen.dart';

/// Step 2 of 3: enter the 6-digit code (Figma: "06 - Verify Code").
class VerifyCodeScreen extends StatefulWidget {
  final String email;
  final ResetCodeRequest request;

  const VerifyCodeScreen({super.key, required this.email, required this.request});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final _code = TextEditingController();
  final _service = AuthService();
  Timer? _timer;
  late int _secondsLeft;
  late String? _devCode = widget.request.devCode;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.request.resendAfter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _secondsLeft = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, seconds));
    });
  }

  static String _mmss(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _verify([String? value]) async {
    final code = value ?? _code.text;
    if (code.length != 6 || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final token = await _service.verifyResetCode(widget.email, code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(resetToken: token),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.errors?['code'] as String? ?? e.message);
      _code.clear();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final request = await _service.requestResetCode(widget.email);
      if (!mounted) return;
      _code.clear();
      setState(() => _devCode = request.devCode);
      _startCountdown(request.resendAfter);
      AppToast.success(context, 'We sent you a new code');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: Alignment.centerLeft, child: CircleBackButton()),
                const SizedBox(height: 20),
                const Center(child: IconCircle(icon: Icons.mark_email_read_rounded)),
                const SizedBox(height: 24),
                Text('Check your email', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to '),
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OtpInput(
                  fieldKey: const Key('otp_field'),
                  controller: _code,
                  hasError: _error != null,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onCompleted: _verify,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
                        ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: _secondsLeft > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 18, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('Resend code in ${_mmss(_secondsLeft)}', style: muted),
                          ],
                        )
                      : TextButton.icon(
                          key: const Key('resend_code'),
                          onPressed: _resending ? null : _resend,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Resend code'),
                        ),
                ),
                const SizedBox(height: 16),
                PillButton(
                  key: const Key('verify_submit'),
                  label: 'Verify',
                  trailingIcon: Icons.arrow_forward_rounded,
                  loading: _verifying,
                  onPressed: _code.text.length == 6 ? _verify : null,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Wrong email?', style: text.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Change it', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                // Development server only (no real email): show the code so the flow can be tested
                if (kDebugMode && _devCode != null)
                  Center(
                    child: ActionChip(
                      avatar: const Icon(Icons.developer_mode_rounded, size: 18),
                      label: Text('Dev code: $_devCode  (tap to fill)'),
                      onPressed: () {
                        _code.text = _devCode!;
                        _verify(_devCode);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
