
import { useEffect, useState } from 'react';

// import showcase from '../assets/tech-showcase.webp';
import showcase from '../assets/Modern Smart Home Showroom.png';
import futuristicShowcase from '../assets/Futuristic Blue Tech Showcase-1.png';
import gamingShowcase from '../assets/Neon Gaming Setup Showcase-2.png';

import {
  Icon,
  ProductCard,
  Spinner,
} from '../components/UI';

import {
  getCategories,
  getProductImages,
  productImage,
  useData,
} from '../lib/data';

import {
  api,
  endpoints,
  withQuery,
} from '../lib/api';

import type {
  Category,
  Page,
  Product,
  ProductImage,
} from '../lib/types';

import { asList } from '../lib/utils';
import { Link } from '../lib/router';

// ============================================================
// HERO CONFIGURATION
// ============================================================

const heroImages = [
  showcase,
  futuristicShowcase,
  gamingShowcase,
];

const SLIDE_INTERVAL = 3500;
const NOTICE_SCROLL_SECONDS = 25;

// ============================================================
// NOTICE TYPES
// ============================================================

interface Notice {
  id: number;
  title: string;
  message: string;
  notice_type: string;
  is_active: boolean;
  is_featured: boolean;
  start_at: string | null;
  end_at: string | null;
  created_at: string;
  updated_at: string;
}

type NoticeResponse =
  | Notice[]
  | {
      count?: number;
      next?: string | null;
      results: Notice[];
    };

// ============================================================
// CATEGORY ICONS
// ============================================================

type CategoryIcon =
  | 'laptop'
  | 'pc'
  | 'phone'
  | 'cpu'
  | 'monitor'
  | 'tv'
  | 'ac'
  | 'fridge'
  | 'watch'
  | 'camera'
  | 'gamepad'
  | 'box';

const categoryIcons: Record<string, CategoryIcon> = {
  laptop: 'laptop',
  desktop: 'pc',
  mobile: 'phone',
  phone: 'phone',
  processor: 'cpu',
  component: 'cpu',
  monitor: 'monitor',
  tv: 'tv',
  ac: 'ac',
  fridge: 'fridge',
  watch: 'watch',
  camera: 'camera',
  gaming: 'gamepad',
};

function categoryIcon(name: string): CategoryIcon {
  const matched = Object.entries(categoryIcons).find(
    ([key]) => name.toLowerCase().includes(key)
  );

  return matched?.[1] ?? 'box';
}

// ============================================================
// NOTICE HELPERS
// ============================================================

function extractNotices(response: NoticeResponse): Notice[] {
  if (Array.isArray(response)) {
    return response;
  }

  if (
    response &&
    typeof response === 'object' &&
    Array.isArray(response.results)
  ) {
    return response.results;
  }

  return [];
}

function isNoticeVisible(notice: Notice): boolean {
  if (!notice.is_active) {
    return false;
  }

  const now = Date.now();

  if (notice.start_at) {
    const start = Date.parse(notice.start_at);

    if (Number.isFinite(start) && now < start) {
      return false;
    }
  }

  if (notice.end_at) {
    const end = Date.parse(notice.end_at);

    if (Number.isFinite(end) && now > end) {
      return false;
    }
  }

  return true;
}

function sortNotices(notices: Notice[]): Notice[] {
  return [...notices].sort((a, b) => {
    if (a.is_featured !== b.is_featured) {
      return a.is_featured ? -1 : 1;
    }

    const first = Date.parse(a.created_at);
    const second = Date.parse(b.created_at);

    return (
      (Number.isFinite(second) ? second : 0) -
      (Number.isFinite(first) ? first : 0)
    );
  });
}

// ============================================================
// HOME PAGE
// ============================================================

