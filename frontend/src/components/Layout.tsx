import { createPortal } from 'react-dom';

import {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type FormEvent,
  type ReactNode,
} from 'react';

import {
  useAuth,
  useCart,
  useCompare,
  useWishlist,
} from '../contexts/Store';

import { getCategories } from '../lib/data';
import { Link, navigate, useRoute } from '../lib/router';
import type { Category } from '../lib/types';
import { Icon, Button } from './UI';

// ============================================================
// CONFIGURATION
// ============================================================

const SUPPORT_EMAIL = 'techzone@gmail.com';
const SUPPORT_PHONE = '01339883436';

const GMAIL_COMPOSE_URL =
  'https://mail.google.com/mail/?view=cm&fs=1' +
  `&to=${encodeURIComponent(SUPPORT_EMAIL)}` +
  `&su=${encodeURIComponent('TechZone Customer Inquiry')}`;

const NAV_GAP = 6;
const NAV_SAFE_SPACE = 16;
const MORE_RESERVED_WIDTH = 94;

// ============================================================
// CATEGORY AND BRAND TYPES
// ============================================================

type Id = string | number;

interface BrandNode {
  id: Id;
  name: string;
  slug: string;
  is_active?: boolean;
}

interface CategoryNode {
  id: Id;
  name: string;
  slug: string;
  parent?: Id | { id: Id } | null;
  parent_id?: Id | null;
  is_active?: boolean;
  brands: BrandNode[];
  children: CategoryNode[];
}

type RawCategory = Category & {
  parent?: Id | { id: Id } | null;
  parent_id?: Id | null;
  is_active?: boolean;
  brands?: unknown;
  sub_categories?: RawCategory[];
  subcategories?: RawCategory[];
  children?: RawCategory[];
};

function isObject(
  value: unknown
): value is Record<string, unknown> {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value)
  );
}

function getId(value: unknown): Id | null {
  if (
    typeof value === 'string' ||
    typeof value === 'number'
  ) {
    return value;
  }

  if (isObject(value)) {
    const id = value.id;

    if (
      typeof id === 'string' ||
      typeof id === 'number'
    ) {
      return id;
    }
  }

  return null;
}

function getArray(value: unknown): unknown[] {
  if (Array.isArray(value)) {
    return value;
  }

  if (isObject(value) && Array.isArray(value.results)) {
    return value.results;
  }

  return [];
}

function parseBrands(value: unknown): BrandNode[] {
  const seen = new Set<string>();

  return getArray(value)
    .filter(isObject)
    .filter((brand) => brand.is_active !== false)
    .map((brand) => {
      const name = String(brand.name ?? '').trim();
      const slug = String(brand.slug ?? '').trim();

      return {
        id: getId(brand.id) ?? slug,
        name,
        slug,
      };
    })
    .filter((brand) => {
      if (!brand.name || !brand.slug) {
        return false;
      }

      const key = String(brand.id);

      if (seen.has(key)) {
        return false;
      }

      seen.add(key);
      return true;
    });
}

function normalizeCategories(
  input: RawCategory[]
): CategoryNode[] {
  const nodes = new Map<string, CategoryNode>();
  const parents = new Map<string, string | null>();
  const order: string[] = [];

  const visit = (
    category: RawCategory,
    inheritedParent: Id | null = null,
    ancestors: Set<string> = new Set()
  ) => {
    if (!category || category.is_active === false) {
      return;
    }

    const id = getId(category.id);

    if (id === null) {
      return;
    }

    const key = String(id);

    if (ancestors.has(key)) {
      return;
    }

    const existing = nodes.get(key);

    const ownBrands = parseBrands(category.brands);

    const node: CategoryNode = existing ?? {
      id,
      name: String(category.name ?? ''),
      slug: String(category.slug ?? ''),
      brands: [],
      children: [],
    };

    node.name = String(category.name ?? node.name);
    node.slug = String(category.slug ?? node.slug);

    const mergedBrands = new Map<string, BrandNode>();

    for (const brand of [...node.brands, ...ownBrands]) {
      mergedBrands.set(String(brand.id), brand);
    }

    node.brands = [...mergedBrands.values()];

    if (!existing) {
      nodes.set(key, node);
      order.push(key);
    }

    const explicitParent =
      getId(category.parent_id) ??
      getId(category.parent);

    const parentId = explicitParent ?? inheritedParent;

    if (
      parentId !== null &&
      String(parentId) !== key
    ) {
      parents.set(key, String(parentId));
    } else if (!parents.has(key)) {
      parents.set(key, null);
    }

    const nested = [
      ...getArray(category.sub_categories),
      ...getArray(category.subcategories),
      ...getArray(category.children),
    ];

    const nextAncestors = new Set(ancestors);
    nextAncestors.add(key);

    for (const child of nested) {
      if (isObject(child)) {
        visit(
          child as unknown as RawCategory,
          id,
          nextAncestors
        );
      }
    }
  };

  for (const category of input) {
    visit(category);
  }

  for (const node of nodes.values()) {
    node.children = [];
  }

  const roots: CategoryNode[] = [];

  for (const key of order) {
    const node = nodes.get(key);

    if (!node) {
      continue;
    }

    const parentKey = parents.get(key);
    const parent = parentKey
      ? nodes.get(parentKey)
      : undefined;

    if (!parent) {
      roots.push(node);
      continue;
    }

    // Prevent malformed parent references from creating cycles.
    let cursor: string | null | undefined = parentKey;
    const visited = new Set<string>([key]);
    let cycle = false;

    while (cursor) {
      if (visited.has(cursor)) {
        cycle = true;
        break;
      }

      visited.add(cursor);
      cursor = parents.get(cursor);
    }

    if (cycle) {
      roots.push(node);
    } else {
      parent.children.push(node);
    }
  }

  return roots;
}

