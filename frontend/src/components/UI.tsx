
import {
  useState,
  type ButtonHTMLAttributes,
  type ReactNode,
  type SVGProps,
} from 'react';

import { Link } from '../lib/router';

import {
  absoluteMedia,
  money,
  priceOf,
  variantOf,
} from '../lib/utils';

import type { Product } from '../lib/types';

import {
  useAuth,
  useCart,
  useCompare,
  useToast,
  useWishlist,
} from '../contexts/Store';

// =========================================================
// Icon Types
// =========================================================

type IconName =
  | 'search'
  | 'arrow'
  | 'chevron'
  | 'down'
  | 'up'
  | 'left'
  | 'cart'
  | 'heart'
  | 'compare'
  | 'pc'
  | 'user'
  | 'menu'
  | 'x'
  | 'grid'
  | 'filter'
  | 'check'
  | 'check-circle'
  | 'shield'
  | 'truck'
  | 'headphones'
  | 'sparkle'
  | 'star'
  | 'bolt'
  | 'bag'
  | 'box'
  | 'package'
  | 'monitor'
  | 'laptop'
  | 'cpu'
  | 'phone'
  | 'camera'
  | 'watch'
  | 'tv'
  | 'fridge'
  | 'ac'
  | 'mouse'
  | 'memory'
  | 'hard-drive'
  | 'keyboard'
  | 'gamepad'
  | 'info'
  | 'alert'
  | 'minus'
  | 'plus'
  | 'trash'
  | 'share'
  | 'download'
  | 'logout'
  | 'receipt'
  | 'pin'
  | 'lock'
  | 'mail'
  | 'eye'
  | 'eye-off'
  | 'refresh'
  | 'clock'
  | 'credit-card'
  | 'sliders'
  | 'tag'
  | 'settings'
  | 'external'
  | 'sort'
  | 'circle'
  | 'shield-check';

// =========================================================
// Icon Component
// =========================================================

