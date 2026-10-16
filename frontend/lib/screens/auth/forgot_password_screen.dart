import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { requestOtp, verifyOtp, setPassword, done }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _otpKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Step _step = _Step.requestOtp;
  String? _resetToken;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().clearError(),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    final ok = await context.read<AuthProvider>().forgotPassword(_email.text);
    if (!mounted || !ok) return;
    setState(() => _step = _Step.verifyOtp);
  }

  Future<void> _verifyOtp() async {
    if (!(_otpKey.currentState?.validate() ?? false)) return;
    final token = await context.read<AuthProvider>().verifyPasswordOtp(
      email: _email.text,
      otp: _otp.text,
    );
    if (!mounted || token == null) return;
    setState(() {
      _resetToken = token;
      _step = _Step.setPassword;
    });
  }

  Future<void> _resetPassword() async {
    if (!(_passwordKey.currentState?.validate() ?? false)) return;
    final token = _resetToken;
    if (token == null) return;

    final ok = await context.read<AuthProvider>().resetPassword(
      resetToken: token,
      password: _password.text,
      confirmPassword: _confirm.text,
    );
    if (!mounted || !ok) return;
    setState(() => _step = _Step.done);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: switch (_step) {
        _Step.requestOtp => 'Reset your password',
        _Step.verifyOtp => 'Enter your code',
        _Step.setPassword => 'Choose a new password',
        _Step.done => 'Password updated',
      },
      subtitle: switch (_step) {
        _Step.requestOtp =>
          'Tell us your email address and we will send a 6-digit reset code.',
        _Step.verifyOtp =>
          'We emailed a code to ${_email.text.trim()}. It expires in 10 minutes.',
        _Step.setPassword =>
          'Your code is confirmed. Set a new password to finish.',
        _Step.done => 'You can now sign in with your new password.',
      },
      error: _step == _Step.done ? null : auth.error,
      footer: _step == _Step.done
          ? null
          : TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to sign in'),
            ),
      children: [
        switch (_step) {
          _Step.requestOtp => _buildEmailForm(auth),
          _Step.verifyOtp => _buildOtpForm(auth),
          _Step.setPassword => _buildPasswordForm(auth),
          _Step.done => _buildDone(),
        },
      ],
    );
  }

  Widget _buildEmailForm(AuthProvider auth) => Form(
    key: _emailKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _requestOtp(),
          decoration: InputDecoration(
            labelText: 'Email address',
            prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
            errorText: auth.fieldErrors['email'],
          ),
          validator: AuthValidators.email,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: auth.isBusy ? null : _requestOtp,
          child: auth.isBusy ? const _Spinner() : const Text('Send reset code'),
        ),
      ],
    ),
  );

  Widget _buildOtpForm(AuthProvider auth) => Form(
    key: _otpKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _otp,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          onFieldSubmitted: (_) => _verifyOtp(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: 'Reset code',
            hintText: '000000',
            counterText: '',
            errorText: auth.fieldErrors['otp'],
          ),
          validator: AuthValidators.otp,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: auth.isBusy ? null : _verifyOtp,
          child: auth.isBusy ? const _Spinner() : const Text('Verify code'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: auth.isBusy
              ? null
              : () => setState(() => _step = _Step.requestOtp),
          child: const Text('Use a different email'),
        ),
      ],
    ),
  );

  Widget _buildPasswordForm(AuthProvider auth) => Form(
    key: _passwordKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _password,
          autofocus: true,
          obscureText: _obscure,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'New password',
            helperText: 'At least 8 characters, not all numbers.',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            errorText: auth.fieldErrors['password'],
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: AuthValidators.password,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _confirm,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _resetPassword(),
          decoration: InputDecoration(
            labelText: 'Confirm new password',
            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
            errorText: auth.fieldErrors['password2'],
          ),
          validator: (value) => AuthValidators.confirm(value, _password.text),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: auth.isBusy ? null : _resetPassword,
          child: auth.isBusy
              ? const _Spinner()
              : const Text('Set new password'),
        ),
      ],
    ),
  );

  Widget _buildDone() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(
        Icons.check_circle_outline_rounded,
        size: 46,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: () => context.go('/login'),
        child: const Text('Go to sign in'),
      ),
    ],
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.white),
  );
}
