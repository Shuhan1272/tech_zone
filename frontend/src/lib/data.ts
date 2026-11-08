import { useEffect, useState } from 'react';

import { api, endpoints } from './api';
import type { Category, Brand, ProductImage } from './types';
import { asList, errorMessage } from './utils';

// ============================================================
// GENERIC DATA FETCHING HOOK
// ============================================================

export function useData<T>(
  key: string,
  load: () => Promise<T>,
  initial: T
) {
  const [data, setData] = useState<T>(initial);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [version, setVersion] = useState(0);

  useEffect(() => {
    let active = true;

    setLoading(true);
    setError('');

    load()
      .then((value) => {
        if (active) {
          setData(value);
        }
      })
      .catch((error) => {
        if (active) {
          setError(errorMessage(error));
        }
      })
      .finally(() => {
        if (active) {
          setLoading(false);
        }
      });

    // Cleanup to prevent state updates after unmounting
    return () => {
      active = false;
    };
  }, [key, version]);

  // Manually trigger data reloading
  const refresh = () => {
    setVersion((previous) => previous + 1);
  };

  return {
    data,
    loading,
    error,
    refresh,
    setData,
  };
}

// ============================================================
// CATEGORY DATA CACHE
// ============================================================

let categoryCache: Category[] | null = null;

let categoryPromise: Promise<Category[]> | null = null;

// ============================================================
// FETCH CATEGORIES
// ============================================================

export async function getCategories(): Promise<Category[]> {
  // Return cached categories if available
  if (categoryCache) {
    return categoryCache;
  }

  // Prevent duplicate API requests
  if (!categoryPromise) {
    categoryPromise = api<unknown>(endpoints.categories)
      .then((response) => {
        categoryCache = asList<Category>(response);

        return categoryCache;
      })
      .finally(() => {
        categoryPromise = null;
      });
  }

  return categoryPromise;
}

// ============================================================
// BRAND DATA CACHE
// ============================================================

let brandCache: Brand[] | null = null;

let brandPromise: Promise<Brand[]> | null = null;

// ============================================================
// FETCH BRANDS
// ============================================================

export async function getBrands(): Promise<Brand[]> {
  // Return cached brands if available
  if (brandCache) {
    return brandCache;
  }

  // Prevent duplicate API requests
  if (!brandPromise) {
    brandPromise = api<unknown>(endpoints.brands)
      .then((response) => {
        brandCache = asList<Brand>(response);

        return brandCache;
      })
      .finally(() => {
        brandPromise = null;
      });
  }

  return brandPromise;
}

// ============================================================
// PRODUCT IMAGE DATA CACHE
// ============================================================

let imageCache: ProductImage[] | null = null;

let imagePromise: Promise<ProductImage[]> | null = null;

// ============================================================
// FETCH PRODUCT IMAGES
// ============================================================

export async function getProductImages(): Promise<ProductImage[]> {
  // Return cached images if available
  if (imageCache) {
    return imageCache;
  }

  // Prevent duplicate API requests
  if (!imagePromise) {
    imagePromise = api<unknown>(endpoints.images)
      .then((response) => {
        imageCache = asList<ProductImage>(response);

        return imageCache;
      })
      .finally(() => {
        imagePromise = null;
      });
  }

  return imagePromise;
}

// ============================================================
// GET PRODUCT IMAGE
// ============================================================

/**
 * Returns the preferred image for a product.
 *
 * Priority:
 * 1. Primary image
 * 2. Lowest display order
 *
 * Returns undefined if no matching image exists.
 */

export function productImage(
  images: ProductImage[],
  id: number
) {
  return images
    .filter((image) => image.product === id)
    .sort(
      (a, b) =>
        Number(Boolean(b.is_primary)) -
          Number(Boolean(a.is_primary)) ||
        (a.display_order ?? 0) -
          (b.display_order ?? 0)
    )[0]?.image;
}

// ============================================================
// FLATTEN NESTED CATEGORIES
// ============================================================

/**
 * Converts nested categories into a flat array.
 *
 * Example:
 *
 * Electronics
 *   - Mobile
 *   - Laptop
 *       - Gaming Laptop
 *
 * Result:
 *
 * [
 *   Electronics,
 *   Mobile,
 *   Laptop,
 *   Gaming Laptop
 * ]
 */

export function flattenCategories(
  categories: Category[]
): Category[] {
  return categories.flatMap((category) => [
    category,
    ...flattenCategories(category.sub_categories ?? []),
  ]);
}