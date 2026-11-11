import { type ReactNode } from 'react';
import { label, money, title, type Row } from './api';

const paths: Record<string, string> = {
  overview: 'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z',
  orders: 'M5 4h14v17l-3-2-4 2-4-2-3 2z M9 8h6 M9 12h6',
  Commerce: 'M4 8h16l-1 13H5z M8 9V6a4 4 0 018 0v3',
  Catalog: 'm3 7 9-5 9 5-9 5z M3 7v10l9 5 9-5V7 M12 12v10',
  products: 'm3 7 9-5 9 5-9 5z M3 7v10l9 5 9-5V7 M12 12v10',
  variants: 'M4 4h16v16H4z M4 9h16 M9 9v11 M14 13h3 M14 16h3',
  categories: 'M3 4h7v7H3z M14 4h7v7h-7z M3 15h7v7H3z M14 15h7v7h-7z',
  brands: 'M4 4h8l9 9-8 8-9-9z M8 8h.01',
  images: 'M3 3h18v18H3z M3 16l5-5 4 4 3-3 6 6 M16 7h.01',
  colors: 'M12 3a9 9 0 109 9c0-2-4-1-4-4s-1-5-5-5 M7 10h.01 M9 6h.01 M6 14h.01 M10 17h.01',
  Merchandising: 'm3 4 9-1 10 10-9 9L3 12z M7 8h.01',
  discounts: 'M7 3H3v4l14 14 4-4L7 3z M7 7h.01 M14 5l5 5 M17 3l4 4',
  notices: 'M4 9h4l11-5v16L8 15H4z M8 15l2 6h3l-2-5 M22 10v4',
  Community:
    'M16 21v-2a5 5 0 00-5-5H8a5 5 0 00-5 5v2 M14 7a4 4 0 11-8 0 4 4 0 018 0 M16 4a4 4 0 010 8 M18 15q4 1 4 6',
  customers:
    'M16 21v-2a5 5 0 00-5-5H8a5 5 0 00-5 5v2 M14 7a4 4 0 11-8 0 4 4 0 018 0 M16 4a4 4 0 010 8 M18 15q4 1 4 6',
  team: 'M16 21v-2a5 5 0 00-5-5H8a5 5 0 00-5 5v2 M14 7a4 4 0 11-8 0 4 4 0 018 0 M17 8h5 M19.5 5.5v5',
  reviews: 'm12 3 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1z',
  questions: 'M21 11a9 9 0 01-9 9H3l2-5a9 9 0 1116-4 M9 8a3 3 0 015 2c0 2-2 2-2 4 M12 17h.01',
  addresses: 'M19 9c0 5-7 12-7 12S5 14 5 9a7 7 0 1114 0 M15 9a3 3 0 11-6 0 3 3 0 016 0',
  carts: 'M2 3h3l3 13h11l3-9H6 M9 21h.01 M18 21h.01',
  wishlists: 'M20 5c-4-4-8 1-8 1S8 1 4 5c-5 5 8 15 8 15s13-10 8-15',
  'PC builder': 'M3 3h18v13H3z M12 16v5 M8 21h8',
  builds: 'M3 3h18v13H3z M12 16v5 M8 21h8',
  mappings: 'M4 4h6v6H4z M14 14h6v6h-6z M7 10v7h7 M10 7h7v7',
  Administration: 'M12 3l9 4v5c0 5-9 10-9 10S3 17 3 12V7z M8 12l3 3 5-6',
  roles: 'M12 3l9 4v5c0 5-9 10-9 10S3 17 3 12V7z M8 12l3 3 5-6',
  activity: 'M3 12h4l3-8 4 16 3-8h4',
  payments: 'M3 5h18v14H3z M3 10h18 M7 15h3',
  refunds: 'M3 10h12a6 6 0 010 12 M3 10l5-5 M3 10l5 5 M12 3h8v8',
  chart: 'M3 18l6-7 4 3 8-10 M15 4h6v6',
  clock: 'M21 12a9 9 0 11-18 0 9 9 0 0118 0 M12 6v6l4 2',
  wallet: 'M3 5h17v15H3z M15 10h6v5h-6z',
  arrow: 'M5 12h14 M14 7l5 5-5 5',
  chevron: 'm9 5 7 7-7 7',
  menu: 'M3 5h18 M3 12h18 M3 19h18',
  close: 'm6 6 12 12 M6 18 18 6',
  exit: 'M10 3H4v18h6 M9 12h12l-5-5 M21 12l-5 5',
  search: 'M16 10a6 6 0 11-12 0 6 6 0 0112 0 M15 15l6 6',
  lock: 'M5 10h14v11H5z M8 10V6a4 4 0 018 0v4 M12 14v3',
  shield: 'M12 3l9 4v5c0 5-9 10-9 10S3 17 3 12V7z M8 12l3 3 5-6',
  check: 'm5 12 4 4 10-10',
  plus: 'M12 4v16 M4 12h16',
  refresh: 'M20 7a9 9 0 10.5 9 M20 3v5h-5',
  filter: 'M3 5h18 M7 12h10 M10 19h4',
  download: 'M12 3v12 M7 10l5 5 5-5 M4 16v5h16v-5',
  eye: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12 M15 12a3 3 0 11-6 0 3 3 0 016 0',
  eyeoff:
    'M3 3l18 18 M10 5h2c6 0 10 7 10 7a22 22 0 01-4 4 M6 6a22 22 0 00-4 6s4 7 10 7a13 13 0 005-1 M10 10a3 3 0 004 4',
};

