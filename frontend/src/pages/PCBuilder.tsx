import {
  useState,
  type FormEvent,
} from 'react';

import {
  useAuth,
  useCart,
  useToast,
} from '../contexts/Store';

import {
  api,
  endpoints,
} from '../lib/api';

import { useData } from '../lib/data';

import {
  Link,
  navigate,
} from '../lib/router';

import type {
  Compatibility,
  Page,
  PcBuild,
  PcVariant,
} from '../lib/types';

import {
  asList,
  errorMessage,
  money,
  pcLabels,
  pcRequired,
} from '../lib/utils';

import {
  Breadcrumbs,
  Button,
  Empty,
  Icon,
  Notice,
  ProductVisual,
  Spinner,
} from '../components/UI';

// ============================================================
// PC BUILDER COMPONENT
// ============================================================

export function PCBuilder() {
  // ----------------------------------------------------------
  // CONTEXTS
  // ----------------------------------------------------------

  const auth = useAuth();
  const cart = useCart();
  const toast = useToast();

  // ----------------------------------------------------------
  // FETCH SAVED PC BUILDS
  // ----------------------------------------------------------

  const builds = useData(
    `pc-builds:${auth.user?.id ?? 0}`,

    () =>
      auth.user
        ? api<PcBuild[] | Page<PcBuild>>(
            endpoints.pcBuilds
          ).then(asList<PcBuild>)
        : Promise.resolve([] as PcBuild[]),

    [] as PcBuild[]
  );

  // ----------------------------------------------------------
  // COMPONENT STATE
  // ----------------------------------------------------------

  const [activeId, setActiveId] = useState<number | null>(
    null
  );

  const [picker, setPicker] = useState<string | null>(
    null
  );

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const [buildName, setBuildName] = useState(
    'My Gaming PC'
  );

  // ----------------------------------------------------------
  // ACTIVE BUILD
  // ----------------------------------------------------------

  const active =
    builds.data.find(
      (build) => build.id === activeId
    ) ?? builds.data[0];

  // ----------------------------------------------------------
  // FETCH COMPATIBILITY REPORT
  // ----------------------------------------------------------

  const report = useData(
    `pc-compat:${active?.id ?? 0}`,

    () =>
      active
        ? api<Compatibility>(
            `${endpoints.pcBuilds}${active.id}/compatibility/`
          )
        : Promise.resolve({
            status: '',
            issues: [],
            warnings: [],
            missing_required: pcRequired,
            checked_rules: [],
          } as Compatibility),

    null as Compatibility | null
  );

  // ----------------------------------------------------------
  // RUN BUILD OPERATIONS
  // ----------------------------------------------------------

  const run = async (
    operation: () => Promise<void>
  ) => {
    if (busy) {
      return;
    }

    setBusy(true);
    setError('');

    try {
      await operation();

      builds.refresh();
      report.refresh();
    } catch (error) {
      setError(errorMessage(error));
    } finally {
      setBusy(false);
    }
  };

  // ----------------------------------------------------------
  // CREATE NEW PC BUILD
  // ----------------------------------------------------------

  const create = (event: FormEvent) => {
    event.preventDefault();

    void run(async () => {
      const build = await api<PcBuild>(
        endpoints.pcBuilds,
        {
          method: 'POST',
          body: {
            name:
              buildName.trim() ||
              'My PC Build',
          },
        }
      );

      setActiveId(build.id);

      toast(
        'PC build created',
        'success'
      );
    });
  };

  // ----------------------------------------------------------
  // REMOVE COMPONENT FROM BUILD
  // ----------------------------------------------------------

  const remove = (itemId: number) => {
    if (!active) {
      return;
    }

    void run(async () => {
      await api(
        `${endpoints.pcBuilds}${active.id}/components/${itemId}/`,
        {
          method: 'DELETE',
        }
      );
    });
  };

  // ----------------------------------------------------------
  // ADD COMPLETE BUILD TO CART
  // ----------------------------------------------------------

  const addCart = () => {
    if (!active) {
      return;
    }

    void run(async () => {
      await api(
        `${endpoints.pcBuilds}${active.id}/add-to-cart/`,
        {
          method: 'POST',
        }
      );

      await cart.reload();

      toast(
        'Build added to cart',
        'success'
      );

      navigate('/cart');
    });
  };

  // ==========================================================
  // PC BUILDER PAGE
  // ==========================================================

  return (
    <div className="container-wide page-space">

      {/* ======================================================
          BREADCRUMBS
      ====================================================== */}

      <Breadcrumbs
        items={[
          {
            label: 'PC Builder',
          },
        ]}
      />

      {/* ======================================================
          HERO SECTION
      ====================================================== */}

      <div className="builder-hero">
        <div>
          <span className="eyebrow">
            BUILD SOMETHING AMAZING
          </span>

          <h1>
            Your perfect PC.
            <br />
            Built your way.
          </h1>

          <p>
            Choose your components, check compatibility,
            and make a setup that's truly yours.
          </p>
        </div>

        <div className="builder-hero-art">
          <Icon
            name="cpu"
            size={116}
          />
        </div>
      </div>

      {/* ======================================================
          AUTHENTICATION CHECK
      ====================================================== */}

      {!auth.user ? (
        <Empty
          icon="pc"
          title="Sign in to start your PC build"
          description="Save builds, check compatibility and add your components to the cart."
          action={
            <Link
              to="/login?next=%2Fpc-builder"
              className="btn btn-primary"
            >
              Sign in
            </Link>
          }
        />
      ) : (
        <>

          {/* ==================================================
              BUILD TOP BAR
          ================================================== */}

          <div className="builder-topbar">
            <div>
              <h2>My builds</h2>

              <p>
                Select an existing build or create a new one.
              </p>
            </div>

            {/* CREATE BUILD FORM */}

            <form
              className="builder-create"
              onSubmit={create}
            >
              <input
                aria-label="New build name"
                maxLength={150}
                value={buildName}
                onChange={(event) =>
                  setBuildName(event.target.value)
                }
              />

              <Button loading={busy}>
                <Icon
                  name="plus"
                  size={17}
                />

                New build
              </Button>
            </form>
          </div>

          {/* ==================================================
              ERROR MESSAGES
          ================================================== */}

          {error && (
            <Notice message={error} />
          )}

          {builds.error && (
            <Notice message={builds.error} />
          )}

          {/* ==================================================
              BUILD LOADING / EMPTY / CONTENT
          ================================================== */}

          {builds.loading ? (
            <Spinner label="Loading PC builds..." />
          ) : builds.data.length === 0 ? (
            <Empty
              icon="cpu"
              title="No builds yet"
              description="Create your first build using the form above."
            />
          ) : (
            <>

              {/* ==============================================
                  BUILD TABS
              ============================================== */}

              <div className="build-tabs">
                {builds.data.map((build) => (
                  <button
                    key={build.id}
                    className={
                      active?.id === build.id
                        ? 'active'
                        : ''
                    }
                    onClick={() =>
                      setActiveId(build.id)
                    }
                  >
                    {build.name}
                  </button>
                ))}
              </div>

              {/* ==============================================
                  ACTIVE BUILD
              ============================================== */}

              {active && (
                <div className="builder-layout">

                  {/* ==========================================
                      COMPONENT SELECTION
                  ========================================== */}

                  <div className="builder-components">

                    {/* COMPONENT HEADER */}

                    <div className="builder-components-head">
                      <h2>
                        Choose your components
                      </h2>

                      <span>
                        {active.items.length} selected
                      </span>
                    </div>

                    {/* COMPONENT ROWS */}

                    {Object.entries(pcLabels).map(
                      ([type, label]) => {
                        const item = active.items.find(
                          (item) =>
                            item.component_type === type
                        );

                        return (
                          <div
                            className="component-row"
                            key={type}
                          >

                            {/* COMPONENT ICON */}

                            <div className="component-icon">
                              <Icon
                                name={
                                  type === 'cpu'
                                    ? 'cpu'
                                    : type === 'monitor'
                                    ? 'monitor'
                                    : type === 'keyboard'
                                    ? 'keyboard'
                                    : type === 'mouse'
                                    ? 'mouse'
                                    : type === 'storage'
                                    ? 'hard-drive'
                                    : 'box'
                                }
                                size={24}
                              />
                            </div>

                            {/* COMPONENT INFORMATION */}

                            <div className="component-info">
                              <strong>
                                {label}

                                {pcRequired.includes(type) && (
                                  <span className="required-dot">
                                    *
                                  </span>
                                )}
                              </strong>

                              {item ? (
                                <>
                                  <span>
                                    {item.variant.product_name}
                                  </span>

                                  <small>
                                    {money(item.subtotal)}
                                    {' · '}
                                    Qty {item.quantity}
                                  </small>
                                </>
                              ) : (
                                <span className="component-placeholder">
                                  Not selected
                                </span>
                              )}
                            </div>

                            {/* COMPONENT ACTIONS */}

                            <div className="component-actions">

                              {item && (
                                <button
                                  title="Remove component"
                                  onClick={() =>
                                    remove(item.id)
                                  }
                                  disabled={busy}
                                >
                                  <Icon
                                    name="trash"
                                    size={18}
                                  />
                                </button>
                              )}

                              <Button
                                variant={
                                  item
                                    ? 'outline'
                                    : 'primary'
                                }
                                onClick={() =>
                                  setPicker(type)
                                }
                                disabled={busy}
                              >
                                <Icon
                                  name={
                                    item
                                      ? 'refresh'
                                      : 'plus'
                                  }
                                  size={16}
                                />

                                {item
                                  ? 'Change'
                                  : 'Choose'}
                              </Button>

                            </div>
                          </div>
                        );
                      }
                    )}
                  </div>

                  {/* ==========================================
                      BUILD SUMMARY
                  ========================================== */}

                  <aside className="builder-summary">

                    {/* SUMMARY HEADER */}

                    <div className="builder-summary-head">
                      <Icon
                        name="cpu"
                        size={27}
                      />

                      <h3>
                        Build summary
                      </h3>
                    </div>

                    {/* TOTAL PRICE */}

                    <div className="builder-total">
                      <small>
                        Estimated total
                      </small>

                      <strong>
                        {money(active.total_price)}
                      </strong>
                    </div>

                    {/* BUILD PROGRESS */}

                    <div className="builder-progress">
                      <div
                        style={{
                          width: `${
                            Math.min(
                              100,
                              (
                                pcRequired.filter(
                                  (type) =>
                                    active.items.some(
                                      (item) =>
                                        item.component_type ===
                                        type
                                    )
                                ).length /
                                pcRequired.length
                              ) * 100
                            )
                          }%`,
                        }}
                      />
                    </div>

                    <p>
                      {
                        pcRequired.filter(
                          (type) =>
                            active.items.some(
                              (item) =>
                                item.component_type ===
                                type
                            )
                        ).length
                      }
                      {' '}of {pcRequired.length}
                      {' '}essential components
                    </p>

                    {/* ========================================
                        COMPATIBILITY CHECK
                    ======================================== */}

                    <div className="builder-check">

                      <strong>
                        <Icon
                          name="shield-check"
                          size={19}
                        />

                        Compatibility check
                      </strong>

                      {report.loading ? (
                        <Spinner label="Checking..." />
                      ) : report.error ? (
                        <Notice message={report.error} />
                      ) : report.data ? (
                        <>

                          {/* COMPATIBILITY STATUS */}

                          <span
                            className={`status-pill status-${
                              report.data.issues.length
                                ? 'failed'
                                : 'paid'
                            }`}
                          >
                            {report.data.issues.length
                              ? 'Needs attention'
                              : 'Checked'}
                          </span>

                          {/* COMPATIBILITY ISSUES */}

                          {report.data.issues.map(
                            (issue, index) => (
                              <p
                                key={index}
                                className="builder-issue"
                              >
                                {issue}
                              </p>
                            )
                          )}

                          {/* COMPATIBILITY WARNINGS */}

                          {report.data.warnings.map(
                            (warning, index) => (
                              <p
                                key={index}
                                className="builder-warning"
                              >
                                {warning}
                              </p>
                            )
                          )}

                          {/* MISSING REQUIRED COMPONENTS */}

                          {report.data.missing_required.length >
                            0 && (
                            <p className="builder-warning">
                              Missing:{' '}

                              {report.data.missing_required
                                .map(
                                  (type) =>
                                    pcLabels[type] || type
                                )
                                .join(', ')}
                            </p>
                          )}

                        </>
                      ) : null}
                    </div>

                    {/* ========================================
                        ADD BUILD TO CART
                    ======================================== */}

                    <Button
                      className="full-width"
                      disabled={
                        busy ||
                        report.loading ||
                        !report.data ||
                        active.items.length === 0 ||
                        Boolean(
                          report.data?.issues.length
                        ) ||
                        Boolean(
                          report.data?.missing_required.length
                        )
                      }
                      loading={busy}
                      onClick={addCart}
                    >
                      <Icon
                        name="cart"
                        size={18}
                      />

                      Add build to cart
                    </Button>

                    <p className="form-note">
                      Prices and compatibility are verified
                      by Django.
                    </p>

                  </aside>
                </div>
              )}
            </>
          )}

          {/* ==================================================
              COMPONENT PICKER MODAL
          ================================================== */}

          {picker && active && (
            <ComponentPicker
              type={picker}
              onClose={() =>
                setPicker(null)
              }
              onSelect={async (variant) => {
                setPicker(null);

                await run(async () => {
                  await api(
                    `${endpoints.pcBuilds}${active.id}/components/`,
                    {
                      method: 'POST',
                      body: {
                        component_type: picker,
                        variant_id: variant.id,
                        quantity: 1,
                      },
                    }
                  );
                });
              }}
            />
          )}

        </>
      )}
    </div>
  );
}

