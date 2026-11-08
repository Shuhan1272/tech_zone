import {
  Fragment,
  useState,
} from 'react';

import {
  useAuth,
  useCart,
  useCompare,
  useToast,
  useWishlist,
} from '../contexts/Store';

import {
  api,
  endpoints,
  tokens,
} from '../lib/api';

import { useData } from '../lib/data';

import {
  Link,
  useRoute,
} from '../lib/router';

import type {
  CompareResult,
  Wishlist,
} from '../lib/types';

import {
  errorMessage,
  money,
  valueText,
} from '../lib/utils';

import {
  Breadcrumbs,
  Button,
  Empty,
  Icon,
  Notice,
  PageHeading,
  ProductVisual,
  Spinner,
} from '../components/UI';

// ============================================================
// WISHLIST PAGE
// ============================================================

export function WishlistPage() {
  // ----------------------------------------------------------
  // CONTEXTS
  // ----------------------------------------------------------

  const auth = useAuth();
  const wish = useWishlist();
  const cart = useCart();
  const toast = useToast();

  // ----------------------------------------------------------
  // COMPONENT STATE
  // ----------------------------------------------------------

  const [busy, setBusy] = useState<number | null>(null);
  const [error, setError] = useState('');
  const [share, setShare] = useState('');

  // ----------------------------------------------------------
  // ADD WISHLIST PRODUCT TO CART
  // ----------------------------------------------------------

  const add = async (variantId: number) => {
    setBusy(variantId);

    try {
      await cart.add(variantId);
    } catch (error) {
      toast(
        errorMessage(error),
        'error'
      );
    } finally {
      setBusy(null);
    }
  };

  // ----------------------------------------------------------
  // SHARE WISHLIST
  // ----------------------------------------------------------

  const shareWishlist = async () => {
    try {
      const response = await api<{
        share_url: string;
      }>(
        `${endpoints.wishlist}share/`,
        {
          method: 'POST',
        }
      );

      const sharedUrl = new URL(
        response.share_url,
        window.location.origin
      );

      const url = `${window.location.origin}${sharedUrl.pathname}`;

      setShare(url);

      await navigator.clipboard
        .writeText(url)
        .catch(() => {});

      toast(
        'Wishlist link ready to share',
        'success'
      );
    } catch (error) {
      setError(errorMessage(error));
    }
  };

  // ----------------------------------------------------------
  // DOWNLOAD WISHLIST AS PDF
  // ----------------------------------------------------------

  const download = async () => {
    try {
      const response = await fetch(
        '/api/v1/wishlist/download/',
        {
          headers: {
            Authorization: `Bearer ${
              tokens.getAccess() ?? ''
            }`,
          },
        }
      );

      if (!response.ok) {
        throw Error(
          'Could not download your wishlist'
        );
      }

      const blob = await response.blob();

      const url = URL.createObjectURL(blob);

      const anchor = document.createElement('a');

      anchor.href = url;
      anchor.download = 'TechZone_Wishlist.pdf';

      anchor.click();

      window.setTimeout(() => {
        URL.revokeObjectURL(url);
      }, 1500);
    } catch (error) {
      setError(errorMessage(error));
    }
  };

  // ==========================================================
  // WISHLIST PAGE JSX
  // ==========================================================

  return (
    <div className="container-wide page-space">

      {/* ======================================================
          BREADCRUMBS
      ====================================================== */}

      <Breadcrumbs
        items={[
          {
            label: 'Wishlist',
          },
        ]}
      />

      {/* ======================================================
          PAGE HEADING
      ====================================================== */}

      <PageHeading
        eyebrow="SAVED FOR LATER"
        title="My wishlist"
        description="All the tech you love, in one place."
        action={
          auth.user && wish.wishlist?.items.length ? (
            <div className="heading-actions">

              {/* SHARE WISHLIST */}

              <Button
                variant="outline"
                onClick={() =>
                  void shareWishlist()
                }
              >
                <Icon
                  name="share"
                  size={17}
                />

                Share
              </Button>

              {/* DOWNLOAD PDF */}

              <Button
                variant="outline"
                onClick={() =>
                  void download()
                }
              >
                <Icon
                  name="download"
                  size={17}
                />

                PDF
              </Button>

            </div>
          ) : undefined
        }
      />

      {/* ======================================================
          NOTIFICATIONS
      ====================================================== */}

      {error && (
        <Notice message={error} />
      )}

      {share && (
        <Notice
          type="success"
          message={`Shareable link: ${share}`}
        />
      )}

      {/* ======================================================
          WISHLIST CONTENT
      ====================================================== */}

      {!auth.user ? (

        // USER NOT AUTHENTICATED

        <Empty
          icon="heart"
          title="Sign in to save your favorites"
          action={
            <Link
              to="/login?next=%2Fwishlist"
              className="btn btn-primary"
            >
              Sign in
            </Link>
          }
        />

      ) : wish.wishlist?.items.length ? (

        // WISHLIST PRODUCTS

        <div className="wishlist-grid">

          {wish.wishlist.items.map((item) => (
            <div
              className="wishlist-card"
              key={item.id}
            >

              {/* PRODUCT IMAGE */}

              <Link
                to={`/product/${item.product_slug}`}
              >
                <ProductVisual
                  src={item.image}
                  name={item.product_name}
                />
              </Link>

              {/* PRODUCT INFORMATION */}

              <div>

                <span className="eyebrow">
                  {item.category}
                </span>

                <Link
                  to={`/product/${item.product_slug}`}
                  className="wishlist-name"
                >
                  {item.product_name}
                </Link>

                <strong className="price">
                  {money(item.discounted_price)}
                </strong>

                {/* PRODUCT ACTIONS */}

                <div className="wishlist-actions">

                  {/* ADD TO CART */}

                  <Button
                    loading={
                      busy === item.variant_id
                    }
                    disabled={!item.is_available}
                    onClick={() =>
                      void add(item.variant_id)
                    }
                  >
                    <Icon
                      name="cart"
                      size={17}
                    />

                    Add to cart
                  </Button>

                  {/* REMOVE FROM WISHLIST */}

                  <button
                    className="icon-action"
                    title="Remove"
                    onClick={() =>
                      void wish.remove(item.id)
                    }
                  >
                    <Icon
                      name="trash"
                      size={19}
                    />
                  </button>

                </div>
              </div>
            </div>
          ))}

        </div>

      ) : (

        // EMPTY WISHLIST

        <Empty
          icon="heart"
          title="Nothing saved yet"
          description="Tap the heart on any product to keep it here."
          action={
            <Link
              to="/catalog"
              className="btn btn-primary"
            >
              Discover products
            </Link>
          }
        />

      )}

    </div>
  );
}

