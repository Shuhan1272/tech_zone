import {
  useEffect,
  useState,
} from 'react';

import showcase from '../assets/tech-showcase.webp';

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
// CATEGORY ICON CONFIGURATION
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

// ============================================================
// GET CATEGORY ICON
// ============================================================

const categoryIcon = (name: string): CategoryIcon => {
  const matchedIcon = Object.entries(categoryIcons).find(
    ([key]) => name.toLowerCase().includes(key)
  );

  return matchedIcon?.[1] ?? 'box';
};

// ============================================================
// HOME COMPONENT
// ============================================================

export function Home() {

  // ----------------------------------------------------------
  // FETCH CATEGORIES
  // ----------------------------------------------------------

  const categories = useData(
    'home-categories',
    getCategories,
    [] as Category[]
  );

  // ----------------------------------------------------------
  // FETCH FEATURED PRODUCTS
  // ----------------------------------------------------------

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

  // ----------------------------------------------------------
  // FETCH NEWEST PRODUCTS
  // ----------------------------------------------------------

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

  // ----------------------------------------------------------
  // PRODUCT IMAGES
  // ----------------------------------------------------------

  const [images, setImages] = useState<ProductImage[]>([]);

  useEffect(() => {
    getProductImages()
      .then(setImages)
      .catch(() => {});
  }, []);

  // ----------------------------------------------------------
  // SELECT PRODUCTS TO DISPLAY
  // ----------------------------------------------------------

  const products = featured.data.length
    ? featured.data
    : newest.data;

  // ==========================================================
  // HOME PAGE JSX
  // ==========================================================

  return (
    <>

      {/* ======================================================
          HERO SECTION
      ====================================================== */}

      <section className="home-hero">

        <div className="container-wide hero-inner">

          {/* HERO CONTENT */}

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

            {/* HERO BUTTONS */}

            <div className="hero-buttons">

              <Link
                to="/catalog"
                className="btn btn-white"
              >
                Explore products

                <Icon
                  name="arrow"
                  size={18}
                />
              </Link>

              <Link
                to="/pc-builder"
                className="btn btn-hero-outline"
              >
                <Icon
                  name="pc"
                  size={19}
                />

                Build your PC
              </Link>

            </div>

            {/* HERO STATS */}

            <div className="hero-stats">

              <span>
                <Icon
                  name="shield-check"
                  size={19}
                />

                100% genuine
              </span>

              <span>
                <Icon
                  name="truck"
                  size={19}
                />

                Nationwide delivery
              </span>

              <span>
                <Icon
                  name="headphones"
                  size={19}
                />

                Helpful support
              </span>

            </div>
          </div>

          {/* HERO ART */}

          <div className="hero-art">

            <div className="hero-orbit orbit-one" />

            <div className="hero-orbit orbit-two" />

            <img
              src={showcase}
              alt="Laptop, headphones, smartphone and wearable technology"
            />

            <div className="hero-floating-tag">

              <Icon
                name="bolt"
                size={16}
              />

              Explore what’s next
            </div>

          </div>
        </div>

        {/* HERO SLIDER DOTS */}

        <div className="hero-dots">
          <span className="active" />
          <span />
          <span />
        </div>

      </section>

      {/* ======================================================
          BENEFITS SECTION
      ====================================================== */}

      <section className="benefits-strip">

        <div className="container-wide benefits-grid">

          {/* RELIABLE DELIVERY */}

          <div>
            <span className="benefit-icon blue">
              <Icon
                name="truck"
                size={23}
              />
            </span>

            <span>
              <strong>Reliable delivery</strong>
              <small>Across Bangladesh</small>
            </span>
          </div>

          {/* AUTHENTIC PRODUCTS */}

          <div>
            <span className="benefit-icon green">
              <Icon
                name="shield-check"
                size={23}
              />
            </span>

            <span>
              <strong>Authentic products</strong>
              <small>Shop with confidence</small>
            </span>
          </div>

          {/* GREAT VALUE */}

          <div>
            <span className="benefit-icon orange">
              <Icon
                name="tag"
                size={23}
              />
            </span>

            <span>
              <strong>Great value</strong>
              <small>Transparent pricing</small>
            </span>
          </div>

          {/* CUSTOMER SUPPORT */}

          <div>
            <span className="benefit-icon purple">
              <Icon
                name="headphones"
                size={23}
              />
            </span>

            <span>
              <strong>Here to help</strong>
              <small>Support when you need it</small>
            </span>
          </div>

        </div>
      </section>

      {/* ======================================================
          SHOP BY CATEGORY SECTION
      ====================================================== */}

      <section className="section container-wide">

        {/* SECTION HEADING */}

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

            <Icon
              name="arrow"
              size={18}
            />
          </Link>

        </div>

        {/* CATEGORY CONTENT */}

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

                    <Icon
                      name="arrow"
                      size={14}
                    />
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
          PROMOTIONAL SECTION
      ====================================================== */}

      <section className="container-wide">

        <div className="promo-row">

          {/* PC BUILDER PROMOTION */}

          <div className="promo-panel promo-dark">

            <span className="promo-kicker">
              YOUR DREAM SETUP
            </span>

            <h3>
              Build it your way.
            </h3>

            <p>
              Pick compatible components, check your
              build, and bring your PC to life.
            </p>

            <Link
              to="/pc-builder"
              className="btn btn-white btn-small"
            >
              Open PC Builder

              <Icon
                name="arrow"
                size={17}
              />
            </Link>

            <div className="promo-decoration">
              <Icon
                name="cpu"
                size={116}
              />
            </div>

          </div>

          {/* PRODUCT COMPARISON PROMOTION */}

          <div className="promo-panel promo-light">

            <span className="promo-kicker">
              SMARTER SHOPPING
            </span>

            <h3>
              Compare before you buy.
            </h3>

            <p>
              See the details that matter, side by
              side, and choose with confidence.
            </p>

            <Link
              to="/compare"
              className="btn btn-primary btn-small"
            >
              Compare products

              <Icon
                name="arrow"
                size={17}
              />
            </Link>

            <div className="promo-decoration">
              <Icon
                name="compare"
                size={110}
              />
            </div>

          </div>

        </div>
      </section>

      {/* ======================================================
          FEATURED PRODUCTS SECTION
      ====================================================== */}

      <section className="section container-wide">

        {/* SECTION HEADING */}

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
            to="/catalog?featured=true"
            className="section-link"
          >
            View all products

            <Icon
              name="arrow"
              size={18}
            />
          </Link>

        </div>

        {/* PRODUCT CONTENT */}

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

          {/* CTA CONTENT */}

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

          {/* CTA BUTTON */}

          <Link
            to="/catalog"
            className="btn btn-white"
          >
            Start shopping

            <Icon
              name="arrow"
              size={18}
            />
          </Link>

        </div>

      </section>

    </>
  );
}