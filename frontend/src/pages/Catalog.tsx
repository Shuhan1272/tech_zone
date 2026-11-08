import {
  useEffect,
  useMemo,
  useState,
  type FormEvent,
} from 'react';

import {
  Icon,
  ProductCard,
  Spinner,
  Notice,
  Breadcrumbs,
  Empty,
  Button,
} from '../components/UI';

import { api, endpoints, withQuery } from '../lib/api';

import {
  flattenCategories,
  getBrands,
  getCategories,
  getProductImages,
  productImage,
  useData,
} from '../lib/data';

import { navigate, useRoute } from '../lib/router';

import {
  catalogApiParams,
  toggledCsv,
  toggledSpec,
} from '../lib/catalogFilters';

import type {
  Brand,
  Category,
  Page,
  Product,
  ProductImage,
} from '../lib/types';

// ============================================================
// SORTING OPTIONS
// ============================================================

const sorts = [
  ['-created_at', 'Newest first'],
  ['price', 'Price: low to high'],
  ['-price', 'Price: high to low'],
  ['name', 'Name: A to Z'],
  ['-name', 'Name: Z to A'],
];

// ============================================================
// AVAILABILITY OPTIONS
// ============================================================

const availability = [
  ['in_stock', 'In stock'],
  ['out_of_stock', 'Out of stock'],
  ['pre_order', 'Pre-order'],
  ['coming_soon', 'Coming soon'],
];

// ============================================================
// CATALOG COMPONENT
// ============================================================