export function Icon({
  name,
  size = 20,
  ...props
}: {
  name: IconName;
  size?: number;
} & SVGProps<SVGSVGElement>) {
  const common = {
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.85,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
  };

  const shapes: Record<IconName, ReactNode> = {
    search: (
      <>
        <circle cx="11" cy="11" r="7" />
        <path d="m20 20-4-4" />
      </>
    ),

    arrow: (
      <path d="M5 12h14m-6-6 6 6-6 6" />
    ),

    chevron: <path d="m9 18 6-6-6-6" />,
    down: <path d="m6 9 6 6 6-6" />,
    up: <path d="m6 15 6-6 6 6" />,
    left: <path d="m15 18-6-6 6-6" />,

    cart: (
      <>
        <circle cx="9" cy="21" r="1" />
        <circle cx="20" cy="21" r="1" />
        <path d="M1 2h3l2.8 13h13l2.5-10H5" />
      </>
    ),

    heart: (
      <path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z" />
    ),

    compare: (
      <>
        <path d="M4 7h16m-4-4 4 4-4 4M20 17H4m4-4-4 4 4 4" />
      </>
    ),

    pc: (
      <>
        <rect x="3" y="3" width="18" height="14" rx="2" />
        <path d="M8 21h8m-4-4v4" />
      </>
    ),

    user: (
      <>
        <circle cx="12" cy="8" r="4" />
        <path d="M4 21a8 8 0 0 1 16 0" />
      </>
    ),

    menu: <path d="M4 6h16M4 12h16M4 18h16" />,
    x: <path d="M5 5l14 14M19 5 5 19" />,

    grid: (
      <>
        <rect x="3" y="3" width="7" height="7" rx="1" />
        <rect x="14" y="3" width="7" height="7" rx="1" />
        <rect x="3" y="14" width="7" height="7" rx="1" />
        <rect x="14" y="14" width="7" height="7" rx="1" />
      </>
    ),

    filter: (
      <>
        <path d="M4 7h16M7 12h10m-7 5h4" />
        <circle
          cx="8"
          cy="7"
          r="2"
          fill="currentColor"
          stroke="none"
        />
      </>
    ),

    check: <path d="m5 12 4 4L19 6" />,

    'check-circle': (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="m7 12 3 3 6-6" />
      </>
    ),

    shield: (
      <>
        <path d="M12 2 3 6v6c0 5 3.5 8 9 10 5.5-2 9-5 9-10V6Z" />
        <path d="m8 12 3 3 5-6" />
      </>
    ),

    truck: (
      <>
        <path d="M2 5h12v12H2zM14 9h4l4 4v4h-8" />
        <circle cx="6" cy="19" r="2" />
        <circle cx="18" cy="19" r="2" />
      </>
    ),

    headphones: (
      <>
        <path d="M4 14v-3a8 8 0 0 1 16 0v3" />
        <rect x="2" y="13" width="4" height="7" rx="2" />
        <rect x="18" y="13" width="4" height="7" rx="2" />
      </>
    ),

    sparkle: (
      <path d="m12 2 2.3 7.7L22 12l-7.7 2.3L12 22l-2.3-7.7L2 12l7.7-2.3Z" />
    ),

    star: (
      <path d="m12 2 3.1 6.3 7 1-5.1 5 .9 7-5.9-3.3-6 3.3 1-7-5.1-5 7-1Z" />
    ),

    bolt: (
      <path d="m13 2-9 12h7l-1 8 10-12h-7Z" />
    ),

    bag: (
      <>
        <path d="M4 8h16l-1 13H5Z" />
        <path d="M9 9V6a3 3 0 0 1 6 0v3" />
      </>
    ),

    box: (
      <>
        <path d="m12 2 9 5-9 5-9-5 9-5Zm-9 5v10l9 5 9-5V7M12 12v10" />
      </>
    ),

    package: (
      <>
        <path d="m12 2 9 5-9 5-9-5 9-5Zm-9 5v10l9 5 9-5V7M12 12v10" />
      </>
    ),

    monitor: (
      <>
        <rect x="2" y="3" width="20" height="15" rx="2" />
        <path d="M8 22h8m-4-4v4" />
      </>
    ),

    laptop: (
      <>
        <rect x="4" y="3" width="16" height="13" rx="2" />
        <path d="M2 20h20l-2-4H4Z" />
      </>
    ),

    cpu: (
      <>
        <rect x="5" y="5" width="14" height="14" rx="2" />
        <rect x="9" y="9" width="6" height="6" rx="1" />
        <path d="M9 1v4m6-4v4M9 19v4m6-4v4M1 9h4m-4 6h4m14-6h4m-4 6h4" />
      </>
    ),

    phone: (
      <>
        <rect x="6" y="2" width="12" height="20" rx="3" />
        <path d="M10 18h4" />
      </>
    ),

    camera: (
      <>
        <path d="M3 7h4l2-3h6l2 3h4v13H3Z" />
        <circle cx="12" cy="13" r="4" />
      </>
    ),

    watch: (
      <>
        <circle cx="12" cy="12" r="6" />
        <path d="M9 6V2h6v4m-6 12v4h6v-4m-3-9v3l2 2" />
      </>
    ),

    tv: (
      <>
        <rect x="2" y="4" width="20" height="15" rx="2" />
        <path d="M8 23h8m-4-4v4" />
      </>
    ),

    fridge: (
      <>
        <rect x="6" y="2" width="12" height="20" rx="2" />
        <path d="M6 10h12m-9-5v3m0 5v3" />
      </>
    ),

    ac: (
      <>
        <rect x="2" y="5" width="20" height="9" rx="2" />
        <path d="M6 18v3m6-4v4m6-3v3M6 10h12" />
      </>
    ),

    mouse: (
      <>
        <rect x="6" y="2" width="12" height="20" rx="6" />
        <path d="M12 2v7" />
      </>
    ),

    memory: (
      <>
        <rect x="2" y="7" width="20" height="10" rx="2" />
        <path d="M6 10v4m4-4v4m4-4v4m4-4v4M6 17v3m6-3v3m6-3v3m6-3v3" />
      </>
    ),

    'hard-drive': (
      <>
        <rect x="3" y="5" width="18" height="14" rx="2" />
        <path d="M3 14h18m-5 3h.01" />
      </>
    ),

    keyboard: (
      <>
        <rect x="2" y="6" width="20" height="12" rx="2" />
        <path d="M5 10h1m3 0h1m3 0h1m3 0h1M6 14h12" />
      </>
    ),

    gamepad: (
      <>
        <path d="M7 7h10c3 0 5 2 5 5l-1 5c-.5 3-3 4-5 1l-2-2h-4l-2 2c-2 3-4.5 2-5-1l-1-5c0-3 2-5 5-5Z" />
        <path d="M7 11v5m-2.5-2.5h5M17 12h.01m2 2h.01" />
      </>
    ),

    info: (
      <>
        <circle cx="12" cy="12" r="10" />
        <path d="M12 11v6m0-10v.1" />
      </>
    ),

    alert: (
      <>
        <path d="M12 2 2 21h20L12 2Zm0 7v5m0 4v.1" />
      </>
    ),

    minus: <path d="M5 12h14" />,
    plus: <path d="M5 12h14M12 5v14" />,

    trash: (
      <path d="M4 7h16m-13 0 1 14h8l1-14M9 7V4h6v3" />
    ),

    share: (
      <>
        <circle cx="18" cy="5" r="3" />
        <circle cx="6" cy="12" r="3" />
        <circle cx="18" cy="19" r="3" />
        <path d="m9 11 6-5m-6 8 6 4" />
      </>
    ),

    download: (
      <path d="M12 3v13m-5-5 5 5 5-5M4 18v3h16v-3" />
    ),

    logout: (
      <path d="M10 4H4v16h6m4-4 4-4-4-4m-8 4h12" />
    ),

    receipt: (
      <>
        <path d="M5 2h14v20l-3-2-4 2-4-2-3 2Z" />
        <path d="M8 8h8m-8 4h8m-8 4h5" />
      </>
    ),

    pin: (
      <>
        <path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 0 1 16 0Z" />
        <circle cx="12" cy="10" r="3" />
      </>
    ),

    lock: (
      <>
        <rect x="5" y="10" width="14" height="12" rx="2" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3" />
      </>
    ),

    mail: (
      <>
        <rect x="2" y="4" width="20" height="16" rx="2" />
        <path d="m3 6 9 7 9-7" />
      </>
    ),

    eye: (
      <>
        <path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z" />
        <circle cx="12" cy="12" r="3" />
      </>
    ),

    'eye-off': (
      <>
        <path d="M3 3l18 18M10 5.2A11 11 0 0 1 12 5c6 0 10 7 10 7a15 15 0 0 1-3 3.8M6 6C3.5 8 2 12 2 12s4 7 10 7c1 0 2-.2 3-.5" />
      </>
    ),

    refresh: (
      <>
        <path d="M20 7V3l-4 4m4 0a8 8 0 0 0-14-2m-2 12v4l4-4m-4 0a8 8 0 0 0 14 2" />
      </>
    ),

    clock: (
      <>
        <circle cx="12" cy="12" r="10" />
        <path d="M12 6v6l4 2" />
      </>
    ),

    'credit-card': (
      <>
        <rect x="2" y="5" width="20" height="14" rx="2" />
        <path d="M2 10h20m-16 5h4" />
      </>
    ),

    sliders: (
      <>
        <path d="M4 7h16M4 17h16" />
        <circle cx="9" cy="7" r="3" fill="white" />
        <circle cx="16" cy="17" r="3" fill="white" />
      </>
    ),

    tag: (
      <>
        <path d="M3 3h9l9 9-9 9-9-9V3Z" />
        <circle cx="8" cy="8" r="1" />
      </>
    ),

    settings: (
      <>
        <circle cx="12" cy="12" r="3" />
        <path d="M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M19 5l-2 2M7 17l-2 2" />
      </>
    ),

    external: (
      <>
        <path d="M12 5h7v7m0-7-9 9M19 15v4H5V5h4" />
      </>
    ),

    sort: <path d="M4 7h16M4 12h12M4 17h8" />,

    circle: <circle cx="12" cy="12" r="9" />,

    'shield-check': (
      <>
        <path d="M12 2 3 6v6c0 5 3.5 8 9 10 5.5-2 9-5 9-10V6Z" />
        <path d="m8 12 3 3 5-6" />
      </>
    ),
  };

  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      aria-hidden="true"
      {...common}
      {...props}
    >
      {shapes[name]}
    </svg>
  );
}

