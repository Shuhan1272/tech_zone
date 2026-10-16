import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.error,
    this.footer,
    this.maxWidth = 440,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? error;
  final Widget? footer;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.gutter(context),
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: InkWell(
                      onTap: () => context.go('/'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                Icons.memory_rounded,
                                size: 20,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'TechZone',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 18),
                            _ErrorBanner(message: error!),
                          ],
                          const SizedBox(height: 22),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                  if (footer != null) ...[const SizedBox(height: 18), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthValidators {
  const AuthValidators._();

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Email is required.';

    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  static String? required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required.';
    return null;
  }

  static String? phone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Phone number is required.';
    if (text.length > 20) return 'Phone number must be 20 characters or fewer.';
    if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(text)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required.';
    if (text.length < 8) return 'Use at least 8 characters.';
    if (RegExp(r'^[0-9]+$').hasMatch(text)) {
      return 'Password cannot be entirely numeric.';
    }
    return null;
  }

  static String? confirm(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? otp(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the 6-digit code.';
    if (text.length != 6) return 'The code is exactly 6 digits.';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(text)) return 'Digits only.';
    return null;
  }
}