// ============================================================
// ROUTES
// ============================================================

function categoryUrl(category: CategoryNode): string {
  return (
    '/catalog?category=' +
    encodeURIComponent(category.slug)
  );
}

// A brand link inside a category menu keeps that category,
// so "Smart Watch > Oraimo" shows only Oraimo smart watches.
function brandUrl(
  brand: BrandNode,
  category?: CategoryNode
): string {
  const params = new URLSearchParams();

  if (category?.slug) {
    params.set('category', category.slug);
  }

  params.set('brand', brand.slug);

  return '/catalog?' + params.toString();
}

function hasChildren(category: CategoryNode): boolean {
  return (
    category.children.length > 0 ||
    category.brands.length > 0
  );
}

// ============================================================
// FOOTER STYLES
// ============================================================

const footerStyles: Record<string, CSSProperties> = {
  footer: {
    paddingTop: '38px',
    paddingBottom: 0,
  },

  main: {
    display: 'grid',
    gridTemplateColumns:
      'minmax(220px, 1.5fr) repeat(3, minmax(140px, 1fr))',
    columnGap: '40px',
    rowGap: '26px',
    alignItems: 'start',
    paddingBottom: '32px',
  },

  column: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'flex-start',
    gap: '12px',
    minWidth: 0,
  },

  heading: {
    margin: '0 0 5px',
    fontSize: '15px',
    fontWeight: 700,
    lineHeight: 1.5,
  },

  link: {
    display: 'block',
    width: 'fit-content',
    maxWidth: '100%',
    fontSize: '14px',
    lineHeight: 1.6,
    color: 'inherit',
    textDecoration: 'none',
    whiteSpace: 'normal',
    overflowWrap: 'anywhere',
    margin: 0,
    padding: 0,
  },

  description: {
    margin: '12px 0 0',
    fontSize: '13px',
    lineHeight: 1.7,
    maxWidth: '280px',
  },

  contactText: {
    margin: 0,
    fontSize: '13px',
    lineHeight: 1.6,
  },

  contactLink: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '9px',
    color: 'inherit',
    textDecoration: 'none',
    fontSize: '13px',
    lineHeight: 1.6,
    overflowWrap: 'anywhere',
    maxWidth: '100%',
  },

  bottom: {
    paddingTop: '17px',
    paddingBottom: '17px',
  },
};

// ============================================================
// DESKTOP CATEGORY MENU CONTENT
// ============================================================

