import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import 'auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.next});

  final String? next;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Clear a stale error from a previous visit.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AuthProvider>().clearError(),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(email: _email.text, password: _password.text);
    if (!mounted) return;

    if (ok) {
      await context.read<CartProvider>().load();
      if (!mounted) return;
      context.go(widget.next ?? '/');
    }
  }

  bool get _needsVerification {
    final auth = context.read<AuthProvider>();
    final emailError = auth.fieldErrors['email'] ?? '';
    return emailError.toLowerCase().contains('verify');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to your TechZone account to shop and manage orders.',
      error: auth.error,
      footer: Column(
        children: [
          if (_needsVerification)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '/verify-email?email=${Uri.encodeQueryComponent(_email.text.trim())}',
                ),
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                label: const Text('Verify my email now'),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('New to TechZone?'),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('Create an account'),
              ),
            ],
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
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                  errorText: auth.fieldErrors['email'],
                ),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
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
                validator: (value) =>
                    AuthValidators.required(value, 'Password'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 6),
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
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
