
import {
  useEffect,
  useRef,
  useState,
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
  // WISHLIST ITEM COUNT
  // ==========================================

  const wishlistCount = auth.user
    ? (wish.wishlist?.items.length ?? 0)
    : 0;

  const accountRef = useRef<HTMLDivElement>(null);

  // ==========================================
  // LOAD ALL CATEGORIES FROM DJANGO API
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
  // CLOSE ACCOUNT MENU WHEN CLICKING OUTSIDE
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
  // MOBILE DRAWER BODY SCROLL
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

            {/* PC BUILDER */}

            {/* <Link
              to="/pc-builder"
              className="header-action"
            >
              <Icon name="pc" size={21} />
              <span>PC Builder</span>
            </Link> */}

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

            {/* WISHLIST WITH COUNT */}

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
          CATEGORY NAVIGATION - ALL CATEGORIES
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

      {/* FOOTER */}

      <footer className="site-footer">
        <div className="container-wide footer-main">

          <div className="footer-brand">
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

            <p>
              Discover technology that moves you forward.
              Genuine products, transparent prices, and
              a shopping experience built around you.
            </p>

            <div className="footer-trust">
              <Icon name="shield-check" size={19} />
              Shop confidently with TechZone
            </div>
          </div>

          <div>
            <h4>Explore</h4>

            <Link to="/catalog">
              All products
            </Link>

            <Link to="/catalog?featured=true">
              Featured deals
            </Link>

            <Link to="/pc-builder">
              PC Builder
            </Link>

            <Link to="/compare">
              Compare products
            </Link>
          </div>

          <div>
            <h4>My account</h4>

            <Link to="/account">
              Account settings
            </Link>

            <Link to="/orders">
              Order history
            </Link>

            <Link to="/wishlist">
              Wishlist
            </Link>

            <Link to="/account/address">
              Delivery address
            </Link>
          </div>

          <div>
            <h4>Why TechZone</h4>

            <p className="footer-small">
              <Icon name="truck" size={18} />
              Nationwide delivery
            </p>

            <p className="footer-small">
              <Icon name="shield" size={18} />
              Genuine technology
            </p>

            <p className="footer-small">
              <Icon name="headphones" size={18} />
              Friendly support
            </p>

            <div className="footer-newsletter">
              Built for your next upgrade.
            </div>
          </div>
        </div>

        <div className="container-wide footer-bottom">
          <span>
            © {new Date().getFullYear()} TechZone.
            All rights reserved.
          </span>

          <span>
            Designed for a better tech shopping
            experience.
          </span>
        </div>
      </footer>

      {/* COMPARISON FLOATING BAR */}

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

      {/* MOBILE DRAWER */}

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
