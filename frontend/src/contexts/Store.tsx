import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { api, endpoints, tokens } from '../lib/api';
import type { Cart, User, Wishlist } from '../lib/types';
import { errorMessage } from '../lib/utils';

// ============================================================
// TYPES
// ============================================================

type AuthContextValue = {
  user: User | null;
  ready: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  reload: () => Promise<void>;
  acceptTokens: (access: string, refresh: string) => Promise<void>;
};

type Toast = {
  id: number;
  message: string;
  type: 'success' | 'error' | 'info';
};

type ToastValue = {
  toast: (message: string, type?: Toast['type']) => void;
};

type CartValue = {
  cart: Cart | null;
  loading: boolean;
  count: number;
  subtotal: number;
  reload: () => Promise<void>;
  add: (variant: number, quantity?: number) => Promise<void>;
  change: (item: number, quantity: number) => Promise<void>;
  remove: (item: number) => Promise<void>;
};

type WishlistValue = {
  wishlist: Wishlist | null;
  reload: () => Promise<void>;
  toggle: (variant: number) => Promise<void>;
  remove: (id: number) => Promise<void>;
};

type CompareValue = {
  ids: number[];
  toggle: (id: number) => void;
  clear: () => void;
};

// ============================================================
// AUTH CONTEXT
// ============================================================

const AuthContext = createContext<AuthContextValue | null>(null);

export const useAuth = () => {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error('Auth provider missing');
  }

  return context;
};

// ============================================================
// TOAST CONTEXT
// ============================================================

const ToastContext = createContext<ToastValue | null>(null);

export const useToast = () => {
  const context = useContext(ToastContext);

  if (!context) {
    throw new Error('Toast provider missing');
  }

  return context.toast;
};

// ============================================================
// TOAST PROVIDER
// ============================================================