// ============================================================
// COMPONENT PICKER MODAL
// ============================================================

function ComponentPicker({
  type,
  onClose,
  onSelect,
}: {
  type: string;
  onClose: () => void;
  onSelect: (variant: PcVariant) => Promise<void>;
}) {
  // ----------------------------------------------------------
  // COMPONENT STATE
  // ----------------------------------------------------------

  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  // ----------------------------------------------------------
  // FETCH AVAILABLE COMPONENTS
  // ----------------------------------------------------------

  const data = useData(
    `pc-pick:${type}:${search}:${page}`,

    () =>
      api<Page<PcVariant>>(
        `${endpoints.pcComponents}?type=${type}&search=${encodeURIComponent(
          search
        )}&page=${page}&page_size=12`
      ),

    {
      count: 0,
      next: null,
      previous: null,
      results: [],
    } as Page<PcVariant>
  );

  // ==========================================================
  // COMPONENT PICKER JSX
  // ==========================================================

  return (
    <div
      className="modal-backdrop"
      onClick={onClose}
    >

      <div
        className="component-modal"
        onClick={(event) =>
          event.stopPropagation()
        }
        role="dialog"
        aria-modal="true"
        aria-label={`Choose ${pcLabels[type]}`}
      >

        {/* ====================================================
            MODAL HEADER
        ==================================================== */}

        <div className="modal-header">
          <div>
            <span className="eyebrow">
              PC BUILDER
            </span>

            <h2>
              Choose {pcLabels[type] || type}
            </h2>
          </div>

          <button
            aria-label="Close"
            onClick={onClose}
          >
            <Icon name="x" />
          </button>
        </div>

        {/* ====================================================
            SEARCH COMPONENTS
        ==================================================== */}

        <div className="modal-search">
          <Icon
            name="search"
            size={19}
          />

          <input
            placeholder="Search compatible products..."
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              setPage(1);
            }}
          />
        </div>

        {/* ====================================================
            COMPONENT RESULTS
        ==================================================== */}

        {data.error ? (
          <Notice message={data.error} />
        ) : data.loading ? (
          <Spinner label="Finding components..." />
        ) : data.data.results.length ? (

          <div className="component-options">

            {data.data.results.map((variant) => (

              <div
                className="component-option"
                key={variant.id}
              >

                {/* PRODUCT IMAGE */}

                <ProductVisual
                  src={variant.image}
                  name={variant.product_name}
                />

                {/* PRODUCT INFORMATION */}

                <div>
                  <strong>
                    {variant.product_name}
                  </strong>

                  <small>
                    {variant.brand}
                    {' · '}
                    Stock {variant.stock}
                  </small>

                  <span className="price">
                    {money(variant.discounted_price)}
                  </span>
                </div>

                {/* SELECT BUTTON */}

                <Button
                  onClick={() =>
                    void onSelect(variant)
                  }
                >
                  Select

                  <Icon
                    name="check"
                    size={16}
                  />
                </Button>

              </div>
            ))}

          </div>

        ) : (
          <Empty
            icon="box"
            title="No components found"
            description="Make sure PC Builder category mappings are configured in Django Admin."
          />
        )}

        {/* ====================================================
            MODAL FOOTER
        ==================================================== */}

        <div className="modal-footer">

          <span>
            {data.data.count} results
          </span>

          <div>
            <Button
              variant="outline"
              disabled={page <= 1}
              onClick={() =>
                setPage(
                  (previous) => previous - 1
                )
              }
            >
              Previous
            </Button>

            <Button
              variant="outline"
              disabled={!data.data.next}
              onClick={() =>
                setPage(
                  (previous) => previous + 1
                )
              }
            >
              Next
            </Button>
          </div>

        </div>
      </div>
    </div>
  );
}