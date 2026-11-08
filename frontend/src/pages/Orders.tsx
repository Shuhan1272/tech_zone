
import { useEffect, useState } from 'react';
import { api, endpoints } from '../lib/api';
import { useData } from '../lib/data';
import { Link, useRoute } from '../lib/router';
import type { Order, Page, Payment } from '../lib/types';
import {
  asList,
  errorMessage,
  money,
  shortDate,
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

// ==========================================
// REFUND TYPES
// ==========================================

type RefundStatus =
  | 'requested'
  | 'approved'
  | 'rejected'
  | 'initiating'
  | 'processing'
  | 'refunded'
  | 'failed';

interface Refund {
  id: number;
  payment_id: number;
  order_id: number;
  amount: string;
  currency: string;
  reason: string;
  status: RefundStatus;
  status_display: string;
  refund_reference_id: string;
  admin_note: string;
  reviewed_at: string | null;
  processing_started_at: string | null;
  completed_at: string | null;
  failure_reason: string;
  created_at: string;
  updated_at: string;
}

interface OrderRefundResponse {
  has_refund: boolean;
  refund: Refund | null;
}

interface RefundRequestResponse {
  message: string;
  refund: Refund;
}

// ==========================================
// REFUND API ENDPOINTS
// ==========================================

const REFUND_BASE = '/api/v1/payments/refunds/';

function refundStatusUrl(orderId: number) {
  return `${REFUND_BASE}order/${orderId}/`;
}

function refundRequestUrl() {
  return `${REFUND_BASE}request/`;
}

// ==========================================
// REFUND HELPERS
// ==========================================

const ACTIVE_REFUND_STATUSES: RefundStatus[] = [
  'requested',
  'approved',
  'initiating',
  'processing',
];

function isActiveRefund(status: RefundStatus) {
  return ACTIVE_REFUND_STATUSES.includes(status);
}

function refundStatusLabel(status: RefundStatus) {
  const labels: Record<RefundStatus, string> = {
    requested: 'Request submitted',
    approved: 'Approved',
    rejected: 'Rejected',
    initiating: 'Starting refund',
    processing: 'Processing refund',
    refunded: 'Refund completed',
    failed: 'Refund failed',
  };

  return labels[status] || status;
}

function refundDescription(status: RefundStatus) {
  const descriptions: Record<RefundStatus, string> = {
    requested:
      'Your request has been submitted and is waiting for administrator review.',

    approved:
      'Your refund request has been approved. The administrator will initiate the refund.',

    rejected:
      'Your refund request was rejected. Please review the administrator response.',

    initiating:
      'The refund has been submitted for gateway processing. Its outcome may still require verification.',

    processing:
      'SSLCommerz is processing your refund. Please wait for confirmation.',

    refunded:
      'Your refund has been verified and recorded as completed.',

    failed:
      'The refund could not be completed. Please contact support for assistance.',
  };

  return descriptions[status] || '';
}

// ==========================================
// PRODUCT IMAGE
// ==========================================

function OrderProductImage({
  image,
  name,
}: {
  image?: string | null;
  name: string;
}) {
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setFailed(false);
  }, [image]);

  if (!image || failed) {
    return <Icon name="box" size={26} />;
  }

  return (
    <img
      src={image}
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

// ==========================================
// ORDER LIST
// ==========================================

export function Orders() {
  const data = useData(
    'orders',
    async () =>
      asList<Order>(
        await api<Order[] | Page<Order>>(
          endpoints.orders
        )
      ),
    [] as Order[]
  );

  return (
    <div className="container-wide page-space">
      <Breadcrumbs
        items={[{ label: 'My orders' }]}
      />

      <PageHeading
        eyebrow="MY ACCOUNT"
        title="My orders"
        description="Track your purchases and manage payments."
      />

      {data.error ? (
        <Notice message={data.error} />
      ) : data.loading ? (
        <Spinner label="Loading your orders..." />
      ) : data.data.length ? (
        <div className="order-list">
          {data.data.map((o) => (
            <Link
              to={`/orders/${o.id}`}
              key={o.id}
              className="order-list-item"
            >
              <div className="order-icon">
                <Icon name="receipt" size={24} />
              </div>

              <div className="order-list-main">
                <strong>Order #{o.id}</strong>
                <span>
                  {shortDate(o.created_at)} ·{' '}
                  {o.items.length} item
                  {o.items.length !== 1 ? 's' : ''}
                </span>
              </div>

              <div className="order-list-status">
                <span
                  className={`status-pill status-${o.payment_status}`}
                >
                  Payment: {o.payment_status}
                </span>

                <span className="order-status-text">
                  {o.status}
                </span>
              </div>

              <strong className="order-list-price">
                {money(o.total_amount)}
              </strong>

              <Icon name="chevron" size={20} />
            </Link>
          ))}
        </div>
      ) : (
        <Empty
          icon="receipt"
          title="No orders yet"
          description="Your orders will show up here after checkout."
          action={
            <Link
              to="/catalog"
              className="btn btn-primary"
            >
              Start shopping
            </Link>
          }
        />
      )}
    </div>
  );
}

// ==========================================
// REFUND STATUS COMPONENT
// ==========================================

function RefundStatusCard({
  refund,
  onRefresh,
  refreshing,
}: {
  refund: Refund;
  onRefresh: () => void;
  refreshing: boolean;
}) {
  const steps = [
    {
      key: 'requested',
      label: 'Requested',
    },
    {
      key: 'approved',
      label: 'Approved',
    },
    {
      key: 'processing',
      label: 'Processing',
    },
    {
      key: 'refunded',
      label: 'Refunded',
    },
  ];

  const progress: Record<string, number> = {
    requested: 0,
    approved: 1,
    initiating: 2,
    processing: 2,
    refunded: 3,
    rejected: 0,
    failed: 2,
  };

  const currentProgress = progress[refund.status] ?? 0;

  const successful = refund.status === 'refunded';

  const unsuccessful =
    refund.status === 'rejected' ||
    refund.status === 'failed';

  return (
    <div
      className="form-card"
      style={{
        marginTop: 20,
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
          flexWrap: 'wrap',
          marginBottom: 14,
        }}
      >
        <div>
          <h2 style={{ marginBottom: 4 }}>
            Refund status
          </h2>

          <p style={{ margin: 0, opacity: 0.75 }}>
            Refund request #{refund.id}
          </p>
        </div>

        <span
          className={`status-pill status-${
            successful
              ? 'paid'
              : unsuccessful
                ? 'failed'
                : 'pending'
          }`}
        >
          {refundStatusLabel(refund.status)}
        </span>
      </div>

      <p style={{ marginBottom: 18 }}>
        {refundDescription(refund.status)}
      </p>

      {!unsuccessful && (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
            gap: 8,
            marginBottom: 22,
          }}
        >
          {steps.map((step, index) => {
            const done = index <= currentProgress;

            return (
              <div
                key={step.key}
                style={{
                  textAlign: 'center',
                  minWidth: 0,
                }}
              >
                <div
                  style={{
                    width: 30,
                    height: 30,
                    margin: '0 auto 8px',
                    borderRadius: '50%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    background: done
                      ? '#16a34a'
                      : '#e5e7eb',
                    color: done
                      ? '#ffffff'
                      : '#6b7280',
                    fontWeight: 700,
                    fontSize: 13,
                  }}
                >
                  {done ? '✓' : index + 1}
                </div>

                <span
                  style={{
                    fontSize: 12,
                    fontWeight: done ? 600 : 400,
                    overflowWrap: 'anywhere',
                  }}
                >
                  {step.label}
                </span>
              </div>
            );
          })}
        </div>
      )}

      <div className="summary-line">
        <span>Refund amount</span>
        <strong>{money(refund.amount)}</strong>
      </div>

      <div className="summary-line">
        <span>Request date</span>
        <strong>{shortDate(refund.created_at)}</strong>
      </div>

      {refund.completed_at && (
        <div className="summary-line">
          <span>Completed</span>
          <strong>
            {shortDate(refund.completed_at)}
          </strong>
        </div>
      )}

      <div
        style={{
          marginTop: 16,
          marginBottom: 16,
        }}
      >
        <strong>Reason for refund</strong>

        <p
          style={{
            marginTop: 6,
            whiteSpace: 'pre-wrap',
            overflowWrap: 'anywhere',
          }}
        >
          {refund.reason}
        </p>
      </div>

      {refund.status === 'rejected' && (
        <Notice
          message={
            refund.admin_note ||
            'Your refund request was rejected.'
          }
        />
      )}

      {refund.status === 'failed' && (
        <Notice
          message={
            refund.failure_reason ||
            'Refund processing failed. Contact support.'
          }
        />
      )}

      {refund.status === 'refunded' && (
        <Notice
          type="success"
          message="Your refund has been verified. You can now cancel the order if it is still eligible for cancellation."
        />
      )}

      <Button
        variant="outline"
        disabled={refreshing}
        onClick={onRefresh}
        className="full-width"
      >
        <Icon name="refresh" size={17} />
        {refreshing
          ? 'Refreshing...'
          : 'Refresh refund status'}
      </Button>
    </div>
  );
}

