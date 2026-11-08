import {
  useEffect,
  type ReactNode,
} from 'react';

// ============================================================
// LAYOUT AND UI COMPONENTS
// ============================================================

import { Layout } from './components/Layout';

import {
  Empty,
  Spinner,
} from './components/UI';

// ============================================================
// CONTEXT PROVIDERS
// ============================================================

import {
  StoreProviders,
  useAuth,
} from './contexts/Store';

// ============================================================
// ROUTING UTILITIES
// ============================================================

import {
  Link,
  navigate,
  useRoute,
} from './lib/router';

// ============================================================
// PAGE COMPONENTS
// ============================================================

// Home
import { Home } from './pages/Home';

// Catalog and Product Details
import { Catalog } from './pages/Catalog';
import { ProductDetail } from './pages/ProductDetail';

// Authentication
import {
  Login,
  Register,
  VerifyEmail,
  ForgotPassword,
} from './pages/Auth';

// Cart and Checkout
import {
  CartPage,
  Checkout,
} from './pages/CartCheckout';

// Orders and Payments
import {
  Orders,
  OrderDetail,
  PaymentResult,
} from './pages/Orders';

// Wishlist and Comparison
import {
  WishlistPage,
  SharedWishlist,
  Compare,
} from './pages/WishlistCompare';

// PC Builder
import { PCBuilder } from './pages/PCBuilder';

// Account Management
import {
  Account,
  AddressPage,
  ChangePassword,
} from './pages/Account';

// ============================================================
// PROTECTED ROUTE COMPONENT
// ============================================================

function Protected({
  children,
}: {
  children: ReactNode;
}) {
  // ----------------------------------------------------------
  // AUTHENTICATION AND ROUTING
  // ----------------------------------------------------------

  const auth = useAuth();
  const route = useRoute();

  // ----------------------------------------------------------
  // REDIRECT UNAUTHENTICATED USERS
  // ----------------------------------------------------------

  useEffect(() => {
    if (auth.ready && !auth.user) {
      navigate(
        `/login?next=${encodeURIComponent(
          route.pathname + route.search
        )}`,
        true
      );
    }
  }, [
    auth.ready,
    auth.user,
    route.pathname,
    route.search,
  ]);

  // ----------------------------------------------------------
  // SESSION LOADING STATE
  // ----------------------------------------------------------

  if (!auth.ready) {
    return (
      <Spinner label="Restoring your session..." />
    );
  }

  // ----------------------------------------------------------
  // UNAUTHENTICATED STATE
  // ----------------------------------------------------------

  if (!auth.user) {
    return (
      <Spinner label="Redirecting to sign in..." />
    );
  }

  // ----------------------------------------------------------
  // AUTHENTICATED CONTENT
  // ----------------------------------------------------------

  return <>{children}</>;
}

// ============================================================
// APPLICATION ROUTES
// ============================================================

function AppRoutes() {
  // ----------------------------------------------------------
  // CURRENT ROUTE
  // ----------------------------------------------------------

  const route = useRoute();

  // Remove trailing slash (except for root path)
  const path =
    route.pathname.replace(/\/$/, '') || '/';

  let page: ReactNode;

  // ==========================================================
  // ROUTE MATCHING
  // ==========================================================

  switch (true) {

    // --------------------------------------------------------
    // HOME
    // --------------------------------------------------------

    case path === '/':
      page = <Home />;
      break;

    // --------------------------------------------------------
    // CATALOG
    // --------------------------------------------------------

    case path === '/catalog':
      page = <Catalog />;
      break;

    // --------------------------------------------------------
    // PRODUCT DETAILS
    // --------------------------------------------------------

    case path.startsWith('/product/'):
      page = <ProductDetail />;
      break;

    // --------------------------------------------------------
    // AUTHENTICATION
    // --------------------------------------------------------

    case path === '/login':
      page = <Login />;
      break;

    case path === '/register':
      page = <Register />;
      break;

    case path === '/verify-email':
      page = <VerifyEmail />;
      break;

    case path === '/forgot-password':
      page = <ForgotPassword />;
      break;

    // --------------------------------------------------------
    // CART
    // --------------------------------------------------------

    case path === '/cart':
      page = (
        <Protected>
          <CartPage />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // CHECKOUT
    // --------------------------------------------------------

    case path === '/checkout':
      page = (
        <Protected>
          <Checkout />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // ORDERS
    // --------------------------------------------------------

    case path === '/orders':
      page = (
        <Protected>
          <Orders />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // ORDER DETAILS
    // --------------------------------------------------------

    case /^\/orders\/\d+$/.test(path):
      page = (
        <Protected>
          <OrderDetail />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // PAYMENT RESULT
    // --------------------------------------------------------

    case path === '/payment-result':
      page = (
        <Protected>
          <PaymentResult />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // WISHLIST
    // --------------------------------------------------------

    case path === '/wishlist':
      page = (
        <Protected>
          <WishlistPage />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // SHARED WISHLIST (PUBLIC)
    // --------------------------------------------------------

    case path.startsWith('/wishlist/shared/'):
      page = <SharedWishlist />;
      break;

    // --------------------------------------------------------
    // PRODUCT COMPARISON
    // --------------------------------------------------------

    case path === '/compare':
      page = <Compare />;
      break;

    // --------------------------------------------------------
    // PC BUILDER
    // --------------------------------------------------------

    case path === '/pc-builder':
      page = (
        <Protected>
          <PCBuilder />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // ACCOUNT DASHBOARD
    // --------------------------------------------------------

    case path === '/account':
      page = (
        <Protected>
          <Account />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // ACCOUNT ADDRESSES
    // --------------------------------------------------------

    case path === '/account/address':
      page = (
        <Protected>
          <AddressPage />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // CHANGE PASSWORD
    // --------------------------------------------------------

    case path === '/account/password':
      page = (
        <Protected>
          <ChangePassword />
        </Protected>
      );
      break;

    // --------------------------------------------------------
    // 404 - PAGE NOT FOUND
    // --------------------------------------------------------

    default:
      page = (
        <div className="container-wide page-space">
          <Empty
            icon="search"
            title="Page not found"
            description="The page you're looking for doesn't exist."
            action={
              <Link
                to="/"
                className="btn btn-primary"
              >
                Back to home
              </Link>
            }
          />
        </div>
      );
      break;
  }

  // ==========================================================
  // RENDER PAGE INSIDE MAIN LAYOUT
  // ==========================================================

  return (
    <Layout>
      {page}
    </Layout>
  );
}

// ============================================================
// ROOT APPLICATION COMPONENT
// ============================================================

export default function App() {
  return (
    <StoreProviders>
      <AppRoutes />
    </StoreProviders>
  );
}