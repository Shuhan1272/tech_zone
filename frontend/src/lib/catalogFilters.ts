/**
 * ============================================================
 * CATALOG FILTER UTILITIES
 * ============================================================
 *
 * Handles URL-based product catalog filtering.
 *
 * Supports:
 * - Product availability
 * - Pagination
 * - Product ordering
 * - Featured products
 * - Brand filtering (comma-separated values)
 * - Specification filtering (repeated query parameters)
 *
 * Compatible with the Django ProductFilter implementation.
 * ============================================================
 */

// ============================================================
// BUILD CATALOG API PARAMETERS
// ============================================================

export function catalogApiParams(
  search: string
): URLSearchParams {
  const current = new URLSearchParams(search);
  const next = new URLSearchParams();

  // Default product filters
  next.set('is_active', 'true');

  next.set(
    'limit',
    current.get('limit') || '20'
  );

  next.set(
    'ordering',
    current.get('ordering') || '-created_at'
  );

  // Featured products
  if (current.get('featured') === 'true') {
    next.set('is_featured', 'true');
  }

  // Parameters already handled above
  const excludedKeys = [
    'is_active',
    'limit',
    'ordering',
    'featured',
  ];

  // Preserve remaining query parameters
  for (const [key, value] of current.entries()) {
    if (excludedKeys.includes(key)) {
      continue;
    }

    next.append(key, value);
  }

  return next;
}

// ============================================================
// TOGGLE COMMA-SEPARATED FILTER VALUES
// ============================================================

/**
 * Adds or removes a value from a comma-separated filter.
 *
 * Example:
 *
 * brand=Samsung,Apple
 *
 * Toggle Samsung:
 * brand=Apple
 *
 * Toggle Xiaomi:
 * brand=Samsung,Apple,Xiaomi
 */

export function toggledCsv(
  search: string,
  key: string,
  value: string
): URLSearchParams {
  const next = new URLSearchParams(search);

  // Get currently selected values
  const oldValues = (next.get(key) || '')
    .split(',')
    .filter(Boolean);

  // Add or remove selected value
  const selectedValues = oldValues.includes(value)
    ? oldValues.filter((item) => item !== value)
    : [...oldValues, value];

  // Remove previous filter
  next.delete(key);

  // Apply updated filter values
  if (selectedValues.length > 0) {
    next.set(
      key,
      selectedValues.join(',')
    );
  }

  // Reset pagination after filter changes
  next.delete('page');

  return next;
}

// ============================================================
// TOGGLE SPECIFICATION FILTER VALUES
// ============================================================

/**
 * Adds or removes specification filter values.
 *
 * Supports repeated query parameters.
 *
 * Example:
 *
 * ram=8GB&ram=16GB
 *
 * Toggle 8GB:
 * ram=16GB
 *
 * Toggle 32GB:
 * ram=8GB&ram=16GB&ram=32GB
 *
 * Also supports comma-separated input values.
 */

export function toggledSpec(
  search: string,
  key: string,
  value: string
): URLSearchParams {
  const next = new URLSearchParams(search);

  // Get all existing specification values
  const oldValues = next
    .getAll(key)
    .flatMap((item) => item.split(','))
    .filter(Boolean);

  // Add or remove selected specification
  const selectedValues = oldValues.includes(value)
    ? oldValues.filter((item) => item !== value)
    : [...oldValues, value];

  // Remove existing specification parameters
  next.delete(key);

  // Add updated specification parameters
  selectedValues.forEach((item) => {
    next.append(key, item);
  });

  // Reset pagination after filter changes
  next.delete('page');

  return next;
}