// ==========================================
// REFUND REQUEST FORM
// ==========================================

function RefundRequestForm({
  amount,
  busy,
  onSubmit,
  onClose,
}: {
  amount: string | number;
  busy: boolean;
  onSubmit: (reason: string) => Promise<void>;
  onClose: () => void;
}) {
  const [reason, setReason] = useState('');

  const trimmedReason = reason.trim();

  return (
    <div
      className="form-card"
      style={{
        marginTop: 20,
      }}
    >
      <h2>Request a refund</h2>

      <p>
        You are requesting a full refund of{' '}
        <strong>{money(amount)}</strong>.
      </p>

      <p>
        Your request will be reviewed by an
        administrator before any refund is initiated.
      </p>

      <form
        onSubmit={(event) => {
          event.preventDefault();

          if (
            trimmedReason.length < 1 ||
            trimmedReason.length > 255
          ) {
            return;
          }

          void onSubmit(trimmedReason);
        }}
      >
        <label
          htmlFor="refund-reason"
          style={{
            display: 'block',
            fontWeight: 600,
            marginBottom: 8,
          }}
        >
          Why do you want a refund?
        </label>

        <textarea
          id="refund-reason"
          value={reason}
          onChange={(event) =>
            setReason(event.target.value)
          }
          placeholder="Please explain why you want to cancel this order and receive a refund."
          maxLength={255}
          required
          disabled={busy}
          rows={4}
          style={{
            width: '100%',
            padding: 12,
            borderRadius: 8,
            border: '1px solid #cbd5e1',
            background: 'transparent',
            color: 'inherit',
            font: 'inherit',
            resize: 'vertical',
            boxSizing: 'border-box',
          }}
        />

        <div
          style={{
            textAlign: 'right',
            fontSize: 12,
            opacity: 0.7,
            marginTop: 4,
            marginBottom: 16,
          }}
        >
          {reason.length}/255
        </div>

        <div
          style={{
            display: 'flex',
            gap: 10,
            flexWrap: 'wrap',
          }}
        >
          <Button
            loading={busy}
            disabled={
              busy ||
              trimmedReason.length < 1 ||
              trimmedReason.length > 255
            }
            onClick={() => {
              void onSubmit(trimmedReason);
            }}
          >
            Submit refund request
          </Button>

          <Button
            variant="outline"
            disabled={busy}
            onClick={onClose}
          >
            Cancel
          </Button>
        </div>
      </form>
    </div>
  );
}

