import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../screens/account/account_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/verify_email_screen.dart';
import '../../screens/cart/cart_screen.dart';
import '../../screens/catalog/catalog_screen.dart';
import '../../screens/checkout/checkout_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';
import '../utils/responsive.dart';

/// Application routes.
///
/// Storefront pages are nested in a [ShellRoute] so the header, category nav
/// and footer persist across navigation. Auth screens sit outside it, since
/// they are full-page and have their own chrome.
///
/// Protected routes redirect to `/login?next=…` rather than rendering an empty
/// state, and the redirect waits for [AuthProvider.isResolving] to finish so a
/// browser refresh on a protected URL does not bounce a signed-in customer.
class AppRouter {
  AppRouter(this._auth);

  final AuthProvider _auth;

  /// Routes that need a signed-in customer.
  static const _protected = <String>{
    '/checkout',
    '/account',
    '/account/address',
    '/account/password',
  };

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    // initialLocation: '/login',
    // Rebuild redirects when the session changes.
    refreshListenable: _auth,
    redirect: (context, state) {
      // Hold still until the stored token has been checked.
      if (_auth.isResolving) return null;

      final location = state.matchedLocation;
      final isAuthRoute = _authRoutes.contains(location);

      if (!_auth.isSignedIn && _protected.contains(location)) {
        final next = Uri.encodeQueryComponent(state.uri.toString());
        return '/login?next=$next';
      }

      // A signed-in customer has no use for the sign-in pages.
      if (_auth.isSignedIn && isAuthRoute) return '/';

      return null;
    },
    errorBuilder: (context, state) => AppShell(
      child: PageContainer(
        child: EmptyState(
          title: 'Page not found',
          message: 'We could not find ${state.uri.path} on the storefront.',
          icon: Icons.explore_off_rounded,
          action: FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Back to home'),
          ),
        ),
      ),
    ),
    routes: [
      // ---------------------------------------------------------- storefront
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/catalog',
            name: 'catalog',
            builder: (context, state) {
              final params = state.uri.queryParameters;
              return CatalogScreen(
                categorySlug: params['category'],
                brandSlug: params['brand'],
                search: params['search'],
                featured: params['featured'] == 'true',
              );
            },
          ),
          GoRoute(
            path: '/product/:slug',
            name: 'product',
            builder: (context, state) => ProductDetailScreen(
              slug: state.pathParameters['slug']!,
              // The clicked card, when navigation came from a listing. It
              // carries `key_feature`/`colors`, which the detail serializer
              // omits. Null on a direct URL visit, which the screen handles.
              listEntry: state.extra is Product ? state.extra as Product : null,
            ),
          ),
          GoRoute(
            path: '/cart',
            name: 'cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: '/checkout',
            name: 'checkout',
            builder: (context, state) => const CheckoutScreen(),
          ),
          GoRoute(
            path: '/account',
            name: 'account',
            builder: (context, state) => const AccountScreen(),
            routes: [
              GoRoute(
                path: 'address',
                name: 'address',
                builder: (context, state) => const AddressScreen(),
              ),
              GoRoute(
                path: 'password',
                name: 'change-password',
                builder: (context, state) => const ChangePasswordScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------------------- auth
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) =>
            LoginScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(email: state.uri.queryParameters['email']),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
    ],
  );

  /// Auth pages a signed-in customer should not land on.
  ///
  /// `/verify-email` is excluded: `verifyEmail` signs the customer in as part
  /// of its own success path, and redirecting mid-flow would interrupt it.
  static const _authRoutes = <String>{
    '/login',
    '/register',
    '/forgot-password',
  };
}
