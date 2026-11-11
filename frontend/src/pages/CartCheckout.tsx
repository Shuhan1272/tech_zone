
import {
  useEffect,
  useRef,
  useState,
  type FormEvent,
} from 'react';

import {
  useAuth,
  useCart,
  useToast,
} from '../contexts/Store';

import {
  ApiError,
  api,
  endpoints,
} from '../lib/api';

import { Link, navigate } from '../lib/router';

import type {
  Address,
  CartItem,
  Order,
} from '../lib/types';

import {
  absoluteMedia,
  errorMessage,
  money,
  validateGatewayUrl,
} from '../lib/utils';

import {
  Breadcrumbs,
  Button,
  Empty,
  Icon,
  Notice,
  PageHeading,
  Spinner,
} from '../components/UI';

// =========================================================
// TYPES
// =========================================================

type PaymentMethod = 'sslcommerz' | 'cod';
type DiscountType = 'promo' | 'staff' | 'new_customer';

const discountLabels: Record<DiscountType, string> = {
  promo: 'Promo discount',
  staff: 'Staff discount',
  new_customer: 'New customer discount',
};

type ShippingForm = {
  name: string;
  phone: string;
  house: string;
  road: string;
  division: string;
  district: string;
  upazila: string;
  postalCode: string;
  instructions: string;
};

type PendingCheckout = {
  orderId: number;
  paymentMethod: PaymentMethod;
  userId: string;
};

type VariantColor = {
  id?: number;
  name?: string;
  hex_code?: string;
};

type ExtendedCartItem = CartItem & {
  ram?: string | null;
  storage?: string | null;
  color?: VariantColor | string | null;
  sku?: string;
  stock?: number;
  is_active?: boolean;
  product_slug?: string;
  variant_details?: {
    ram?: string | null;
    storage?: string | null;
    color?: VariantColor | string | null;
    sku?: string;
    stock?: number;
    is_active?: boolean;
  };
};

type VariantDisplay = {
  ram: string;
  storage: string;
  color: string;
  hex: string;
  sku: string;
  stock: number | null;
  active: boolean;
};

const divisions = [
  { value: 'dhaka', label: 'Dhaka' },
  { value: 'chattogram', label: 'Chattogram' },
  { value: 'rajshahi', label: 'Rajshahi' },
  { value: 'khulna', label: 'Khulna' },
  { value: 'barishal', label: 'Barishal' },
  { value: 'sylhet', label: 'Sylhet' },
  { value: 'rangpur', label: 'Rangpur' },
  { value: 'mymensingh', label: 'Mymensingh' },
];

const initialShipping: ShippingForm = {
  name: '',
  phone: '',
  house: '',
  road: '',
  division: '',
  district: '',
  upazila: '',
  postalCode: '',
  instructions: '',
};

// =========================================================
// HELPERS
// =========================================================

function textValue(value: unknown): string {
  if (value === null || value === undefined) {
    return '';
  }

  if (typeof value === 'string') {
    return value.trim();
  }

  if (
    typeof value === 'number' ||
    typeof value === 'boolean'
  ) {
    return String(value);
  }

  return '';
}

function recordValue(
  value: unknown
): Record<string, unknown> {
  if (
    value &&
    typeof value === 'object' &&
    !Array.isArray(value)
  ) {
    return value as Record<string, unknown>;
  }

  return {};
}

function optionValue(
  options: Record<string, unknown>,
  name: string
): unknown {
  const entry = Object.entries(options).find(
    ([key]) => key.toLowerCase() === name.toLowerCase()
  );

  return entry?.[1];
}

function colorValue(value: unknown): {
  name: string;
  hex: string;
} {
  if (typeof value === 'string') {
    return {
      name: value.trim(),
      hex: '',
    };
  }

  const data = recordValue(value);

  return {
    name: textValue(data.name),
    hex: textValue(data.hex_code),
  };
}

function getVariantDisplay(
  item: ExtendedCartItem
): VariantDisplay {
  const details = item.variant_details ?? {};
  const options = recordValue(item.variant_options);

  const nestedOptions = recordValue(
    optionValue(options, 'options')
  );

  const readOption = (key: string): unknown => {
    return (
      optionValue(options, key) ??
      optionValue(nestedOptions, key)
    );
  };

  const ram =
    textValue(item.ram) ||
    textValue(details.ram) ||
    textValue(readOption('ram'));

  const storage =
    textValue(item.storage) ||
    textValue(details.storage) ||
    textValue(readOption('storage'));

  const color =
    colorValue(item.color).name
      ? colorValue(item.color)
      : colorValue(details.color).name
        ? colorValue(details.color)
        : colorValue(readOption('color'));

  const sku =
    textValue(item.sku) ||
    textValue(details.sku) ||
    textValue(readOption('sku'));

  const rawStock =
    item.stock ??
    details.stock ??
    readOption('stock');

  const stock =
    rawStock !== null &&
    rawStock !== undefined &&
    rawStock !== '' &&
    Number.isFinite(Number(rawStock))
      ? Number(rawStock)
      : null;

  return {
    ram,
    storage,
    color: color.name,
    hex: color.hex,
    sku,
    stock,
    active:
      item.is_active !== false &&
      details.is_active !== false,
  };
}