// =========================================================
// Button Component
// =========================================================

export function Button({
  children,
  variant = 'primary',
  loading = false,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
  loading?: boolean;
}) {
  return (
    <button
      {...props}
      disabled={props.disabled || loading}
      className={`btn btn-${variant} ${props.className ?? ''}`}
    >
      {loading && (
        <span className="spinner spinner-sm" />
      )}

      {children}
    </button>
  );
}

// =========================================================
// Spinner Component
// =========================================================

export function Spinner({
  label = 'Loading...',
}: {
  label?: string;
}) {
  return (
    <div className="loading-state">
      <span className="spinner" />
      <span>{label}</span>
    </div>
  );
}

// =========================================================
// Notice Component
// =========================================================

export function Notice({
  message,
  type = 'error',
}: {
  message: string;
  type?: 'error' | 'success' | 'info';
}) {
  return (
    <div
      role={type === 'error' ? 'alert' : 'status'}
      className={`notice notice-${type}`}
    >
      <Icon
        name={
          type === 'error'
            ? 'alert'
            : type === 'success'
              ? 'check-circle'
              : 'info'
        }
        size={19}
      />

      <span>{message}</span>
    </div>
  );
}

// =========================================================
// Empty State Component
// =========================================================

export function Empty({
  icon = 'box',
  title,
  description,
  action,
}: {
  icon?: IconName;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty-state">
      <div className="empty-icon">
        <Icon name={icon} size={30} />
      </div>

      <h3>{title}</h3>

      {description && <p>{description}</p>}

      {action && (
        <div className="mt-5">
          {action}
        </div>
      )}
    </div>
  );
}

