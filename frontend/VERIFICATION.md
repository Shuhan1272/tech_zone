# Verification and limitations

## Completed in the authoring environment

- All TypeScript and TSX source files parsed successfully with the TypeScript compiler.
- All relative source/asset imports were checked for missing files.
- TypeScript type-checking was performed with a temporary **React declaration shim** because npm packages were not downloadable in the authoring environment. This is not equivalent to checking with official `@types/react`.
- All 11 included Node regression/static tests passed.
- CSS parsed successfully with PostCSS.
- ZIP file integrity and file paths were checked.

## Not completed in the authoring environment

- `npm install` (the package registry was not reachable).
- `npm run build` using the actual React/Vite/Tailwind dependencies.
- Live Chrome runtime testing with React 19 and a running Django backend.
- Real SSLCommerz payment testing.

Do not treat this project as production-verified until those steps pass on your Windows machine. The frontend cannot fix the backend's requirement for real SSLCommerz sandbox credentials and a public HTTPS callback URL.

## Windows acceptance test

From the extracted `techzone-react` folder:

```cmd
npm install
npm run typecheck
npm test
npm run build
npm run dev
```

With Django running on port 8000, open http://localhost:3000 and verify:

1. Home page at desktop (1440px), tablet (768px) and phone (390px) widths.
2. Category navigation and mobile menu; sign in and registration pages retain header and footer.
3. Catalog multi-brand selection (ASUS + MSI), price range, stock and specification filters, sorting and pagination.
4. Product detail variants, quantity, cart and wishlist actions.
5. Email OTP, forgot-password OTP and password reset with your real email backend.
6. Checkout creates **one** order; payment failure retains the order ID for retry.
7. Payment gateway redirect only after Django returns a valid SSLCommerz HTTPS URL.
8. Orders, comparison, wishlist sharing, PC Builder and account/address updates.

If `npm run typecheck` or `npm run build` reports an error, capture the exact output so it can be fixed. Avoid repeatedly placing test orders while SSLCommerz is unconfigured.
