import type { Page, Product, Variant } from './types';

// ============================================================
// CURRENCY AND NUMBER UTILITIES
// ============================================================

/**
 * Format a numeric value as Bangladeshi Taka (BDT).
 *
 * Example:
 * money(75000) => "৳75,000"
 */

export const money = (value: unknown) =>
  `৳${Number(value ?? 0).toLocaleString('en-BD', {
    maximumFractionDigits: 0,
  })}`;

/**
 * Convert a value to a number.
 * Returns 0 for null or undefined.
 */

export const number = (value: unknown) =>
  Number(value ?? 0);

// ============================================================
// SHIPPING
// ============================================================

/**
 * Shipping is 10% of each product's selling price.
 * Mirrors calculate_shipping() in Backend/order/services.py,
 * which decides the amount actually charged on the order.
 */

export const SHIPPING_RATE = 0.1;

export const shippingFor = (subtotal: number) =>
  subtotal > 0
    ? Math.round(subtotal * SHIPPING_RATE * 100) / 100
    : 0;

// ============================================================
// EMI
// ============================================================

/**
 * 0% EMI through SSLCommerz. Mirrors Backend/order/services.py.
 * EMI is charged at the regular (non-discounted) price.
 */

export const EMI_MONTHS = [3, 6, 9, 12] as const;
export const EMI_MAX_MONTHS = 12;
export const EMI_MIN_AMOUNT = 5000;

export type EmiMonths = (typeof EMI_MONTHS)[number];

/** Monthly instalment rounded up to the next whole taka. */
export const emiMonthly = (total: number, months: number) =>
  total > 0 && months > 0 ? Math.ceil(total / months) : 0;

/** Remembers the payment plan picked on a product page for checkout. */
export const PAYMENT_PLAN_KEY = 'techzone_payment_plan';

// ============================================================
// API RESPONSE UTILITIES
// ============================================================

/**
 * Convert an API response into an array.
 *
 * Supports:
 * - Direct arrays
 * - Paginated Django REST Framework responses
 * - Empty or invalid responses
 */

export const asList = <T,>(
  value: T[] | Page<T> | unknown
): T[] => {
  if (Array.isArray(value)) {
    return value as T[];
  }

  if (
    value &&
    typeof value === 'object' &&
    'results' in value &&
    Array.isArray((value as Page<T>).results)
  ) {
    return (value as Page<T>).results;
  }

  return [];
};

// ============================================================
// PRODUCT VARIANT UTILITIES
// ============================================================

/**
 * Get the preferred variant of a product.
 *
 * Priority:
 * 1. Default variant
 * 2. Active variant marked as default
 * 3. First active variant
 */

export const variantOf = (
  product: Product
): Variant | undefined => {
  return (
    product.default_variant ??
    product.variants?.find(
      (variant) =>
        variant.is_active !== false &&
        variant.is_default
    ) ??
    product.variants?.find(
      (variant) =>
        variant.is_active !== false
    )
  );
};

/**
 * Get the effective product price.
 *
 * Uses discounted price when available.
 * Otherwise, uses the regular price.
 */

export const priceOf = (product: Product) =>
  number(
    variantOf(product)?.discounted_price ??
    variantOf(product)?.price
  );

// ============================================================
// STRING UTILITIES
// ============================================================

/**
 * Convert a string into a URL-friendly slug.
 *
 * Example:
 * "Gaming Laptop ASUS" => "gaming-laptop-asus"
 */

export const slugify = (value: string) =>
  value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

// ============================================================
// DATE UTILITIES
// ============================================================

/**
 * Format a date using the Bangladesh locale.
 *
 * Example:
 * "2026-11-08" => "8 Nov 2026"
 */

export const shortDate = (value: string) =>
  value
    ? new Date(value).toLocaleDateString('en-BD', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      })
    : '';

// ============================================================
// VALUE FORMATTING UTILITIES
// ============================================================