export function Home() {

  // ==========================================================
  // HERO SLIDER
  // ==========================================================

  const [activeSlide, setActiveSlide] = useState(0);

  useEffect(() => {
    const interval = window.setInterval(() => {
      setActiveSlide(
        (current) => (current + 1) % heroImages.length
      );
    }, SLIDE_INTERVAL);

    return () => window.clearInterval(interval);
  }, []);

  // ==========================================================
  // DJANGO NOTICES
  // ==========================================================

  const [notices, setNotices] = useState<Notice[]>([]);
  const [noticesLoading, setNoticesLoading] = useState(true);
  const [noticeError, setNoticeError] = useState('');

  useEffect(() => {
    const controller = new AbortController();

    async function loadNotices() {
      try {
        setNoticesLoading(true);
        setNoticeError('');

        const response = await api<NoticeResponse>(
          endpoints.notices,
          {
            method: 'GET',
            auth: false,
            signal: controller.signal,
          }
        );

        if (controller.signal.aborted) {
          return;
        }

        const allNotices = extractNotices(response);

        const visibleNotices = sortNotices(
          allNotices.filter(isNoticeVisible)
        );

        setNotices(visibleNotices);

      } catch (error) {
        if (controller.signal.aborted) {
          return;
        }

        console.error(
          'TechZone notice API request failed:',
          error
        );

        setNoticeError(
          error instanceof Error
            ? error.message
            : 'Unable to load notices.'
        );

      } finally {
        if (!controller.signal.aborted) {
          setNoticesLoading(false);
        }
      }
    }

    void loadNotices();

    return () => {
      controller.abort();
    };
  }, []);

  // ==========================================================
  // CATEGORIES
  // ==========================================================

  const categories = useData(
    'home-categories',
    getCategories,
    [] as Category[]
  );

  // ==========================================================
  // FEATURED PRODUCTS
  // ==========================================================

  const featured = useData(
    'home-featured',

    async () =>
      asList<Product>(
        await api<Page<Product>>(
          withQuery(endpoints.products, {
            is_active: true,
            is_featured: true,
            limit: 8,
          })
        )
      ),

    [] as Product[]
  );

  // ==========================================================
  // NEW PRODUCTS
  // ==========================================================

  const newest = useData(
    'home-new',

    async () =>
      asList<Product>(
        await api<Page<Product>>(
          withQuery(endpoints.products, {
            is_active: true,
            limit: 8,
            ordering: '-created_at',
          })
        )
      ),

    [] as Product[]
  );

  // ==========================================================
  // PRODUCT IMAGES
  // ==========================================================

  const [images, setImages] = useState<ProductImage[]>([]);

  useEffect(() => {
    let mounted = true;

    getProductImages()
      .then((result) => {
        if (mounted) {
          setImages(result);
        }
      })
      .catch((error) => {
        console.error(
          'Failed to load product images:',
          error
        );
      });

    return () => {
      mounted = false;
    };
  }, []);

  const products = featured.data.length
    ? featured.data
    : newest.data;

  // ==========================================================
  // JSX
  // ==========================================================

  return (
    <>

      {/* ======================================================
          HERO SECTION
      ====================================================== */}

      <section className="home-hero">

        <div className="container-wide hero-inner">

          {/* LEFT CONTENT */}

          <div className="hero-content">

            <div className="hero-pill">
              <span className="pulse-dot" />
              YOUR NEXT UPGRADE STARTS HERE
            </div>

            <h1>
              Tech that moves{' '}
              <em>you forward.</em>
            </h1>

            <p>
              Discover the latest laptops, PC components,
              smart gadgets and everyday essentials — all
              in one better place to shop.
            </p>

            <div className="hero-buttons">

              <Link
                to="/catalog"
                className="btn btn-white"
              >
                Explore products
                <Icon name="arrow" size={18} />
              </Link>

              {/* <Link
                to="/pc-builder"
                className="btn btn-hero-outline"
              >
                <Icon name="pc" size={19} />
                Build your PC
              </Link> */}

            </div>

            <div className="hero-stats">

              <span>
                <Icon name="shield-check" size={19} />
                100% genuine
              </span>

              <span>
                <Icon name="truck" size={19} />
                Nationwide delivery
              </span>

              <span>
                <Icon name="headphones" size={19} />
                Helpful support
              </span>

            </div>

          </div>

          {/* ==================================================
              RIGHT IMAGE SLIDER
          ================================================== */}

          <div className="hero-art techzone-hero-art">

            <div className="techzone-hero-image-frame">

              {heroImages.map((image, index) => (

                <Link
                  key={index}
                  to="/catalog"
                  className="techzone-hero-slide"
                  aria-label={`Explore products, slide ${index + 1}`}
                  aria-hidden={activeSlide !== index}
                  tabIndex={activeSlide === index ? 0 : -1}
                  style={{
                    opacity: activeSlide === index ? 1 : 0,
                    zIndex: activeSlide === index ? 2 : 1,
                    pointerEvents:
                      activeSlide === index
                        ? 'auto'
                        : 'none',
                  }}
                >

                  <img
                    src={image}
                    alt={`TechZone technology showcase ${index + 1}`}
                    loading={index === 0 ? 'eager' : 'lazy'}
                    draggable={false}
                    className="techzone-hero-image"
                  />

                </Link>

              ))}

              <div className="techzone-hero-image-label">
                <Icon name="bolt" size={16} />
                Explore what's next
              </div>

            </div>

          </div>

        </div>

        {/* SLIDER INDICATORS */}

        <div className="hero-dots">

          {heroImages.map((_, index) => (

            <button
              key={index}
              type="button"
              aria-label={`Show image ${index + 1}`}
              aria-current={
                activeSlide === index ? 'true' : undefined
              }
              className={
                activeSlide === index ? 'active' : ''
              }
              onClick={() => setActiveSlide(index)}
              style={{
                width: activeSlide === index ? 26 : 9,
                height: 9,
                border: 0,
                borderRadius: 20,
                background:
                  activeSlide === index
                    ? '#ffffff'
                    : 'rgba(255,255,255,.45)',
                cursor: 'pointer',
                padding: 0,
                transition: 'all 250ms ease',
              }}
            />

          ))}

        </div>

      </section>

      {/* ======================================================
          SCROLLING NOTICE BAR
      ====================================================== */}

      <section
        className="techzone-notice-section"
        aria-label="TechZone notices"
      >

        <div className="container-wide">

          <div className="techzone-notice-bar">

            <div className="techzone-notice-label">
              <Icon name="bolt" size={15} />
              <span>NOTICE</span>
            </div>

            <div
              className="techzone-notice-viewport"
              aria-live="polite"
            >

              {noticesLoading ? (

                <span className="techzone-notice-status">
                  Loading latest notices...
                </span>

              ) : noticeError ? (

                <span
                  className="techzone-notice-status techzone-notice-error"
                  title={noticeError}
                >
                  Unable to load notices: {noticeError}
                </span>

              ) : notices.length === 0 ? (

                <span className="techzone-notice-status">
                  No active announcements at the moment.
                </span>

              ) : (

                <div className="techzone-notice-track">

                  {[0, 1].map((copy) => (

                    <div
                      key={copy}
                      className="techzone-notice-group"
                      aria-hidden={copy === 1}
                    >

                      {notices.map((notice) => (

                        <span
                          key={`${copy}-${notice.id}`}
                          className="techzone-notice-item"
                        >

                          <strong>
                            {notice.title}
                          </strong>

                          <span className="techzone-notice-separator">
                            —
                          </span>

                          <span>
                            {notice.message}
                          </span>

                          <span className="techzone-notice-bullet">
                            •
                          </span>

                        </span>

                      ))}

                    </div>

                  ))}

                </div>

              )}

            </div>

          </div>

        </div>

      </section>

      {/* ======================================================
          BENEFITS
      ====================================================== */}

      <section className="benefits-strip">

        <div className="container-wide benefits-grid">

          <div>
            <span className="benefit-icon blue">
              <Icon name="truck" size={23} />
            </span>

            <span>
              <strong>Reliable delivery</strong>
              <small>Across Bangladesh</small>
            </span>
          </div>

          <div>
            <span className="benefit-icon green">
              <Icon name="shield-check" size={23} />
            </span>

            <span>
              <strong>Authentic products</strong>
              <small>Shop with confidence</small>
            </span>
          </div>

          <div>
            <span className="benefit-icon orange">
              <Icon name="tag" size={23} />
            </span>

            <span>
              <strong>Great value</strong>
              <small>Transparent pricing</small>
            </span>
          </div>

          <div>
            <span className="benefit-icon purple">
              <Icon name="headphones" size={23} />
            </span>

            <span>
              <strong>Here to help</strong>
              <small>Support when you need it</small>
            </span>
          </div>

        </div>

      </section>

      {/* ======================================================
          CATEGORIES
      ====================================================== */}

      <section className="section container-wide">

        <div className="section-title">

          <div>
            <span className="eyebrow">
              FIND YOUR NEXT FAVORITE
            </span>

            <h2>Shop by category</h2>

            <p>
              Everything you need, neatly organized.
            </p>
          </div>

          <Link
            to="/catalog"
            className="section-link"
          >
            Browse all categories
            <Icon name="arrow" size={18} />
          </Link>

        </div>

        {categories.loading ? (

          <Spinner label="Loading categories..." />

        ) : categories.data.length ? (

          <div className="category-grid">

            {categories.data
              .slice(0, 10)
              .map((category, index) => (

                <Link
                  key={category.id}
                  to={`/catalog?category=${encodeURIComponent(
                    category.slug
                  )}`}
                  className={`category-tile category-color-${
                    index % 5
                  }`}
                >

                  <span className="category-tile-icon">
                    <Icon
                      name={categoryIcon(category.name)}
                      size={32}
                    />
                  </span>

                  <strong>
                    {category.name}
                  </strong>

                  <small>
                    Explore collection
                    <Icon name="arrow" size={14} />
                  </small>

                </Link>

              ))}

          </div>

        ) : (

          <div className="section-placeholder">
            Categories will appear here once they're
            added in Django Admin.
          </div>

        )}

      </section>

      {/* ======================================================
          PROMOTIONAL PANELS
      ====================================================== */}

      <section className="container-wide">

        <div className="promo-row">

          <div className="promo-panel promo-dark">

            <span className="promo-kicker">
              YOUR DREAM SETUP
            </span>

            <h3>Build it your way.</h3>

            <p>
              Pick compatible components, check your
              build, and bring your PC to life.
            </p>

            <Link
              to="/pc-builder"
              className="btn btn-white btn-small"
            >
              Open PC Builder
              <Icon name="arrow" size={17} />
            </Link>

            <div className="promo-decoration">
              <Icon name="cpu" size={116} />
            </div>

          </div>

          <div className="promo-panel promo-light">

            <span className="promo-kicker">
              SMARTER SHOPPING
            </span>

            <h3>Compare before you buy.</h3>

            <p>
              See the details that matter, side by
              side, and choose with confidence.
            </p>

            <Link
              to="/compare"
              className="btn btn-primary btn-small"
            >
              Compare products
              <Icon name="arrow" size={17} />
            </Link>

            <div className="promo-decoration">
              <Icon name="compare" size={110} />
            </div>

          </div>

        </div>

      </section>

      {/* ======================================================
          FEATURED PRODUCTS
      ====================================================== */}

      <section className="section container-wide">

        <div className="section-title">

          <div>
            <span className="eyebrow">
              HANDPICKED FOR YOU
            </span>

            <h2>
              {featured.data.length
                ? 'Featured products'
                : 'Fresh arrivals'}
            </h2>

            <p>
              Discover great tech at great prices.
            </p>
          </div>

          <Link
            to={
              featured.data.length
                ? '/catalog?featured=true'
                : '/catalog'
            }
            className="section-link"
          >
            View all products
            <Icon name="arrow" size={18} />
          </Link>

        </div>

        {featured.loading && newest.loading ? (

          <Spinner label="Loading products..." />

        ) : products.length ? (

          <div className="product-grid">

            {products.map((product) => (

              <ProductCard
                key={product.id}
                product={product}
                image={productImage(
                  images,
                  product.id
                )}
              />

            ))}

          </div>

        ) : (

          <div className="section-placeholder">
            Your products will appear here when
            your catalog is populated.
          </div>

        )}

      </section>

      {/* ======================================================
          BOTTOM CALL TO ACTION
      ====================================================== */}

      <section className="bottom-cta">

        <div className="container-wide bottom-cta-inner">

          <div>
            <span className="eyebrow">
              READY TO UPGRADE?
            </span>

            <h2>
              Your perfect setup is a few clicks away.
            </h2>

            <p>
              Find the right gear for work, play,
              and everything in between.
            </p>
          </div>

          <Link
            to="/catalog"
            className="btn btn-white"
          >
            Start shopping
            <Icon name="arrow" size={18} />
          </Link>

        </div>

      </section>

      {/* ======================================================
          HOME PAGE STYLES
      ====================================================== */}

      <style>{`

        /* ================================================
           HERO IMAGE SLIDER
           Fixed size, centered, no cropping
        ================================================ */

        .techzone-hero-art {
          position: relative !important;
          display: flex !important;
          align-items: center !important;
          justify-content: center !important;
          min-width: 0;
          overflow: visible !important;
          background: transparent !important;
        }

        .techzone-hero-image-frame {
          position: relative;

          width: 100%;
          max-width: 590px;

          height: auto;
          min-height: 0;
          aspect-ratio: 16 / 9;

          flex: 0 1 590px;

          border-radius: 16px;
          overflow: hidden;
          isolation: isolate;

          background: transparent;

          box-shadow:
            0 10px 28px rgba(0, 0, 0, 0.12);
        }

        .techzone-hero-slide {
          position: absolute;
          inset: 0;

          display: block;
          width: 100%;
          height: 100%;

          border-radius: 16px;
          overflow: hidden;

          transition: opacity 650ms ease-in-out;
        }

        .techzone-hero-image {
          display: block;

          width: 100%;
          height: 100%;

          object-fit: contain;
          object-position: center;

          border-radius: 16px;
        }

        .techzone-hero-image-label {
          position: absolute;
          bottom: 14px;
          right: 14px;
          z-index: 5;

          display: flex;
          align-items: center;
          gap: 7px;

          padding: 9px 13px;
          border-radius: 9px;

          background: rgba(255, 255, 255, 0.96);
          color: #1d4ed8;

          font-size: 12px;
          font-weight: 700;

          pointer-events: none;

          box-shadow:
            0 4px 16px rgba(0, 0, 0, 0.12);
        }

        /* ================================================
           NOTICE BAR
        ================================================ */

        .techzone-notice-section {
          padding: 10px 0;
          background: #f3f4f9;
        }

        .techzone-notice-bar {
          display: flex;
          align-items: center;
          height: 40px;
          background: #ffffff;
          border: 1px solid #e2e8f0;
          border-radius: 24px;
          overflow: hidden;
          box-shadow:
            0 2px 10px rgba(15, 23, 42, 0.04);
        }

        .techzone-notice-label {
          height: 100%;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 6px;
          padding: 0 17px;
          flex-shrink: 0;
          color: #ffffff;
          background: #2563eb;
          font-size: 11px;
          font-weight: 800;
          letter-spacing: 0.6px;
          position: relative;
          z-index: 2;
        }

        .techzone-notice-viewport {
          flex: 1;
          min-width: 0;
          height: 100%;
          display: flex;
          align-items: center;
          overflow: hidden;
        }

        .techzone-notice-status {
          font-size: 12px;
          color: #64748b;
          padding: 0 16px;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }

        .techzone-notice-error {
          color: #b45309;
        }

        .techzone-notice-track {
          display: flex;
          align-items: center;
          width: max-content;
          flex-shrink: 0;
          animation:
            techzoneNoticeMove
            ${NOTICE_SCROLL_SECONDS}s
            linear infinite;
        }

        .techzone-notice-group {
          display: flex;
          align-items: center;
          flex-shrink: 0;
          width: max-content;
        }

        .techzone-notice-item {
          display: inline-flex;
          align-items: center;
          flex-shrink: 0;
          gap: 7px;
          padding-right: 50px;
          white-space: nowrap;
          color: #475569;
          font-size: 13px;
          font-weight: 400;
        }

        .techzone-notice-item strong {
          color: #1d4ed8;
          font-weight: 700;
        }

        .techzone-notice-separator {
          color: #94a3b8;
        }

        .techzone-notice-bullet {
          color: #2563eb;
          font-size: 17px;
          padding-left: 30px;
        }

        .techzone-notice-track:hover {
          animation-play-state: paused;
        }

        @keyframes techzoneNoticeMove {
          from {
            transform: translateX(0);
          }

          to {
            transform: translateX(-50%);
          }
        }

        /* ================================================
           RESPONSIVE
        ================================================ */

        @media (max-width: 900px) {
          .techzone-hero-image-frame {
            width: 100%;
            max-width: 100%;
            height: auto;
            min-height: 0;
            aspect-ratio: 16 / 9;
          }
        }

        @media (max-width: 600px) {

          .techzone-hero-image-frame {
            width: 100%;
            max-width: 100%;
            height: auto;
            min-height: 0;
            aspect-ratio: 16 / 9;
            border-radius: 14px;
          }

          .techzone-hero-slide,
          .techzone-hero-image {
            border-radius: 14px;
          }

          .techzone-hero-image-label {
            bottom: 10px;
            right: 10px;
            padding: 7px 10px;
            font-size: 10px;
          }

          .techzone-notice-section {
            padding: 8px 0;
          }

          .techzone-notice-bar {
            height: 36px;
          }

          .techzone-notice-label {
            padding: 0 11px;
            font-size: 10px;
          }

          .techzone-notice-item {
            font-size: 12px;
            padding-right: 35px;
          }
        }

        @media (prefers-reduced-motion: reduce) {
          .techzone-notice-track {
            animation: none;
          }

          .techzone-hero-slide {
            transition: none;
          }
        }

      `}</style>

    </>
  );
}