export function Icon({ name }: { name: string }) {
  return (
    <svg
      aria-hidden="true"
      width="19"
      height="19"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.65"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d={paths[name] || paths.Catalog} />
    </svg>
  );
}

export function Brand() {
  return (
    <div className="brand">
      <span className="mark" aria-hidden="true">
        <svg width="23" height="27" viewBox="0 0 24 28" fill="none">
          <path d="M14.5 1 2 16h9l-1 11L23 11h-9l.5-10Z" fill="currentColor" />
        </svg>
      </span>
      <div>
        TechZone<small>ADMIN CONSOLE</small>
      </div>
    </div>
  );
}

export function ErrorBox({ message }: { message: string }) {
  return message ? (
    <p role="alert" className="err">
      {message}
    </p>
  ) : null;
}

const booleanLabels: Record<string, [string, string]> = {
  is_active: ['Active', 'Inactive'],
  is_approved: ['Approved', 'Pending review'],
  is_featured: ['Featured', 'Standard'],
  is_email_verified: ['Verified', 'Unverified'],
  is_staff: ['Staff', 'Customer'],
  is_superuser: ['Owner', 'Staff'],
  is_public: ['Public', 'Private'],
  is_default: ['Default', 'No'],
};

export function display(key: string, value: unknown): ReactNode {
  if (value == null || value === '') return key === 'last_login' ? 'Never signed in' : '—';

  if (typeof value === 'boolean' || ['status', 'payment_status', 'availability'].includes(key)) {
    const text =
      typeof value === 'boolean'
        ? (booleanLabels[key] || ['Yes', 'No'])[value ? 0 : 1]
        : title(String(value));
    const state = typeof value === 'boolean' ? (value ? 'positive' : 'neutral') : String(value);
    return <span className={'badge state-' + state}>{text}</span>;
  }

  if (
    [
      'amount',
      'total_amount',
      'price',
      'unit_price',
      'line_total',
      'subtotal',
      'discount_amount',
    ].includes(key)
  ) {
    return <span className="money">{money(value)}</span>;
  }

  if (key === 'image' && String(value).startsWith('/media/')) {
    return <img className="thumb" src={String(value)} alt="Record image" />;
  }

  if (/^\d{4}-\d\d-\d\dT/.test(String(value))) {
    return new Date(String(value)).toLocaleDateString('en-GB', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      ...(['last_login', 'action_time'].includes(key)
        ? ({ hour: '2-digit', minute: '2-digit' } as const)
        : {}),
    });
  }

  return typeof value === 'object' ? JSON.stringify(value, null, 2) : String(value);
}

export function Grid({
  rows,
  columns,
  open,
}: {
  rows: Row[];
  columns: string[];
  open?: (id: number) => void;
}) {
  return (
    <div className="tablewrap">
      <table>
        <thead>
          <tr>
            <th scope="col">ID</th>
            {columns.map((column) => (
              <th scope="col" key={column}>
                {label(column)}
              </th>
            ))}
            {open && (
              <th scope="col">
                <span className="sr-only">Actions</span>
              </th>
            )}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id}>
              <td className="mono">#{row.id}</td>
              {columns.map((column) => (
                <td
                  className={
                    ['email', 'shipping_name', 'name', 'product_name'].includes(column)
                      ? 'cell-primary'
                      : undefined
                  }
                  key={column}
                >
                  {display(column, row[column])}
                </td>
              ))}
              {open && (
                <td className="row-action">
                  <button
                    className="link"
                    onClick={() => open(row.id)}
                    aria-label={'Open record ' + row.id}
                  >
                    View <Icon name="arrow" />
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
      {!rows.length && (
        <div className="empty empty-state">
          <span className="empty-icon">
            <Icon name="Catalog" />
          </span>
          <strong>No records found</strong>
          <span>Records matching this view will appear here.</span>
        </div>
      )}
    </div>
  );
}