/**
 * Convert different data types into readable text.
 *
 * Supports:
 * - Arrays
 * - Objects
 * - Strings
 * - Numbers
 * - Null and undefined
 */

export const valueText = (value: unknown): string => {
  if (Array.isArray(value)) {
    return value.map(valueText).join(', ');
  }

  if (value && typeof value === 'object') {
    return Object.entries(value)
      .map(
        ([key, item]) =>
          `${key}: ${valueText(item)}`
      )
      .join(' · ');
  }

  return String(value ?? '—');
};

// ============================================================
// SAFE REDIRECT UTILITIES
// ============================================================

/**
 * Validate an internal redirect path.
 *
 * Prevents:
 * - External redirects
 * - Protocol-relative redirects
 * - Redirects back to login routes
 */

export const safeNext = (
  value: string | null | undefined
) =>
  value &&
  value.startsWith('/') &&
  !value.startsWith('//') &&
  !value.startsWith('/login')
    ? value
    : '/';

// ============================================================
// MEDIA URL UTILITIES
// ============================================================

/**
 * Convert media paths into valid URLs.
 *
 * Handles:
 * - Absolute image URLs
 * - Relative image paths
 * - Django localhost media URLs
 * - Vite same-origin media proxy
 *
 * Allows only HTTP and HTTPS URLs.
 */

export const absoluteMedia = (
  value: string | undefined | null
) => {
  if (!value) {
    return '';
  }

  try {
    const url = new URL(
      value,
      window.location.origin
    );

    // Allow only HTTP and HTTPS protocols
    if (
      url.protocol !== 'http:' &&
      url.protocol !== 'https:'
    ) {
      return '';
    }

    // Django may return:
    // http://127.0.0.1:8000/media/...
    //
    // Use Vite's same-origin proxy for local media.

    if (
      ['localhost', '127.0.0.1'].includes(
        url.hostname
      ) &&
      url.pathname.startsWith('/media/')
    ) {
      return url.pathname + url.search;
    }

    return url.href;
  } catch {
    return '';
  }
};

// ============================================================
// ERROR HANDLING UTILITIES
// ============================================================

/**
 * Extract a readable error message.
 */

export function errorMessage(
  error: unknown
): string {
  return error instanceof Error
    ? error.message
    : 'Something went wrong. Please try again.';
}

// ============================================================
// PAYMENT GATEWAY URL VALIDATION
// ============================================================

/**
 * Validate SSLCommerz payment gateway URLs.
 *
 * Requirements:
 * - HTTPS protocol
 * - sslcommerz.com domain
 * - Valid SSLCommerz subdomain
 */

export function validateGatewayUrl(
  raw: string
): boolean {
  try {
    const url = new URL(raw);

    return (
      url.protocol === 'https:' &&
      (
        url.hostname === 'sslcommerz.com' ||
        url.hostname.endsWith(
          '.sslcommerz.com'
        )
      )
    );
  } catch {
    return false;
  }
}

// ============================================================
// PC BUILDER COMPONENT LABELS
// ============================================================

/**
 * Human-readable labels for PC Builder components.
 */

export const pcLabels: Record<string, string> = {
  cpu: 'Processor',
  cpu_cooler: 'CPU Cooler',
  motherboard: 'Motherboard',
  ram: 'Memory (RAM)',
  storage: 'Storage',
  gpu: 'Graphics Card',
  psu: 'Power Supply',
  case: 'PC Case',
  monitor: 'Monitor',
  case_cooler: 'Case Fan',
  keyboard: 'Keyboard',
  mouse: 'Mouse',
  speaker: 'Speakers',
  headphone: 'Headphones',
  network: 'Network Adapter',
  ups: 'UPS',
};

// ============================================================
// REQUIRED PC BUILDER COMPONENTS
// ============================================================

/**
 * Minimum components required for a PC build.
 */

export const pcRequired = [
  'cpu',
  'motherboard',
  'ram',
  'storage',
  'psu',
  'case',
];