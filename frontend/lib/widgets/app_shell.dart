import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/responsive.dart';
import '../models/catalog.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';

/// Chrome shared by every storefront page: brand bar, search, category nav,
/// account menu, cart badge and footer.
///
/// On mobile the category nav collapses into a drawer and the search field
/// moves to its own row, so the same widget serves all breakpoints.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      drawer: isDesktop ? null : const _CategoryDrawer(),
      body: Column(
        children: [
          _HeaderBand(
            child: Column(
              children: [const _TopBar(), if (isDesktop) const _CategoryBar()],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [child, const _Footer()]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Turns the buttons inside the blue header white.
///
/// Scoped to the band rather than set on each button, and deliberately not a
/// `textTheme` override: the account and category menus open with this theme,
/// and their items are drawn on a white surface.
class _HeaderBand extends StatelessWidget {
  const _HeaderBand({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: AppColors.white),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return Material(
      color: theme.appBarTheme.backgroundColor,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Responsive.maxContentWidth,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.gutter(context),
                vertical: 10,
              ),
              child: isMobile
                  ? Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                              icon: const Icon(Icons.menu_rounded),
                              tooltip: 'Browse categories',
                            ),
                            const Expanded(child: _Brand()),
                            const _AccountButton(),
                            const _CartButton(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const _SearchField(),
                      ],
                    )
                  : Row(
                      children: [
                        const _Brand(),
                        const SizedBox(width: 28),
                        const Expanded(child: _SearchField()),
                        const SizedBox(width: 20),
                        const _AccountButton(),
                        const _CartButton(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go('/'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Inverted against the blue band: white chip, blue mark.
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.memory_rounded,
                size: 18,
                color: AppColors.electricBlue,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'TechZone',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search box wired to the backend's `SearchFilter`, which matches against
/// `name`, `brand__name` and `description`.
class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final term = value.trim();
    if (term.isEmpty) return;
    context.go('/catalog?search=${Uri.encodeQueryComponent(term)}');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: _submit,
      decoration: InputDecoration(
        hintText: 'Search laptops, ACs, gadgets…',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        suffixIcon: IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          onPressed: () => _submit(_controller.text),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartProvider, int>((c) => c.totalQuantity);

    return IconButton(
      tooltip: 'Cart',
      onPressed: () => context.push('/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        // Inverted against the blue band, and never red: the count is a
        // highlight, not a problem.
        backgroundColor: AppColors.white,
        textColor: AppColors.electricBlue,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

/// Account menu. Shows a sign-in affordance when signed out and the profile
/// menu when signed in — there is no role switch, because `UserSerializer`
/// does not expose `role` and admin actions live in Django admin.
class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (!auth.isSignedIn) {
      return Responsive.isMobile(context)
          ? IconButton(
              tooltip: 'Sign in',
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.person_outline_rounded),
            )
          : Padding(
              padding: const EdgeInsets.only(right: 4),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: const Text('Sign in'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
            );
    }

    final user = auth.user;
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 46),
      onSelected: (value) async {
        switch (value) {
          case 'profile':
            context.push('/account');
          case 'address':
            context.push('/account/address');
          case 'password':
            context.push('/account/password');
          case 'logout':
            context.read<CartProvider>().reset();
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.fullName ?? 'Account',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                user?.email ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline_rounded, size: 20),
            title: Text('My profile'),
          ),
        ),
        const PopupMenuItem(
          value: 'address',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.location_on_outlined, size: 20),
            title: Text('Shipping address'),
          ),
        ),
        const PopupMenuItem(
          value: 'password',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.lock_outline_rounded, size: 20),
            title: Text('Change password'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, size: 20),
            title: Text('Sign out'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            user?.initials ?? '?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop category strip. Root categories with children open a hover menu of
/// their sub-categories, matching the taxonomy the API returns.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context) {
    final categories = context.select<CatalogProvider, List<Category>>(
      (catalog) => catalog.categories,
    );
    if (categories.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Material(
      color: theme.appBarTheme.backgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Responsive.maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.gutter(context) - 8,
            ),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  // White on the blue band; _HeaderBand already sets the
                  // foreground, so these buttons just inherit it.
                  TextButton.icon(
                    onPressed: () => context.go('/catalog'),
                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                    label: const Text('All products'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 2),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        if (!category.hasChildren) {
                          return Center(
                            child: TextButton(
                              onPressed: () => context.go(
                                '/catalog?category=${category.slug}',
                              ),
                              child: Text(category.name),
                            ),
                          );
                        }
                        return Center(
                          child: PopupMenuButton<String>(
                            tooltip: category.name,
                            offset: const Offset(0, 40),
                            onSelected: (slug) =>
                                context.go('/catalog?category=$slug'),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: category.slug,
                                child: Text('All ${category.name}'),
                              ),
                              const PopupMenuDivider(),
                              for (final child in category.subCategories)
                                PopupMenuItem(
                                  value: child.slug,
                                  child: Text(child.name),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    category.name,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    size: 16,
                                    color: AppColors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile/tablet category drawer.
class _CategoryDrawer extends StatelessWidget {
  const _CategoryDrawer();

  @override
  Widget build(BuildContext context) {
    final categories = context.select<CatalogProvider, List<Category>>(
      (catalog) => catalog.categories,
    );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Browse',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('All products'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/catalog');
              },
            ),
            const Divider(),
            for (final category in categories)
              if (category.hasChildren)
                ExpansionTile(
                  title: Text(category.name),
                  childrenPadding: const EdgeInsets.only(left: 16),
                  children: [
                    ListTile(
                      dense: true,
                      title: Text('All ${category.name}'),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go('/catalog?category=${category.slug}');
                      },
                    ),
                    for (final child in category.subCategories)
                      ListTile(
                        dense: true,
                        title: Text(child.name),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/catalog?category=${child.slug}');
                        },
                      ),
                  ],
                )
              else
                ListTile(
                  title: Text(category.name),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/catalog?category=${category.slug}');
                  },
                ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Responsive.maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.gutter(context),
              vertical: 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isMobile ? 0 : 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TechZone',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Laptops, desktops, appliances and gadgets.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMobile) const SizedBox(height: 20),
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shop',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _FooterLink(
                            label: 'All products',
                            onTap: () => context.go('/catalog'),
                          ),
                          _FooterLink(
                            label: 'Featured',
                            onTap: () => context.go('/catalog?featured=true'),
                          ),
                          _FooterLink(
                            label: 'Your cart',
                            onTap: () => context.push('/cart'),
                          ),
                        ],
                      ),
                    ),
                    if (isMobile) const SizedBox(height: 20),
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _FooterLink(
                            label: 'My profile',
                            onTap: () => context.push('/account'),
                          ),
                          _FooterLink(
                            label: 'Shipping address',
                            onTap: () => context.push('/account/address'),
                          ),
                          _FooterLink(
                            label: 'Sign in',
                            onTap: () => context.push('/login'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'TechZone storefront — Flutter Web frontend on the TechZone '
                  'Django REST API.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
