import {
  useEffect,
  useState,
  type AnchorHTMLAttributes,
  type MouseEvent,
} from 'react';

// ============================================================
// TYPES
// ============================================================

export type RouteLocation = {
  pathname: string;
  search: string;
  hash: string;
};

// ============================================================
// GET CURRENT LOCATION
// ============================================================

const getLocation = (): RouteLocation => ({
  pathname: window.location.pathname,
  search: window.location.search,
  hash: window.location.hash,
});

// ============================================================
// NAVIGATION
// ============================================================

/**
 * Navigate to an internal application route.
 *
 * Supports:
 * - Push navigation
 * - Replace navigation
 * - Custom navigation events
 * - Automatic scroll to top
 */

export function navigate(
  to: string,
  replace = false
) {
  // Prevent external and protocol-relative navigation
  if (!to.startsWith('/') || to.startsWith('//')) {
    return;
  }

  // Update browser history
  window.history[
    replace ? 'replaceState' : 'pushState'
  ]({}, '', to);

  // Notify route listeners
  window.dispatchEvent(
    new Event('techzone:navigate')
  );

  // Scroll to the top of the page
  window.scrollTo({
    top: 0,
    behavior: 'auto',
  });
}

// ============================================================
// ROUTE HOOK
// ============================================================

/**
 * Tracks the current browser location.
 *
 * Updates when:
 * - Browser back/forward buttons are used
 * - Internal application navigation occurs
 */

export function useRoute(): RouteLocation {
  const [location, setLocation] =
    useState<RouteLocation>(getLocation);

  useEffect(() => {
    // Update current route
    const update = () => {
      setLocation(getLocation());
    };

    // Listen for browser navigation
    window.addEventListener('popstate', update);

    // Listen for custom application navigation
    window.addEventListener(
      'techzone:navigate',
      update
    );

    // Remove listeners on unmount
    return () => {
      window.removeEventListener(
        'popstate',
        update
      );

      window.removeEventListener(
        'techzone:navigate',
        update
      );
    };
  }, []);

  return location;
}

// ============================================================
// CUSTOM LINK COMPONENT
// ============================================================

/**
 * Custom Link component for client-side navigation.
 *
 * Features:
 * - Prevents unnecessary page reloads
 * - Supports normal browser link behavior
 * - Supports Ctrl/Cmd + Click
 * - Supports opening links in a new tab
 * - Preserves standard anchor attributes
 */

export function Link({
  to,
  children,
  onClick,
  ...rest
}: Omit<
  AnchorHTMLAttributes<HTMLAnchorElement>,
  'href'
> & {
  to: string;
}) {
  // Handle link clicks
  const click = (
    event: MouseEvent<HTMLAnchorElement>
  ) => {
    // Execute custom click handler
    onClick?.(event);

    // Preserve default browser behavior
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey ||
      rest.target === '_blank'
    ) {
      return;
    }

    // Prevent full page reload
    event.preventDefault();

    // Navigate internally
    navigate(to);
  };

  return (
    <a
      href={to}
      onClick={click}
      {...rest}
    >
      {children}
    </a>
  );
}

// ============================================================
// FLUTTER HASH ROUTE MIGRATION
// ============================================================

/**
 * Converts legacy Flutter hash-based routes
 * into standard browser routes.
 *
 * Example:
 *
 * Before:
 * https://example.com/#/products
 *
 * After:
 * https://example.com/products
 */

export function migrateFlutterHash() {
  // Check for Flutter-style hash routes
  if (
    window.location.hash.startsWith('#/')
  ) {
    const target = window.location.hash.slice(1);

    // Validate internal route
    if (
      target.startsWith('/') &&
      !target.startsWith('//')
    ) {
      // Replace URL without reloading the page
      window.history.replaceState(
        {},
        '',
        target
      );
    }
  }
}