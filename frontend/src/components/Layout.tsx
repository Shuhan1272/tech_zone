
import {
  useEffect,
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

// ==========================================
// TECHZONE CONTACT INFORMATION
// ==========================================

const SUPPORT_EMAIL = 'techzone@gmail.com';
const SUPPORT_PHONE = '01339883436';

const GMAIL_COMPOSE_URL =
  'https://mail.google.com/mail/?view=cm&fs=1' +
  `&to=${encodeURIComponent(SUPPORT_EMAIL)}` +
  `&su=${encodeURIComponent('TechZone Customer Inquiry')}`;

// ==========================================
// FOOTER STYLES
// ==========================================

const footerStyles: Record<string, CSSProperties> = {
  footer: {
    paddingTop: '38px',
    paddingBottom: '0',
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
    lineHeight: '1.5',
  },

  link: {
    display: 'block',
    width: 'fit-content',
    maxWidth: '100%',
    fontSize: '14px',
    lineHeight: '1.6',
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
    lineHeight: '1.7',
    maxWidth: '280px',
  },

  contactText: {
    margin: 0,
    fontSize: '13px',
    lineHeight: '1.6',
  },

  contactLink: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '9px',
    color: 'inherit',
    textDecoration: 'none',
    fontSize: '13px',
    lineHeight: '1.6',
    overflowWrap: 'anywhere',
    maxWidth: '100%',
  },

  bottom: {
    paddingTop: '17px',
    paddingBottom: '17px',
  },
};

