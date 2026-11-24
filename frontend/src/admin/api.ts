export type Section = {
  key: string;
  title: string;
  group: string;
  actions?: string[];
};
export type Row = Record<string, unknown> & {
  id: number;
};
export type List = {
  columns: string[];
  filters: Record<string, [string, string][]>;
  rows: Row[];
  page: number;
  pages: number;
  count: number;
  create: boolean;
  summary?: Record<string, number>;
  ordering?: string;
  sortable?: string[];
};
export type DeletionSummary = {
  changes: string[];
  blockers: string[];
  token: string;
};

export type Detail = {
  deletion: DeletionSummary | null;
  data: Row;
  form: string;
  version: string;
  items: Row[];
  actions: string[];
  delete: boolean;
  access?: {
    groups: { id: number; name: string }[];
    direct_permissions: number[];
    effective_permissions: string[];
    last_login: string | null;
    date_joined: string;
  };
  members?: { id: number; email: string; is_active: boolean; is_staff: boolean }[];
};
export type Stats = {
  start?: string;
  end?: string;
  days?: number;
  sellers: {
    product_name: string;
    units: number;
  }[];
  revenue: number;
  orders: number;
  average: number;
  pending: number;
  states: Record<string, number>;
  series: {
    date: string;
    value: number;
  }[];
  recent: Row[];
  alerts?: { key: string; title: string; count: number; filter?: string }[];
  summary?: Record<string, number>;
};
export const sessionKey = 'techzone.ops.access';
const SMALL_WORDS = new Set(['a', 'an', 'and', 'of', 'or', 'the', 'to', 'in', 'on', 'for', 'by']);

/** snake_case or plain text → Title Case ("payment_status" → "Payment Status"). */
export const title = (value: string) =>
  value
    .replaceAll('_', ' ')
    .split(' ')
    .map((word, index) =>
      index > 0 && SMALL_WORDS.has(word.toLowerCase())
        ? word.toLowerCase()
        : word.charAt(0).toUpperCase() + word.slice(1),
    )
    .join(' ');
export const money = (value: unknown) =>
  '৳' +
  Number(value).toLocaleString('en-BD', {
    maximumFractionDigits: 2,
  });
export const labels: Record<string, string> = {
  shipping_name: 'Customer',
  total_amount: 'Total',
  is_active: 'Active',
  is_approved: 'Approved',
  sku: 'SKU',
  is_emi: 'EMI',
  emi_months: 'EMI Months',
  created_at: 'Created',
  collect_cod: 'Confirm COD Collection',
  confirmed: 'Confirm Order',
  cancelled: 'Cancel Order',
  shipped: 'Mark Shipped',
  delivered: 'Mark Delivered',
  activate_staff: 'Activate Staff Account',
  deactivate_staff: 'Suspend Staff Account',
  groups: 'Roles',
  group: 'Role',
  permissions: 'Permissions',
  user_permissions: 'Additional Permissions',
  first_name: 'First Name',
  last_login: 'Last Sign-In',
  date_joined: 'Joined',
  action_flag: 'Action',
  object_repr: 'Record',
  action_time: 'Time',
  permission_count: 'Permissions',
  member_count: 'Assigned Accounts',
};
export const label = (key: string) => labels[key] || title(key);
export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = sessionStorage.getItem(sessionKey);
  const headers = new Headers(options.headers);
  if (token && path !== 'login/') headers.set('Authorization', 'Bearer ' + token);
  if (typeof options.body === 'string') headers.set('Content-Type', 'application/json');
  const res = await fetch('/api/v1/admin-panel/' + path, {
    ...options,
    headers,
  });
  if (res.status === 401 && token) {
    sessionStorage.removeItem(sessionKey);
    window.dispatchEvent(new Event('ops-expired'));
  }
  if (res.status === 204) return undefined as T;
  const body = await res.json().catch(() => ({
    detail: 'The server could not complete this request.',
  }));
  if (!res.ok)
    throw new Error(
      typeof body === 'string'
        ? body
        : Array.isArray(body)
          ? body.join(' ')
          : Object.entries(body)
              .map(
                ([k, v]) => (k === 'detail' || k === '__all__' ? '' : label(k) + ' — ') + String(v),
              )
              .join(' · '),
    );
  return body;
}
