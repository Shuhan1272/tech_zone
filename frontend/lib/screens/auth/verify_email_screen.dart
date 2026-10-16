import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _otp = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email ?? '');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().clearError(),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  /// Asks for a fresh code. The account already exists at this point, so
  /// there is nothing to register again.
  Future<void> _resend() async {
    final email = _email.text.trim();

    final problem = AuthValidators.email(email);
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(appSnackBar(context, ok: false, message: problem));
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.resendEmailOtp(email);
    if (!mounted) return;

    // A refusal — the one-minute cooldown, or an address that is already
    // verified — comes back in the provider's error.
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        ok: ok,
        message: ok
            ? 'A new code is on its way to $email.'
            : (auth.error ?? 'Could not send a new code.'),
      ),
    );

    if (ok) {
      _otp.clear();
      auth.clearError();
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyEmail(email: _email.text, otp: _otp.text);
    if (!mounted || !ok) return;

    await context.read<CartProvider>().load();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        ok: true,
        message: 'Email verified. You are signed in.',
      ),
    );
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: 'Verify your email',
      subtitle:
          'Enter the 6-digit code we emailed you. The code expires after 10 '
          'minutes.',
      error: auth.error,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Need a new code?'),
          TextButton(
            onPressed: auth.isBusy ? null : _resend,
            child: const Text('Send again'),
          ),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                  errorText: auth.fieldErrors['email'],
                ),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                onFieldSubmitted: (_) => _submit(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Verification code',
                  counterText: '',
                  hintText: '000000',
                  errorText: auth.fieldErrors['otp'],
                ),
                validator: AuthValidators.otp,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: auth.isBusy ? null : _submit,
                child: auth.isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.white,
                        ),
                      )
                    : const Text('Verify and sign in'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