// ==========================================
// ORDER DETAILS
// ==========================================

export function OrderDetail() {
  const route = useRoute();

  const id = Number(
    route.pathname.split('/')[2]
  );

  const {
    data: order,
    loading,
    error,
    refresh,
  } = useData(
    `order:${id}`,
    () =>
      api<Order>(
        `${endpoints.orders}${id}/`
      ),
    null as Order | null
  );

  // ========================================
  // REFUND STATE
  // ========================================

  const [refund, setRefund] = useState<Refund | null>(
    null
  );

  const [refundLoading, setRefundLoading] =
    useState(true);

  const [refundError, setRefundError] =
    useState('');

  const [refundFormOpen, setRefundFormOpen] =
    useState(false);

  const [refundBusy, setRefundBusy] =
    useState(false);

  const [busy, setBusy] = useState(false);

  const [actionError, setActionError] =
    useState('');

  const [actionSuccess, setActionSuccess] =
    useState('');

  // ========================================
  // LOAD REFUND STATUS
  // ========================================

  const loadRefund = async (
    orderId: number,
    showLoading = true
  ) => {
    if (showLoading) {
      setRefundLoading(true);
    }

    setRefundError('');

    try {
      const result = await api<OrderRefundResponse>(
        refundStatusUrl(orderId)
      );

      setRefund(
        result.has_refund
          ? result.refund
          : null
      );
    } catch (e) {
      setRefundError(errorMessage(e));
    } finally {
      setRefundLoading(false);
    }
  };

  useEffect(() => {
    if (!Number.isInteger(id) || id < 1) {
      setRefundLoading(false);
      return;
    }

    setRefund(null);
    setRefundFormOpen(false);

    void loadRefund(id);
  }, [id]);

  // ========================================
  // CLEAR PENDING PAYMENT
  // ========================================

  useEffect(() => {
    if (
      order?.payment_status === 'paid' &&
      sessionStorage.getItem(
        'techzone_pending_order'
      ) === String(order.id)
    ) {
      sessionStorage.removeItem(
        'techzone_pending_order'
      );
    }
  }, [
    order?.payment_status,
    order?.id,
  ]);

  // ========================================
  // REFRESH ORDER + REFUND
  // ========================================

  const refreshAll = async () => {
    refresh();
    await loadRefund(id);
  };

  // ========================================
  // PAY
  // ========================================

  const pay = async () => {
    if (!order) return;

    setBusy(true);
    setActionError('');
    setActionSuccess('');

    try {
      const result = await api<{
        payment_url: string;
      }>(
        endpoints.paymentInitiate,
        {
          method: 'POST',
          body: {
            order_id: order.id,
          },
        }
      );

      if (
        !validateGatewayUrl(result.payment_url)
      ) {
        throw Error(
          'The backend returned an invalid SSLCommerz payment URL.'
        );
      }

      window.location.assign(
        result.payment_url
      );
    } catch (e) {
      setActionError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  // ========================================
  // CANCEL ORDER
  // ========================================

  const cancel = async () => {
    if (!order) return;

    if (
      !window.confirm(
        'Are you sure you want to cancel this order?'
      )
    ) {
      return;
    }

    setBusy(true);
    setActionError('');
    setActionSuccess('');

    try {
      await api(
        `${endpoints.orders}${id}/cancel/`,
        {
          method: 'POST',
        }
      );

      setActionSuccess(
        'Your order has been cancelled successfully.'
      );

      await refreshAll();
    } catch (e) {
      setActionError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  // ========================================
  // SUBMIT REFUND REQUEST
  // ========================================

  const submitRefund = async (
    reason: string
  ) => {
    if (!order) return;

    setRefundBusy(true);
    setActionError('');
    setActionSuccess('');

    try {
      const result =
        await api<RefundRequestResponse>(
          refundRequestUrl(),
          {
            method: 'POST',
            body: {
              order_id: order.id,
              reason,
            },
          }
        );

      setRefund(result.refund);
      setRefundFormOpen(false);

      setActionSuccess(
        result.message ||
        'Your refund request has been submitted successfully.'
      );

      await loadRefund(order.id, false);
    } catch (e) {
      setActionError(errorMessage(e));
    } finally {
      setRefundBusy(false);
    }
  };

  // ========================================
  // LOADING
  // ========================================

  if (loading) {
    return (
      <div className="container-wide">
        <Spinner label="Loading order..." />
      </div>
    );
  }

  if (error || !order) {
    return (
      <div className="container-wide page-space">
        <Notice
          message={
            error || 'Order not found'
          }
        />
      </div>
    );
  }

  // ========================================
  // ORDER PERMISSIONS
  // ========================================

  const isActiveOrder = [
    'pending',
    'confirmed',
  ].includes(order.status);

  const isOnlinePayment =
    order.payment_method === 'sslcommerz';

  const isPaid =
    order.payment_status === 'paid';

  const isRefunded =
    order.payment_status === 'refunded';

  const hasActiveRefund =
    refund !== null &&
    isActiveRefund(refund.status);

  const canPay =
    isActiveOrder &&
    isOnlinePayment &&
    !['paid', 'refunded'].includes(
      order.payment_status
    );

  const canRequestRefund =
    isActiveOrder &&
    isOnlinePayment &&
    isPaid &&
    !hasActiveRefund &&
    (
      refund === null ||
      refund.status === 'rejected'
    );

  const canCancel =
    isActiveOrder &&
    (
      (
        !isPaid &&
        !isRefunded &&
        !hasActiveRefund
      ) ||
      (
        isOnlinePayment &&
        isRefunded &&
        refund?.status === 'refunded'
      )
    );

  // ========================================
  // RENDER
  // ========================================

  return (
    <div className="container-wide page-space">
      <Breadcrumbs
        items={[
          {
            label: 'My orders',
            to: '/orders',
          },
          {
            label: `Order #${id}`,
          },
        ]}
      />

      <PageHeading
        eyebrow="ORDER DETAILS"
        title={`Order #${id}`}
        description={`Placed on ${shortDate(
          order.created_at
        )}`}
        action={
          <Link
            to="/orders"
            className="btn btn-outline"
          >
            <Icon
              name="left"
              size={17}
            />
            All orders
          </Link>
        }
      />

      {new URLSearchParams(
        route.search
      ).has('payment_error') && (
        <Notice
          type="info"
          message="Your order was created but payment has not been completed. You can retry payment below without placing a new order."
        />
      )}

      {actionError && (
        <Notice message={actionError} />
      )}

      {actionSuccess && (
        <Notice
          type="success"
          message={actionSuccess}
        />
      )}

      <div className="order-detail-layout">
        <div>

          {/* =================================
              ORDER STATUS
          ================================= */}

          <div className="form-card">
            <div className="order-status-header">
              <div>
                <h2>Order status</h2>

                <p>
                  Track the progress of your purchase
                </p>
              </div>

              <span
                className={`status-pill status-${order.payment_status}`}
              >
                {order.payment_status}
              </span>
            </div>

            <div className="status-grid">
              <div>
                <small>Order</small>
                <strong>
                  {order.status}
                </strong>
              </div>

              <div>
                <small>Payment</small>
                <strong>
                  {order.payment_status}
                </strong>
              </div>

              <div>
                <small>Items</small>
                <strong>
                  {order.items.length}
                </strong>
              </div>
            </div>
          </div>

          {/* =================================
              REFUND STATUS
          ================================= */}

          {refundLoading ? (
            <div
              className="form-card"
              style={{ marginTop: 20 }}
            >
              <Spinner
                label="Checking refund status..."
              />
            </div>
          ) : refundError ? (
            <div
              style={{ marginTop: 20 }}
            >
              <Notice
                message={refundError}
              />

              <Button
                variant="outline"
                onClick={() => {
                  void loadRefund(id);
                }}
              >
                Retry refund status
              </Button>
            </div>
          ) : refund ? (
            <RefundStatusCard
              refund={refund}
              refreshing={refundLoading}
              onRefresh={() => {
                void refreshAll();
              }}
            />
          ) : null}

          {/* =================================
              REFUND REQUEST FORM
          ================================= */}

          {refundFormOpen &&
            canRequestRefund &&
            !refundLoading &&
            !refundError && (
              <RefundRequestForm
                amount={order.total_amount}
                busy={refundBusy}
                onSubmit={submitRefund}
                onClose={() =>
                  setRefundFormOpen(false)
                }
              />
            )}

          {/* =================================
              ORDER ITEMS
          ================================= */}

          <div
            className="form-card"
            style={{ marginTop: 20 }}
          >
            <h2>
              Items in your order
            </h2>

            {order.items.map((item) => (
              <div
                key={item.id}
                className="order-product-row"
              >
                <div className="cart-row-art">
                  <OrderProductImage
                    image={
                      item.product_image
                    }
                    name={
                      item.product_name
                    }
                  />
                </div>

                <div>
                  <strong>
                    {item.product_name}
                  </strong>

                  <span>
                    SKU: {item.sku} · Qty{' '}
                    {item.quantity}
                  </span>
                </div>

                <strong>
                  {money(item.line_total)}
                </strong>
              </div>
            ))}
          </div>

          {/* =================================
              SHIPPING DETAILS
          ================================= */}

          <div className="form-card">
            <h2>
              Shipping details
            </h2>

            <p className="shipping-detail">
              <Icon
                name="user"
                size={18}
              />
              {order.shipping_name}
            </p>

            <p className="shipping-detail">
              <Icon
                name="phone"
                size={18}
              />
              {order.shipping_phone}
            </p>

            <p className="shipping-detail">
              <Icon
                name="pin"
                size={18}
              />
              {order.shipping_address}
            </p>
          </div>
        </div>

        {/* ===================================
            PAYMENT SUMMARY
        =================================== */}

        <div className="summary-card order-summary">
          <h3>
            Payment summary
          </h3>

          <div className="summary-line">
            <span>Subtotal</span>
            <strong>
              {money(order.subtotal)}
            </strong>
          </div>

          <div className="summary-line">
            <span>Discount</span>
            <strong>
              -{money(
                order.discount_amount ?? 0
              )}
            </strong>
          </div>

          <div className="summary-divider" />

          <div className="summary-total">
            <span>Total</span>
            <strong>
              {money(order.total_amount)}
            </strong>
          </div>

          {/* PAYMENT BUTTON */}

          {canPay && (
            <Button
              loading={busy}
              disabled={busy}
              onClick={() => {
                void pay();
              }}
              className="full-width"
            >
              <Icon
                name="credit-card"
                size={18}
              />
              Pay with SSLCommerz
            </Button>
          )}

          {/* REQUEST REFUND BUTTON */}

          {canRequestRefund &&
            !refundFormOpen &&
            !refundLoading &&
            !refundError && (
              <Button
                variant="outline"
                disabled={
                  busy ||
                  refundBusy
                }
                onClick={() => {
                  setRefundFormOpen(true);
                  setActionError('');
                  setActionSuccess('');
                }}
                className="full-width"
              >
                Request full refund
              </Button>
            )}

          {/* REFUND PENDING NOTICE */}

          {hasActiveRefund && (
            <Notice
              type="info"
              message="Your refund request is being handled. Order cancellation will become available after the refund is verified."
            />
          )}

          {/* CANCEL ORDER BUTTON */}

          {canCancel &&
            !refundLoading &&
            !refundError && (
              <Button
                variant="outline"
                disabled={
                  busy ||
                  refundBusy
                }
                onClick={() => {
                  void cancel();
                }}
                className="full-width"
              >
                Cancel order
              </Button>
            )}

          {/* PAID NOTICE */}

          {isPaid &&
            !hasActiveRefund && (
              <Notice
                type="success"
                message="Payment has been confirmed."
              />
            )}

          {/* REFUNDED NOTICE */}

          {isRefunded && (
            <Notice
              type="success"
              message="The payment has been refunded successfully."
            />
          )}

          {/* REFRESH BUTTON */}

          <Button
            variant="ghost"
            disabled={
              busy ||
              refundBusy
            }
            onClick={() => {
              void refreshAll();
            }}
            className="full-width"
          >
            <Icon
              name="refresh"
              size={17}
            />
            Refresh status
          </Button>
        </div>
      </div>
    </div>
  );
}

// ==========================================
// PAYMENT RESULT
// ==========================================

export function PaymentResult() {
  const route = useRoute();

  const params = new URLSearchParams(
    route.search
  );

  const transaction =
    params.get('transaction_id') || '';

  const result =
    params.get('result') || 'pending';

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const {
    data: payments,
    loading,
    refresh,
  } = useData(
    `payments:${transaction}`,
    async () => {
      if (!transaction) {
        return [] as Payment[];
      }

      const all: Payment[] = [];

      for (
        let page = 1;
        page <= 10;
        page++
      ) {
        const res = await api<Page<Payment>>(
          `${endpoints.payments}?page=${page}&page_size=100`
        );

        all.push(
          ...asList<Payment>(res)
        );

        if (!res.next) break;
      }

      return all;
    },
    [] as Payment[]
  );

  const payment = payments.find(
    (p) =>
      p.transaction_id === transaction
  );

  useEffect(() => {
    if (
      payment?.status === 'paid'
    ) {
      sessionStorage.removeItem(
        'techzone_pending_order'
      );
    }
  }, [payment?.status]);

  const verify = async () => {
    if (!payment) return;

    setBusy(true);
    setError('');

    try {
      await api(
        `${endpoints.payments}${payment.id}/verify/`,
        {
          method: 'POST',
        }
      );

      refresh();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="container-wide page-space">
      <div className="checkout-confirm">
        <div className="confirm-icon">
          <Icon
            name={
              payment?.status === 'paid'
                ? 'check-circle'
                : 'credit-card'
            }
            size={45}
          />
        </div>

        <h1>
          Payment{' '}
          {payment?.status === 'paid'
            ? 'confirmed'
            : result === 'success'
              ? 'verification'
              : result === 'cancelled'
                ? 'cancelled'
                : 'status'}
        </h1>

        <p>
          {payment?.status === 'paid'
            ? 'Your payment was verified by SSLCommerz and marked as paid in our system.'
            : 'Your payment is not confirmed yet. The gateway result alone does not mark an order as paid.'}
        </p>

        {loading ? (
          <Spinner
            label="Checking payment..."
          />
        ) : (
          <>
            <div className="payment-result-status">
              Transaction:{' '}
              <strong>
                {transaction ||
                  'Not supplied'}
              </strong>

              <br />

              Status:{' '}
              <strong>
                {payment?.status ||
                  'Not found'}
              </strong>
            </div>

            {error && (
              <Notice message={error} />
            )}

            <Button
              loading={busy}
              onClick={() => {
                void verify();
              }}
              disabled={
                !payment ||
                busy ||
                payment.status === 'paid' ||
                payment.status === 'refunded'
              }
            >
              <Icon
                name="refresh"
                size={18}
              />
              Verify payment
            </Button>

            {payment && (
              <Link
                to={`/orders/${payment.order}`}
                className="btn btn-outline"
              >
                View order
              </Link>
            )}

            <Link
              to="/orders"
              className="text-action"
            >
              All orders
            </Link>
          </>
        )}
      </div>
    </div>
  );
}
