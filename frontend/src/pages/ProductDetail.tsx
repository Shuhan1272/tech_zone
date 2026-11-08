
import {
  useEffect,
  useState,
  type FormEvent,
  type MouseEvent,
  type WheelEvent,
} from 'react';

import {
  useAuth,
  useCart,
  useCompare,
  useToast,
  useWishlist,
} from '../contexts/Store';

import { api, endpoints, withQuery } from '../lib/api';
import { getProductImages, useData } from '../lib/data';
import { navigate, useRoute, Link } from '../lib/router';

import type {
  Page,
  Product,
  ProductImage,
  ProductQuestion,
  ProductReview,
  Variant,
} from '../lib/types';

import {
  absoluteMedia,
  money,
  number,
  valueText,
  variantOf,
} from '../lib/utils';

import {
  Breadcrumbs,
  Button,
  Empty,
  Icon,
  Notice,
  ProductVisual,
  Spinner,
} from '../components/UI';

import './ProductDetail.css';

// =========================================================
// LOCAL TYPES
// No changes to src/lib/types.ts are required.
// =========================================================

type DetailColor = {
  id: number;
  name: string;
  hex_code?: string;
};

type DetailVariant = Variant & {
  ram?: string | null;
  storage?: string | null;
  color?: DetailColor | string | null;
};

type Tab =
  | 'specification'
  | 'description'
  | 'questions'
  | 'reviews';

type ZoomPosition = {
  x: number;
  y: number;
};

// =========================================================
// HELPERS
// =========================================================

function results<T>(value: Page<T> | T[]): T[] {
  return Array.isArray(value) ? value : value.results;
}