function CategoryMenuContent({
  category,
  closeMenu,
}: {
  category: CategoryNode;
  closeMenu: () => void;
}) {
  return (
    <div className="tz-menu-content">
      <Link
        to={categoryUrl(category)}
        className="tz-menu-shop-all"
        onClick={closeMenu}
      >
        Shop all {category.name}
        <Icon name="arrow" size={15} />
      </Link>

      {category.children.length > 0 && (
        <div className="tz-menu-section">
          <div className="tz-menu-heading">
            Subcategories
          </div>

          {category.children.map((child) => (
            <CategoryMenuRow
              key={String(child.id)}
              category={child}
              closeMenu={closeMenu}
              depth={0}
            />
          ))}
        </div>
      )}

      {category.brands.length > 0 && (
        <div className="tz-menu-section">
          <div className="tz-menu-heading">
            Brands
          </div>

          {category.brands.map((brand) => (
            <Link
              key={String(brand.id)}
              to={brandUrl(brand, category)}
              className="tz-menu-row tz-brand-row"
              onClick={closeMenu}
            >
              <span>{brand.name}</span>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

// ============================================================
// RECURSIVE SUBCATEGORY ROW
// ============================================================

function CategoryMenuRow({
  category,
  closeMenu,
  depth,
}: {
  category: CategoryNode;
  closeMenu: () => void;
  depth: number;
}) {
  const expandable = hasChildren(category);

  return (
    <div
      className={
        'tz-menu-branch' +
        (expandable ? ' has-children' : '')
      }
    >
      <Link
        to={categoryUrl(category)}
        className="tz-menu-row"
        onClick={closeMenu}
      >
        <span>{category.name}</span>

        {expandable && (
          <Icon name="down" size={13} />
        )}
      </Link>

      {expandable && (
        <div
          className={
            'tz-menu-flyout' +
            (depth >= 1 ? ' tz-deep-flyout' : '')
          }
        >
          <div className="tz-menu-flyout-inner">
            <CategoryMenuContent
              category={category}
              closeMenu={closeMenu}
            />
          </div>
        </div>
      )}
    </div>
  );
}

// ============================================================
// MOBILE CATEGORY TREE
// ============================================================

function MobileCategory({
  category,
  navigateTo,
  depth = 0,
}: {
  category: CategoryNode;
  navigateTo: (path: string) => void;
  depth?: number;
}) {
  const expandable = hasChildren(category);

  if (!expandable) {
    return (
      <button
        type="button"
        className="tz-mobile-category-link"
        style={{
          paddingLeft: `${16 + depth * 14}px`,
        }}
        onClick={() => navigateTo(categoryUrl(category))}
      >
        {category.name}
      </button>
    );
  }

  return (
    <details className="tz-mobile-category">
      <summary
        style={{
          paddingLeft: `${16 + depth * 14}px`,
        }}
      >
        <span>{category.name}</span>
        <Icon name="down" size={15} />
      </summary>

      <div className="tz-mobile-category-content">
        <button
          type="button"
          className="tz-mobile-category-link tz-mobile-shop-all"
          style={{
            paddingLeft: `${30 + depth * 14}px`,
          }}
          onClick={() => navigateTo(categoryUrl(category))}
        >
          All {category.name}
        </button>

        {category.children.map((child) => (
          <MobileCategory
            key={String(child.id)}
            category={child}
            navigateTo={navigateTo}
            depth={depth + 1}
          />
        ))}

        {category.brands.length > 0 && (
          <details className="tz-mobile-category">
            <summary
              style={{
                paddingLeft: `${30 + depth * 14}px`,
              }}
            >
              <span>Brands</span>
              <Icon name="down" size={14} />
            </summary>

            {category.brands.map((brand) => (
              <button
                key={String(brand.id)}
                type="button"
                className="tz-mobile-category-link"
                style={{
                  paddingLeft: `${44 + depth * 14}px`,
                }}
                onClick={() =>
                  navigateTo(brandUrl(brand, category))
                }
              >
                {brand.name}
              </button>
            ))}
          </details>
        )}
      </div>
    </details>
  );
}

// ============================================================
// MAIN LAYOUT
// ============================================================

export function Layout({
  children,
}: {
  children: ReactNode;
}) {
  const { pathname } = useRoute();

  const [categories, setCategories] = useState<
    RawCategory[]
  >([]);

  const [menuOpen, setMenuOpen] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);
  const [search, setSearch] = useState('');

  const [activeCategory, setActiveCategory] =
    useState<string | null>(null);

  const [moreOpen, setMoreOpen] = useState(false);

  const [visibleCount, setVisibleCount] = useState(0);

  const [navigationReady, setNavigationReady] =
    useState(false);

  const auth = useAuth();
  const cart = useCart();
  const compare = useCompare();
  const wish = useWishlist();

  const accountRef = useRef<HTMLDivElement>(null);
  const [accountMenuPosition, setAccountMenuPosition] = useState({ top: 0, left: 0 });

  const navContainerRef = useRef<HTMLDivElement>(null);
  const allProductsRef = useRef<HTMLDivElement>(null);
  const measureRef = useRef<HTMLDivElement>(null);

  const categoryTree = useMemo(
    () => normalizeCategories(categories),
    [categories]
  );

  const wishlistCount = auth.user
    ? (wish.wishlist?.items.length ?? 0)
    : 0;

  // ==========================================================
  // LOAD CATEGORIES
  // ==========================================================

  useEffect(() => {
    let mounted = true;

    getCategories()
      .then((result) => {
        if (mounted) {
          setCategories(result as RawCategory[]);
        }
      })
      .catch((error) => {
        console.error(
          'Failed to load categories:',
          error
        );
      });

    return () => {
      mounted = false;
    };
  }, []);

  // ==========================================================
  // RESPONSIVE CATEGORY FITTING
  // ==========================================================

  useLayoutEffect(() => {
    const container = navContainerRef.current;
    const allProducts = allProductsRef.current;
    const measure = measureRef.current;

    if (!container || !allProducts || !measure) {
      return;
    }

    const calculate = () => {
      const total = categoryTree.length;

      if (total === 0) {
        setVisibleCount(0);
        setNavigationReady(true);
        return;
      }

      // FIX: use the inner (content) width only.
      // The old code used the full box width including padding,
      // so "More" could run into the right edge.
      const styles = window.getComputedStyle(container);

      const paddingX =
        (parseFloat(styles.paddingLeft) || 0) +
        (parseFloat(styles.paddingRight) || 0);

      const availableWidth =
        container.clientWidth - paddingX;

      const allWidth =
        allProducts.getBoundingClientRect().width;

      const items = Array.from(
        measure.querySelectorAll<HTMLElement>(
          '[data-category-measure]'
        )
      );

      const widths = items.map(
        (item) => item.getBoundingClientRect().width
      );

      if (!availableWidth || widths.length !== total) {
        return;
      }

      // Space left for the category list after "All Products",
      // the flex gaps, and a small safety margin.
      const remainingWidth =
        availableWidth -
        allWidth -
        NAV_GAP * 2 -
        NAV_SAFE_SPACE;

      const fit = (limit: number) => {
        let used = 0;
        let count = 0;

        for (const width of widths) {
          const next =
            used + width + (count > 0 ? NAV_GAP : 0);

          if (next <= limit) {
            used = next;
            count++;
          } else {
            break;
          }
        }

        return count;
      };

      let count = fit(remainingWidth);

      // Reserve space for More when anything is hidden.
      if (count < total) {
        count = fit(remainingWidth - MORE_RESERVED_WIDTH);
      }

      setVisibleCount(count);
      setNavigationReady(true);
    };

    calculate();

    const observer = new ResizeObserver(calculate);

    observer.observe(container);
    observer.observe(allProducts);
    observer.observe(measure);

    window.addEventListener('resize', calculate);

    if (document.fonts) {
      void document.fonts.ready.then(calculate);
    }

    return () => {
      observer.disconnect();
      window.removeEventListener('resize', calculate);
    };
  }, [categoryTree]);

  const visibleCategories = categoryTree.slice(
    0,
    visibleCount
  );

  const hiddenCategories = categoryTree.slice(
    visibleCount
  );

  // Number of columns in the "More" dropdown.
  const moreColumns =
    hiddenCategories.length > 14
      ? 3
      : hiddenCategories.length > 6
        ? 2
        : 1;

  // ==========================================================
  // CLOSE MENUS ON ROUTE CHANGE
  // ==========================================================

  useEffect(() => {
    setMenuOpen(false);
    setAccountOpen(false);
    setActiveCategory(null);
    setMoreOpen(false);
  }, [pathname]);

  // ==========================================================
  // OUTSIDE ACCOUNT CLICK
  // ==========================================================

  useEffect(() => {
    const onDoc = (event: MouseEvent) => {
      if (
        accountRef.current &&
        !accountRef.current.contains(event.target as Node) &&
        !(event.target as Element).closest?.('.account-menu')
      ) {
        setAccountOpen(false);
      }
    };

    document.addEventListener('mousedown', onDoc);

    return () => {
      document.removeEventListener('mousedown', onDoc);
    };
  }, []);

  // Position the profile dropdown directly below the avatar.
  // The header stacking layer keeps it ABOVE category hover menus.
  useLayoutEffect(() => {
    if (!accountOpen) return;

    const updateAccountPosition = () => {
      const account = accountRef.current;
      if (!account) return;
      const accountRect = account.getBoundingClientRect();
      const menuWidth = Math.min(260, window.innerWidth - 24);
      const left = Math.max(12, Math.min(
        accountRect.right - menuWidth,
        window.innerWidth - menuWidth - 12
      ));
      const top = accountRect.bottom + 8;
      setAccountMenuPosition({ top, left });
    };

    updateAccountPosition();
    window.addEventListener('resize', updateAccountPosition);
    window.addEventListener('scroll', updateAccountPosition, true);
    return () => {
      window.removeEventListener('resize', updateAccountPosition);
      window.removeEventListener('scroll', updateAccountPosition, true);
    };
  }, [accountOpen]);

  // ==========================================================
  // MOBILE DRAWER SCROLL LOCK
  // ==========================================================

  useEffect(() => {
    document.body.style.overflow = menuOpen
      ? 'hidden'
      : '';

    return () => {
      document.body.style.overflow = '';
    };
  }, [menuOpen]);

  // ==========================================================
  // SEARCH
  // ==========================================================

  const submitSearch = (event: FormEvent) => {
    event.preventDefault();

    if (search.trim()) {
      navigate(
        `/catalog?search=${encodeURIComponent(
          search.trim()
        )}`
      );
    }
  };

  const nav = (to: string) => {
    setMenuOpen(false);
    setActiveCategory(null);
    setMoreOpen(false);
    navigate(to);
  };

  const closeCategoryMenus = () => {
    setActiveCategory(null);
    setMoreOpen(false);
  };

  // ==========================================================
  // FOOTER RESPONSIVENESS
  // ==========================================================

  const [footerWidth, setFooterWidth] = useState(
    typeof window !== 'undefined'
      ? window.innerWidth
      : 1200
  );

  useEffect(() => {
    const updateWidth = () => {
      setFooterWidth(window.innerWidth);
    };

    window.addEventListener('resize', updateWidth);

    return () => {
      window.removeEventListener('resize', updateWidth);
    };
  }, []);

  const footerColumns =
    footerWidth < 950
      ? 'repeat(2, minmax(0, 1fr))'
      : 'minmax(220px, 1.5fr) repeat(3, minmax(140px, 1fr))';

  // ==========================================================
  // JSX
  // ==========================================================

  return (
    <div className="app-root">

      {/* ======================================================
          ANNOUNCEMENT BAR
      ====================================================== */}

      <div className="announcement">
        <div className="container-wide announcement-inner">
          <span>
            <Icon name="sparkle" size={14} />
            Your destination for smarter tech
          </span>

          <span className="announcement-right">
            <Icon name="shield-check" size={15} />
            Authentic products

            <i />

            <Icon name="truck" size={15} />
            Nationwide delivery
          </span>
        </div>
      </div>

      {/* ======================================================
          HEADER
      ====================================================== */}

      <header className="site-header">
        <div className="container-wide header-inner">

          <button
            className="mobile-menu-btn"
            aria-label="Open menu"
            onClick={() => setMenuOpen(true)}
          >
            <Icon name="menu" size={24} />
          </button>

          <Link to="/" className="brand-logo">
            <span className="brand-icon">
              <Icon name="cpu" size={23} />
            </span>

            <span>
              Tech<span>Zone</span>
            </span>
          </Link>

          {/* SEARCH */}

          <form
            className="header-search"
            onSubmit={submitSearch}
            role="search"
          >
            <Icon name="search" size={21} />

            <input
              aria-label="Search products"
              placeholder="Search laptops, components, gadgets..."
              value={search}
              onChange={(event) =>
                setSearch(event.target.value)
              }
            />

            <button
              type="submit"
              aria-label="Search"
            >
              <Icon name="arrow" size={19} />
            </button>
          </form>

          {/* HEADER ACTIONS */}

          <nav
            className="header-actions"
            aria-label="Quick links"
          >
            <Link
              to="/pc-builder"
              className="header-action"
              title="Build Your PC"
              aria-label="PC Builder"
            >
              <Icon name="pc" size={21} />
              <span>PC Builder</span>
            </Link>

            <Link
              to="/compare"
              className="header-action"
            >
              <Icon name="compare" size={21} />
              <span>Compare</span>

              {compare.ids.length > 0 && (
                <em className="tiny-count">
                  {compare.ids.length}
                </em>
              )}
            </Link>

            <Link
              to="/wishlist"
              className="header-action"
              aria-label={`Wishlist with ${wishlistCount} items`}
            >
              <Icon name="heart" size={21} />
              <span>Wishlist</span>

              {wishlistCount > 0 && (
                <em className="tiny-count">
                  {wishlistCount}
                </em>
              )}
            </Link>
          </nav>

          {/* ACCOUNT */}

          <div
            className="header-account"
            ref={accountRef}
          >
            {auth.user ? (
              <>
                <button
                  className="account-avatar"
                  aria-label="Account menu"
                  aria-expanded={accountOpen}
                  onClick={() =>
                    setAccountOpen((value) => !value)
                  }
                >
                  {(auth.user.first_name ||
                    auth.user.email)
                    .charAt(0)
                    .toUpperCase()}

                  <Icon name="down" size={13} />
                </button>

                {accountOpen && createPortal(
                  <div
                    className="account-menu"
                    style={{
                      position: 'fixed',
                      top: accountMenuPosition.top,
                      left: accountMenuPosition.left,
                      right: 'auto',
                      width: 'min(260px, calc(100vw - 24px))',
                      zIndex: 2147483647,
                      maxHeight: `calc(100vh - ${Math.min(accountMenuPosition.top, window.innerHeight - 60)}px - 12px)`,
                      overflowY: 'auto',
                    }}
                  >
                    <div className="account-menu-user">
                      <strong>
                        {auth.user.first_name ||
                          'My account'}
                      </strong>

                      <small>{auth.user.email}</small>
                    </div>

                    <Link
                      to="/account"
                      onClick={() =>
                        setAccountOpen(false)
                      }
                    >
                      <Icon name="user" size={17} />
                      My profile
                    </Link>

                    <Link
                      to="/orders"
                      onClick={() =>
                        setAccountOpen(false)
                      }
                    >
                      <Icon name="receipt" size={17} />
                      My orders
                    </Link>

                    <Link
                      to="/account/address"
                      onClick={() =>
                        setAccountOpen(false)
                      }
                    >
                      <Icon name="pin" size={17} />
                      Address
                    </Link>

                    <button
                      onClick={() => {
                        auth.logout();
                        setAccountOpen(false);
                        navigate('/');
                      }}
                    >
                      <Icon name="logout" size={17} />
                      Sign out
                    </button>
                  </div>,
                  document.body
                )}
              </>
            ) : (
              <div className="auth-actions">
                <Link
                  to="/login"
                  className="sign-in"
                >
                  Sign in
                </Link>

                <Link
                  to="/register"
                  className="register-btn"
                >
                  Register
                </Link>
              </div>
            )}
          </div>

          {/* CART */}

          <Link
            to="/cart"
            className="header-cart"
            aria-label={`Cart with ${cart.count} items`}
          >
            <Icon name="cart" size={24} />

            {cart.count > 0 && (
              <span>{cart.count}</span>
            )}
          </Link>
        </div>

        {/* MOBILE SEARCH */}

        <form
          className="mobile-search container-wide"
          onSubmit={submitSearch}
          role="search"
        >
          <Icon name="search" size={19} />

          <input
            aria-label="Search products on mobile"
            placeholder="Search for products..."
            value={search}
            onChange={(event) =>
              setSearch(event.target.value)
            }
          />

          <button
            type="submit"
            aria-label="Search"
          >
            <Icon name="arrow" size={17} />
          </button>
        </form>
      </header>

      {/* ======================================================
          RESPONSIVE CATEGORY NAVIGATION
      ====================================================== */}

      <div className="tz-category-nav">
        <div className="container-wide">
        <div
          ref={navContainerRef}
          className="tz-category-inner"
        >
          <div
            ref={allProductsRef}
            className="tz-all-products"
          >
            <Link
              to="/catalog"
              className="tz-all-link"
              onClick={closeCategoryMenus}
            >
              <Icon name="grid" size={17} />
              All Products
            </Link>
          </div>

          {/* INVISIBLE CATEGORY WIDTH MEASUREMENT */}

          <div
            ref={measureRef}
            className="tz-nav-measure"
            aria-hidden="true"
          >
            {categoryTree.map((category) => (
              <span
                key={String(category.id)}
                data-category-measure
                className="tz-category-trigger"
              >
                {category.name}

                {hasChildren(category) && (
                  <Icon name="down" size={13} />
                )}
              </span>
            ))}
          </div>

          {/* VISIBLE CATEGORIES */}

          <div
            className="tz-visible-categories"
            style={{
              visibility: navigationReady
                ? 'visible'
                : 'hidden',
            }}
          >
            {visibleCategories.map((category) => {
              const key = String(category.id);
              const expandable = hasChildren(category);
              const isOpen = activeCategory === key;

              return (
                <div
                  key={key}
                  className={
                    'tz-category-item' +
                    (isOpen ? ' tz-open' : '')
                  }
                  onMouseEnter={() => {
                    setActiveCategory(key);
                    setMoreOpen(false);
                  }}
                  onMouseLeave={() =>
                    setActiveCategory(null)
                  }
                  onFocus={() => {
                    setActiveCategory(key);
                    setMoreOpen(false);
                  }}
                  onBlur={(event) => {
                    if (
                      !event.currentTarget.contains(
                        event.relatedTarget as Node
                      )
                    ) {
                      setActiveCategory(null);
                    }
                  }}
                >
                  <Link
                    to={categoryUrl(category)}
                    className="tz-category-trigger"
                    onClick={closeCategoryMenus}
                    aria-haspopup={
                      expandable ? 'true' : undefined
                    }
                    aria-expanded={
                      expandable ? isOpen : undefined
                    }
                  >
                    <span>{category.name}</span>

                    {expandable && (
                      <Icon name="down" size={13} />
                    )}
                  </Link>

                  {expandable && isOpen && (
                    <div className="tz-category-dropdown">
                      <CategoryMenuContent
                        category={category}
                        closeMenu={closeCategoryMenus}
                      />
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {/* MORE MENU */}

          {hiddenCategories.length > 0 && (
            <div
              className={
                'tz-more-wrapper' +
                (moreOpen ? ' tz-open' : '')
              }
              onMouseEnter={() => {
                setMoreOpen(true);
                setActiveCategory(null);
              }}
              onMouseLeave={() => setMoreOpen(false)}
              onFocus={() => setMoreOpen(true)}
              onBlur={(event) => {
                if (
                  !event.currentTarget.contains(
                    event.relatedTarget as Node
                  )
                ) {
                  setMoreOpen(false);
                }
              }}
            >
              <button
                type="button"
                className="tz-more-button"
                aria-haspopup="true"
                aria-expanded={moreOpen}
                onClick={() =>
                  setMoreOpen((value) => !value)
                }
              >
                More
                <Icon name="down" size={14} />
              </button>

              {moreOpen && (
                <div
                  className="tz-more-dropdown"
                  style={{
                    width: `${moreColumns * 250 + 16}px`,
                  }}
                >
                  <div className="tz-more-heading">
                    More Categories
                  </div>

                  <div
                    className="tz-more-list"
                    style={{
                      gridTemplateColumns: `repeat(${moreColumns}, minmax(0, 1fr))`,
                    }}
                  >
                    {hiddenCategories.map((category) => (
                      <CategoryMenuRow
                        key={String(category.id)}
                        category={category}
                        closeMenu={closeCategoryMenus}
                        depth={0}
                      />
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
        </div>
      </div>

      {/* ======================================================
          PAGE CONTENT
      ====================================================== */}

      <main id="main-content">
        {children}
      </main>

      {/* ======================================================
          FOOTER
      ====================================================== */}

      <footer
        className="site-footer"
        style={footerStyles.footer}
      >
        <div
          className="container-wide"
          style={{
            ...footerStyles.main,
            gridTemplateColumns: footerColumns,
            columnGap:
              footerWidth < 600 ? '20px' : '40px',
          }}
        >
          {/* BRAND */}

          <div style={footerStyles.column}>
            <Link
              to="/"
              className="brand-logo brand-logo-dark"
            >
              <span className="brand-icon">
                <Icon name="cpu" size={23} />
              </span>

              <span>
                Tech<span>Zone</span>
              </span>
            </Link>

            <p style={footerStyles.description}>
              Your trusted destination for genuine
              technology, competitive prices, and
              nationwide delivery.
            </p>

            <div className="footer-trust">
              <Icon name="shield-check" size={17} />
              Shop confidently with TechZone
            </div>
          </div>

          {/* EXPLORE */}

          <div style={footerStyles.column}>
            <h4 style={footerStyles.heading}>
              Explore
            </h4>

            <div style={footerStyles.link}>
              <Link to="/catalog">
                All products
              </Link>
            </div>

            <div style={footerStyles.link}>
              <Link to="/catalog?featured=true">
                Featured deals
              </Link>
            </div>

            <div style={footerStyles.link}>
              <Link to="/pc-builder">
                PC Builder
              </Link>
            </div>

            <div style={footerStyles.link}>
              <Link to="/compare">
                Compare products
              </Link>
            </div>
          </div>

          {/* MY ACCOUNT */}

          <div style={footerStyles.column}>
            <h4 style={footerStyles.heading}>
              My account
            </h4>

            <div style={footerStyles.link}>
              <Link to="/account">
                Account settings
              </Link>
            </div>

            <div style={footerStyles.link}>
              <Link to="/orders">
                Order history
              </Link>
            </div>

            <div style={footerStyles.link}>
              <Link to="/wishlist">
                Wishlist
              </Link>
            </div>

            <div style={footerStyles.link}>
              <Link to="/account/address">
                Address
              </Link>
            </div>
          </div>

          {/* CONTACT */}

          <div style={footerStyles.column}>
            <h4 style={footerStyles.heading}>
              Contact Us
            </h4>

            <p style={footerStyles.contactText}>
              Have any questions or queries?
              We're here to help.
            </p>

            <a
              href={GMAIL_COMPOSE_URL}
              target="_blank"
              rel="noopener noreferrer"
              style={footerStyles.contactLink}
              title="Send an email using Gmail"
            >
              <Icon name="mail" size={17} />
              <span>{SUPPORT_EMAIL}</span>
            </a>

            <a
              href="tel:+8801339883436"
              style={footerStyles.contactLink}
              title="Call TechZone"
            >
              <Icon name="phone" size={17} />
              <span>{SUPPORT_PHONE}</span>
            </a>
          </div>
        </div>

        {/* FOOTER BOTTOM */}

        <div
          className="container-wide footer-bottom"
          style={footerStyles.bottom}
        >
          <span>
            © {new Date().getFullYear()} TechZone.
            All rights reserved.
          </span>

          <span>
            Genuine products. Nationwide delivery.
          </span>
        </div>
      </footer>

      {/* ======================================================
          COMPARISON FLOATING BAR
      ====================================================== */}

      {compare.ids.length > 0 &&
        pathname !== '/compare' && (
          <div className="compare-float">
            <div className="compare-float-icon">
              <Icon name="compare" size={20} />
            </div>

            <div>
              <strong>
                {compare.ids.length} product
                {compare.ids.length > 1 ? 's' : ''}{' '}
                selected
              </strong>

              <span>
                Compare specifications side by side
              </span>
            </div>

            <Link
              to="/compare"
              className="btn btn-primary btn-small"
            >
              Compare now
              <Icon name="arrow" size={16} />
            </Link>

            <button
              aria-label="Clear comparison"
              onClick={compare.clear}
            >
              <Icon name="x" size={17} />
            </button>
          </div>
        )}

      {/* ======================================================
          MOBILE DRAWER
      ====================================================== */}

      {menuOpen && (
        <div
          className="mobile-drawer-overlay"
          onClick={() => setMenuOpen(false)}
        >
          <aside
            className="mobile-drawer"
            onClick={(event) =>
              event.stopPropagation()
            }
          >
            <div className="mobile-drawer-head">
              <strong>Browse TechZone</strong>

              <button
                aria-label="Close menu"
                onClick={() => setMenuOpen(false)}
              >
                <Icon name="x" />
              </button>
            </div>

            <button
              onClick={() => nav('/catalog')}
              className="mobile-drawer-link"
            >
              <Icon name="grid" size={18} />
              All Products
            </button>

            {/* RECURSIVE MOBILE CATEGORIES */}

            {categoryTree.map((category) => (
              <MobileCategory
                key={String(category.id)}
                category={category}
                navigateTo={nav}
              />
            ))}

            <div className="mobile-drawer-separator" />

            {[
              ['pc', 'PC Builder', '/pc-builder'],
              ['compare', 'Compare', '/compare'],
              ['heart', 'Wishlist', '/wishlist'],
              ['receipt', 'My Orders', '/orders'],
            ].map(([icon, label, path]) => (
              <button
                key={path}
                onClick={() => nav(path)}
                className="mobile-drawer-link"
              >
                <Icon
                  name={icon as 'pc'}
                  size={18}
                />
                {label}
              </button>
            ))}

            {!auth.user && (
              <div className="mobile-auth">
                <Button
                  onClick={() => nav('/login')}
                >
                  Sign in
                </Button>

                <Button
                  variant="outline"
                  onClick={() => nav('/register')}
                >
                  Register
                </Button>
              </div>
            )}
          </aside>
        </div>
      )}

      {/* ======================================================
          CATEGORY NAVIGATION STYLES
      ====================================================== */}

      <style>{`
        /* -----------------------------------------------
           MAIN NAVIGATION
           All Products -> More sits inside the container's
           left and right edges (same as the header content).
           Items stretch to the full nav height so there is
           NO gap between a trigger and its dropdown.
        ----------------------------------------------- */

        /* Profile menu must paint above every category / More flyout. */
        .site-header {
          position: relative;
          z-index: 5000 !important;
          overflow: visible !important;
        }

        .site-header .header-inner,
        .site-header .header-account {
          overflow: visible !important;
        }

        .site-header .account-menu {
          z-index: 6000 !important;
        }

        .tz-category-nav {
          position: relative;
          z-index: 100;
          width: 100%;
          overflow: visible !important;
          background: #fff;
          border-bottom: 1px solid #e8edf5;
        }

        .tz-category-inner {
          position: relative;
          display: flex;
          align-items: stretch;
          width: 100%;
          min-width: 0;
          min-height: 54px;
          gap: ${NAV_GAP}px;
          overflow: visible !important;
          box-sizing: border-box;
        }

        .tz-all-products {
          display: flex;
          align-items: center;
          flex: 0 0 auto;
          white-space: nowrap;
        }

        /* "All Products" - fixed at the far left of the row */

        .tz-all-link {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 6px;
          min-width: 76px;
          padding: 10px 12px;
          border: 1px solid #dbe5f3;
          border-radius: 8px;
          background: #f8faff;
          color: #1d4ed8;
          font-size: 12px;
          font-weight: 800;
          cursor: pointer;
          white-space: nowrap;
          transition: all 150ms ease;
        }

        .tz-all-link:hover {
          background: #1d4ed8;
          color: #ffffff;
        }

        /* Lighter icon colour (change #dbeafe to adjust) */

        // .tz-all-link svg {
        //   color: #1d4ed8;
        //   stroke: #1d4ed8;
        //   flex-shrink: 0;
        // }

        .tz-visible-categories {
          display: flex;
          flex: 1 1 auto;
          align-items: stretch;
          justify-content: space-between;
          min-width: 0;
          gap: ${NAV_GAP}px;
        }

        .tz-category-item {
          position: relative;
          display: flex;
          align-items: center;
          flex: 0 0 auto;
          min-width: 0;
        }

        .tz-category-trigger {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 5px;
          padding: 14px 9px;
          color: #14254c;
          font-size: 12px;
          font-weight: 700;
          line-height: 22px;
          white-space: nowrap;
          text-decoration: none;
          cursor: pointer;
          transition: color 150ms ease;
        }

        .tz-category-trigger:hover,
        .tz-category-item.tz-open > .tz-category-trigger {
          color: #2563eb;
        }

        .tz-category-item.tz-open > .tz-category-trigger {
          background: #f4f7ff;
          border-radius: 7px;
        }

        /* Hidden width measurement */

        .tz-nav-measure {
          position: fixed;
          top: -9999px;
          left: -9999px;
          display: flex;
          width: max-content;
          visibility: hidden;
          pointer-events: none;
          white-space: nowrap;
        }

        .tz-nav-measure .tz-category-trigger {
          flex: 0 0 auto;
        }

        /* -----------------------------------------------
           CATEGORY DROPDOWN
           top: 100% = attached directly under the nav item,
           so the mouse never crosses an empty gap.
        ----------------------------------------------- */

        .tz-category-dropdown {
          position: absolute;
          top: 100%;
          left: 0;
          z-index: 1001;
          width: 250px;
          max-width: calc(100vw - 30px);
          padding: 8px;
          border: 1px solid #e2e8f0;
          border-radius: 12px;
          background: #fff;
          box-shadow: 0 14px 35px rgba(15, 23, 42, .13);
        }

        /* Right-hand categories open towards the left */

        .tz-category-item:nth-last-child(-n+4)
        > .tz-category-dropdown {
          left: auto;
          right: 0;
        }

        .tz-menu-content {
          min-width: 0;
        }

        .tz-menu-shop-all {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 10px;
          padding: 12px 11px;
          color: #1d4ed8;
          background: #eff6ff;
          border-radius: 8px;
          font-size: 12px;
          font-weight: 800;
          text-decoration: none;
        }

        .tz-menu-shop-all:hover {
          background: #dbeafe;
        }

        .tz-menu-section {
          padding-top: 8px;
        }

        .tz-menu-section + .tz-menu-section {
          border-top: 1px solid #eef2f7;
          margin-top: 8px;
        }

        .tz-menu-heading {
          padding: 8px 10px 5px;
          color: #64748b;
          font-size: 10px;
          font-weight: 800;
          letter-spacing: .65px;
          text-transform: uppercase;
        }

        .tz-menu-row {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 10px;
          width: 100%;
          min-height: 36px;
          padding: 9px 10px;
          color: #334155;
          border-radius: 7px;
          font-size: 12px;
          font-weight: 600;
          line-height: 1.5;
          text-decoration: none;
          white-space: normal;
          overflow-wrap: anywhere;
          box-sizing: border-box;
          transition:
            background 150ms ease,
            color 150ms ease;
        }

        .tz-menu-row:hover,
        .tz-menu-branch:hover > .tz-menu-row,
        .tz-menu-branch:focus-within > .tz-menu-row {
          background: #eff6ff;
          color: #2563eb;
        }

        .tz-menu-branch {
          position: relative;
        }

        .tz-menu-branch > .tz-menu-row svg {
          transform: rotate(-90deg);
          flex-shrink: 0;
        }

        .tz-brand-row {
          font-weight: 500;
        }

        /* -----------------------------------------------
           NESTED FLYOUTS
           FIX: no overflow on these containers. Setting
           overflow-y: auto also forces overflow-x to auto,
           which clipped every nested flyout.
        ----------------------------------------------- */

        .tz-menu-flyout {
          position: absolute;
          display: none;
          top: -8px;
          left: calc(100% - 2px);
          width: 250px;
          max-width: calc(100vw - 30px);
          z-index: 1005;
          padding: 8px;
          background: #fff;
          border: 1px solid #e2e8f0;
          border-radius: 12px;
          box-shadow: 0 14px 35px rgba(15, 23, 42, .13);
        }

        .tz-menu-branch:hover > .tz-menu-flyout,
        .tz-menu-branch:focus-within > .tz-menu-flyout {
          display: block;
        }

        .tz-category-item:nth-last-child(-n+4)
        .tz-menu-flyout {
          left: auto;
          right: calc(100% - 2px);
        }

        .tz-menu-flyout .tz-menu-flyout {
          left: calc(100% - 2px);
          right: auto;
        }

        .tz-menu-flyout-inner {
          overflow: visible;
        }

        /* -----------------------------------------------
           MORE BUTTON
        ----------------------------------------------- */

        .tz-more-wrapper {
          position: relative;
          display: flex;
          align-items: center;
          flex: 0 0 auto;
          margin-left: auto;
        }

        .tz-more-button {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 6px;
          min-width: 76px;
          padding: 9px 12px;
          border: 1px solid #dbe5f3;
          border-radius: 8px;
          background: #f8faff;
          color: #1d4ed8;
          font-size: 12px;
          font-weight: 800;
          cursor: pointer;
          white-space: nowrap;
          transition: all 150ms ease;
        }

        .tz-more-button:hover,
        .tz-more-wrapper.tz-open > .tz-more-button {
          background: #eff6ff;
          border-color: #bfdbfe;
        }

        /* FIX: no scrolling here (it clipped the flyouts).
           Long lists use 2 or 3 columns instead. */

        .tz-more-dropdown {
          position: absolute;
          top: 100%;
          right: 0;
          z-index: 1100;
          max-width: calc(100vw - 30px);
          padding: 8px;
          border: 1px solid #e2e8f0;
          border-radius: 12px;
          background: #fff;
          box-shadow: 0 14px 35px rgba(15, 23, 42, .15);
          box-sizing: border-box;
        }

        .tz-more-heading {
          padding: 10px;
          color: #64748b;
          font-size: 11px;
          font-weight: 800;
          letter-spacing: .5px;
          text-transform: uppercase;
          border-bottom: 1px solid #eef2f7;
          margin-bottom: 5px;
        }

        .tz-more-list {
          display: grid;
          gap: 2px 8px;
        }

        .tz-more-dropdown .tz-menu-flyout {
          left: auto;
          right: calc(100% - 2px);
        }

        /* -----------------------------------------------
           MOBILE CATEGORY TREE
        ----------------------------------------------- */

        .tz-mobile-category {
          width: 100%;
          border-bottom: 1px solid #f1f5f9;
        }

        .tz-mobile-category summary {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 12px;
          min-height: 44px;
          padding: 10px 16px;
          color: #1e293b;
          font-size: 13px;
          font-weight: 700;
          cursor: pointer;
          list-style: none;
        }

        .tz-mobile-category summary::-webkit-details-marker {
          display: none;
        }

        .tz-mobile-category summary svg {
          transition: transform 150ms ease;
        }

        .tz-mobile-category[open] > summary svg {
          transform: rotate(180deg);
        }

        .tz-mobile-category-content {
          padding-bottom: 6px;
          background: #f8faff;
        }

        .tz-mobile-category-link {
          display: block;
          width: 100%;
          min-height: 38px;
          padding: 9px 16px;
          border: 0;
          background: transparent;
          color: #475569;
          font-size: 12px;
          font-weight: 500;
          line-height: 1.5;
          text-align: left;
          cursor: pointer;
        }

        .tz-mobile-category-link:hover {
          color: #2563eb;
          background: #eff6ff;
        }

        .tz-mobile-shop-all {
          color: #2563eb;
          font-weight: 700;
        }

        /* -----------------------------------------------
           RESPONSIVE BREAKPOINTS
        ----------------------------------------------- */

        @media (max-width: 1100px) {
          .tz-category-trigger {
            font-size: 11px;
            padding-left: 7px;
            padding-right: 7px;
          }
        }

        @media (max-width: 768px) {
          .tz-category-nav {
            display: none;
          }
        }

        @media (prefers-reduced-motion: reduce) {
          .tz-category-trigger,
          .tz-menu-row,
          .tz-all-link,
          .tz-more-button {
            transition: none;
          }
        }
      `}</style>
    </div>
  );
}
