import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/account_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'services/account_service.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/discount_service.dart';
import 'services/product_service.dart';

void main() {
  runApp(const TechZoneApp());
}

/// Composition root.
///
/// The dependency graph is wired once here — one [TokenStorage], one
/// [ApiClient], one service per API area — and handed to the providers, so
/// every request shares the same session and the same refresh logic.
class TechZoneApp extends StatefulWidget {
  const TechZoneApp({super.key});

  @override
  State<TechZoneApp> createState() => _TechZoneAppState();
}

class _TechZoneAppState extends State<TechZoneApp> {
  late final TokenStorage _tokens;
  late final ApiClient _client;

  late final AuthService _authService;
  late final AccountService _accountService;
  late final ProductService _productService;
  late final CartService _cartService;
  late final DiscountService _discountService;

  late final AuthProvider _auth;
  late final CatalogProvider _catalog;
  late final CartProvider _cart;
  late final AccountProvider _account;

  late final AppRouter _router;

  @override
  void initState() {
    super.initState();

    _tokens = TokenStorage();
    _client = ApiClient(tokens: _tokens);

    _authService = AuthService(client: _client, tokens: _tokens);
    _accountService = AccountService(_client);
    _productService = ProductService(_client);
    _cartService = CartService(_client);
    _discountService = DiscountService(_client);

    _auth = AuthProvider(service: _authService, tokens: _tokens);
    _catalog = CatalogProvider(_productService);
    _cart = CartProvider(
      cartService: _cartService,
      productService: _productService,
      discountService: _discountService,
    );
    _account = AccountProvider(_accountService);

    // A failed token refresh drops the app to signed-out and clears the cart,
    // rather than leaving the UI in a half-authenticated state.
    _client.onSessionExpired = () {
      _auth.handleSessionExpired();
      _cart.reset();
      _account.reset();
    };

    _router = AppRouter(_auth);

    _bootstrap();
  }

  /// Restores the session, then loads the data that depends on it.
  Future<void> _bootstrap() async {
    // Catalog reference data is public, so it can load in parallel with the
    // session check.
    final catalogLoad = _catalog.load();
    await _auth.bootstrap();

    if (_auth.isSignedIn) {
      await _cart.load();
      await _account.load();
    }
    await catalogLoad;
  }

  @override
  void dispose() {
    _auth.dispose();
    _catalog.dispose();
    _cart.dispose();
    _account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services, so screens can spin up their own scoped providers
        // (e.g. a ProductListProvider per listing).
        Provider<ApiClient>.value(value: _client),
        Provider<ProductService>.value(value: _productService),
        Provider<AuthService>.value(value: _authService),
        Provider<CartService>.value(value: _cartService),
        Provider<DiscountService>.value(value: _discountService),
        Provider<AccountService>.value(value: _accountService),

        // App-wide state.
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider<CatalogProvider>.value(value: _catalog),
        ChangeNotifierProvider<CartProvider>.value(value: _cart),
        ChangeNotifierProvider<AccountProvider>.value(value: _account),
      ],
      child: MaterialApp.router(
        title: 'TechZone',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // One theme only: the storefront is light throughout, so the platform
        // dark setting must not swap the palette out from under it.
        themeMode: ThemeMode.light,
        routerConfig: _router.router,
      ),
    );
  }
}