// ============================================================
// SHARED WISHLIST PAGE
// ============================================================

export function SharedWishlist() {
  // ----------------------------------------------------------
  // ROUTING
  // ----------------------------------------------------------

  const route = useRoute();

  const token = route.pathname.split('/')[3];

  // ----------------------------------------------------------
  // FETCH SHARED WISHLIST
  // ----------------------------------------------------------

  const data = useData(
    `shared:${token}`,

    () =>
      api<Wishlist>(
        `${endpoints.wishlist}shared/${token}/`,
        {
          auth: false,
        }
      ),

    {
      count: 0,
      is_public: false,
      items: [],
    } as Wishlist
  );

  // ==========================================================
  // SHARED WISHLIST JSX
  // ==========================================================

  return (
    <div className="container-wide page-space">

      {/* ======================================================
          BREADCRUMBS
      ====================================================== */}

      <Breadcrumbs
        items={[
          {
            label: 'Shared wishlist',
          },
        ]}
      />

      {/* ======================================================
          PAGE HEADING
      ====================================================== */}

      <PageHeading
        eyebrow="SHARED COLLECTION"
        title="Someone's TechZone wishlist"
        description="A handpicked collection of favorite products."
      />

      {/* ======================================================
          SHARED WISHLIST CONTENT
      ====================================================== */}

      {data.error ? (

        <Notice message={data.error} />

      ) : data.loading ? (

        <Spinner />

      ) : data.data.items.length ? (

        <div className="wishlist-grid">

          {data.data.items.map((item) => (

            <Link
              key={item.id}
              to={`/product/${item.product_slug}`}
              className="wishlist-card"
            >

              {/* PRODUCT IMAGE */}

              <ProductVisual
                src={item.image}
                name={item.product_name}
              />

              {/* PRODUCT INFORMATION */}

              <div>

                <strong className="wishlist-name">
                  {item.product_name}
                </strong>

                <span className="price">
                  {money(item.discounted_price)}
                </span>

              </div>

            </Link>
          ))}

        </div>

      ) : (

        <Empty
          title="This wishlist is empty or unavailable"
        />

      )}

    </div>
  );
}

// ============================================================
// PRODUCT COMPARISON PAGE
// ============================================================

