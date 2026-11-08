
import type { AnyRecord } from './types';

// =========================================================
// API Configuration
// =========================================================

const base = (
  import.meta.env.VITE_API_BASE_URL ?? ''
).replace(/\/$/, '');

const tokenKey = 'techzone_access';
const refreshKey = 'techzone_refresh';

// =========================================================
// Token Management
// =========================================================

export const tokens = {

  getAccess: () =>
    localStorage.getItem(tokenKey),

  getRefresh: () =>
    localStorage.getItem(refreshKey),

  save: (access: string, refresh: string) => {
    localStorage.setItem(tokenKey, access);
    localStorage.setItem(refreshKey, refresh);
  },

  clear: () => {
    localStorage.removeItem(tokenKey);
    localStorage.removeItem(refreshKey);
  },
};

// =========================================================
// API Error Class
// =========================================================

export class ApiError extends Error {

  constructor(
    message: string,
    public status: number,
    public fields: AnyRecord = {}
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

// =========================================================
// Extract Error Message
// =========================================================

const getError = (
  data: unknown,
  status: number
): ApiError => {

  if (typeof data === 'string') {

    // Never display an entire HTML error page.
    if (
      data.includes('<!DOCTYPE html') ||
      data.includes('<html')
    ) {
      return new ApiError(
        `Server error (${status}). Please check the Django backend terminal.`,
        status
      );
    }

    const message = data.trim();

    return new ApiError(
      message.length > 500
        ? message.slice(0, 500) + '...'
        : message || `Request failed (${status})`,
      status
    );
  }

  if (!data || typeof data !== 'object') {
    return new ApiError(
      `Request failed (${status})`,
      status
    );
  }

  const fields = data as AnyRecord;

  const value =
    fields.detail ??
    fields.message ??
    fields.non_field_errors ??
    Object.values(fields)[0];

  let message: string;

  if (Array.isArray(value)) {

    message = value.map(String).join(' ');

  } else if (typeof value === 'string') {

    message = value;

  } else {

    message = JSON.stringify(value ?? fields);

  }

  if (message.length > 500) {
    message = message.slice(0, 500) + '...';
  }

  return new ApiError(
    message || `Request failed (${status})`,
    status,
    fields
  );
};

// =========================================================
// Token Refresh
// =========================================================

let refreshPromise: Promise<string | null> | null = null;

async function refreshToken(): Promise<string | null> {

  if (refreshPromise) {
    return refreshPromise;
  }

  refreshPromise = (async () => {

    const refresh = tokens.getRefresh();

    if (!refresh) {
      return null;
    }

    try {

      const response = await fetch(
        `${base}/api/v1/accounts/token/refresh/`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ refresh }),
        }
      );

      if (!response.ok) {
        throw new Error('Session expired');
      }

      const json = (await response.json()) as {
        access: string;
        refresh?: string;
      };

      if (!json.access) {
        throw new Error('Invalid refresh response');
      }

      tokens.save(
        json.access,
        json.refresh ?? refresh
      );

      return json.access;

    } catch {

      tokens.clear();

      window.dispatchEvent(
        new Event('techzone:auth-expired')
      );

      return null;
    }

  })();

  try {
    return await refreshPromise;
  } finally {
    refreshPromise = null;
  }
}

// =========================================================
// Main API Function
// =========================================================

export async function api<T>(
  path: string,
  options: {
    method?: string;
    body?: unknown;
    auth?: boolean;
    signal?: AbortSignal;
    headers?: Record<string, string>;
  } = {}
): Promise<T> {

  const {
    method = 'GET',
    body,
    auth = true,
    signal,
    headers = {},
  } = options;

  // Build API URL
  const url = path.startsWith('http')
    ? path
    : `${base}${path.startsWith('/') ? path : `/${path}`}`;

  // =======================================================
  // Request Function
  // =======================================================

  const request = async (
    access: string | null
  ): Promise<Response> => {

    const h: Record<string, string> = {
      ...headers,
    };

    if (body !== undefined) {
      h['Content-Type'] = 'application/json';
    }

    if (auth && access) {
      h.Authorization = `Bearer ${access}`;
    }

    return fetch(url, {
      method,
      headers: h,
      body:
        body === undefined
          ? undefined
          : JSON.stringify(body),
      signal,
    });
  };

  // =======================================================
  // Send Request
  // =======================================================

  let response: Response;

  try {

    response = await request(tokens.getAccess());

  } catch (error) {

    if (
      error instanceof Error &&
      error.name === 'AbortError'
    ) {
      throw error;
    }

    throw new ApiError(
      'Unable to connect to the server. Check your internet connection or Django backend.',
      0
    );
  }

  // =======================================================
  // Refresh Expired Token
  // =======================================================

  if (
    response.status === 401 &&
    auth &&
    tokens.getRefresh()
  ) {

    const fresh = await refreshToken();

    if (fresh) {

      try {
        response = await request(fresh);
      } catch (error) {

        if (
          error instanceof Error &&
          error.name === 'AbortError'
        ) {
          throw error;
        }

        throw new ApiError(
          'Unable to connect to the server.',
          0
        );
      }
    }
  }

  // =======================================================
  // No Content
  // =======================================================

  if (response.status === 204) {
    return undefined as T;
  }

  // =======================================================
  // Handle Response
  // =======================================================

  const contentType =
    response.headers.get('content-type') ?? '';

  let data: unknown;

  if (contentType.includes('application/json')) {

    try {

      data = await response.json();

    } catch {

      throw new ApiError(
        'Invalid JSON response from the backend.',
        response.status
      );
    }

  } else {

    const text = await response.text();

    // Prevent Django HTML traceback from appearing.
    if (!response.ok) {

      throw new ApiError(
        response.status >= 500
          ? `Internal server error (${response.status}). Check the Django terminal.`
          : `Request failed (${response.status}).`,
        response.status
      );
    }

    data = text;
  }

  // =======================================================
  // HTTP Error
  // =======================================================

  if (!response.ok) {
    throw getError(data, response.status);
  }

  return data as T;
}

// =========================================================
// API Endpoints
// =========================================================

export const endpoints = {

  products: '/api/v1/products/products/',
  images: '/api/v1/products/product-images/',
  categories: '/api/v1/products/categories/',
  brands: '/api/v1/products/brands/',

  questions: '/api/v1/products/questions/',
  reviews: '/api/v1/products/reviews/',

  cart: '/api/v1/cart/',
  cartItems: '/api/v1/cart/items/',

  orders: '/api/v1/orders/',
  checkout: '/api/v1/orders/checkout/',

  wishlist: '/api/v1/wishlist/',
  wishlistItems: '/api/v1/wishlist/items/',

  payments: '/api/v1/payments/',
  paymentInitiate: '/api/v1/payments/initiate/',

  pcBuilds: '/api/v1/pc-builder/builds/',
  pcComponents: '/api/v1/pc-builder/components/',
};

// =========================================================
// Query Parameter Helper
// =========================================================

export function withQuery(
  path: string,
  params:
    | URLSearchParams
    | Record<
        string,
        string | number | boolean | undefined | null
      >
) {

  const query =
    params instanceof URLSearchParams
      ? params
      : new URLSearchParams(
          Object.entries(params)
            .filter(
              ([, value]) =>
                value !== undefined &&
                value !== null &&
                value !== ''
            )
            .map(([key, value]) => [
              key,
              String(value),
            ])
        );

  return `${path}${
    query.toString() ? `?${query.toString()}` : ''
  }`;
}