export function Catalog() {
  // ----------------------------------------------------------
  // ROUTING AND QUERY PARAMETERS
  // ----------------------------------------------------------

  const route = useRoute();

  const params = useMemo(
    () => new URLSearchParams(route.search),
    [route.search]
  );

  // ----------------------------------------------------------
  // COMPONENT STATE
  // ----------------------------------------------------------

  const [categories, setCategories] = useState<Category[]>([]);
  const [brands, setBrands] = useState<Brand[]>([]);
  const [images, setImages] = useState<ProductImage[]>([]);

  const [mobileFilters, setMobileFilters] = useState(false);

  const [minPrice, setMinPrice] = useState(
    params.get('min_price') ?? ''
  );

  const [maxPrice, setMaxPrice] = useState(
    params.get('max_price') ?? ''
  );

  // ----------------------------------------------------------
  // LOAD CATEGORIES, BRANDS AND PRODUCT IMAGES
  // ----------------------------------------------------------

  useEffect(() => {
    getCategories()
      .then(setCategories)
      .catch(() => {});

    getBrands()
      .then(setBrands)
      .catch(() => {});

    getProductImages()
      .then(setImages)
      .catch(() => {});
  }, []);

  // ----------------------------------------------------------
  // SYNCHRONIZE PRICE FILTERS WITH URL
  // ----------------------------------------------------------

  useEffect(() => {
    setMinPrice(params.get('min_price') ?? '');
    setMaxPrice(params.get('max_price') ?? '');
  }, [route.search]);

  // ----------------------------------------------------------
  // CATEGORY DATA
  // ----------------------------------------------------------

  const flat = useMemo(
    () => flattenCategories(categories),
    [categories]
  );

  const selected = flat.find(
    (category) => category.slug === params.get('category')
  );

  // ----------------------------------------------------------
  // FIND SELECTED CATEGORY PATH
  // ----------------------------------------------------------

  const categoryPath = useMemo(() => {
    const visit = (
      items: Category[],
      path: Category[]
    ): Category[] => {
      for (const category of items) {
        const next = [...path, category];

        if (category.slug === params.get('category')) {
          return next;
        }

        const found = visit(
          category.sub_categories ?? [],
          next
        );

        if (found.length) {
          return found;
        }
      }

      return [];
    };

    return visit(categories, []);
  }, [categories, route.search]);

  // ----------------------------------------------------------
  // CATEGORY BRANDS
  // ----------------------------------------------------------

  const categoryBrands =
    categoryPath
      .slice()
      .reverse()
      .find((category) => category.brands?.length)
      ?.brands ?? brands;

  // ----------------------------------------------------------
  // SPECIFICATION FILTERS
  // ----------------------------------------------------------

  const specFilters = Object.assign(
    {},
    ...categoryPath.map(
      (category) => category.filters ?? {}
    )
  ) as Record<string, string[]>;

  const activeSpecs = Object.keys(specFilters).filter(
    (key) => params.has(key)
  );

  // ----------------------------------------------------------
  // FETCH CATALOG PRODUCTS
  // ----------------------------------------------------------

  const list = useData(
    `catalog:${route.search}`,
    () =>
      api<Page<Product>>(
        withQuery(
          endpoints.products,
          catalogApiParams(route.search)
        )
      ),
    {
      count: 0,
      next: null,
      previous: null,
      results: [],
    } as Page<Product>
  );

  // ----------------------------------------------------------
  // UPDATE URL QUERY PARAMETERS
  // ----------------------------------------------------------

  const update = (
    key: string,
    value: string | string[] | null,
    resetPage = true
  ) => {
    const next = new URLSearchParams(route.search);

    next.delete(key);

    if (Array.isArray(value)) {
      value.forEach((item) => {
        next.append(key, item);
      });
    } else if (value !== null && value !== '') {
      next.set(key, value);
    }

    if (resetPage) {
      next.delete('page');
    }

    navigate(
      `/catalog${next.toString() ? `?${next}` : ''}`
    );
  };

  // ----------------------------------------------------------
  // TOGGLE COMMA-SEPARATED FILTER
  // ----------------------------------------------------------

  const toggleCsv = (
    key: string,
    value: string
  ) => {
    navigate(
      `/catalog?${toggledCsv(route.search, key, value)}`
    );
  };

  // ----------------------------------------------------------
  // TOGGLE SPECIFICATION FILTER
  // ----------------------------------------------------------

  const toggleSpec = (
    key: string,
    value: string
  ) => {
    navigate(
      `/catalog?${toggledSpec(route.search, key, value)}`
    );
  };

  // ----------------------------------------------------------
  // CLEAR FILTERS
  // ----------------------------------------------------------

  const clear = () => {
    const next = new URLSearchParams();

    for (const key of [
      'category',
      'search',
      'featured',
    ]) {
      if (params.has(key)) {
        next.set(key, params.get(key)!);
      }
    }

    navigate(
      `/catalog${next.size ? `?${next}` : ''}`
    );
  };

  // ----------------------------------------------------------
  // APPLY PRICE FILTER
  // ----------------------------------------------------------

  const applyPrice = (event: FormEvent) => {
    event.preventDefault();

    if (
      minPrice &&
      maxPrice &&
      Number(minPrice) > Number(maxPrice)
    ) {
      return;
    }

    const next = new URLSearchParams(route.search);

    if (minPrice && Number(minPrice) >= 0) {
      next.set('min_price', minPrice);
    } else {
      next.delete('min_price');
    }

    if (maxPrice && Number(maxPrice) >= 0) {
      next.set('max_price', maxPrice);
    } else {
      next.delete('max_price');
    }

    next.delete('page');

    navigate(`/catalog?${next}`);
  };

  // ----------------------------------------------------------
  // PAGINATION
  // ----------------------------------------------------------

  const page = Math.max(
    1,
    Number(params.get('page') || 1)
  );

  const pageSize = Math.max(
    1,
    Number(params.get('limit') || 20)
  );

  const totalPages = Math.max(
    1,
    Math.ceil(list.data.count / pageSize)
  );

  // ----------------------------------------------------------
  // ACTIVE FILTER CHIPS
  // ----------------------------------------------------------

  const activeChips: [string, string, string][] = [];

  // Brand chips
  (params.get('brand') || '')
    .split(',')
    .filter(Boolean)
    .forEach((slug) => {
      activeChips.push([
        'brand',
        brands.find((brand) => brand.slug === slug)?.name || slug,
        slug,
      ]);
    });

  // Availability chips
  (params.get('availability') || '')
    .split(',')
    .filter(Boolean)
    .forEach((value) => {
      activeChips.push([
        'availability',
        value.replaceAll('_', ' '),
        value,
      ]);
    });

  // Specification chips
  for (const key of activeSpecs) {
    params
      .getAll(key)
      .flatMap((value) => value.split(','))
      .filter(Boolean)
      .forEach((value) => {
        activeChips.push([
          key,
          `${key}: ${value}`,
          value,
        ]);
      });
  }

  // Price chips
  if (params.has('min_price')) {
    activeChips.push([
      'min_price',
      `Min ${params.get('min_price')}`,
      '',
    ]);
  }

  if (params.has('max_price')) {
    activeChips.push([
      'max_price',
      `Max ${params.get('max_price')}`,
      '',
    ]);
  }

  // Stock and sale chips
  if (params.get('in_stock') === 'true') {
    activeChips.push([
      'in_stock',
      'In stock',
      '',
    ]);
  }

  if (params.get('on_sale') === 'true') {
    activeChips.push([
      'on_sale',
      'On sale',
      '',
    ]);
  }

  // ----------------------------------------------------------
  // REMOVE ACTIVE FILTER CHIP
  // ----------------------------------------------------------

  const removeChip = (
    key: string,
    value: string
  ) => {
    if (
      key === 'brand' ||
      key === 'availability'
    ) {
      toggleCsv(key, value);
    } else if (key in specFilters) {
      toggleSpec(key, value);
    } else {
      update(key, null);
    }
  };

  // ==========================================================
  // FILTER SIDEBAR
  // ==========================================================

  const filters = (
    <div className="filters-panel">

      {/* ======================================================
          FILTER HEADER
      ====================================================== */}

      <div className="filter-head">
        <strong>
          <Icon name="sliders" size={19} />
          Filters
        </strong>

        <button onClick={clear}>
          Clear all
        </button>
      </div>

      {/* ======================================================
          CATEGORY FILTER
      ====================================================== */}

      {/* <div className="filter-section">
        <h4>Category</h4>

        <div className="filter-scroll">
          <button
            className={
              !selected
                ? 'filter-category active'
                : 'filter-category'
            }
            onClick={() => update('category', null)}
          >
            All categories
          </button>

          {categories.map((category) => (
            <div key={category.id}>
              <button
                className={
                  selected?.slug === category.slug
                    ? 'filter-category active'
                    : 'filter-category'
                }
                onClick={() =>
                  update('category', category.slug)
                }
              >
                {category.name}
              </button>

              {category.sub_categories?.map(
                (subCategory) => (
                  <button
                    key={subCategory.id}
                    className={`filter-category sub ${
                      selected?.slug === subCategory.slug
                        ? 'active'
                        : ''
                    }`}
                    onClick={() =>
                      update(
                        'category',
                        subCategory.slug
                      )
                    }
                  >
                    {subCategory.name}
                  </button>
                )
              )}
            </div>
          ))}
        </div>
      </div> */}

      {/* ======================================================
          PRICE RANGE FILTER
      ====================================================== */}

      <div className="filter-section">
        <h4>Price range</h4>

        <form onSubmit={applyPrice}>
          <div className="price-fields">
            <label>
              Min (৳)

              <input
                type="number"
                min="0"
                placeholder="0"
                value={minPrice}
                onChange={(event) =>
                  setMinPrice(event.target.value)
                }
              />
            </label>

            <span>—</span>

            <label>
              Max (৳)

              <input
                type="number"
                min="0"
                placeholder="Any"
                value={maxPrice}
                onChange={(event) =>
                  setMaxPrice(event.target.value)
                }
              />
            </label>
          </div>

          {minPrice &&
            maxPrice &&
            Number(minPrice) > Number(maxPrice) && (
              <small className="text-red-600">
                Minimum cannot exceed maximum.
              </small>
            )}

          <Button
            variant="outline"
            className="filter-apply"
            disabled={Boolean(
              minPrice &&
              maxPrice &&
              Number(minPrice) > Number(maxPrice)
            )}
          >
            Apply price
          </Button>
        </form>
      </div>

      {/* ======================================================
          AVAILABILITY AND OFFERS
      ====================================================== */}

      <div className="filter-section">
        <h4>Availability &amp; offers</h4>

        <div className="filter-checkboxes">
          <label>
            <input
              type="checkbox"
              checked={
                params.get('in_stock') === 'true'
              }
              onChange={(event) =>
                update(
                  'in_stock',
                  event.target.checked
                    ? 'true'
                    : null
                )
              }
            />

            <span>In stock only</span>
          </label>

          <label>
            <input
              type="checkbox"
              checked={
                params.get('on_sale') === 'true'
              }
              onChange={(event) =>
                update(
                  'on_sale',
                  event.target.checked
                    ? 'true'
                    : null
                )
              }
            />

            <span>On sale</span>
          </label>

          {availability.map(([value, label]) => (
            <label key={value}>
              <input
                type="checkbox"
                checked={(params.get('availability') || '')
                  .split(',')
                  .includes(value)}
                onChange={() =>
                  toggleCsv('availability', value)
                }
              />

              <span>{label}</span>
            </label>
          ))}
        </div>
      </div>

      {/* ======================================================
          BRAND FILTER
      ====================================================== */}

      <div className="filter-section">
        <h4>
          Brand

          <span>
            {(params.get('brand') || '')
              .split(',')
              .filter(Boolean).length || ''}
          </span>
        </h4>

        <div className="filter-scroll filter-checkboxes">
          {categoryBrands
            .filter(
              (brand) => brand.is_active !== false
            )
            .map((brand) => (
              <label key={brand.id}>
                <input
                  type="checkbox"
                  checked={(params.get('brand') || '')
                    .split(',')
                    .includes(brand.slug)}
                  onChange={() =>
                    toggleCsv('brand', brand.slug)
                  }
                />

                <span>{brand.name}</span>
              </label>
            ))}

          {categoryBrands.length === 0 && (
            <small>No brands available</small>
          )}
        </div>
      </div>

      

      {/* ======================================================
          DYNAMIC SPECIFICATION FILTERS
      ====================================================== */}

      {Object.entries(specFilters)
        .filter(
          ([, values]) =>
            Array.isArray(values) &&
            values.length > 0
        )
        .map(([key, values]) => (
          <div
            className="filter-section"
            key={key}
          >
            <h4>{key}</h4>

            <div className="filter-scroll filter-checkboxes">
              {values.map((value) => (
                <label key={value}>
                  <input
                    type="checkbox"
                    checked={params
                      .getAll(key)
                      .flatMap((item) =>
                        item.split(',')
                      )
                      .includes(value)}
                    onChange={() =>
                      toggleSpec(key, value)
                    }
                  />

                  <span>{value}</span>
                </label>
              ))}
            </div>
          </div>
        ))}
    </div>
  );

  // ==========================================================
  // CATALOG PAGE
  // ==========================================================

  return (
    <div className="catalog-page container-wide">

      {/* ======================================================
          BREADCRUMBS
      ====================================================== */}

      <Breadcrumbs
        items={[
          {
            label: 'Products',
            to: '/catalog',
          },
          ...(selected
            ? [{ label: selected.name }]
            : []),
        ]}
      />

      {/* ======================================================
          CATALOG HEADING
      ====================================================== */}

      <div className="catalog-heading">
        <div>
          <div className="eyebrow">
            THE TECHZONE COLLECTION
          </div>

          <h1>
            {selected?.name ||
              (params.get('search')
                ? `Results for “${params.get('search')}”`
                : 'All products')}
          </h1>

          <p>
            Find the right technology for your everyday.
          </p>
        </div>

        <div className="catalog-count">
          {list.loading
            ? 'Loading...'
            : `${list.data.count.toLocaleString()} products`}
        </div>
      </div>

      {/* ======================================================
          CATALOG LAYOUT
      ====================================================== */}

      <div className="catalog-layout">

        {/* DESKTOP FILTER SIDEBAR */}

        <aside className="catalog-sidebar">
          {filters}
        </aside>

        {/* ====================================================
            PRODUCT RESULTS
        ==================================================== */}

        <div className="catalog-results">

          {/* ==================================================
              TOOLBAR
          ================================================== */}

          <div className="catalog-toolbar">

            {/* Mobile filter button */}

            <button
              className="mobile-filter-toggle"
              onClick={() =>
                setMobileFilters(true)
              }
            >
              <Icon name="filter" size={19} />

              Filters

              {activeChips.length > 0 && (
                <b>{activeChips.length}</b>
              )}
            </button>

            {/* Product count */}

            <div className="toolbar-count">
              Showing{' '}

              {list.data.count
                ? `${
                    (page - 1) * pageSize + 1
                  }–${Math.min(
                    page * pageSize,
                    list.data.count
                  )}`
                : '0'}

              {' '}of {list.data.count}
            </div>

            {/* Sorting and page size */}

            <div className="toolbar-controls">
              <label>
                Sort by

                <select
                  aria-label="Sort products"
                  value={
                    params.get('ordering') ||
                    '-created_at'
                  }
                  onChange={(event) =>
                    update(
                      'ordering',
                      event.target.value
                    )
                  }
                >
                  {sorts.map(([value, label]) => (
                    <option
                      value={value}
                      key={value}
                    >
                      {label}
                    </option>
                  ))}
                </select>
              </label>

              <label className="page-size-control">
                Show

                <select
                  aria-label="Products per page"
                  value={
                    params.get('limit') || '20'
                  }
                  onChange={(event) =>
                    update(
                      'limit',
                      event.target.value
                    )
                  }
                >
                  {[12, 20, 36, 60].map(
                    (value) => (
                      <option key={value}>
                        {value}
                      </option>
                    )
                  )}
                </select>
              </label>
            </div>
          </div>

          {/* ==================================================
              ACTIVE FILTER CHIPS
          ================================================== */}

          {activeChips.length > 0 && (
            <div className="active-filters">
              {activeChips.map(
                ([key, label, value], index) => (
                  <button
                    key={`${key}-${value}-${index}`}
                    onClick={() =>
                      removeChip(key, value)
                    }
                  >
                    {label}

                    <Icon
                      name="x"
                      size={14}
                    />
                  </button>
                )
              )}

              <button
                className="clear-chip"
                onClick={clear}
              >
                Clear filters
              </button>
            </div>
          )}

          {/* ==================================================
              PRODUCT RESULTS STATES
          ================================================== */}

          {list.error ? (
            <Notice message={list.error} />
          ) : list.loading ? (
            <Spinner
              label="Finding your products..."
            />
          ) : list.data.results.length ? (
            <>
              {/* PRODUCT GRID */}

              <div className="product-grid catalog-product-grid">
                {list.data.results.map(
                  (product) => (
                    <ProductCard
                      key={product.id}
                      product={product}
                      image={productImage(
                        images,
                        product.id
                      )}
                    />
                  )
                )}
              </div>

              {/* ==============================================
                  PAGINATION
              ============================================== */}

              <div className="pagination">
                <button
                  disabled={page <= 1}
                  onClick={() =>
                    update(
                      'page',
                      String(page - 1),
                      false
                    )
                  }
                >
                  <Icon
                    name="left"
                    size={17}
                  />

                  Previous
                </button>

                <span>
                  Page {page} of {totalPages}
                </span>

                <button
                  disabled={
                    page >= totalPages
                  }
                  onClick={() =>
                    update(
                      'page',
                      String(page + 1),
                      false
                    )
                  }
                >
                  Next

                  <Icon
                    name="chevron"
                    size={17}
                  />
                </button>
              </div>
            </>
          ) : (
            <Empty
              icon="search"
              title="No products match your filters"
              description="Try another brand, category or price range."
              action={
                <Button onClick={clear}>
                  Clear filters
                </Button>
              }
            />
          )}
        </div>
      </div>

      {/* ======================================================
          MOBILE FILTER OVERLAY
      ====================================================== */}

      {mobileFilters && (
        <div
          className="mobile-filter-overlay"
          onClick={() =>
            setMobileFilters(false)
          }
        >
          <div
            className="mobile-filter-panel"
            onClick={(event) =>
              event.stopPropagation()
            }
          >

            {/* MOBILE FILTER HEADER */}

            <div className="mobile-filter-head">
              <strong>
                Filter products
              </strong>

              <button
                onClick={() =>
                  setMobileFilters(false)
                }
                aria-label="Close filters"
              >
                <Icon name="x" />
              </button>
            </div>

            {/* FILTER CONTENT */}

            {filters}

            {/* MOBILE FILTER FOOTER */}

            <div className="mobile-filter-bottom">
              <Button
                onClick={() =>
                  setMobileFilters(false)
                }
              >
                Show {list.data.count} products
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}