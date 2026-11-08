# TechZone — React + TypeScript + Tailwind CSS

A complete React storefront built against the supplied TechZone Django REST Framework backend. The previous Flutter project is not required.

## Requirements
- Node.js 20.19+ or Node.js 22+
- npm
- Django backend running at `http://127.0.0.1:8000`

## Start — fixed ports

**CMD window 1 (Django)**
```cmd
cd /d "D:\project work 2\tech_zone\Backend"
venv\Scripts\activate
python manage.py runserver 127.0.0.1:8000
```

**CMD window 2 (React)**
```cmd
cd /d "D:\project work 2\tech_zone\techzone-react"
npm install
npm run dev
```

Open **http://localhost:3000**. You can also double-click `start_frontend.bat` after extracting the project.

The Vite development server proxies `/api`, `/media`, and `/static` to Django. No `.env` is required for local development. Do not set `VITE_API_BASE_URL` unless you are intentionally using a separately hosted backend.

## Build and tests
```cmd
npm run typecheck
npm test
npm run build
```

## Django integration

Uses the existing `/api/v1/` endpoints for products, categories, brands, product images, cart, orders, payments, wishlist, accounts, PC Builder and discounts.

The catalog expects the **multi-brand filtering patch you already applied** (`brand=asus,msi`, `min_price`, `max_price`, `in_stock`, `on_sale`, category specification keys). Categories' `filters` JSON controls which specification filters are shown. Product images are loaded from the separate `product-images/` API because the list serializer doesn't include image fields.

**SSLCommerz:** React opens only HTTPS payment URLs on an `sslcommerz.com` hostname returned by Django. Your Django backend must have working sandbox credentials and a real public HTTPS callback URL. React cannot bypass the backend's public HTTPS requirement. Keep `FRONTEND_URL` and `SSLCOMMERZ_FRONTEND_URL` as `http://localhost:3000` for local testing. Don't create duplicate orders to retry payment: use the existing order's **Pay with SSLCommerz** button.

**Payment return:** Django redirects to `/payment-result/?transaction_id=...&result=...`. React checks the authenticated payment history and provides a backend verification action. It never marks an order paid based solely on the URL.

**Production:** Configure `VITE_API_BASE_URL` to your deployed Django HTTPS origin or use a same-origin reverse proxy, configure Django CORS, `ALLOWED_HOSTS`, and `CSRF_TRUSTED_ORIGINS` as appropriate, and serve the React SPA with an index.html fallback for deep links. JWT tokens are currently stored in browser localStorage to match the existing Django JWT API; for production, consider migrating to HttpOnly-cookie authentication to reduce token exposure to XSS.

## Important known constraints

- The backend ZIP is an earlier snapshot of `products/filters.py`. This React frontend assumes your **tested multi-select filter patch** is installed (you reported 6/6 passing tests).
- The product-list API does not include images, so the frontend loads product images from the separate endpoint. For very large catalogs, a backend batch-image endpoint or image field in the list serializer is recommended.
- PC Builder requires `PCComponentCategory` mappings in Django Admin. Compatibility is checked by the backend.
- No demo/fake products or mock payment confirmations are injected into real shopping flows.
- Registration requires email OTP, and password recovery requires the backend's OTP + reset token sequence.

## Pages

Home, catalog, product details, login, registration, email OTP, forgot-password/OTP/reset, cart, checkout, orders, order detail, payment result, wishlist, public shared wishlist, comparison, PC Builder, profile, address, and change password.
