import { useEffect, useMemo, useRef, useState } from 'react';

import { api, endpoints, withQuery } from '../lib/api';
import { productImage } from '../lib/data';
import { Link } from '../lib/router';
import type { Page, Product, ProductImage } from '../lib/types';
import { absoluteMedia, asList, money, priceOf, variantOf } from '../lib/utils';

// ============================================================
// CATALOG SPOTLIGHT
// ============================================================
//
// A rotating banner shown beside the catalog heading. It fills the
// empty space under the navbar with the best deals and trending
// (featured) products of the current category. Each slide links to
// its product page.

type Kind = 'deal' | 'trending' | 'new';

type Slide = {
  kind: Kind;
  product: Product;
  price: number;
  original: number;
  percent: number;
};

const ROTATE_MS = 4500;
const MAX_SLIDES = 6;

const kindLabel: Record<Kind, string> = {
  deal: 'Top Discount',
  trending: 'Trending Now',
  new: 'New Arrival',
};

function toSlide(product: Product, kind: Kind): Slide | null {
  const variant = variantOf(product);
  if (!variant) return null;

  const price = priceOf(product);
  const original = Number(variant.price ?? 0);

  if (!(price > 0)) return null;

  const percent =
    original > price ? Math.round(((original - price) / original) * 100) : 0;

  return { kind, product, price, original, percent };
}

async function loadProducts(params: Record<string, string>) {
  const query = new URLSearchParams({ is_active: 'true', ...params });
  const result = await api<Page<Product> | Product[]>(
    withQuery(endpoints.products, query)
  );
  return asList<Product>(result);
}

export function CatalogSpotlight({
  category,
  images,
}: {
  category?: string;
  images: ProductImage[];
}) {
  const [slides, setSlides] = useState<Slide[]>([]);
  const [index, setIndex] = useState(0);
  const [paused, setPaused] = useState(false);
  const reduceMotion = useRef(
    typeof window !== 'undefined' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );

  // ----------------------------------------------------------
  // LOAD DEALS AND TRENDING PRODUCTS FOR THIS CATEGORY
  // ----------------------------------------------------------

  useEffect(() => {
    let live = true;
    const scope: Record<string, string> = category ? { category } : {};

    setSlides([]);
    setIndex(0);

    Promise.allSettled([
      loadProducts({ ...scope, on_sale: 'true', limit: '24' }),
      loadProducts({ ...scope, is_featured: 'true', limit: '8' }),
    ]).then(async ([dealResult, trendingResult]) => {
      const deals = (dealResult.status === 'fulfilled' ? dealResult.value : [])
        .map((product) => toSlide(product, 'deal'))
        .filter((slide): slide is Slide => !!slide && slide.percent > 0)
        .sort((a, b) => b.percent - a.percent || b.original - b.price - (a.original - a.price))
        .slice(0, 4);

      const used = new Set(deals.map((slide) => slide.product.id));

      const trending = (trendingResult.status === 'fulfilled' ? trendingResult.value : [])
        .filter((product) => !used.has(product.id))
        .map((product) => toSlide(product, 'trending'))
        .filter((slide): slide is Slide => !!slide)
        .slice(0, 3);

      // Alternate deal / trending so both kinds show early.
      const mixed: Slide[] = [];
      for (let i = 0; i < Math.max(deals.length, trending.length); i += 1) {
        if (deals[i]) mixed.push(deals[i]);
        if (trending[i]) mixed.push(trending[i]);
      }

      // Nothing on sale or featured here: show the newest products instead.
      if (!mixed.length) {
        const fresh = await loadProducts({
          ...scope,
          ordering: '-created_at',
          limit: '4',
        }).catch(() => []);
        fresh
          .map((product) => toSlide(product, 'new'))
          .forEach((slide) => slide && mixed.push(slide));
      }

      if (live) setSlides(mixed.slice(0, MAX_SLIDES));
    });

    return () => {
      live = false;
    };
  }, [category]);

  // ----------------------------------------------------------
  // AUTO ROTATE
  // ----------------------------------------------------------

  useEffect(() => {
    if (paused || reduceMotion.current || slides.length < 2) return;
    const timer = window.setInterval(
      () => setIndex((value) => (value + 1) % slides.length),
      ROTATE_MS
    );
    return () => window.clearInterval(timer);
  }, [paused, slides.length]);

  const imageFor = useMemo(
    () => (id: number) => absoluteMedia(productImage(images, id)),
    [images]
  );

  if (!slides.length) return null;

  const go = (next: number) =>
    setIndex((next + slides.length) % slides.length);

  return (
    <section
      className="spotlight"
      aria-roledescription="carousel"
      aria-label="Deals and trending products"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocus={() => setPaused(true)}
      onBlur={() => setPaused(false)}
    >
      <div
        className="spotlight-track"
        style={{ transform: `translateX(-${index * 100}%)` }}
      >
        {slides.map((slide, position) => {
          const image = imageFor(slide.product.id);
          const active = position === index;

          return (
            <Link
              key={`${slide.kind}-${slide.product.id}`}
              to={`/product/${slide.product.slug}`}
              className={`spotlight-slide is-${slide.kind}`}
              aria-hidden={!active}
              tabIndex={active ? 0 : -1}
              aria-label={`${kindLabel[slide.kind]}: ${slide.product.name}, ${money(slide.price)}`}
            >
              <div className="spotlight-copy">
                <span className="spotlight-badge">
                  {slide.kind === 'deal'
                    ? `${slide.percent}% OFF`
                    : kindLabel[slide.kind]}
                </span>
                <strong className="spotlight-name">{slide.product.name}</strong>
                <span className="spotlight-price">
                  {money(slide.price)}
                  {slide.original > slide.price && (
                    <del>{money(slide.original)}</del>
                  )}
                </span>
                <span className="spotlight-cta">
                  {slide.kind === 'deal'
                    ? `Save ${money(slide.original - slide.price)} →`
                    : 'Shop Now →'}
                </span>
              </div>

              <div className="spotlight-art">
                {image && (
                  <img
                    src={image}
                    alt=""
                    loading={position === 0 ? 'eager' : 'lazy'}
                    decoding="async"
                  />
                )}
              </div>
            </Link>
          );
        })}
      </div>

      {slides.length > 1 && (
        <>
          <button
            type="button"
            className="spotlight-arrow prev"
            aria-label="Previous slide"
            onClick={() => go(index - 1)}
          >
            ‹
          </button>
          <button
            type="button"
            className="spotlight-arrow next"
            aria-label="Next slide"
            onClick={() => go(index + 1)}
          >
            ›
          </button>
          <div className="spotlight-dots">
            {slides.map((slide, position) => (
              <button
                key={`${slide.kind}-${slide.product.id}`}
                type="button"
                className={position === index ? 'active' : ''}
                aria-label={`Show slide ${position + 1}`}
                aria-current={position === index}
                onClick={() => go(position)}
              />
            ))}
          </div>
        </>
      )}
    </section>
  );
}
