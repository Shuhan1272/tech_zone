import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/address.dart';
import '../../core/utils/responsive.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import '../auth/auth_scaffold.dart';

/// Profile screen: shows the fields `UserSerializer` exposes and lets the
/// customer edit the three that are writable.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _fillFromUser();
  }

  void _fillFromUser() {
    final user = context.read<AuthProvider>().user;
    _firstName.text = user?.firstName ?? '';
    _lastName.text = user?.lastName ?? '';
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      firstName: _firstName.text,
      lastName: _lastName.text,
      phone: _phone.text,
    );
    if (!mounted) return;

    if (ok) {
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(context, ok: true, message: 'Profile updated.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (!auth.isSignedIn) return const _SignedOutNotice();

    final user = auth.user!;

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AccountHeader(title: 'My profile'),
          const SizedBox(height: 20),
          SplitLayout(
            secondaryWidth: 300,
            primary: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              user.initials,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_editing)
                            TextButton.icon(
                              onPressed: () {
                                _fillFromUser();
                                setState(() => _editing = true);
                              },
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: const Text('Edit'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 18),
                      if (auth.error != null && _editing) ...[
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            auth.error!,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstName,
                              enabled: _editing,
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
                              enabled: _editing,
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
                        controller: _phone,
                        enabled: _editing,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          errorText: auth.fieldErrors['phone'],
                        ),
                        validator: AuthValidators.phone,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: user.email,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          helperText: 'Your email is not changeable. ',
                        ),
                      ),
                      if (_editing) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: auth.isBusy
                                    ? null
                                    : () {
                                        _fillFromUser();
                                        setState(() => _editing = false);
                                        auth.clearError();
                                      },
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: auth.isBusy ? null : _save,
                                child: auth.isBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.white,
                                        ),
                                      )
                                    : const Text('Save changes'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            secondary: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Account details',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(label: 'Customer ID', value: '#${user.id}'),
                        _DetailRow(
                          label: 'Member since',
                          value: Formatters.date(user.dateJoined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('Shipping address'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/account/address'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded),
                        title: const Text('Change password'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/account/password'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: const Text('Order history'),
                        subtitle: const Text('Your past and current orders'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/account/orders'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _SignedOutNotice extends StatelessWidget {
  const _SignedOutNotice();

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: EmptyState(
        title: 'Sign in to view your account',
        message: 'Your profile, address and settings live behind sign-in.',
        icon: Icons.person_outline_rounded,
        action: FilledButton.icon(
          onPressed: () => context.push('/login?next=/account'),
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Sign in'),
        ),
      ),
    );
  }
}

/// Shipping address form, backed by the single-address `/accounts/address/`
/// endpoint.
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _company = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _postalCode = TextEditingController();
  final _region = TextEditingController();
  final _country = TextEditingController(text: 'Bangladesh');

  bool _filled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.read<AuthProvider>().isSignedIn) return;
      await context.read<AccountProvider>().load();
      if (mounted) _fill();
    });
  }

  /// Seeds the form from the saved address, or from the profile name as a
  /// convenience on first use.
  void _fill() {
    if (_filled) return;
    final account = context.read<AccountProvider>();
    final address = account.address;

    if (address != null) {
      _firstName.text = address.firstName;
      _lastName.text = address.lastName;
      _company.text = address.company;
      _address1.text = address.address1;
      _address2.text = address.address2;
      _city.text = address.city;
      _postalCode.text = address.postalCode;
      _region.text = address.region;
      _country.text = address.country;
    } else {
      final user = context.read<AuthProvider>().user;
      _firstName.text = user?.firstName ?? '';
      _lastName.text = user?.lastName ?? '';
    }
    _filled = true;
    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _company,
      _address1,
      _address2,
      _city,
      _postalCode,
      _region,
      _country,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final account = context.read<AccountProvider>();
    final existing = account.address;

    final ok = await account.save(
      Address(
        id: existing?.id ?? 0,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        company: _company.text.trim(),
        address1: _address1.text.trim(),
        address2: _address2.text.trim(),
        city: _city.text.trim(),
        postalCode: _postalCode.text.trim(),
        region: _region.text.trim(),
        country: _country.text.trim().isEmpty
            ? 'Bangladesh'
            : _country.text.trim(),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        ok: ok,
        message: ok
            ? 'Shipping address saved.'
            : (account.error ?? 'Could not save.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final account = context.watch<AccountProvider>();

    if (!auth.isSignedIn) return const _SignedOutNotice();

    if (account.isLoading && !_filled) {
      return const PageContainer(
        child: LoadingState(message: 'Loading your address…'),
      );
    }

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AccountHeader(title: 'Shipping address'),
          const SizedBox(height: 6),
          Text(
            'TechZone stores one shipping address per account.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (account.error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            account.error!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _Pair(
                        left: TextFormField(
                          controller: _firstName,
                          decoration: InputDecoration(
                            labelText: 'First name *',
                            errorText: account.fieldErrors['first_name'],
                          ),
                          validator: (v) =>
                              AuthValidators.required(v, 'First name'),
                        ),
                        right: TextFormField(
                          controller: _lastName,
                          decoration: InputDecoration(
                            labelText: 'Last name *',
                            errorText: account.fieldErrors['last_name'],
                          ),
                          validator: (v) =>
                              AuthValidators.required(v, 'Last name'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _company,
                        decoration: InputDecoration(
                          labelText: 'Company (optional)',
                          errorText: account.fieldErrors['company'],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _address1,
                        decoration: InputDecoration(
                          labelText: 'Address line 1 *',
                          hintText: 'House 12, Road 5',
                          errorText: account.fieldErrors['address1'],
                        ),
                        validator: (v) =>
                            AuthValidators.required(v, 'Address line 1'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _address2,
                        decoration: InputDecoration(
                          labelText: 'Address line 2 (optional)',
                          errorText: account.fieldErrors['address2'],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Pair(
                        left: TextFormField(
                          controller: _city,
                          decoration: InputDecoration(
                            labelText: 'City *',
                            errorText: account.fieldErrors['city'],
                          ),
                          validator: (v) => AuthValidators.required(v, 'City'),
                        ),
                        right: TextFormField(
                          controller: _region,
                          decoration: InputDecoration(
                            labelText: 'Region / District *',
                            errorText: account.fieldErrors['region'],
                          ),
                          validator: (v) =>
                              AuthValidators.required(v, 'Region'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Pair(
                        left: TextFormField(
                          controller: _postalCode,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Postal code *',
                            errorText: account.fieldErrors['postal_code'],
                          ),
                          validator: (v) =>
                              AuthValidators.required(v, 'Postal code'),
                        ),
                        right: TextFormField(
                          controller: _country,
                          decoration: InputDecoration(
                            labelText: 'Country *',
                            errorText: account.fieldErrors['country'],
                          ),
                          validator: (v) =>
                              AuthValidators.required(v, 'Country'),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          if (account.hasAddress)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: account.isSaving
                                    ? null
                                    : () async {
                                        final confirmed =
                                            await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Delete address?',
                                                ),
                                                content: const Text(
                                                  'Your saved shipping address '
                                                  'will be removed.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                        if (confirmed != true) return;
                                        await account.delete();
                                      },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text('Delete'),
                              ),
                            ),
                          if (account.hasAddress) const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: account.isSaving ? null : _save,
                              child: account.isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : Text(
                                      account.hasAddress
                                          ? 'Update address'
                                          : 'Save address',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two fields side by side on wide screens, stacked on mobile.
class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return Column(children: [left, const SizedBox(height: 14), right]);
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

/// Change-password form for a signed-in customer.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
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
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(
      currentPassword: _current.text,
      newPassword: _password.text,
      confirmPassword: _confirm.text,
    );
    if (!mounted) return;

    if (ok) {
      _current.clear();
      _password.clear();
      _confirm.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          ok: true,
          message: 'Password changed successfully.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (!auth.isSignedIn) return const _SignedOutNotice();

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AccountHeader(title: 'Change password'),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (auth.error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            auth.error!,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _current,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          errorText: auth.fieldErrors['current_password'],
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            AuthValidators.required(v, 'Current password'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          helperText: 'At least 8 characters, not all numbers.',
                          errorText: auth.fieldErrors['new_password'],
                        ),
                        validator: AuthValidators.password,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        onFieldSubmitted: (_) => _save(),
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          errorText: auth.fieldErrors['new_password2'],
                        ),
                        validator: (v) =>
                            AuthValidators.confirm(v, _password.text),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: auth.isBusy ? null : _save,
                        child: auth.isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text('Change password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
