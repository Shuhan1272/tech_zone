# Admin upgrade notes

## Delivered changes

- Responsive navy and emerald admin design, two-column sign-in, resource icons, navigation search, account identity, status badges, and consistent empty/loading/error states.
- Owner-managed staff accounts, active/suspended totals, role/status filters, last sign-in, password reset, suspension/reactivation actions, and effective access summaries.
- Reusable roles with a searchable grouped permission picker, role member display, and protection against deleting assigned roles.
- Permission-aware operational alerts with filtered destinations; scoped inventory, fulfillment, moderation, and refund queues.
- Collection search, whitelisted ordering, clear filters, pagination, and safe current-page CSV downloads.
- Version checks, dependency-reviewed deletion for supported resources, unsaved-edit protection, preserved financial/staff history, and read-only activity history.
- Server-side authorization fixes across console APIs, legacy product/discount/refund APIs, and Django admin mutation actions.
- Registration now preserves existing identities, including unverified staff; password changes revoke previously issued access tokens.
- Prettier/Black formatting, editor settings, maintainable components, and setup documentation.

## Verification

Backend tests cover authorization, role changes, live-token suspension, staff provisioning, password hashing, stale updates, protected history, role dependencies, login auditing, safe cascades, account registration protection, and alternate admin API/action restrictions. Customer registration and owned refund flows are also covered.

Frontend checks include strict TypeScript, production builds for both entry points, existing storefront tests, and CSV correctness/formula protection. Chromium browser checks exercise owner sign-in, filtered alerts, role and staff creation, assigned access, unsaved changes, staff suspension/reactivation, denied delegated administration, CSV download, and mobile layout/navigation.

All browser checks use a separate database with fictional staff and store data. The uploaded database and media are preserved. Preview credentials and preview-only configuration are not shipped. External email and payment services were not exercised.

### Verified results

- Django system check: passed; migration check: no model changes detected.
- Backend suite: 49 tests passed.
- Frontend suite: 14 tests passed.
- Strict TypeScript and storefront/admin production builds: passed.
- Prettier and Black checks on the updated code: passed.
- Chromium: staff/role creation, access assignment, unsaved-change protection, suspension and reactivation, blocked delegated administration, CSV download, role membership display, and sign-out verified.
- Responsive browser checks: 390px dashboard and staff pages have no document overflow; mobile navigation opens and closes correctly. No JavaScript page errors.
- Original database snapshot checksum: unchanged from the uploaded archive.

The `previews` folder in the archive contains screenshots with fictional data. Open `previews/index.html` to review the design without running the app.