// =========================================================
// Page Heading Component
// =========================================================

export function PageHeading({
  eyebrow,
  title,
  description,
  action,
}: {
  eyebrow?: string;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="page-heading">
      <div>
        {eyebrow && (
          <div className="eyebrow">
            {eyebrow}
          </div>
        )}

        <h1>{title}</h1>

        {description && <p>{description}</p>}
      </div>

      {action}
    </div>
  );
}

// =========================================================
// Breadcrumbs Component
// =========================================================

export function Breadcrumbs({
  items,
}: {
  items: {
    label: string;
    to?: string;
  }[];
}) {
  return (
    <nav
      aria-label="Breadcrumb"
      className="breadcrumbs"
    >
      <Link to="/">Home</Link>

      {items.map((item, index) => (
        <span
          key={index}
          className="breadcrumb-item"
        >
          <Icon name="chevron" size={13} />

          {item.to ? (
            <Link to={item.to}>
              {item.label}
            </Link>
          ) : (
            <span aria-current="page">
              {item.label}
            </span>
          )}
        </span>
      ))}
    </nav>
  );
}

// =========================================================
// Product Visual Component
// =========================================================

export function ProductVisual({
  src,
  name,
  kind = 'product',
  className = '',
}: {
  src?: string | null;
  name: string;
  kind?: string;
  className?: string;
}) {
  const [broken, setBroken] = useState(false);

  const url = absoluteMedia(src);

  return (
    <div className={`product-visual ${className}`}>
      {url && !broken ? (
        <img
          loading="lazy"
          src={url}
          alt={name}
          onError={() => setBroken(true)}
        />
      ) : (
        <div className="product-placeholder">
          <Icon
            name={
              kind === 'Laptop'
                ? 'laptop'
                : kind === 'Desktop'
                  ? 'pc'
                  : 'box'
            }
            size={60}
          />

          <span>TECHZONE</span>
        </div>
      )}
    </div>
  );
}

// =========================================================
// Product Card Component
// =========================================================

