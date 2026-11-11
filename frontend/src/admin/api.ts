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
export const title = (value: string) =>
  value.replaceAll('_', ' ').replace(/^./, (c) => c.toUpperCase());
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
  created_at: 'Created',
  collect_cod: 'Confirm COD collection',
  confirmed: 'Confirm order',
  cancelled: 'Cancel order',
  shipped: 'Mark shipped',
  delivered: 'Mark delivered',
  activate_staff: 'Activate staff account',
  deactivate_staff: 'Suspend staff account',
  groups: 'Roles',
  group: 'Role',
  permissions: 'Permissions',
  user_permissions: 'Additional permissions',
  first_name: 'First name',
  last_login: 'Last sign-in',
  date_joined: 'Joined',
  action_flag: 'Action',
  object_repr: 'Record',
  action_time: 'Time',
  permission_count: 'Permissions',
  member_count: 'Assigned accounts',
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
