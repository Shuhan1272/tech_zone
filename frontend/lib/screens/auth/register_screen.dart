import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

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
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      email: _email.text,
      phone: _phone.text,
      firstName: _firstName.text,
      lastName: _lastName.text,
      password: _password.text,
      confirmPassword: _confirm.text,
    );
    if (!mounted || !ok) return;

    // The account exists but is unverified and cannot sign in yet, so go
    // straight to the OTP step with the email prefilled.
    context.push(
      '/verify-email?email=${Uri.encodeQueryComponent(_email.text.trim())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      maxWidth: 520,
      title: 'Create your account',
      subtitle:
          'We will email you a 6-digit code to verify your address before '
          'your first sign-in.',
      error: auth.error,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Already have an account?'),
          TextButton(
            onPressed: () => context.push('/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'First name',
                        errorText: auth.fieldErrors['first_name'],
                      ),
                      validator: (value) =>
                          AuthValidators.required(value, 'First name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Last name',
                        errorText: auth.fieldErrors['last_name'],
                      ),
                      validator: (value) =>
                          AuthValidators.required(value, 'Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
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
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: '01712345678',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  errorText: auth.fieldErrors['phone'],
                ),
                validator: AuthValidators.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
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
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                  errorText: auth.fieldErrors['password2'],
                ),
                validator: (value) =>
                    AuthValidators.confirm(value, _password.text),
              ),
              const SizedBox(height: 20),
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
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