export function ProductCard({
  product,
  image,
}: {
  product: Product;
  image?: string;
}) {
  const { user } = useAuth();
  const cart = useCart();
  const wish = useWishlist();
  const compare = useCompare();
  const toast = useToast();

  const [busy, setBusy] = useState(false);

  // -------------------------------------------------------
  // Product Pricing
  // -------------------------------------------------------

  const variant = variantOf(product);

  const price = priceOf(product);

  const original = Number(
    variant?.price ?? 0
  );

  const savedAmount = Math.max(
    0,
    original - price
  );

  const saved = original > price && price > 0;

  const discountPercentage = saved
    ? Math.round(
        (savedAmount / original) * 100
      )
    : 0;

  const inStock = Boolean(
    variant && variant.stock > 0
  );

  // -------------------------------------------------------
  // Wishlist and Comparison
  // -------------------------------------------------------

  const inWishlist = wish.wishlist?.items.some(
    item => item.variant_id === variant?.id
  );

  const inCompare = compare.ids.includes(
    product.id
  );

  // -------------------------------------------------------
  // Add to Cart
  // -------------------------------------------------------

  const add = async () => {
    if (!user) {
      toast(
        'Sign in to add products to your cart',
        'info'
      );
      return;
    }

    if (!variant) return;

    setBusy(true);

    try {
      await cart.add(variant.id);
    } catch (error) {
      toast(
        error instanceof Error
          ? error.message
          : 'Could not add to cart',
        'error'
      );
    } finally {
      setBusy(false);
    }
  };

  // -------------------------------------------------------
  // Wishlist Toggle
  // -------------------------------------------------------

  const favorite = async () => {
    if (!user) {
      toast(
        'Sign in to use your wishlist',
        'info'
      );
      return;
    }

    if (!variant) return;

    try {
      await wish.toggle(variant.id);
    } catch (error) {
      toast(
        error instanceof Error
          ? error.message
          : 'Wishlist unavailable',
        'error'
      );
    }
  };

  // -------------------------------------------------------
  // Product Card UI
  // -------------------------------------------------------

  return (
    <article className="product-card">
      {/* Product Image */}

      <div className="product-card-image">
        <Link
          to={`/product/${product.slug}`}
          aria-label={`View ${product.name}`}
        >
          <ProductVisual
            src={image}
            name={product.name}
            kind={product.category}
          />
        </Link>

        {/* Discount Percentage Badge */}

        {saved && (
          <span className="sale-badge">
            -{discountPercentage}%
          </span>
        )}


        {/* Wishlist and Compare */}

        <div className="product-quick-actions">
          <button
            type="button"
            aria-label={
              inWishlist
                ? 'Remove from wishlist'
                : 'Add to wishlist'
            }
            title="Wishlist"
            onClick={() => void favorite()}
            className={inWishlist ? 'active' : ''}
          >
            <Icon name="heart" size={18} />
          </button>

          <button
            type="button"
            aria-label={
              inCompare
                ? 'Remove from comparison'
                : 'Compare product'
            }
            title="Compare"
            onClick={() =>
              compare.toggle(product.id)
            }
            className={inCompare ? 'active' : ''}
          >
            <Icon name="compare" size={18} />
          </button>
        </div>
      </div>

      {/* Product Information */}

      <div className="product-card-body">
        <div className="product-card-brand">
          {product.brand || 'TechZone'}
        </div>

        <Link
          to={`/product/${product.slug}`}
          className="product-card-name"
        >
          {product.name}
        </Link>

        <div className="product-card-features">
          {Object.entries(
            product.key_feature ?? {}
          )
            .slice(0, 2)
            .map(([key, value]) => (
              <span key={key}>
                {typeof value === 'string'
                  ? value
                  : `${key}: ${String(value)}`}
              </span>
            ))}
        </div>

        {/* Price and Stock */}

        <div className="product-card-bottom">
          <div>
            <strong className="price">
              {variant
                ? money(price)
                : 'Price on request'}
            </strong>

            {saved && (
              <div className="product-price-savings">
                <span className="old-price">
                  {money(original)}
                </span>

                <span className="product-save-amount">
                  Save {money(savedAmount)}
                </span>
              </div>
            )}
          </div>

          <span
            className={`stock ${
              inStock ? 'in' : 'out'
            }`}
          >
            {inStock
              ? 'In stock'
              : 'Unavailable'}
          </span>
        </div>

        {/* Add to Cart */}

        <Button
          disabled={!inStock || busy}
          loading={busy}
          onClick={() => void add()}
          className="product-add"
        >
          <Icon name="cart" size={17} />

          {inStock
            ? 'Add to cart'
            : 'Out of stock'}
        </Button>
      </div>
    </article>
  );
}
