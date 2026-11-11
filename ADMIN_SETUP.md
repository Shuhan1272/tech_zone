# TechZone operations console

The existing Django backend and React storefront now include an upgraded operations console at **http://localhost:3000/admin/**. The storefront remains at http://localhost:3000/ and Django administration remains at http://127.0.0.1:8000/admin/.

## Start the project

Use Python 3.12 or later and Node.js 22 or later. Extract into a new folder first. Keep your current database, uploaded media, and `.env` if they are newer than the uploaded project snapshot. The improved archive excludes `.env`, dependencies, caches, and all fictional preview data.

### Backend (Windows)

```bat
cd Backend
py -m venv venv
venv\Scripts\activate
python -m pip install -r requirements.txt
```

Copy your existing `.env` into Backend, or copy `.env.example` to `.env` and fill in your own settings. Generate a new development secret if needed:

```bat
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

Skip `createsuperuser` if you already have an owner account. On macOS/Linux use `python3 -m venv venv` and `source venv/bin/activate` instead of the Windows activation commands.

### Frontend

In a second terminal:

```sh
cd Frontend
npm ci
npm run dev
```

Open `/admin/` and sign in with an active staff or owner account. New permissions do not require new migrations; they use the existing Django Group and Permission models.

## Set up your team

1. Sign in as a Django superuser (workspace owner).
2. Open **Administration → Roles & permissions** and create a role such as “Catalog manager” or “Order operator”.
3. Search the grouped permission picker and choose **View** for each resource the role should access. Add **Add**, **Change**, or **Delete** only where the role needs them. Operational actions such as order confirmation require the resource's **Change** permission.
4. Open **Staff accounts → Add staff member**. Set a strong initial password, complete their contact details, and assign one or more roles. Additional permissions support individual exceptions.
5. Staff sign in using their email and password. Their navigation shows only permitted resources. **View Orders** enables the analytics dashboard.

Staff accounts show active/suspended status, role assignments, last sign-in, and an effective permission count. Filters support role and account status. The directory excludes superusers so routine staff changes cannot lock out an owner.

Open a staff record to edit details, reset their password, suspend them, or reactivate them. Suspension immediately blocks existing tokens and new sign-ins. Password changes invalidate previously issued access tokens. Role grants and revocations apply on the next request without requiring staff to sign in again. After this upgrade, existing JWT sessions need to sign in again because tokens now include a password revocation check.

Staff records are preserved rather than deleted. A role cannot be deleted while assigned to an account. Reassign those accounts first. Account/role administration in both the console and the original Django admin is restricted to superusers; customer account permissions do not grant staff-management access.

## Everyday operations

| Area | Capabilities |
| --- | --- |
| Overview | 7/30/90-day paid revenue, average order value, fulfillment counts, recent orders, best sellers, and permission-scoped operational alerts |
| Commerce | Order/customer/shipping details, line items, order status transitions, COD collection, payment verification, and refund review/processing |
| Catalog | Products, category trees, brands, images, colors, variant pricing, stock, and visibility |
| Merchandising | Promo codes, discount values and limits, scheduling, and customer announcements |
| Community | Customer access, addresses, carts, wishlists, review moderation, and product answers |
| PC builder | Component-category mappings and saved configurations |
| Administration | Staff provisioning, status, reusable roles, individual permissions, and activity history |

**Needs attention** uses current store-wide counts, separate from the dashboard's selected reporting period. Its links open filtered low-stock/out-of-stock inventory, pending orders, reviews, unanswered questions, refund requests, or payment reviews. Alerts and counts only include resources the current operator may view.

Paid revenue includes paid, non-cancelled orders by their order creation date. Average paid order uses the same set. Best sellers use saved order-line product names and paid unit counts. Reports use the store's Asia/Dhaka timezone and display BDT. Staff sign-in history also displays in that timezone. The dashboard does not invent growth comparisons or live presence; “Active” means account enabled, not currently online.

## Search, exports, and editing

- Search by displayed record ID or supported descriptive fields. Use filters, sorting, and pagination to narrow a collection, or clear filters to start again.
- **Export page** downloads the displayed page as CSV, including the applied filters and ordering. It is a page export, not a complete database export. Text is quoted and spreadsheet formula prefixes are neutralized.
- Editors preserve submitted values after validation failures. Closing an edited form asks before discarding unsaved changes.
- Version checks reject stale edits. Reopen a record to load current values after a conflict.
- Activity history records console sign-ins and changes, including staff status and role changes. Activity entries cannot be edited or deleted through the console. This is application history, not an external tamper-proof logging service.

## Fulfillment, payments, and deletion

Use the offered order transitions to confirm, ship, and deliver orders. Confirm COD collection only after delivery and receipt of payment. Use cancellation workflows so reserved stock is handled correctly.

Refund approval and gateway submission are separate steps. Gateway operations use your existing SSLCommerz configuration and services. Configure your own gateway settings before using these operations; no real gateway requests were made during verification.

Financial records (orders, payments, and refunds), staff records, and activity history cannot be deleted through the console. Supported catalog/content deletion shows affected records and dependencies first, checks delete permission for every affected model, and rechecks the plan on confirmation. Prefer deactivation when historical references should be kept.

## Code organization and formatting

- `Backend/admin_panel/resources.py`: explicit resource fields, permissions, and safe deletion policy.
- `Backend/admin_panel/permissions.py`: active staff access gate.
- `Backend/admin_panel/insights.py`: permission-scoped operational counts and alerts.
- `Backend/admin_panel/forms.py`: server validation, staff password hashing, and permission choices.
- `Backend/admin_panel/views.py`: login, workspace, permission catalog, record operations, and reporting.
- `Frontend/src/admin/Console.tsx`: workspace shell and resource routing.
- `Frontend/src/admin/AccessFields.tsx`: role assignment and searchable permission choices.
- `Frontend/src/admin/Editor.tsx`: record editing and reviewed operations.
- `Frontend/src/admin/Collection.tsx`: resource search, filters, sorting, and export.
- `Frontend/src/admin/Overview.tsx`: dashboard and operational queues.
- `Frontend/src/admin/export.ts`: safe CSV output.

The admin code uses Prettier for TypeScript/CSS and Black for Python. `.editorconfig` and `Frontend/.prettierrc.json` keep indentation and formatting consistent.

```sh
# From Frontend
npm run format:admin
npm run format:check
npm run typecheck
npm test
npm run build

# From Backend with the virtual environment active
python -m pip install -r requirements-dev.txt
python -m black admin_panel
python manage.py check
python manage.py test
```

Vite builds both storefront and admin entry points into `Frontend/dist`. For deployment, serve `dist/admin/index.html` for `/admin/` on the frontend host and forward `/api/` and `/media/` to Django. Keep Django's `/admin/` on the backend host/port or route it separately. Set production secrets, allowed hosts, HTTPS, and integration settings for your existing hosting environment.

See `ADMIN_CHANGES.md` for the implementation and verification notes.