function dateLabel(value: string): string {
  return new Date(value).toLocaleDateString('en-BD', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function optionValue(
  variant: DetailVariant,
  name: string
): string {
  const field = name.toLowerCase();

  if (field === 'ram') {
    const value = variant.ram;
    if (value != null && String(value).trim()) {
      return String(value).trim();
    }
  }

  if (field === 'storage') {
    const value = variant.storage;
    if (value != null && String(value).trim()) {
      return String(value).trim();
    }
  }

  if (field === 'color') {
    const color = variant.color;

    if (typeof color === 'string' && color.trim()) {
      return color.trim();
    }

    if (
      color &&
      typeof color === 'object' &&
      color.name
    ) {
      return color.name.trim();
    }
  }

  // Backward compatibility with older variant data.
  const entry = Object.entries(variant.options ?? {})
    .find(
      ([key]) => key.toLowerCase() === field
    );

  return entry && entry[1] != null
    ? String(entry[1]).trim()
    : '';
}

function colorHex(
  variant: DetailVariant | undefined
): string {
  if (!variant) return '#e5e7eb';

  const color = variant.color;

  if (
    color &&
    typeof color === 'object' &&
    color.hex_code
  ) {
    return color.hex_code;
  }

  return '#e5e7eb';
}

function configurationKey(
  variant: DetailVariant
): string {
  const ram = optionValue(variant, 'RAM');
  const storage = optionValue(variant, 'Storage');

  if (ram || storage) {
    return JSON.stringify({ ram, storage });
  }

  const legacy = Object.entries(variant.options ?? {})
    .filter(
      ([key]) => key.toLowerCase() !== 'color'
    )
    .sort(([a], [b]) => a.localeCompare(b));

  return JSON.stringify(legacy);
}

function configurationLabel(
  variant: DetailVariant
): string {
  const ram = optionValue(variant, 'RAM');
  const storage = optionValue(variant, 'Storage');

  const parts: string[] = [];

  if (ram) parts.push(`RAM: ${ram}`);
  if (storage) parts.push(`Storage: ${storage}`);

  if (parts.length > 0) {
    return parts.join(' / ');
  }

  return (
    Object.entries(variant.options ?? {})
      .filter(
        ([key, value]) =>
          key.toLowerCase() !== 'color' &&
          value != null &&
          String(value).trim() !== ''
      )
      .map(
        ([key, value]) =>
          `${key}: ${valueText(value)}`
      )
      .join(' / ') || 'Standard configuration'
  );
}

// =========================================================
// STAR RATING
// =========================================================

function Stars({
  rating,
  onChange,
}: {
  rating: number;
  onChange?: (value: number) => void;
}) {
  return (
    <span
      className="pd-stars"
      aria-label={`${rating} out of 5 stars`}
    >
      {[1, 2, 3, 4, 5].map((n) =>
        onChange ? (
          <button
            type="button"
            key={n}
            className={n <= rating ? 'filled' : ''}
            aria-label={`${n} stars`}
            onClick={() => onChange(n)}
          >
            ★
          </button>
        ) : (
          <span
            key={n}
            className={
              n <= Math.round(rating) ? 'filled' : ''
            }
          >
            ★
          </span>
        )
      )}
    </span>
  );
}

// =========================================================
// PRODUCT DETAIL
// =========================================================

export function ProductDetail() {
  const route = useRoute();

  const slug = decodeURIComponent(
    route.pathname.split('/')[2] || ''
  );

  // =======================================================
  // PRODUCT DATA
  // =======================================================

  const {
    data: product,
    loading,
    error,
  } = useData(
    `product:${slug}`,
    () =>
      api<Product>(
        `${endpoints.products}${encodeURIComponent(slug)}/`
      ),
    null as Product | null
  );

  const { user } = useAuth();
  const cart = useCart();
  const wishlist = useWishlist();
  const compare = useCompare();
  const toast = useToast();

  // =======================================================
  // STATE
  // =======================================================

  const [images, setImages] = useState<ProductImage[]>([]);

  const [selectedId, setSelectedId] = useState<
    number | null
  >(null);

  const [activeImage, setActiveImage] = useState(0);
  const [qty, setQty] = useState(1);
  const [busy, setBusy] = useState(false);

  const [zoomOpen, setZoomOpen] = useState(false);
  const [zoomScale, setZoomScale] = useState(1);

  const [zoomPosition, setZoomPosition] =
    useState<ZoomPosition>({
      x: 50,
      y: 50,
    });

  const [shareOpen, setShareOpen] = useState(false);

  const [tab, setTab] =
    useState<Tab>('specification');

  const [questions, setQuestions] =
    useState<ProductQuestion[]>([]);

  const [reviews, setReviews] =
    useState<ProductReview[]>([]);

  const [questionsLoading, setQuestionsLoading] =
    useState(false);

  const [reviewsLoading, setReviewsLoading] =
    useState(false);

  const [questionsError, setQuestionsError] =
    useState('');

  const [reviewsError, setReviewsError] =
    useState('');

  const [questionText, setQuestionText] =
    useState('');

  const [reviewText, setReviewText] =
    useState('');

  const [rating, setRating] = useState(5);

  const [questionForm, setQuestionForm] =
    useState(false);

  const [reviewForm, setReviewForm] =
    useState(false);

  const [submitting, setSubmitting] =
    useState(false);

  // =======================================================
  // LOAD PRODUCT IMAGES
  // =======================================================

  useEffect(() => {
    let alive = true;

    getProductImages()
      .then((value) => {
        if (alive) {
          setImages(value);
        }
      })
      .catch(() => {
        if (alive) {
          setImages([]);
        }
      });

    return () => {
      alive = false;
    };
  }, []);

  // =======================================================
  // RESET WHEN PRODUCT CHANGES
  // =======================================================

  useEffect(() => {
    setSelectedId(null);
    setActiveImage(0);
    setQty(1);

    setTab('specification');

    setZoomOpen(false);
    setZoomScale(1);
    setZoomPosition({ x: 50, y: 50 });

    setShareOpen(false);

    setQuestionForm(false);
    setReviewForm(false);

    setQuestions([]);
    setReviews([]);

    setQuestionText('');
    setReviewText('');
    setRating(5);
  }, [slug]);

  // =======================================================
  // LOAD QUESTIONS AND REVIEWS
  // =======================================================

  useEffect(() => {
    if (!product?.id) return;

    let alive = true;
    const id = product.id;

    const load = async <T,>(
      path: string,
      set: (data: T[]) => void,
      setLoading: (value: boolean) => void,
      setError: (value: string) => void
    ) => {
      setLoading(true);
      setError('');

      try {
        let url: string | null = withQuery(path, {
          product: id,
        });

        const all: T[] = [];
        let pageCount = 0;

        while (url && pageCount < 100) {
          const response: Page<T> | T[] =
            await api<Page<T> | T[]>(url, {
              auth: false,
            });

          all.push(...results(response));

          url = Array.isArray(response)
            ? null
            : response.next;

          pageCount++;
        }

        if (alive) {
          set(all);
        }
      } catch (e) {
        if (alive) {
          setError(
            e instanceof Error
              ? e.message
              : 'Could not load data'
          );
        }
      } finally {
        if (alive) {
          setLoading(false);
        }
      }
    };

    void load<ProductQuestion>(
      endpoints.questions,
      (data) =>
        setQuestions(
          data.filter(
            (q) =>
              q.product === id &&
              q.is_approved === true
          )
        ),
      setQuestionsLoading,
      setQuestionsError
    );

    void load<ProductReview>(
      endpoints.reviews,
      (data) =>
        setReviews(
          data.filter(
            (r) =>
              r.product === id &&
              r.is_approved === true
          )
        ),
      setReviewsLoading,
      setReviewsError
    );

    return () => {
      alive = false;
    };
  }, [product?.id]);

  // =======================================================
  // IMAGE GALLERY
  // =======================================================

  const imageList = images
    .filter((im) => im.product === product?.id)
    .sort(
      (a, b) =>
        Number(Boolean(b.is_primary)) -
          Number(Boolean(a.is_primary)) ||
        (a.display_order ?? 0) -
          (b.display_order ?? 0)
    );

  // =======================================================
  // IMAGE ZOOM CONTROLS
  // =======================================================

  const resetZoom = () => {
    setZoomScale(1);
    setZoomPosition({ x: 50, y: 50 });
  };

  const changeImage = (direction: number) => {
    setActiveImage((current) => {
      const total = imageList.length;

      if (!total) return 0;

      return (
        (current + direction + total) % total
      );
    });

    resetZoom();
  };

  const handleZoomMove = (
    event: MouseEvent<HTMLDivElement>
  ) => {
    if (zoomScale <= 1) return;

    const rect =
      event.currentTarget.getBoundingClientRect();

    const x =
      ((event.clientX - rect.left) / rect.width) *
      100;

    const y =
      ((event.clientY - rect.top) / rect.height) *
      100;

    setZoomPosition({
      x: Math.max(0, Math.min(100, x)),
      y: Math.max(0, Math.min(100, y)),
    });
  };

  const handleZoomWheel = (
    event: WheelEvent<HTMLDivElement>
  ) => {
    event.preventDefault();

    setZoomScale((current) => {
      const next =
        current + (event.deltaY < 0 ? 0.25 : -0.25);

      return Math.max(
        1,
        Math.min(3, Number(next.toFixed(2)))
      );
    });
  };

  useEffect(() => {
    if (!zoomOpen) return;

    const oldOverflow =
      document.body.style.overflow;

    document.body.style.overflow = 'hidden';

    const keydown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setZoomOpen(false);
      }

      if (e.key === 'ArrowRight') {
        setActiveImage(
          (v) =>
            (v + 1) %
            Math.max(1, imageList.length)
        );

        setZoomScale(1);
        setZoomPosition({ x: 50, y: 50 });
      }

      if (e.key === 'ArrowLeft') {
        setActiveImage(
          (v) =>
            (v -
              1 +
              Math.max(1, imageList.length)) %
            Math.max(1, imageList.length)
        );

        setZoomScale(1);
        setZoomPosition({ x: 50, y: 50 });
      }
    };

    window.addEventListener('keydown', keydown);

    return () => {
      document.body.style.overflow = oldOverflow;
      window.removeEventListener(
        'keydown',
        keydown
      );
    };
  }, [zoomOpen, imageList.length]);

  // =======================================================
  // LOADING AND ERROR STATES
  // =======================================================

  if (loading) {
    return (
      <div className="container-wide">
        <Spinner label="Loading product..." />
      </div>
    );
  }

  if (error) {
    return (
      <div className="container-wide page-space">
        <Notice message={error} />
      </div>
    );
  }

  if (!product) {
    return (
      <div className="container-wide page-space">
        <Empty
          title="Product not found"
          action={
            <Link
              to="/catalog"
              className="btn btn-primary"
            >
              Back to products
            </Link>
          }
        />
      </div>
    );
  }

  // =======================================================
  // VARIANT MANAGEMENT
  // =======================================================

  const variants: DetailVariant[] = (
    product.variants ?? []
  ).filter((v) => v.is_active !== false);

  const defaultVariant = variantOf(
    product
  ) as DetailVariant | undefined;

  const variant: DetailVariant | undefined =
    variants.find((v) => v.id === selectedId) ??
    variants.find(
      (v) => v.id === defaultVariant?.id
    ) ??
    variants[0];

  // Group variants by RAM and Storage.
  // Different colors of the same configuration
  // belong to one configuration group.

  const configurations = Array.from(
    new Map(
      variants.map(
        (v) =>
          [
            configurationKey(v),
            v,
          ] as const
      )
    ).entries()
  ).map(([key, representative]) => ({
    key,
    representative,
  }));

  const selectedConfiguration = variant
    ? configurationKey(variant)
    : '';

  const configurationVariants = variants.filter(
    (v) =>
      configurationKey(v) ===
      selectedConfiguration
  );

  // =======================================================
  // IMPORTANT FIX:
  // SHOW RAM/STORAGE EVEN FOR ONE VARIANT
  // =======================================================

  const hasConfigurationDetails =
    configurations.some(({ representative }) => {
      const ram = optionValue(
        representative,
        'RAM'
      );

      const storage = optionValue(
        representative,
        'Storage'
      );

      return Boolean(ram || storage);
    });

  const showConfigurationSelector =
    configurations.length > 1 ||
    hasConfigurationDetails;

  // =======================================================
  // COLOR MANAGEMENT
  // =======================================================

  const configuredColors = Array.from(
    new Set(
      configurationVariants
        .map((v) => optionValue(v, 'Color'))
        .filter(Boolean)
    )
  );

  const colorChoices = configuredColors;

  const selectedColor = variant
    ? optionValue(variant, 'Color')
    : '';

  const changeVariant = (id: number) => {
    setSelectedId(id);
    setQty(1);
  };

  const changeConfiguration = (key: string) => {
    const matches = variants.filter(
      (v) => configurationKey(v) === key
    );

    const next =
      matches.find(
        (v) =>
          optionValue(v, 'Color') ===
            selectedColor &&
          v.stock > 0
      ) ??
      matches.find(
        (v) =>
          v.is_default &&
          v.stock > 0
      ) ??
      matches.find((v) => v.stock > 0) ??
      matches[0];

    if (next) {
      changeVariant(next.id);
    }
  };

  const changeColor = (color: string) => {
    const next = configurationVariants.find(
      (v) =>
        optionValue(v, 'Color') === color
    );

    if (next) {
      changeVariant(next.id);
    }
  };

  // =======================================================
  // PRODUCT PRICE AND STOCK
  // =======================================================

  const currentImage = imageList[activeImage];

  const currentUrl = absoluteMedia(
    currentImage?.image
  );

  const price = number(
    variant?.discounted_price ?? variant?.price
  );

  const original = number(variant?.price);

  const stock = variant?.stock ?? 0;

  const inStock =
    Boolean(variant) &&
    stock > 0 &&
    product.availability !== 'out_of_stock' &&
    product.availability !== 'coming_soon';

  const saved = wishlist.wishlist?.items.some(
    (item) => item.variant_id === variant?.id
  );

  const average = reviews.length
    ? reviews.reduce(
        (sum, r) => sum + r.rating,
        0
      ) / reviews.length
    : 0;

  // =======================================================
  // LOGIN
  // =======================================================

  const login = () =>
    navigate(
      `/login?next=${encodeURIComponent(
        route.pathname
      )}`
    );

  // =======================================================
  // ADD TO CART / BUY NOW
  // =======================================================

  const add = async (buyNow = false) => {
    if (!user) {
      login();
      return;
    }

    if (!variant || !inStock || busy) return;

    setBusy(true);

    try {
      await cart.add(variant.id, qty);

      if (buyNow) {
        navigate('/cart');
      }
    } catch (e) {
      toast(
        e instanceof Error
          ? e.message
          : 'Could not add product',
        'error'
      );
    } finally {
      setBusy(false);
    }
  };

  // =======================================================
  // WISHLIST
  // =======================================================

  const toggleWish = async () => {
    if (!user) {
      login();
      return;
    }

    if (!variant) return;

    try {
      await wishlist.toggle(variant.id);
    } catch (e) {
      toast(
        e instanceof Error
          ? e.message
          : 'Wishlist unavailable',
        'error'
      );
    }
  };

  // =======================================================
  // SHARE
  // =======================================================

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(
        window.location.href
      );

      toast('Product link copied', 'success');
      setShareOpen(false);
    } catch {
      toast('Could not copy the link', 'error');
    }
  };

  const openShare = (url: string) => {
    window.open(
      url,
      '_blank',
      'noopener,noreferrer'
    );

    setShareOpen(false);
  };

  const shareUrl = encodeURIComponent(
    window.location.href
  );

  const shareText = encodeURIComponent(
    `${product.name} — ${money(price)}`
  );

  // =======================================================
  // SUBMIT QUESTION
  // =======================================================

  const submitQuestion = async (
    e: FormEvent<HTMLFormElement>
  ) => {
    e.preventDefault();

    if (!user) {
      login();
      return;
    }

    if (questionText.trim().length < 10) {
      toast(
        'Enter at least 10 characters',
        'error'
      );
      return;
    }

    setSubmitting(true);

    try {
      await api(endpoints.questions, {
        method: 'POST',
        body: {
          product: product.id,
          question: questionText.trim(),
        },
      });

      setQuestionText('');
      setQuestionForm(false);

      toast(
        'Question submitted for approval',
        'success'
      );
    } catch (err) {
      toast(
        err instanceof Error
          ? err.message
          : 'Could not submit question',
        'error'
      );
    } finally {
      setSubmitting(false);
    }
  };

  // =======================================================
  // SUBMIT REVIEW
  // =======================================================

  const submitReview = async (
    e: FormEvent<HTMLFormElement>
  ) => {
    e.preventDefault();

    if (!user) {
      login();
      return;
    }

    if (reviewText.trim().length < 10) {
      toast(
        'Enter at least 10 characters',
        'error'
      );
      return;
    }

    setSubmitting(true);

    try {
      const created = await api<ProductReview>(
        endpoints.reviews,
        {
          method: 'POST',
          body: {
            product: product.id,
            rating,
            review: reviewText.trim(),
          },
        }
      );

      if (created.is_approved === true) {
        setReviews((prev) => [
          created,
          ...prev,
        ]);
      }

      setReviewText('');
      setRating(5);
      setReviewForm(false);

      toast(
        created.is_approved
          ? 'Review submitted successfully'
          : 'Review submitted for approval',
        'success'
      );
    } catch (err) {
      toast(
        err instanceof Error
          ? err.message
          : 'Could not submit review',
        'error'
      );
    } finally {
      setSubmitting(false);
    }
  };

  // =======================================================
  // RENDER
  // =======================================================

  return (
    <div className="container-wide product-detail-page">
      <Breadcrumbs
        items={[
          {
            label: 'Products',
            to: '/catalog',
          },
          {
            label: product.category || 'Category',
          },
          {
            label: product.name,
          },
        ]}
      />

      <div className="product-detail-layout">
        {/* ================================================
            PRODUCT GALLERY
        ================================================= */}

        <div className="product-gallery">
          <div className="product-gallery-main pd-gallery-main">
            {currentUrl ? (
              <img
                className="pd-main-image"
                src={currentUrl}
                alt={
                  currentImage?.alt_text ||
                  product.name
                }
                onClick={() => {
                  resetZoom();
                  setZoomOpen(true);
                }}
              />
            ) : (
              <ProductVisual
                name={product.name}
                kind={product.category}
              />
            )}

            {currentUrl && (
              <button
                className="pd-zoom-trigger"
                type="button"
                onClick={() => {
                  resetZoom();
                  setZoomOpen(true);
                }}
              >
                <Icon name="search" size={17} />
                Zoom image
              </button>
            )}
          </div>

          {imageList.length > 1 && (
            <div className="gallery-thumbs pd-thumbs">
              {imageList.map((im, index) => (
                <button
                  type="button"
                  key={im.id}
                  className={
                    activeImage === index
                      ? 'active'
                      : ''
                  }
                  aria-label={`View image ${index + 1}`}
                  onClick={() => {
                    setActiveImage(index);
                    resetZoom();
                  }}
                >
                  <img
                    src={absoluteMedia(im.image)}
                    alt={
                      im.alt_text ||
                      `${product.name} image ${index + 1}`
                    }
                  />
                </button>
              ))}
            </div>
          )}

          {imageList.length > 1 && (
            <p className="pd-image-count">
              {activeImage + 1} of{' '}
              {imageList.length} images
            </p>
          )}

          <div className="gallery-note">
            <Icon name="shield-check" size={18} />
            Genuine product · Secure checkout
          </div>
        </div>

        {/* ================================================
            PRODUCT INFORMATION
        ================================================= */}

        <div className="product-detail-info">
          <div className="eyebrow">
            {product.brand || 'TECHZONE'}

            <span className="eyebrow-separator">
              {' / '}
            </span>

            {product.category}
          </div>

          <h1>{product.name}</h1>

          <div className="detail-meta">
            <span className="pd-rating-inline">
              <Stars rating={average} />

              {reviews.length
                ? `${average.toFixed(1)} (${reviews.length} reviews)`
                : 'No reviews yet'}
            </span>

            <span>
              SKU: {variant?.sku || '—'}
            </span>
          </div>

          {/* ============================================
              PRICE
          ============================================= */}

          <div className="detail-price-block">
            <div>
              <strong>
                {variant
                  ? money(price)
                  : 'Contact for price'}
              </strong>

              {original > price && (
                <del>{money(original)}</del>
              )}
            </div>

            {original > price && (
              <span className="detail-save">
                Save {money(original - price)}
              </span>
            )}
          </div>

          {/* ============================================
              STOCK
          ============================================= */}

          <div
            className={`detail-stock ${
              inStock ? 'in' : 'out'
            }`}
          >
            <span className="stock-indicator" />

            {inStock
              ? `In stock · ${stock} available`
              : 'Currently unavailable'}
          </div>

          {/* ============================================
              RAM AND STORAGE CONFIGURATION

              FIX:
              Display configuration even when the
              product has only ONE variant.

              Products without RAM or Storage and
              with only one variant will not show
              an unnecessary configuration selector.
          ============================================= */}

          {showConfigurationSelector && (
            <div className="variant-select">
              <strong>
                {configurations.length > 1
                  ? 'Choose configuration'
                  : 'Configuration'}
              </strong>

              <div className="variant-buttons">
                {configurations.map(
                  ({ key, representative }) => {
                    const matches = variants.filter(
                      (v) =>
                        configurationKey(v) === key
                    );

                    const available = matches.some(
                      (v) => v.stock > 0
                    );

                    const shown =
                      matches.find(
                        (v) => v.stock > 0
                      ) ?? representative;

                    const selected =
                      selectedConfiguration === key;

                    return (
                      <button
                        type="button"
                        key={key}
                        aria-pressed={selected}
                        className={
                          selected ? 'selected' : ''
                        }
                        onClick={() =>
                          changeConfiguration(key)
                        }
                      >
                        {configurationLabel(
                          representative
                        )}

                        <small>
                          {money(
                            shown.discounted_price ??
                              shown.price
                          )}

                          {' · '}

                          {available
                            ? 'Available'
                            : 'Out of stock'}
                        </small>
                      </button>
                    );
                  }
                )}
              </div>
            </div>
          )}

          {/* ============================================
              COLOR SELECTOR
          ============================================= */}

          {colorChoices.length > 0 && (
            <div className="variant-select pd-color-select">
              <strong>
                Choose color

                {selectedColor
                  ? `: ${selectedColor}`
                  : ''}
              </strong>

              <div className="pd-color-options">
                {colorChoices.map((color) => {
                  const matching =
                    configurationVariants.find(
                      (v) =>
                        optionValue(v, 'Color') ===
                        color
                    );

                  const isSelected =
                    selectedColor === color;

                  return (
                    <button
                      type="button"
                      key={color}
                      className={
                        isSelected ? 'selected' : ''
                      }
                      aria-pressed={isSelected}
                      disabled={
                        !matching ||
                        matching.stock < 1
                      }
                      title={
                        !matching
                          ? 'Color not configured'
                          : matching.stock < 1
                            ? 'Out of stock'
                            : color
                      }
                      onClick={() =>
                        changeColor(color)
                      }
                    >
                      <span
                        className="pd-color-dot"
                        aria-hidden="true"
                        style={{
                          backgroundColor:
                            colorHex(matching),
                        }}
                      />

                      <span>{color}</span>

                      {matching && (
                        <small>
                          {matching.stock} available
                        </small>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* ============================================
              KEY FEATURES
          ============================================= */}

          {product.key_feature &&
            Object.keys(product.key_feature).length >
              0 && (
              <div className="detail-features">
                <h3>Key highlights</h3>

                {Object.entries(
                  product.key_feature
                )
                  .slice(0, 6)
                  .map(([key, value]) => (
                    <div key={key}>
                      <Icon
                        name="check-circle"
                        size={16}
                      />

                      <span>
                        {key}: {valueText(value)}
                      </span>
                    </div>
                  ))}
              </div>
            )}

          {/* ============================================
              PURCHASE ACTIONS
          ============================================= */}

          <div className="purchase-actions">
            <div className="quantity-stepper">
              <button
                type="button"
                aria-label="Decrease quantity"
                disabled={qty <= 1}
                onClick={() =>
                  setQty((v) =>
                    Math.max(1, v - 1)
                  )
                }
              >
                <Icon name="minus" size={17} />
              </button>

              <span>{qty}</span>

              <button
                type="button"
                aria-label="Increase quantity"
                disabled={
                  qty >= stock || !inStock
                }
                onClick={() =>
                  setQty((v) =>
                    Math.min(stock, v + 1)
                  )
                }
              >
                <Icon name="plus" size={17} />
              </button>
            </div>

            <Button
              disabled={!inStock || busy}
              loading={busy}
              onClick={() => void add()}
            >
              <Icon name="cart" size={18} />
              Add to cart
            </Button>

            <Button
              variant="secondary"
              disabled={!inStock || busy}
              onClick={() => void add(true)}
            >
              Buy now
              <Icon name="arrow" size={17} />
            </Button>
          </div>

          {/* ============================================
              SECONDARY ACTIONS
          ============================================= */}

          <div className="detail-secondary-actions pd-actions">
            <button
              type="button"
              onClick={() => void toggleWish()}
            >
              <Icon name="heart" size={18} />

              {saved
                ? 'Saved to wishlist'
                : 'Add to wishlist'}
            </button>

            <button
              type="button"
              onClick={() =>
                compare.toggle(product.id)
              }
            >
              <Icon name="compare" size={18} />

              {compare.ids.includes(product.id)
                ? 'Remove comparison'
                : 'Add to compare'}
            </button>

            <button
              type="button"
              onClick={() =>
                setShareOpen((v) => !v)
              }
            >
              <Icon name="share" size={18} />
              Share
            </button>
          </div>

          {/* ============================================
              SHARE MENU
          ============================================= */}

          {shareOpen && (
            <div className="pd-share">
              <strong>Share this product</strong>

              <div>
                <button
                  type="button"
                  onClick={() =>
                    openShare(
                      `https://www.facebook.com/sharer/sharer.php?u=${shareUrl}`
                    )
                  }
                >
                  Facebook
                </button>

                <button
                  type="button"
                  onClick={() =>
                    openShare(
                      `https://wa.me/?text=${shareText}%20${shareUrl}`
                    )
                  }
                >
                  WhatsApp
                </button>

                <button
                  type="button"
                  onClick={() =>
                    openShare(
                      `https://twitter.com/intent/tweet?text=${shareText}&url=${shareUrl}`
                    )
                  }
                >
                  X
                </button>

                <button
                  type="button"
                  onClick={() => void copy()}
                >
                  Copy link
                </button>
              </div>
            </div>
          )}

          {/* ============================================
              DELIVERY
          ============================================= */}

          <div className="detail-delivery">
            <div>
              <Icon name="truck" size={22} />

              <span>
                <strong>
                  Delivery across Bangladesh
                </strong>

                <small>
                  Shipping details confirmed at
                  checkout
                </small>
              </span>
            </div>

            <div>
              <Icon name="lock" size={22} />

              <span>
                <strong>
                  Secure SSLCommerz payment
                </strong>

                <small>
                  Pay safely through the official
                  gateway
                </small>
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* ==================================================
          PRODUCT TABS
      ================================================== */}

      <div className="detail-bottom pd-bottom">
        <div className="detail-tabs-heading">
          <h2>Product information</h2>
        </div>

        <div
          className="pd-tabs"
          role="tablist"
          aria-label="Product information"
        >
          {(
            [
              [
                'specification',
                'Specification',
              ],
              [
                'description',
                'Description',
              ],
              [
                'questions',
                `Questions (${questions.length})`,
              ],
              [
                'reviews',
                `Reviews (${reviews.length})`,
              ],
            ] as [Tab, string][]
          ).map(([key, label]) => (
            <button
              key={key}
              type="button"
              role="tab"
              aria-selected={tab === key}
              className={
                tab === key ? 'active' : ''
              }
              onClick={() => setTab(key)}
            >
              {label}
            </button>
          ))}
        </div>

        <div
          className="pd-panel"
          role="tabpanel"
        >
          {/* ============================================
              SPECIFICATIONS
          ============================================= */}

          {tab === 'specification' && (
            <>
              <h3>Technical specifications</h3>

              {Object.keys(
                product.specification ?? {}
              ).length ? (
                <div className="spec-table">
                  {Object.entries(
                    product.specification ?? {}
                  ).map(([key, value]) =>
                    value &&
                    typeof value === 'object' &&
                    !Array.isArray(value) ? (
                      <div
                        className="spec-group"
                        key={key}
                      >
                        <h3>{key}</h3>

                        {Object.entries(
                          value as Record<
                            string,
                            unknown
                          >
                        ).map(([sub, val]) => (
                          <div
                            className="spec-row"
                            key={sub}
                          >
                            <span>{sub}</span>

                            <strong>
                              {valueText(val)}
                            </strong>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div
                        className="spec-row"
                        key={key}
                      >
                        <span>{key}</span>

                        <strong>
                          {valueText(value)}
                        </strong>
                      </div>
                    )
                  )}
                </div>
              ) : (
                <div className="section-placeholder">
                  Specifications are not available
                  yet.
                </div>
              )}
            </>
          )}

          {/* ============================================
              DESCRIPTION
          ============================================= */}

          {tab === 'description' && (
            <>
              <h3>Product description</h3>

              {product.description ? (
                <div className="detail-description">
                  <p>{product.description}</p>
                </div>
              ) : (
                <div className="section-placeholder">
                  Description is not available yet.
                </div>
              )}
            </>
          )}

          {/* ============================================
              QUESTIONS
          ============================================= */}

          {tab === 'questions' && (
            <>
              <div className="pd-section-header">
                <div>
                  <h3>
                    Customer questions & answers
                  </h3>

                  <p>
                    Ask about this product or read
                    answers from our team.
                  </p>
                </div>

                <button
                  className="btn btn-primary"
                  type="button"
                  onClick={() =>
                    user
                      ? setQuestionForm((v) => !v)
                      : login()
                  }
                >
                  Ask a question
                </button>
              </div>

              {questionForm && (
                <form
                  className="pd-form"
                  onSubmit={(e) =>
                    void submitQuestion(e)
                  }
                >
                  <label htmlFor="pd-question">
                    Your question
                  </label>

                  <textarea
                    id="pd-question"
                    required
                    minLength={10}
                    maxLength={2000}
                    rows={4}
                    value={questionText}
                    onChange={(e) =>
                      setQuestionText(
                        e.target.value
                      )
                    }
                  />

                  <small>
                    Questions appear publicly
                    after admin approval.
                  </small>

                  <button
                    className="btn btn-primary"
                    type="submit"
                    disabled={submitting}
                  >
                    {submitting
                      ? 'Submitting...'
                      : 'Submit question'}
                  </button>
                </form>
              )}

              {questionsLoading ? (
                <Spinner label="Loading questions..." />
              ) : questionsError ? (
                <Notice
                  message={questionsError}
                />
              ) : questions.length ? (
                <div className="pd-list">
                  {questions.map((q) => (
                    <article
                      className="pd-entry"
                      key={q.id}
                    >
                      <div>
                        <strong>
                          {q.user_name ||
                            'Customer'}
                        </strong>

                        <p>
                          Q: {q.question}
                        </p>
                      </div>

                      <small>
                        {dateLabel(q.created_at)}
                      </small>

                      {q.answer && (
                        <div className="pd-answer">
                          <strong>
                            Seller's answer
                          </strong>

                          <p>{q.answer}</p>
                        </div>
                      )}
                    </article>
                  ))}
                </div>
              ) : (
                <div className="section-placeholder">
                  No approved questions yet.
                </div>
              )}
            </>
          )}

          {/* ============================================
              REVIEWS
          ============================================= */}

          {tab === 'reviews' && (
            <>
              <div className="pd-section-header">
                <div>
                  <h3>Customer reviews</h3>

                  <p>
                    Read ratings and feedback
                    from customers.
                  </p>
                </div>

                <button
                  className="btn btn-primary"
                  type="button"
                  onClick={() =>
                    user
                      ? setReviewForm((v) => !v)
                      : login()
                  }
                >
                  Write a review
                </button>
              </div>

              <div className="pd-review-summary">
                <div>
                  <strong>
                    {average.toFixed(1)}
                  </strong>

                  <Stars rating={average} />

                  <small>
                    {reviews.length} reviews
                  </small>
                </div>

                <div className="pd-breakdown">
                  {[5, 4, 3, 2, 1].map((n) => {
                    const count =
                      reviews.filter(
                        (r) => r.rating === n
                      ).length;

                    const percentage =
                      reviews.length
                        ? (count /
                            reviews.length) *
                          100
                        : 0;

                    return (
                      <div key={n}>
                        <span>{n} ★</span>

                        <div>
                          <i
                            style={{
                              width: `${percentage}%`,
                            }}
                          />
                        </div>

                        <span>{count}</span>
                      </div>
                    );
                  })}
                </div>
              </div>

              {reviewForm && (
                <form
                  className="pd-form"
                  onSubmit={(e) =>
                    void submitReview(e)
                  }
                >
                  <label>Your rating</label>

                  <Stars
                    rating={rating}
                    onChange={setRating}
                  />

                  <label htmlFor="pd-review">
                    Your review
                  </label>

                  <textarea
                    id="pd-review"
                    required
                    minLength={10}
                    maxLength={5000}
                    rows={4}
                    value={reviewText}
                    onChange={(e) =>
                      setReviewText(
                        e.target.value
                      )
                    }
                  />

                  <button
                    className="btn btn-primary"
                    type="submit"
                    disabled={submitting}
                  >
                    {submitting
                      ? 'Submitting...'
                      : 'Submit review'}
                  </button>
                </form>
              )}

              {reviewsLoading ? (
                <Spinner label="Loading reviews..." />
              ) : reviewsError ? (
                <Notice
                  message={reviewsError}
                />
              ) : reviews.length ? (
                <div className="pd-list">
                  {reviews.map((r) => (
                    <article
                      className="pd-entry"
                      key={r.id}
                    >
                      <div className="pd-review-top">
                        <div>
                          <strong>
                            {r.user_name ||
                              'Customer'}
                          </strong>

                          <Stars
                            rating={r.rating}
                          />
                        </div>

                        <small>
                          {dateLabel(
                            r.created_at
                          )}
                        </small>
                      </div>

                      <p>{r.review}</p>
                    </article>
                  ))}
                </div>
              ) : (
                <div className="section-placeholder">
                  No reviews yet. Be the first
                  to write one.
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {/* ==================================================
          IMAGE ZOOM MODAL
      ================================================== */}

      {zoomOpen && currentUrl && (
        <div
          className="pd-modal-backdrop"
          onMouseDown={(e) => {
            if (
              e.target === e.currentTarget
            ) {
              setZoomOpen(false);
            }
          }}
        >
          <div
            className="pd-modal"
            role="dialog"
            aria-modal="true"
            aria-label="Product image viewer"
          >
            {/* HEADER */}

            <div className="pd-modal-header">
              <strong>{product.name}</strong>

              <button
                type="button"
                onClick={() =>
                  setZoomOpen(false)
                }
                aria-label="Close"
              >
                ×
              </button>
            </div>

            {/* IMAGE */}

            <div className="pd-modal-stage">
              {imageList.length > 1 && (
                <button
                  type="button"
                  onClick={() =>
                    changeImage(-1)
                  }
                  aria-label="Previous image"
                >
                  ‹
                </button>
              )}

              <div
                className="pd-modal-image-wrap"
                onMouseMove={handleZoomMove}
                onWheel={handleZoomWheel}
                style={{
                  overflow: 'hidden',
                  cursor:
                    zoomScale > 1
                      ? 'zoom-out'
                      : 'zoom-in',
                }}
                onClick={() => {
                  if (zoomScale === 1) {
                    setZoomScale(2);
                  } else {
                    resetZoom();
                  }
                }}
              >
                <img
                  src={currentUrl}
                  alt={
                    currentImage?.alt_text ||
                    product.name
                  }
                  draggable={false}
                  style={{
                    transform: `scale(${zoomScale})`,
                    transformOrigin:
                      `${zoomPosition.x}% ${zoomPosition.y}%`,
                    transition:
                      'transform 0.12s ease-out',
                  }}
                />
              </div>

              {imageList.length > 1 && (
                <button
                  type="button"
                  onClick={() =>
                    changeImage(1)
                  }
                  aria-label="Next image"
                >
                  ›
                </button>
              )}
            </div>

            {/* ZOOM CONTROLS */}

            <div className="pd-modal-footer">
              <span>
                {activeImage + 1} /{' '}
                {imageList.length}
              </span>

              <div>
                <button
                  type="button"
                  onClick={() =>
                    setZoomScale((v) =>
                      Math.max(
                        1,
                        +(v - 0.25).toFixed(2)
                      )
                    )
                  }
                  aria-label="Zoom out"
                >
                  −
                </button>

                <span>
                  {Math.round(
                    zoomScale * 100
                  )}
                  %
                </span>

                <button
                  type="button"
                  onClick={() =>
                    setZoomScale((v) =>
                      Math.min(
                        3,
                        +(v + 0.25).toFixed(2)
                      )
                    )
                  }
                  aria-label="Zoom in"
                >
                  +
                </button>

                <button
                  type="button"
                  onClick={resetZoom}
                >
                  Reset
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