export function Layout({
  children,
}: {
  children: ReactNode;
}) {
  const { pathname } = useRoute();

  const [categories, setCategories] = useState<Category[]>([]);
  const [menuOpen, setMenuOpen] = useState(false);
  const [accountOpen, setAccountOpen] = useState(false);
  const [search, setSearch] = useState('');

  const auth = useAuth();
  const cart = useCart();
  const compare = useCompare();
  const wish = useWishlist();

  // ==========================================
  // WISHLIST COUNT
  // ==========================================

  const wishlistCount = auth.user
    ? (wish.wishlist?.items.length ?? 0)
    : 0;

  const accountRef = useRef<HTMLDivElement>(null);

  // ==========================================
  // LOAD CATEGORIES
  // ==========================================

  useEffect(() => {
    getCategories()
      .then(setCategories)
      .catch((error) => {
        console.error('Failed to load categories:', error);
      });
  }, []);

  // ==========================================
  // CLOSE MENUS ON ROUTE CHANGE
  // ==========================================

  useEffect(() => {
    setMenuOpen(false);
    setAccountOpen(false);
  }, [pathname]);

  // ==========================================
  // CLOSE ACCOUNT MENU ON OUTSIDE CLICK
  // ==========================================

  useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      if (
        accountRef.current &&
        !accountRef.current.contains(e.target as Node)
      ) {
        setAccountOpen(false);
      }
    };

    document.addEventListener('mousedown', onDoc);

    return () => {
      document.removeEventListener('mousedown', onDoc);
    };
  }, []);

  // ==========================================
  // MOBILE DRAWER SCROLL
  // ==========================================

  useEffect(() => {
    document.body.style.overflow = menuOpen
      ? 'hidden'
      : '';

    return () => {
      document.body.style.overflow = '';
    };
  }, [menuOpen]);

  // ==========================================
  // SEARCH
  // ==========================================

  const submitSearch = (e: FormEvent) => {
    e.preventDefault();

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
    navigate(to);
  };

  // ==========================================
  // RESPONSIVE FOOTER
  // ==========================================

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
    footerWidth < 600
      ? 'repeat(2, minmax(0, 1fr))'
      : footerWidth < 950
        ? 'repeat(2, minmax(0, 1fr))'
        : 'minmax(220px, 1.5fr) repeat(3, minmax(140px, 1fr))';

  // ==========================================
  // MAIN LAYOUT
  // ==========================================

  return (
    <div className="app-root">

      {/* ANNOUNCEMENT BAR */}

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

      {/* HEADER */}

      <header className="site-header">
        <div className="container-wide header-inner">

          {/* MOBILE MENU */}

          <button
            className="mobile-menu-btn"
            aria-label="Open menu"
            onClick={() => setMenuOpen(true)}
          >
            <Icon name="menu" size={24} />
          </button>

          {/* LOGO */}

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
              onChange={(e) =>
                setSearch(e.target.value)
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

            {/* COMPARE */}

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

            {/* WISHLIST */}

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
                    setAccountOpen((s) => !s)
                  }
                >
                  {(auth.user.first_name ||
                    auth.user.email)
                    .charAt(0)
                    .toUpperCase()}

                  <Icon name="down" size={13} />
                </button>

                {accountOpen && (
                  <div className="account-menu">
                    <div className="account-menu-user">
                      <strong>
                        {auth.user.first_name ||
                          'My account'}
                      </strong>

                      <small>
                        {auth.user.email}
                      </small>
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
                  </div>
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
            onChange={(e) =>
              setSearch(e.target.value)
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

      {/* ======================================
          CATEGORY NAVIGATION
          ====================================== */}

      <div className="category-nav">
        <div className="container-wide category-inner category-scroll">

          <Link
            to="/catalog"
            className="category-all"
          >
            <Icon name="grid" size={17} />
            All Products
          </Link>

          {categories.map((category) => (
            <div
              key={category.id}
              className="category-item"
            >
              <Link
                to={`/catalog?category=${encodeURIComponent(
                  category.slug
                )}`}
              >
                {category.name}

                {(category.sub_categories?.length ?? 0) >
                  0 && (
                  <Icon name="down" size={13} />
                )}
              </Link>

              {(category.sub_categories?.length ?? 0) >
                0 && (
                <div className="category-dropdown">

                  <Link
                    to={`/catalog?category=${encodeURIComponent(
                      category.slug
                    )}`}
                    className="category-dropdown-title"
                  >
                    Shop all {category.name}
                  </Link>

                  {category.sub_categories?.map(
                    (sub) => (
                      <Link
                        key={sub.id}
                        to={`/catalog?category=${encodeURIComponent(
                          sub.slug
                        )}`}
                      >
                        {sub.name}
                      </Link>
                    )
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* PAGE CONTENT */}

      <main id="main-content">
        {children}
      </main>

      {/* ======================================
          PROFESSIONAL RESPONSIVE FOOTER
          ====================================== */}

      <footer
        className="site-footer"
        style={footerStyles.footer}
      >
        <div
          className="container-wide"
          style={{
            ...footerStyles.main,
            gridTemplateColumns: footerColumns,
            columnGap: footerWidth < 600 ? '20px' : '40px',
          }}
        >

          {/* COLUMN 1: BRAND */}

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

          {/* COLUMN 2: EXPLORE */}

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
              <Link to="/compare">
                Compare products
              </Link>
            </div>
          </div>

          {/* COLUMN 3: MY ACCOUNT */}

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

          {/* COLUMN 4: CONTACT US */}

          <div style={footerStyles.column}>
            <h4 style={footerStyles.heading}>
              Contact Us
            </h4>

            <p style={footerStyles.contactText}>
              Have any questions or queries?
              We're here to help.
            </p>

            {/* GMAIL COMPOSE */}

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

            {/* PHONE */}

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

      {/* ======================================
          COMPARISON FLOATING BAR
          ====================================== */}

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

      {/* ======================================
          MOBILE DRAWER
          ====================================== */}

      {menuOpen && (
        <div
          className="mobile-drawer-overlay"
          onClick={() => setMenuOpen(false)}
        >
          <aside
            className="mobile-drawer"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mobile-drawer-head">
              <strong>
                Browse TechZone
              </strong>

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

            {categories.map((category) => (
              <details
                key={category.id}
                className="mobile-category"
              >
                <summary>
                  {category.name}
                  <Icon name="down" size={16} />
                </summary>

                <button
                  onClick={() =>
                    nav(
                      `/catalog?category=${encodeURIComponent(
                        category.slug
                      )}`
                    )
                  }
                >
                  All {category.name}
                </button>

                {category.sub_categories?.map(
                  (sub) => (
                    <button
                      key={sub.id}
                      onClick={() =>
                        nav(
                          `/catalog?category=${encodeURIComponent(
                            sub.slug
                          )}`
                        )
                      }
                    >
                      {sub.name}
                    </button>
                  )
                )}
              </details>
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
    </div>
  );
}