export function ToastProvider({
  children,
}: {
  children: ReactNode;
}) {
  const [items, setItems] = useState<Toast[]>([]);

  const toast = useCallback(
    (
      message: string,
      type: Toast['type'] = 'info'
    ) => {
      const id = Date.now() + Math.random();

      setItems((previous) =>
        [
          ...previous,
          {
            id,
            message,
            type,
          },
        ].slice(-4)
      );

      window.setTimeout(() => {
        setItems((previous) =>
          previous.filter((item) => item.id !== id)
        );
      }, 5200);
    },
    []
  );

  const dismissToast = (id: number) => {
    setItems((previous) =>
      previous.filter((item) => item.id !== id)
    );
  };

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}

      <div
        className="toast-stack"
        role="status"
        aria-live="polite"
      >
        {items.map((item) => (
          <div
            key={item.id}
            className={`toast toast-${item.type}`}
          >
            <span className="toast-dot" />

            {item.message}

            <button
              type="button"
              aria-label="Dismiss notification"
              onClick={() => dismissToast(item.id)}
            >
              ×
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

// ============================================================
// AUTH PROVIDER
// ============================================================

export function AuthProvider({
  children,
}: {
  children: ReactNode;
}) {
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);

  // ----------------------------------------------------------
  // Reload authenticated user
  // ----------------------------------------------------------

  const reload = useCallback(async () => {
    const accessToken = tokens.getAccess();
    const refreshToken = tokens.getRefresh();

    if (!accessToken && !refreshToken) {
      setUser(null);
      setReady(true);
      return;
    }

    try {
      const profile = await api<User>(
        '/api/v1/accounts/me/'
      );

      setUser(profile);
    } catch {
      setUser(null);
    } finally {
      setReady(true);
    }
  }, []);

  // ----------------------------------------------------------
  // Initialize authentication
  // ----------------------------------------------------------

  useEffect(() => {
    void reload();

    const handleAuthExpired = () => {
      setUser(null);
      setReady(true);
    };

    window.addEventListener(
      'techzone:auth-expired',
      handleAuthExpired
    );

    return () => {
      window.removeEventListener(
        'techzone:auth-expired',
        handleAuthExpired
      );
    };
  }, [reload]);

  // ----------------------------------------------------------
  // Accept access and refresh tokens
  // ----------------------------------------------------------

  const acceptTokens = useCallback(
    async (
      access: string,
      refresh: string
    ) => {
      tokens.save(access, refresh);

      try {
        const profile = await api<User>(
          '/api/v1/accounts/me/'
        );

        setUser(profile);
        setReady(true);
      } catch (error) {
        tokens.clear();
        setUser(null);

        throw error;
      }
    },
    []
  );

  // ----------------------------------------------------------
  // Login
  // ----------------------------------------------------------

  const login = useCallback(
    async (
      email: string,
      password: string
    ) => {
      const pair = await api<{
        access: string;
        refresh: string;
      }>('/api/v1/accounts/token/', {
        method: 'POST',
        auth: false,
        body: {
          email: email.trim(),
          password,
        },
      });

      await acceptTokens(
        pair.access,
        pair.refresh
      );
    },
    [acceptTokens]
  );

  // ----------------------------------------------------------
  // Logout
  // ----------------------------------------------------------

  const logout = useCallback(() => {
    tokens.clear();
    setUser(null);
  }, []);

  // ----------------------------------------------------------
  // Context value
  // ----------------------------------------------------------

  const value: AuthContextValue = {
    user,
    ready,
    login,
    logout,
    reload,
    acceptTokens,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

// ============================================================
// CART CONTEXT
// ============================================================

const CartContext = createContext<CartValue | null>(null);

export const useCart = () => {
  const context = useContext(CartContext);

  if (!context) {
    throw new Error('Cart provider missing');
  }

  return context;
};

// ============================================================
// CART PROVIDER
// ============================================================

export function CartProvider({
  children,
}: {
  children: ReactNode;
}) {
  const { user, ready } = useAuth();
  const toast = useToast();

  const [cart, setCart] = useState<Cart | null>(null);
  const [loading, setLoading] = useState(false);

  // ----------------------------------------------------------
  // Reload cart
  // ----------------------------------------------------------

  const reload = useCallback(async () => {
    if (!user) {
      setCart(null);
      return;
    }

    setLoading(true);

    try {
      const cartData = await api<Cart>(
        endpoints.cart
      );

      setCart(cartData);
    } catch (error) {
      toast(errorMessage(error), 'error');
    } finally {
      setLoading(false);
    }
  }, [user, toast]);

  // ----------------------------------------------------------
  // Load cart after authentication
  // ----------------------------------------------------------

  useEffect(() => {
    if (ready) {
      void reload();
    }
  }, [ready, reload]);

  // ----------------------------------------------------------
  // Add product variant to cart
  // ----------------------------------------------------------

  const add = useCallback(
    async (
      variant: number,
      quantity = 1
    ) => {
      await api(endpoints.cartItems, {
        method: 'POST',
        body: {
          variant,
          quantity,
        },
      });

      await reload();

      toast('Added to your cart', 'success');
    },
    [reload, toast]
  );

  // ----------------------------------------------------------
  // Update cart item quantity
  // ----------------------------------------------------------

  const change = useCallback(
    async (
      id: number,
      quantity: number
    ) => {
      await api(
        `${endpoints.cartItems}${id}/`,
        {
          method: 'PATCH',
          body: {
            quantity,
          },
        }
      );

      await reload();
    },
    [reload]
  );

  // ----------------------------------------------------------
  // Remove cart item
  // ----------------------------------------------------------

  const remove = useCallback(
    async (id: number) => {
      await api(
        `${endpoints.cartItems}${id}/`,
        {
          method: 'DELETE',
        }
      );

      await reload();

      toast('Item removed', 'info');
    },
    [reload, toast]
  );

  // ----------------------------------------------------------
  // Cart calculations
  // ----------------------------------------------------------

  const count =
    cart?.items.reduce(
      (total, item) =>
        total + item.quantity,
      0
    ) ?? 0;

  const subtotal =
    cart?.items.reduce(
      (total, item) =>
        total +
        Number(item.discounted_price) *
          item.quantity,
      0
    ) ?? 0;

  // ----------------------------------------------------------
  // Context value
  // ----------------------------------------------------------

  const value: CartValue = {
    cart,
    loading,
    count,
    subtotal,
    reload,
    add,
    change,
    remove,
  };

  return (
    <CartContext.Provider value={value}>
      {children}
    </CartContext.Provider>
  );
}

// ============================================================
// WISHLIST CONTEXT
// ============================================================

const WishlistContext = createContext<WishlistValue | null>(
  null
);

export const useWishlist = () => {
  const context = useContext(WishlistContext);

  if (!context) {
    throw new Error('Wishlist provider missing');
  }

  return context;
};

// ============================================================
// WISHLIST PROVIDER
// ============================================================

export function WishlistProvider({
  children,
}: {
  children: ReactNode;
}) {
  const { user, ready } = useAuth();
  const toast = useToast();

  const [wishlist, setWishlist] =
    useState<Wishlist | null>(null);

  // ----------------------------------------------------------
  // Reload wishlist
  // ----------------------------------------------------------

  const reload = useCallback(async () => {
    if (!user) {
      setWishlist(null);
      return;
    }

    try {
      const wishlistData = await api<Wishlist>(
        endpoints.wishlist
      );

      setWishlist(wishlistData);
    } catch (error) {
      toast(errorMessage(error), 'error');
    }
  }, [user, toast]);

  // ----------------------------------------------------------
  // Load wishlist after authentication
  // ----------------------------------------------------------

  useEffect(() => {
    if (ready) {
      void reload();
    }
  }, [ready, reload]);

  // ----------------------------------------------------------
  // Remove wishlist item
  // ----------------------------------------------------------

  const remove = useCallback(
    async (id: number) => {
      await api(
        `${endpoints.wishlistItems}${id}/`,
        {
          method: 'DELETE',
        }
      );

      await reload();
    },
    [reload]
  );

  // ----------------------------------------------------------
  // Toggle wishlist product
  // ----------------------------------------------------------

  const toggle = useCallback(
    async (variant: number) => {
      const existing = wishlist?.items.find(
        (item) =>
          item.variant_id === variant
      );

      if (existing) {
        await remove(existing.id);

        toast(
          'Removed from wishlist',
          'info'
        );
      } else {
        await api(endpoints.wishlistItems, {
          method: 'POST',
          body: {
            variant_id: variant,
          },
        });

        await reload();

        toast(
          'Saved to wishlist',
          'success'
        );
      }
    },
    [wishlist, remove, reload, toast]
  );

  // ----------------------------------------------------------
  // Context value
  // ----------------------------------------------------------

  const value: WishlistValue = {
    wishlist,
    reload,
    toggle,
    remove,
  };

  return (
    <WishlistContext.Provider value={value}>
      {children}
    </WishlistContext.Provider>
  );
}

// ============================================================
// COMPARE CONTEXT
// ============================================================

const CompareContext = createContext<CompareValue | null>(
  null
);

export const useCompare = () => {
  const context = useContext(CompareContext);

  if (!context) {
    throw new Error('Compare provider missing');
  }

  return context;
};

// ============================================================
// COMPARE PROVIDER
// ============================================================

export function CompareProvider({
  children,
}: {
  children: ReactNode;
}) {
  const toast = useToast();

  // ----------------------------------------------------------
  // Load saved comparison products
  // ----------------------------------------------------------

  const [ids, setIds] = useState<number[]>(() => {
    try {
      const stored = localStorage.getItem(
        'techzone_compare'
      );

      const parsed: unknown = JSON.parse(
        stored || '[]'
      );

      if (Array.isArray(parsed)) {
        return parsed
          .filter(
            (id): id is number =>
              typeof id === 'number'
          )
          .slice(0, 4);
      }

      return [];
    } catch {
      return [];
    }
  });

  // ----------------------------------------------------------
  // Save comparison products
  // ----------------------------------------------------------

  useEffect(() => {
    localStorage.setItem(
      'techzone_compare',
      JSON.stringify(ids)
    );
  }, [ids]);

  // ----------------------------------------------------------
  // Toggle product comparison
  // ----------------------------------------------------------

  const toggle = useCallback(
    (id: number) => {
      setIds((previous) => {
        // Remove product if already selected
        if (previous.includes(id)) {
          return previous.filter(
            (item) => item !== id
          );
        }

        // Maximum four products
        if (previous.length >= 4) {
          toast(
            'Compare up to four products',
            'info'
          );

          return previous;
        }

        // Add product
        return [...previous, id];
      });
    },
    [toast]
  );

  // ----------------------------------------------------------
  // Clear comparison list
  // ----------------------------------------------------------

  const clear = useCallback(() => {
    setIds([]);
  }, []);

  // ----------------------------------------------------------
  // Memoized context value
  // ----------------------------------------------------------

  const value = useMemo<CompareValue>(
    () => ({
      ids,
      toggle,
      clear,
    }),
    [ids, toggle, clear]
  );

  return (
    <CompareContext.Provider value={value}>
      {children}
    </CompareContext.Provider>
  );
}

// ============================================================
// ROOT STORE PROVIDERS
// ============================================================

export function StoreProviders({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <ToastProvider>
      <AuthProvider>
        <CartProvider>
          <WishlistProvider>
            <CompareProvider>
              {children}
            </CompareProvider>
          </WishlistProvider>
        </CartProvider>
      </AuthProvider>
    </ToastProvider>
  );
}