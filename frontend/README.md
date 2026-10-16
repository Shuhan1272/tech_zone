Written for: developers working on the TechZone frontend.

# TechZone — Flutter frontend

A Flutter Web storefront for the existing TechZone Django REST API. The project
targets web first and keeps an Android-ready structure (nothing web-only sits in
`lib/`; responsive layouts cover phone, tablet and desktop widths).

## Running it

Two terminals, from the repository root.

**Terminal 1 — Django API**

```bat
cd Backend
venv\Scripts\activate
python manage.py runserver
```

API at <http://127.0.0.1:8000/api/v1/>, Django admin at
<http://127.0.0.1:8000/admin/>.

If `Backend\venv` does not exist yet:

```bat
cd Backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

**Terminal 2 — Flutter Web**

```bat
cd frontend
flutter pub get
flutter run -d chrome
```

Flutter prints the port it chose (e.g. <http://localhost:58123>). `CORS_ALLOW_ALL_ORIGINS`
is already enabled on the backend, so any dev port works.

## Configuration

The API host is the only thing to configure, and it is never hardcoded to a
production URL. `AppConfig.serverOrigin` reads the `API_BASE_URL` Dart define
and defaults to `http://127.0.0.1:8000`:

```bat
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```

Everything else is derived: `AppConfig.apiBaseUrl` appends `/api/v1`, and
`AppConfig.resolveMedia` turns relative `MEDIA_URL` paths into absolute ones.

## Authentication

SimpleJWT, no Firebase and no third-party auth. The backend requires email
verification before a first sign-in (`LoginSerializer` rejects unverified
accounts), so the flow is:

```
register  →  OTP emailed  →  verify-email (issues JWT)  →  signed in
```

In development `EMAIL_BACKEND` is the console backend, so **the OTP is printed
in the terminal running `runserver`** rather than emailed.

Tokens live in `localStorage` via `shared_preferences`. `ApiClient` attaches
`Authorization: Bearer <access>` and, on a 401, refreshes once and replays the
request; concurrent 401s share a single refresh. CSRF is not involved — the API
authenticates by bearer token, not session cookie.

## Layout

```
lib/
├── main.dart                  composition root: wires storage → client → services → providers
├── core/
│   ├── config/app_config.dart base URL, timeouts, page sizes, media resolution
│   ├── network/               api_client (JWT + refresh), api_endpoints, api_exception, token_storage
│   ├── router/app_router.dart go_router: shell routes + auth guards
│   ├── theme/app_theme.dart   light/dark Material 3 theme
│   └── utils/                 formatters (BDT money, dates), responsive breakpoints
├── models/                    one class per serializer shape
├── services/                  one class per API area
├── providers/                 ChangeNotifier state (auth, catalog, product list/detail, cart, account)
├── screens/                   auth, home, catalog, product, cart, checkout, account
└── widgets/                   app_shell, product_card, common states
```

State management is `provider`. App-wide state (session, catalog reference data,
cart, address) is created once in `main.dart`; per-screen state such as
`ProductListProvider` is created by the screen that owns it.

## Where the backend decides, not the frontend

- **Prices.** Every amount shown comes from the server: `price`,
  `discounted_price` and `saved_price` are read verbatim from
  `ProductVariantSerializer`. No discount is ever computed on the client.
- **Stock.** The quantity stepper is capped by the variant's `stock`, but an
  over-stock add is still rejected server-side and that message is shown as-is.
- **Cart arithmetic.** Adding a variant that is already in the cart *increments*
  server-side, so every mutation refetches the cart instead of guessing.
- **Filtering, sorting, paging, search.** All delegated to `ProductFilter`,
  `OrderingFilter` and `ProductPagination` via query parameters.
- **Coupons.** The client sends only a code and would display the server's
  computed amount; it never sends or derives a discount figure.

Cart totals are the one client-side sum, because `CartSerializer` returns no
totals. They are built from the server's own per-unit prices and are display
only — there is no checkout endpoint to send them to.

## Not available on the current backend

The UI covers these and reports the gap plainly rather than appearing broken:

- **Coupons / discounts.** `discounts/urls.py` exists but `config/urls.py` never
  `include()`s it, and the app has no migrations (no `discounts_discount`
  table). `POST /api/v1/discounts/apply/` was never implemented.
  `DiscountService.probe()` detects this at runtime, so the coupon field
  activates on its own once the route is wired up.
- **Orders.** The `order` app has no models, serializers, views or URLs, and
  nothing is routed at `/api/v1/orders/`. Checkout reviews the cart and address
  and then stops, with the place-order button disabled. There is no payment
  integration because the backend defines none.

## Tests

```bat
flutter analyze
flutter test                              # all suites
flutter test --exclude-tags integration   # skip the suites needing a server
flutter test test/api_integration_test.dart
```

- `test/widget_test.dart` — parsing and query building (no backend).
- `test/render_test.dart` — pumps the real app over a fake Dio adapter replaying
  captured payloads; asserts every route renders without layout errors.
- `test/api_integration_test.dart` — the real service layer against a running
  Django server. Skips itself (not passes) when no server is reachable. Needs a
  verified account; override with `--dart-define=TEST_EMAIL=…
  --dart-define=TEST_PASSWORD=…`.

Two flutter_test quirks shaped the widget tests and are worth knowing before
adding more: Dio's futures do not progress inside the fake-async zone a
`testWidgets` body runs in, so network work goes through `tester.runAsync`; and
`pumpAndSettle` never returns while a `CircularProgressIndicator` is on screen,
so the helper `_settle()` uses bounded pumps instead.