function selectedOptions(
  item: ExtendedCartItem
): string {
  const variant = getVariantDisplay(item);

  const parts: string[] = [];

  if (variant.ram) {
    parts.push(`RAM: ${variant.ram}`);
  }

  if (variant.storage) {
    parts.push(`Storage: ${variant.storage}`);
  }

  if (variant.color) {
    parts.push(`Color: ${variant.color}`);
  }

  const options = recordValue(item.variant_options);

  const excluded = new Set([
    'ram',
    'storage',
    'color',
    'sku',
    'stock',
    'is_active',
    'options',
  ]);

  Object.entries(options).forEach(([key, value]) => {
    if (excluded.has(key.toLowerCase())) {
      return;
    }

    const text = textValue(value);

    if (text) {
      parts.push(`${key}: ${text}`);
    }
  });

  return parts.join(' / ');
}

function getItemPrice(item: CartItem): number {
  const value = Number(item.discounted_price);

  return Number.isFinite(value)
    ? value
    : 0;
}

function getOriginalPrice(item: CartItem): number {
  const value = Number(item.variant_price);

  return Number.isFinite(value)
    ? value
    : getItemPrice(item);
}

function getSavings(item: CartItem): number {
  return Math.max(
    0,
    getOriginalPrice(item) - getItemPrice(item)
  );
}

function CartProductImage({
  image,
  name,
}: {
  image: string | null;
  name: string;
}) {
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setFailed(false);
  }, [image]);

  if (!image || failed) {
    return <Icon name="box" size={35} />;
  }

  return (
    <img
      src={absoluteMedia(image)}
      alt={name}
      loading="lazy"
      decoding="async"
      onError={() => setFailed(true)}
      style={{
        width: '100%',
        height: '100%',
        objectFit: 'contain',
        display: 'block',
      }}
    />
  );
}

function VariantInformation({
  item,
  compact = false,
}: {
  item: ExtendedCartItem;
  compact?: boolean;
}) {
  const variant = getVariantDisplay(item);

  const hasDetails = Boolean(
    variant.ram ||
    variant.storage ||
    variant.color
  );

  return (
    <div
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: compact ? 5 : 8,
        marginTop: 7,
        alignItems: 'center',
      }}
    >
      {variant.ram && (
        <span
          style={{
            fontSize: compact ? 11 : 12,
            padding: '5px 9px',
            borderRadius: 6,
            background: '#f1f5f9',
            color: '#334155',
          }}
        >
          RAM: <strong>{variant.ram}</strong>
        </span>
      )}

      {variant.storage && (
        <span
          style={{
            fontSize: compact ? 11 : 12,
            padding: '5px 9px',
            borderRadius: 6,
            background: '#f1f5f9',
            color: '#334155',
          }}
        >
          Storage: <strong>{variant.storage}</strong>
        </span>
      )}

      {variant.color && (
        <span
          style={{
            fontSize: compact ? 11 : 12,
            padding: '5px 9px',
            borderRadius: 6,
            background: '#f1f5f9',
            color: '#334155',
            display: 'inline-flex',
            alignItems: 'center',
            gap: 6,
          }}
        >
          {variant.hex && (
            <span
              style={{
                width: 13,
                height: 13,
                borderRadius: '50%',
                border: '1px solid #cbd5e1',
                backgroundColor: variant.hex,
                display: 'inline-block',
              }}
            />
          )}

          Color: <strong>{variant.color}</strong>
        </span>
      )}

      {!hasDetails && selectedOptions(item) && (
        <span
          style={{
            fontSize: 12,
            color: '#64748b',
          }}
        >
          {selectedOptions(item)}
        </span>
      )}
    </div>
  );
}

// =========================================================
// CART PAGE
// =========================================================