export function Compare() {
  // ----------------------------------------------------------
  // COMPARE CONTEXT
  // ----------------------------------------------------------

  const compare = useCompare();

  // ----------------------------------------------------------
  // COMPONENT STATE
  // ----------------------------------------------------------

  const [different, setDifferent] = useState(false);

  // ----------------------------------------------------------
  // SELECTED PRODUCT IDS
  // ----------------------------------------------------------

  const ids = compare.ids.join(',');

  // ----------------------------------------------------------
  // FETCH PRODUCT COMPARISON
  // ----------------------------------------------------------

  const data = useData(
    `compare:${ids}`,

    () =>
      ids
        ? api<CompareResult>(
            `${endpoints.products}compare/?ids=${ids}`
          )
        : Promise.resolve({
            count: 0,
            max_products: 4,
            products: [],
            specification_sections: [],
          } as CompareResult),

    {
      count: 0,
      max_products: 4,
      products: [],
      specification_sections: [],
    } as CompareResult
  );

  // ==========================================================
  // PRODUCT COMPARISON JSX
  // ==========================================================

  return (
    <div className="container-wide page-space">

      {/* ======================================================
          BREADCRUMBS
      ====================================================== */}

      <Breadcrumbs
        items={[
          {
            label: 'Compare products',
          },
        ]}
      />

      {/* ======================================================
          PAGE HEADING
      ====================================================== */}

      <PageHeading
        eyebrow="MAKE THE RIGHT CHOICE"
        title="Compare products"
        description="See the differences that matter, side by side."
        action={
          compare.ids.length > 0 ? (
            <Button
              variant="outline"
              onClick={compare.clear}
            >
              <Icon
                name="trash"
                size={17}
              />

              Clear all
            </Button>
          ) : undefined
        }
      />

      {/* ======================================================
          COMPARISON CONTENT
      ====================================================== */}

      {!ids ? (

        // NO PRODUCTS SELECTED

        <Empty
          icon="compare"
          title="Choose products to compare"
          description="Add up to four products from the catalog to compare their specifications."
          action={
            <Link
              to="/catalog"
              className="btn btn-primary"
            >
              Browse products
            </Link>
          }
        />

      ) : data.error ? (

        // ERROR STATE

        <Notice message={data.error} />

      ) : data.loading ? (

        // LOADING STATE

        <Spinner label="Preparing comparison..." />

      ) : (
        <>

          {/* ==================================================
              COMPARISON TOOLS
          ================================================== */}

          <div className="compare-tools">

            <label>
              <input
                type="checkbox"
                checked={different}
                onChange={(event) =>
                  setDifferent(event.target.checked)
                }
              />

              Show differences only
            </label>

            <span>
              {data.data.count} of 4 products
            </span>

          </div>

          {/* ==================================================
              COMPARISON TABLE
          ================================================== */}

          <div className="compare-scroll">

            <table className="compare-table">

              {/* ==============================================
                  TABLE HEADER
              ============================================== */}

              <thead>
                <tr>

                  <th>
                    Products
                  </th>

                  {data.data.products.map((product) => (

                    <th key={product.id}>

                      {/* REMOVE PRODUCT */}

                      <button
                        className="compare-remove"
                        onClick={() =>
                          compare.toggle(product.id)
                        }
                        title="Remove product"
                      >
                        <Icon
                          name="x"
                          size={16}
                        />
                      </button>

                      {/* PRODUCT DETAILS */}

                      <Link
                        to={`/product/${product.slug}`}
                      >
                        <ProductVisual
                          src={product.image}
                          name={product.name}
                        />

                        <strong>
                          {product.name}
                        </strong>
                      </Link>

                      {/* PRODUCT PRICE */}

                      <div className="compare-price">
                        {money(
                          product.variant?.discounted_price
                        )}
                      </div>

                    </th>
                  ))}

                </tr>
              </thead>

              {/* ==============================================
                  TABLE BODY
              ============================================== */}

              <tbody>

                {/* BRAND ROW */}

                <tr>
                  <th>Brand</th>

                  {data.data.products.map((product) => (
                    <td key={product.id}>
                      {product.brand || '—'}
                    </td>
                  ))}
                </tr>

                {/* CATEGORY ROW */}

                <tr>
                  <th>Category</th>

                  {data.data.products.map((product) => (
                    <td key={product.id}>
                      {product.category || '—'}
                    </td>
                  ))}
                </tr>

                {/* AVAILABILITY ROW */}

                <tr>
                  <th>Availability</th>

                  {data.data.products.map((product) => (
                    <td key={product.id}>
                      {product.availability?.replaceAll(
                        '_',
                        ' '
                      ) || '—'}
                    </td>
                  ))}
                </tr>

                {/* ============================================
                    SPECIFICATION SECTIONS
                ============================================ */}

                {data.data.specification_sections.map(
                  (section) => (

                    <Fragment key={section.name}>

                      {/* SECTION HEADING */}

                      <tr
                        key={`h-${section.name}`}
                        className="compare-section-heading"
                      >
                        <th
                          colSpan={
                            data.data.products.length + 1
                          }
                        >
                          {section.name}
                        </th>
                      </tr>

                      {/* SPECIFICATION ROWS */}

                      {section.rows
                        .filter(
                          (row) =>
                            !different || row.different
                        )
                        .map((row) => (

                          <tr
                            key={`${section.name}-${row.label}`}
                          >

                            {/* SPECIFICATION NAME */}

                            <th>
                              {row.label}
                            </th>

                            {/* PRODUCT SPECIFICATION VALUES */}

                            {row.values.map(
                              (value, index) => (

                                <td key={index}>
                                  {valueText(value)}
                                </td>

                              )
                            )}

                          </tr>
                        ))}

                    </Fragment>
                  )
                )}

              </tbody>
            </table>

          </div>

          {/* ==================================================
              ADD MORE PRODUCTS
          ================================================== */}

          <div className="compare-bottom">

            <Link
              to="/catalog"
              className="btn btn-outline"
            >
              <Icon
                name="plus"
                size={17}
              />

              Add more products
            </Link>

          </div>

        </>
      )}

    </div>
  );
}