export function CartPage() {
  const cart = useCart();
  const toast = useToast();
  const { user } = useAuth();

  const [busy, setBusy] = useState<number | null>(
    null
  );

  const [clearing, setClearing] = useState(false);

  const items: ExtendedCartItem[] =
    cart.cart?.items ?? [];

  const originalSubtotal = items.reduce(
    (total, item) =>
      total +
      getOriginalPrice(item) * item.quantity,
    0
  );

  const totalSavings = items.reduce(
    (total, item) =>
      total + getSavings(item) * item.quantity,
    0
  );

  const subtotal = items.reduce(
    (total, item) =>
      total + getItemPrice(item) * item.quantity,
    0
  );

  const unavailableItems = items.filter((item) => {
    const variant = getVariantDisplay(item);

    return (
      !variant.active ||
      (variant.stock !== null &&
        (variant.stock <= 0 ||
          item.quantity > variant.stock))
    );
  });

  const change = async (
    id: number,
    qty: number
  ) => {
    if (busy !== null || clearing) return;

    setBusy(id);

    try {
      if (qty <= 0) {
        await cart.remove(id);
      } else {
        await cart.change(id, qty);
      }
    } catch (e) {
      toast(errorMessage(e), 'error');
    } finally {
      setBusy(null);
    }
  };

  const clearCart = async () => {
    if (
      clearing ||
      busy !== null ||
      !items.length
    ) {
      return;
    }

    if (
      !window.confirm(
        'Are you sure you want to remove all items from your cart?'
      )
    ) {
      return;
    }

    setClearing(true);

    try {
      for (const item of items) {
        await cart.remove(item.id);
      }

      toast('Cart cleared successfully', 'success');
    } catch (e) {
      toast(errorMessage(e), 'error');

      try {
        await cart.reload();
      } catch {
        // Preserve the original error.
      }
    } finally {
      setClearing(false);
    }
  };

  return (
    <div className="container-wide page-space">
      <Breadcrumbs
        items={[{ label: 'Shopping cart' }]}
      />

      <PageHeading
        eyebrow="YOUR SELECTION"
        title="Shopping cart"
        description="Review your selected products, configurations and prices before checkout."
      />

      <style>{`
        .techzone-cart-layout {
          display: grid;
          grid-template-columns: minmax(0, 1fr) 292px;
          align-items: start;
          gap: 22px;
          width: 100%;
        }
        .techzone-cart-list, .techzone-cart-summary { min-width: 0; max-width: 100%; box-sizing: border-box; }
        .techzone-cart-list { overflow: hidden; }
        .techzone-clear-cart { display: flex; justify-content: flex-end; align-items: center; width: 100%; max-width: 100%; min-width: 0; box-sizing: border-box; padding: 16px 20px; border-top: 1px solid #e2e8f0; }
        .techzone-clear-cart-button { position: static; right: auto; left: auto; transform: none; display: inline-flex; align-items: center; justify-content: center; gap: 8px; width: auto; max-width: 100%; min-width: 0; margin: 0; padding: 10px 14px; box-sizing: border-box; white-space: nowrap; flex-shrink: 0; border: 1px solid #fecaca; border-radius: 8px; background: #fff5f5; color: #dc2626; cursor: pointer; }
        .techzone-clear-cart-button:hover:not(:disabled) { background: #fee2e2; }
        .techzone-clear-cart-button:disabled { opacity: .5; cursor: not-allowed; }
        .techzone-cart-row {
          display: grid;
          grid-template-columns: 90px minmax(0, 1fr) 130px;
          align-items: center;
          gap: 18px;
          padding: 22px 20px;
          min-width: 0;
        }
        .techzone-cart-art {
          width: 90px;
          height: 90px;
          min-width: 0;
          display: flex;
          align-items: center;
          justify-content: center;
          overflow: hidden;
        }
        .techzone-cart-main { min-width: 0; overflow-wrap: anywhere; }
        .techzone-cart-main h3 { margin-top: 0; }
        .techzone-cart-actions {
          min-width: 0;
          display: flex;
          flex-direction: column;
          align-items: flex-end;
          justify-content: center;
          gap: 12px;
          text-align: right;
        }
        .techzone-cart-actions .quantity-stepper { margin: 0; }
        .techzone-cart-actions .cart-remove { margin: 0; }
        .techzone-cart-summary { width: 100%; box-sizing: border-box; }
        .techzone-cart-summary .summary-line { gap: 12px; }
        .techzone-cart-summary .summary-line > * { min-width: 0; }
        @media (max-width: 900px) {
          .techzone-cart-layout { grid-template-columns: minmax(0, 1fr); }
        }
        @media (max-width: 560px) {
          .techzone-cart-row {
            grid-template-columns: 76px minmax(0, 1fr);
            gap: 12px;
            padding: 18px 14px;
          }
          .techzone-cart-art { width: 76px; height: 76px; }
          .techzone-cart-actions {
            grid-column: 2;
            align-items: flex-start;
            text-align: left;
            flex-direction: row;
            flex-wrap: wrap;
            justify-content: space-between;
          }
        }
      `}</style>

      {!user ? (
        <Empty
          icon="cart"
          title="Sign in to view your cart"
          action={
            <Link
              to="/login?next=%2Fcart"
              className="btn btn-primary"
            >
              Sign in
            </Link>
          }
        />
      ) : cart.loading ? (
        <Spinner label="Loading cart..." />
      ) : !items.length ? (
        <Empty
          icon="bag"
          title="Your cart is waiting for something great"
          description="Browse the collection and find your next favorite."
          action={
            <Link
              to="/catalog"
              className="btn btn-primary"
            >
              Explore products
              <Icon name="arrow" size={18} />
            </Link>
          }
        />
      ) : (
        <div className="cart-layout techzone-cart-layout">
          {/* ===========================================
              CART ITEMS
          =========================================== */}

          <div className="cart-list techzone-cart-list">
            <div className="cart-list-title">
              <h2>
                Your items
                <span> ({cart.count})</span>
              </h2>

              <Link to="/catalog">
                Continue shopping
                <Icon name="arrow" size={16} />
              </Link>
            </div>

            {unavailableItems.length > 0 && (
              <div style={{ marginBottom: 16 }}>
                <Notice
                  message="Some selected variants are unavailable or exceed the reported stock. Update your cart before checkout."
                />
              </div>
            )}

            {items.map((item) => {
              const variant = getVariantDisplay(item);

              const unitPrice = getItemPrice(item);
              const originalPrice =
                getOriginalPrice(item);

              const saving = getSavings(item);

              const lineTotal =
                unitPrice * item.quantity;

              const atLimit =
                variant.stock !== null &&
                item.quantity >= variant.stock;

              const unavailable =
                !variant.active ||
                (variant.stock !== null &&
                  variant.stock <= 0);

              return (
                <div
                  className="cart-row techzone-cart-row"
                  key={item.id}
                >
                  {/* IMAGE */}

                  <div className="cart-row-art techzone-cart-art">
                    <CartProductImage
                      image={
                        item.product_image ?? null
                      }
                      name={item.product_name}
                    />
                  </div>

                  {/* INFORMATION */}

                  <div className="cart-row-main techzone-cart-main">
                    <h3>{item.product_name}</h3>

                    {variant.sku && (
                      <div
                        style={{
                          fontSize: 11,
                          color: '#94a3b8',
                          marginTop: 4,
                        }}
                      >
                        SKU: {variant.sku}
                      </div>
                    )}

                    <VariantInformation item={item} />

                    {variant.stock !== null && (
                      <div
                        style={{
                          fontSize: 12,
                          marginTop: 8,
                          color:
                            variant.stock > 0
                              ? '#059669'
                              : '#dc2626',
                        }}
                      >
                        {variant.stock > 0
                          ? `${variant.stock} available`
                          : 'Out of stock'}
                      </div>
                    )}

                    <div className="cart-row-price">
                      <strong>
                        {money(unitPrice)}
                      </strong>
                      {' '}each

                      {saving > 0 && (
                        <div
                          style={{
                            marginTop: 5,
                            display: 'flex',
                            flexWrap: 'wrap',
                            gap: 9,
                            alignItems: 'center',
                          }}
                        >
                          <del
                            style={{
                              color: '#94a3b8',
                              fontSize: 12,
                            }}
                          >
                            {money(originalPrice)}
                          </del>

                          <span
                            style={{
                              color: '#059669',
                              fontSize: 12,
                              fontWeight: 600,
                            }}
                          >
                            Save {money(saving)}
                          </span>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* ACTIONS */}

                  <div className="cart-row-actions techzone-cart-actions">
                    <strong>
                      {money(lineTotal)}
                    </strong>

                    <div className="quantity-stepper">
                      <button
                        type="button"
                        disabled={
                          busy !== null ||
                          clearing ||
                          item.quantity <= 1
                        }
                        aria-label="Decrease quantity"
                        onClick={() =>
                          void change(
                            item.id,
                            item.quantity - 1
                          )
                        }
                      >
                        <Icon
                          name="minus"
                          size={16}
                        />
                      </button>

                      <span>{item.quantity}</span>

                      <button
                        type="button"
                        disabled={
                          busy !== null ||
                          clearing ||
                          unavailable ||
                          atLimit
                        }
                        aria-label="Increase quantity"
                        onClick={() =>
                          void change(
                            item.id,
                            item.quantity + 1
                          )
                        }
                      >
                        <Icon
                          name="plus"
                          size={16}
                        />
                      </button>
                    </div>

                    <button
                      type="button"
                      className="cart-remove"
                      disabled={
                        busy !== null || clearing
                      }
                      onClick={() =>
                        void change(item.id, 0)
                      }
                    >
                      <Icon
                        name="trash"
                        size={15}
                      />
                      Remove
                    </button>
                  </div>
                </div>
              );
            })}

            {/* CLEAR CART */}

            <div className="techzone-clear-cart">
              <button
                type="button"
                className="techzone-clear-cart-button"
                disabled={clearing || busy !== null}
                onClick={() => void clearCart()}
              >
                <Icon name="trash" size={16} />
                <span>{clearing ? 'Clearing cart...' : 'Clear cart'}</span>
              </button>
            </div>
          </div>

          {/* ===========================================
              ORDER SUMMARY
          =========================================== */}

          <div className="summary-card techzone-cart-summary">
            <h3>Order summary</h3>

            <div className="summary-line">
              <span>
                Original subtotal
              </span>

              <strong>
                {money(originalSubtotal)}
              </strong>
            </div>

            {totalSavings > 0 && (
              <div className="summary-line discount-line">
                <span>Product discounts</span>

                <strong>
                  -{money(totalSavings)}
                </strong>
              </div>
            )}

            <div className="summary-line">
              <span>
                Subtotal ({cart.count} items)
              </span>

              <strong>
                {money(subtotal)}
              </strong>
            </div>

            <div className="summary-line">
              <span>Shipping</span>
              <span>
                Calculated at checkout
              </span>
            </div>

            <div className="summary-divider" />

            <div className="summary-total">
              <span>Estimated total</span>

              <strong>
                {money(subtotal)}
              </strong>
            </div>

            {unavailableItems.length > 0 ? (
              <button
                className="btn btn-primary full-width"
                type="button"
                disabled
              >
                Update unavailable items
              </button>
            ) : (
              <Link
                to="/checkout"
                className="btn btn-primary full-width"
              >
                Proceed to checkout
                <Icon
                  name="arrow"
                  size={18}
                />
              </Link>
            )}

            <div className="summary-secure">
              <Icon name="lock" size={17} />
              Secure checkout with SSLCommerz
              or COD
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// =========================================================
// CHECKOUT PAGE
// =========================================================

export function Checkout() {
  const cart = useCart();
  const { user } = useAuth();
  const toast = useToast();

  const userId = user
    ? String(user.email)
    : '';

  const [shipping, setShipping] =
    useState<ShippingForm>(initialShipping);

  const [
    savedAddressLoaded,
    setSavedAddressLoaded,
  ] = useState(false);

  const [
    paymentMethod,
    setPaymentMethod,
  ] = useState<PaymentMethod>('sslcommerz');

  const [promo, setPromo] = useState('');
  const [discount, setDiscount] = useState<number | null>(null);
  const [appliedDiscount, setAppliedDiscount] = useState<{
    code: string;
    type: DiscountType;
    amount: number;
    subtotal: number;
  } | null>(null);
  const [validatingDiscount, setValidatingDiscount] = useState(false);
  const discountRequestRef = useRef(0);

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [uncertain, setUncertain] =
    useState(false);

  const [created, setCreated] =
    useState<PendingCheckout | null>(null);

  const submittingRef = useRef(false);

  // Remove legacy checkout recovery data from older frontend versions.
  useEffect(() => {
    sessionStorage.removeItem('techzone_pending_order');
  }, []);

  const items: ExtendedCartItem[] =
    cart.cart?.items ?? [];

  const subtotal = items.reduce(
    (total, item) =>
      total +
      getItemPrice(item) * item.quantity,
    0
  );

  const productSavings = items.reduce(
    (total, item) =>
      total +
      getSavings(item) * item.quantity,
    0
  );

  const unavailableItems = items.filter((item) => {
    const variant = getVariantDisplay(item);

    return (
      !variant.active ||
      (variant.stock !== null &&
        (variant.stock <= 0 ||
          item.quantity > variant.stock))
    );
  });

  const estimatedTotal = Math.max(
    0,
    subtotal - (appliedDiscount?.subtotal === subtotal ? (discount ?? 0) : 0)
  );

  // =======================================================
  // LOAD SAVED ADDRESS
  // =======================================================

  useEffect(() => {
    if (!user) return;

    let cancelled = false;

    setShipping({
      ...initialShipping,
      name: `${user.first_name || ''} ${
        user.last_name || ''
      }`.trim(),
      phone: user.phone || '',
    });

    setSavedAddressLoaded(false);

    api<unknown>('/api/v1/accounts/address/')
      .then((value) => {
        if (cancelled) return;

        const list = Array.isArray(value)
          ? value
          : value &&
              typeof value === 'object' &&
              'results' in value
            ? (
                value as {
                  results: Address[];
                }
              ).results
            : [];

        const address = (list as Address[])[0];

        if (!address) return;

        setShipping((current) => ({
          ...current,
          name:
            current.name ||
            `${address.first_name || ''} ${
              address.last_name || ''
            }`.trim(),
          house: address.address1 || '',
          road: address.address2 || '',
          postalCode:
            address.postal_code || '',
        }));

        setSavedAddressLoaded(true);
      })
      .catch(() => {
        // Saved address is optional.
      });

    return () => {
      cancelled = true;
    };
  }, [userId]);

  // =======================================================
  // SHIPPING
  // =======================================================

  const updateShipping = (
    field: keyof ShippingForm,
    value: string
  ) => {
    setShipping((current) => ({
      ...current,
      [field]: value,
    }));
  };

  const validateShipping = (): string | null => {
    const phone = shipping.phone
      .replace(/[\s-]/g, '')
      .replace(/^\+880/, '0')
      .replace(/^880/, '0');

    if (!shipping.name.trim()) {
      return 'Recipient name is required.';
    }

    if (!/^01[3-9]\d{8}$/.test(phone)) {
      return 'Enter a valid Bangladesh mobile number.';
    }

    if (!shipping.house.trim()) {
      return 'House or building information is required.';
    }

    if (!shipping.road.trim()) {
      return 'Road or area information is required.';
    }

    if (!shipping.division) {
      return 'Please select your division.';
    }

    if (!shipping.district.trim()) {
      return 'District is required.';
    }

    if (!shipping.upazila.trim()) {
      return 'Upazila or thana is required.';
    }

    if (
      !/^\d{4}$/.test(
        shipping.postalCode.trim()
      )
    ) {
      return 'Postal code must contain exactly 4 digits.';
    }

    return null;
  };

  // =======================================================
  // DISCOUNT CODE
  // =======================================================

  const validatePromo = async () => {
    const code = promo.trim().toUpperCase();
    const requestId = ++discountRequestRef.current;
    setDiscount(null);
    setAppliedDiscount(null);

    if (!code) {
      toast('Enter a discount code.', 'error');
      return;
    }

    setValidatingDiscount(true);

    try {
      const result = await api<{
        discount_amount: string | number;
        discount_type?: DiscountType;
        discount?: { discount_type?: DiscountType };
      }>('/api/v1/discounts/discounts/validate/', {
        method: 'POST',
        body: {
          discount_type: 'promo',
          code,
          order_amount: subtotal.toFixed(2),
        },
      });

      if (requestId !== discountRequestRef.current) return;

      const type = result.discount_type ?? result.discount?.discount_type;
      const amount = Number(result.discount_amount);

      if (!type || !(type in discountLabels)) {
        throw new Error('The discount API must return discount_type.');
      }
      if (!Number.isFinite(amount) || amount < 0 || amount > subtotal) {
        throw new Error('The discount API returned an invalid amount.');
      }

      setDiscount(amount);
      setAppliedDiscount({ code, type, amount, subtotal });
      toast(`${discountLabels[type]} applied`, 'success');
    } catch (e) {
      if (requestId !== discountRequestRef.current) return;
      setDiscount(null);
      setAppliedDiscount(null);
      toast(errorMessage(e), 'error');
    } finally {
      if (requestId === discountRequestRef.current) {
        setValidatingDiscount(false);
      }
    }
  };

  // =======================================================
  // SSLCOMMERZ
  // =======================================================

  const startPayment = async (
    id: number
  ) => {
    const session = await api<{
      payment_url: string;
    }>(endpoints.paymentInitiate, {
      method: 'POST',
      body: {
        order_id: id,
      },
    });

    if (
      !validateGatewayUrl(
        session.payment_url
      )
    ) {
      throw Error(
        'The backend did not return a valid SSLCommerz payment URL.'
      );
    }

    window.location.assign(
      session.payment_url
    );
  };

  // =======================================================
  // CREATE ORDER
  // =======================================================

  const submit = async (
    e: FormEvent
  ) => {
    e.preventDefault();

    if (
      submittingRef.current ||
      busy ||
      created ||
      uncertain
    ) {
      return;
    }

    if (unavailableItems.length > 0) {
      setError(
        'Some items are unavailable or exceed stock. Please update your cart.'
      );
      return;
    }

    if (promo.trim() && (
      !appliedDiscount ||
      appliedDiscount.subtotal !== subtotal ||
      appliedDiscount.code !== promo.trim().toUpperCase()
    )) {
      setError('Please apply a valid discount code before placing your order.');
      return;
    }

    const validationError =
      validateShipping();

    if (validationError) {
      setError(validationError);
      return;
    }

    submittingRef.current = true;
    setBusy(true);
    setError('');

    try {
      const order = await api<Order>(
        endpoints.checkout,
        {
          method: 'POST',
          body: {
            shipping_name:
              shipping.name.trim(),

            shipping_phone:
              shipping.phone.trim(),

            shipping_house:
              shipping.house.trim(),

            shipping_road:
              shipping.road.trim(),

            shipping_division:
              shipping.division,

            shipping_district:
              shipping.district.trim(),

            shipping_upazila:
              shipping.upazila.trim(),

            shipping_postal_code:
              shipping.postalCode.trim(),

            shipping_instructions:
              shipping.instructions.trim(),

            payment_method:
              paymentMethod,

            ...(appliedDiscount
              ? {
                  discount_type: appliedDiscount.type,
                  discount_code: appliedDiscount.code,
                }
              : {}),
          },
        }
      );

      const pending: PendingCheckout = {
        orderId: order.id,
        paymentMethod,
        userId,
      };

      // Confirmation belongs only to this successful checkout.
      // Do not persist it: a new visit to /checkout must show the form.
      setCreated(pending);

      try {
        await cart.reload();
      } catch (refreshError) {
        console.error(
          'Failed to refresh cart:',
          refreshError
        );
      }

      if (paymentMethod === 'cod') {
        toast(
          'Order placed successfully! A confirmation email will be sent to your registered email address.',
          'success'
        );
        return;
      }

      try {
        await startPayment(order.id);
      } catch (paymentError) {
        setError(
          errorMessage(paymentError)
        );
      }
    } catch (e) {
      if (
        !(
          e instanceof ApiError &&
          e.status >= 400 &&
          e.status < 500
        )
      ) {
        setUncertain(true);
      }

      setError(
        `${errorMessage(e)} If your order was created, check My Orders before trying again.`
      );
    } finally {
      submittingRef.current = false;
      setBusy(false);
    }
  };

  // =======================================================
  // RETRY PAYMENT
  // =======================================================

  const retry = async () => {
    const pending = created;

    if (
      !pending ||
      pending.paymentMethod !==
        'sslcommerz' ||
      submittingRef.current
    ) {
      return;
    }

    submittingRef.current = true;
    setBusy(true);
    setError('');

    try {
      await startPayment(
        pending.orderId
      );
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      submittingRef.current = false;
      setBusy(false);
    }
  };

  // =======================================================
  // NOT LOGGED IN
  // =======================================================

  if (!user) {
    return (
      <div className="container-wide page-space">
        <Empty
          icon="lock"
          title="Sign in to check out"
          action={
            <Link
              to="/login?next=%2Fcheckout"
              className="btn btn-primary"
            >
              Sign in
            </Link>
          }
        />
      </div>
    );
  }

  // =======================================================
  // ORDER CREATED
  // =======================================================

  const pendingOrder = created;

  if (pendingOrder) {
    const isCOD =
      pendingOrder.paymentMethod ===
      'cod';

    return (
      <div className="container-wide page-space">
        <div className="checkout-confirm">
          <div className="confirm-icon">
            <Icon
              name="check-circle"
              size={46}
            />
          </div>

          <h1>Order Placed Successfully!</h1>

          <p>
            Thank you for shopping with TechZone! Your order
            #{pendingOrder.orderId} has been received successfully.
          </p>

          <div style={{ maxWidth: 520, width: '100%', margin: '18px auto' }}>
            <Notice
              type="success"
              message="A confirmation email will be sent to your registered email address. Please check your inbox for your order details."
            />
          </div>

          <p>
            {isCOD
              ? 'Cash on Delivery selected. Payment will be collected when your order is delivered.'
              : 'Your order has been received. Online payment is pending until SSLCommerz confirms it.'}
          </p>

          {isCOD ? (
            <Notice
              type="success"
              message="Cash on Delivery selected. No online payment is required."
            />
          ) : (
            <Notice
              type="info"
              message="Do not place this order again. Retry payment for the same order if needed."
            />
          )}

          {error && (
            <Notice message={error} />
          )}

          {!isCOD && (
            <Button
              loading={busy}
              onClick={() => void retry()}
            >
              <Icon
                name="credit-card"
                size={18}
              />
              Pay with SSLCommerz
            </Button>
          )}

          <Link
            to={`/orders/${pendingOrder.orderId}`}
            className="btn btn-outline"
          >
            View order details
          </Link>

          <button
            type="button"
            className="text-action"
            onClick={() => {
              setCreated(null);
              navigate('/orders');
            }}
          >
            View all orders
          </button>
        </div>
      </div>
    );
  }

  // =======================================================
  // CART LOADING
  // =======================================================

  if (cart.loading) {
    return (
      <div className="container-wide">
        <Spinner label="Loading checkout..." />
      </div>
    );
  }

  // =======================================================
  // EMPTY CART
  // =======================================================

  if (!items.length) {
    return (
      <div className="container-wide page-space">
        <Empty
          title="Your cart is empty"
          action={
            <Link
              to="/catalog"
              className="btn btn-primary"
            >
              Browse products
            </Link>
          }
        />
      </div>
    );
  }

  // =======================================================
  // CHECKOUT FORM
  // =======================================================

  return (
    <div className="container-wide page-space">
      <Breadcrumbs
        items={[
          {
            label: 'Cart',
            to: '/cart',
          },
          {
            label: 'Checkout',
          },
        ]}
      />

      <PageHeading
        eyebrow="ALMOST THERE"
        title="Secure checkout"
        description="One last step before your new tech is on its way."
      />

      <form
        onSubmit={submit}
        className="checkout-layout"
      >
        <div className="checkout-main">
          {/* =========================================
              DELIVERY INFORMATION
          ========================================= */}

          <div className="form-card">
            <div className="form-card-title">
              <span>
                <Icon name="pin" size={22} />
              </span>

              <div>
                <h2>Delivery information</h2>
                <p>
                  Where should we send your order?
                </p>
              </div>
            </div>

            <div className="form-grid">
              <label className="form-field">
                <span>Recipient name *</span>

                <input
                  required
                  autoComplete="name"
                  value={shipping.name}
                  onChange={(e) =>
                    updateShipping(
                      'name',
                      e.target.value
                    )
                  }
                  placeholder="Full name"
                />
              </label>

              <label className="form-field">
                <span>Phone number *</span>

                <input
                  required
                  type="tel"
                  autoComplete="tel"
                  value={shipping.phone}
                  onChange={(e) =>
                    updateShipping(
                      'phone',
                      e.target.value
                    )
                  }
                  placeholder="01XXXXXXXXX"
                />
              </label>

              <label className="form-field full">
                <span>
                  House / Flat / Building *
                </span>

                <input
                  required
                  autoComplete="address-line1"
                  value={shipping.house}
                  onChange={(e) =>
                    updateShipping(
                      'house',
                      e.target.value
                    )
                  }
                  placeholder="House 12, Flat 3B"
                />
              </label>

              <label className="form-field full">
                <span>
                  Road / Street / Area *
                </span>

                <input
                  required
                  autoComplete="address-line2"
                  value={shipping.road}
                  onChange={(e) =>
                    updateShipping(
                      'road',
                      e.target.value
                    )
                  }
                  placeholder="Road 5, Dhanmondi"
                />
              </label>

              <label className="form-field">
                <span>Division *</span>

                <select
                  required
                  value={shipping.division}
                  onChange={(e) =>
                    updateShipping(
                      'division',
                      e.target.value
                    )
                  }
                >
                  <option value="">
                    Select division
                  </option>

                  {divisions.map((division) => (
                    <option
                      key={division.value}
                      value={division.value}
                    >
                      {division.label}
                    </option>
                  ))}
                </select>
              </label>

              <label className="form-field">
                <span>District *</span>

                <input
                  required
                  autoComplete="address-level2"
                  value={shipping.district}
                  onChange={(e) =>
                    updateShipping(
                      'district',
                      e.target.value
                    )
                  }
                  placeholder="Enter district"
                />
              </label>

              <label className="form-field">
                <span>Upazila / Thana *</span>

                <input
                  required
                  value={shipping.upazila}
                  onChange={(e) =>
                    updateShipping(
                      'upazila',
                      e.target.value
                    )
                  }
                  placeholder="Enter upazila or thana"
                />
              </label>

              <label className="form-field">
                <span>Postal code *</span>

                <input
                  required
                  inputMode="numeric"
                  pattern="[0-9]{4}"
                  maxLength={4}
                  autoComplete="postal-code"
                  value={shipping.postalCode}
                  onChange={(e) =>
                    updateShipping(
                      'postalCode',
                      e.target.value
                    )
                  }
                  placeholder="e.g. 1209"
                />
              </label>

              <label className="form-field full">
                <span>
                  Delivery instructions (optional)
                </span>

                <textarea
                  rows={3}
                  value={shipping.instructions}
                  onChange={(e) =>
                    updateShipping(
                      'instructions',
                      e.target.value
                    )
                  }
                  placeholder="Nearby landmark, gate number, or special delivery instructions"
                />
              </label>
            </div>

            {savedAddressLoaded && (
              <p className="form-note">
                <Icon
                  name="check-circle"
                  size={15}
                />
                Some saved address details were
                loaded. Please verify the
                remaining fields.
              </p>
            )}
          </div>

          {/* =========================================
              PAYMENT METHOD
          ========================================= */}

          <div className="form-card">
            <div className="form-card-title">
              <span>
                <Icon
                  name="credit-card"
                  size={22}
                />
              </span>

              <div>
                <h2>Payment method</h2>
                <p>
                  Choose how you want to pay
                </p>
              </div>
            </div>

            <label
              className="payment-method"
              style={{
                cursor: 'pointer',
                marginBottom: 12,
                borderColor:
                  paymentMethod ===
                  'sslcommerz'
                    ? '#2457E7'
                    : undefined,
              }}
            >
              <input
                type="radio"
                name="payment_method"
                value="sslcommerz"
                checked={
                  paymentMethod ===
                  'sslcommerz'
                }
                onChange={() =>
                  setPaymentMethod(
                    'sslcommerz'
                  )
                }
                style={{
                  accentColor: '#2457E7',
                }}
              />

              <div style={{ flex: 1 }}>
                <strong>
                  SSLCommerz — Online Payment
                </strong>

                <small>
                  Cards, mobile banking and
                  supported local payment options
                </small>
              </div>

              <Icon
                name="shield-check"
                size={24}
              />
            </label>

            <label
              className="payment-method"
              style={{
                cursor: 'pointer',
                borderColor:
                  paymentMethod === 'cod'
                    ? '#2457E7'
                    : undefined,
              }}
            >
              <input
                type="radio"
                name="payment_method"
                value="cod"
                checked={
                  paymentMethod === 'cod'
                }
                onChange={() =>
                  setPaymentMethod('cod')
                }
                style={{
                  accentColor: '#2457E7',
                }}
              />

              <div style={{ flex: 1 }}>
                <strong>
                  Cash on Delivery (COD)
                </strong>

                <small>
                  Pay in cash when your order
                  is delivered
                </small>
              </div>

              <Icon
                name="truck"
                size={24}
              />
            </label>

            <p className="payment-note">
              {paymentMethod === 'cod'
                ? 'Your order will be placed without redirecting to a payment gateway. Payment remains pending until cash is collected.'
                : "After placing your order, you'll be redirected to the official SSLCommerz payment page. Payment confirmation is handled by your Django backend."}
            </p>
          </div>
        </div>

        {/* ===========================================
            ORDER SUMMARY
        =========================================== */}

        <div className="summary-card checkout-summary">
          <h3>Your order</h3>

          {items.map((item) => {
            const variant = getVariantDisplay(item);

            return (
              <div
                key={item.id}
                className="checkout-item"
              >
                <span>
                  <strong>
                    {item.product_name}
                  </strong>

                  <small>
                    {' '}× {item.quantity}
                  </small>

                  <VariantInformation
                    item={item}
                    compact
                  />

                  {variant.sku && (
                    <small
                      style={{
                        display: 'block',
                        marginTop: 5,
                        color: '#94a3b8',
                      }}
                    >
                      SKU: {variant.sku}
                    </small>
                  )}
                </span>

                <strong>
                  {money(
                    getItemPrice(item) *
                      item.quantity
                  )}
                </strong>
              </div>
            );
          })}

          <div className="summary-divider" />

          <div className="summary-line">
            <span>Subtotal</span>

            <strong>
              {money(subtotal + productSavings)}
            </strong>
          </div>

          {productSavings > 0 && (
            <div className="summary-line discount-line">
              <span>
                Product discounts
              </span>

              <strong>
                -{money(productSavings)}
              </strong>
            </div>
          )}

          {discount !== null && appliedDiscount && appliedDiscount.subtotal === subtotal && (
            <div className="summary-line discount-line">
              <span>
                {discountLabels[appliedDiscount.type]}
              </span>

              <strong>
                -{money(discount)}
              </strong>
            </div>
          )}

          <div className="summary-line">
            <span>Shipping</span>
            <span>Confirmed by store</span>
          </div>

          <div className="summary-divider" />

          <div className="summary-total">
            <span>Estimated total</span>

            <strong>
              {money(estimatedTotal)}
            </strong>
          </div>

          {/* DISCOUNT CODE */}

          <div className="promo-form">
            <label>
              Have a discount code?
            </label>

            <div>
              <input
                value={promo}
                onChange={(e) => {
                  ++discountRequestRef.current;
                  setPromo(e.target.value);
                  setDiscount(null);
                  setAppliedDiscount(null);
                  setValidatingDiscount(false);
                }}
                placeholder="Enter discount code"
              />

              <Button
                type="button"
                variant="outline"
                onClick={() => void validatePromo()}
                disabled={validatingDiscount || busy}
              >
                {validatingDiscount ? 'Checking...' : 'Apply'}
              </Button>
            </div>
          </div>

          {unavailableItems.length > 0 && (
            <Notice
              message="Some cart items are unavailable or exceed stock. Update your cart before placing an order."
            />
          )}

          {error && (
            <Notice message={error} />
          )}

          {uncertain && (
            <Link
              to="/orders"
              className="btn btn-outline full-width"
            >
              Check My Orders first
            </Link>
          )}

          <Button
            loading={busy}
            disabled={
              busy ||
              uncertain ||
              unavailableItems.length > 0
            }
            className="full-width"
          >
            {paymentMethod === 'cod'
              ? 'Place Order'
              : 'Place order & pay'}

            <Icon
              name="arrow"
              size={18}
            />
          </Button>

          <div className="summary-secure">
            <Icon name="lock" size={17} />

            {paymentMethod === 'cod'
              ? 'Pay securely when your order arrives'
              : 'Your order is created once, then paid separately'}
          </div>
        </div>
      </form>
    </div>
  );
}
