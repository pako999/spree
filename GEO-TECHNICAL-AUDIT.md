# GEO Technical SEO Audit — surf-store.com
Date: 2026-04-08

## Technical Score: 74/100 — Good

## Score Breakdown
| Category | Score | Status |
|---|---|---|
| Crawlability | 11/15 | Warn |
| Indexability | 7/12 | Warn |
| Security | 8/10 | Pass |
| URL Structure | 7/8 | Pass |
| Mobile Optimization | 9/10 | Pass |
| Core Web Vitals | 9/15 | Warn |
| Server-Side Rendering | 15/15 | Pass |
| Page Speed & Server | 8/15 | Warn |

Status: Pass = 80%+ of category points, Warn = 50–79%, Fail = <50%

---

## AI Crawler Access
| Crawler | User-Agent | Status | Recommendation |
|---|---|---|---|
| GPTBot | GPTBot | Allowed (via `*`) | No action needed |
| Google-Extended | Google-Extended | Allowed (via `*`) | No action needed |
| Googlebot | Googlebot | Allowed (via `*`) | No action needed |
| Bingbot | bingbot | Allowed (via `*`) | No action needed |
| PerplexityBot | PerplexityBot | Allowed (via `*`) | No action needed |
| ClaudeBot | ClaudeBot | Allowed (via `*`) | No action needed |
| Amazonbot | Amazonbot | Allowed (via `*`) | No action needed |
| CCBot | CCBot | Allowed (via `*`) | No action needed |
| Bytespider | Bytespider | Allowed (via `*`) | No action needed |
| Applebot-Extended | Applebot-Extended | Allowed (via `*`) | No action needed |

All AI crawlers have full access. No AI crawler is explicitly blocked.

---

## Critical Issues (fix immediately)

### 1. Schema URL locale mismatch — affects every product page
The `Product` JSON-LD `url` field and all `BreadcrumbList` item URLs reference locale-prefixed paths:
- **Schema URL:** `https://www.surf-store.com/sl-SI/products/nobile-2026-nt5`
- **Canonical URL:** `https://www.surf-store.com/products/nobile-2026-nt5`

This mismatch causes Google to distrust or discount the structured data. Fix: generate schema URLs using `spree.product_url(product)` without locale prefix (or with `locale: :en` explicitly).

### 2. Missing hreflang tags — duplicate content risk for EN/DE/SL pages
The site serves `/sl-SI/products/...`, `/de/products/...`, and `/products/...` (English) but zero `<link rel="alternate" hreflang="...">` tags exist on any page. Google may treat these as duplicate content. Fix: add hreflang for `en`, `sl`, `de`, and `x-default` on all pages. Also add German/Slovenian URLs to sitemap.

### 3. All locale pages return `<html lang="en">`
Slovenian and German locale pages should return `lang="sl"` and `lang="de"` respectively. Currently all return `lang="en"`.

---

## Warnings (fix this month)

### 4. Product hero images missing width/height and fetchpriority
Product gallery images have no `width`, `height`, or `fetchpriority="high"` attributes. Impact: CLS (layout shift) and suboptimal LCP. Fix: add explicit dimensions + `fetchpriority="high"` on first image + `loading="lazy"` on secondary images.

### 5. Broken Klaviyo integration — `company_id=:-}`
The Klaviyo script tag has a malformed placeholder `company_id=:-}`. Replace with real company ID or remove entirely. Makes unnecessary third-party network requests with no benefit.

### 6. Category page 1.46 MB HTML payload
All products for a category are loaded in a single server response (1.46 MB uncompressed). This causes slow mobile performance and high INP. Fix: implement server-side pagination (20–50 products) or Turbo Frame infinite scroll with URL updates.

### 7. Homepage title too long (70 chars) and meta descriptions over limit
- Homepage title: 70 chars → truncated in SERPs (50–60 char limit)
- Homepage description: 205 chars → truncated (150–160 char limit)
- Product description: 190 chars → truncated

### 8. No `AggregateRating` / `Review` schema on products
Missing star rating rich snippets. If a review system exists or is added, expose ratings in JSON-LD `Product` schema.

### 9. CSP contains `'unsafe-inline'` in script-src
Weakens XSS protection. Migrate to nonce-based or hash-based CSP to remove `unsafe-inline`. Note: requires careful GTM/Klaviyo handling.

### 10. IndexNow not implemented
No IndexNow key file found. Bing (used by ChatGPT) and Yandex are not notified on product changes. Implement IndexNow pings on product create/update events for faster AI search visibility.

---

## Recommendations (optimize this quarter)

### 11. Add `max-snippet` and `max-image-preview` robots meta tag
```html
<meta name="robots" content="index, follow, max-snippet:-1, max-image-preview:large, max-video-preview:-1">
```
Signals to Google that large image previews and full snippets are permitted. Zero-risk improvement.

### 12. Split sitemap into sitemap index
Single `sitemap.xml` at 1,807 URLs works today but is a single point of failure. Split into:
- `sitemap-products.xml` (~1,655 URLs)
- `sitemap-categories.xml` (~136 URLs)
- `sitemap-blog.xml` (5 URLs)
- `sitemap-policies.xml` (10 URLs)

### 13. Add `rel="preload"` for above-fold hero images
```html
<link rel="preload" as="image" href="/hero.webp" fetchpriority="high">
```
Improves LCP on product and homepage.

---

## Detailed Findings

### Category 1: Crawlability — 11/15

**robots.txt** ✅ Valid, correct syntax. Appropriately blocks `/admin`, `/checkout`, `/account`, `/orders`. Sitemap referenced correctly. All AI crawlers allowed via `User-agent: *`.

**Sitemap** ⚠️ Present at `/sitemap.xml`, 1,807 URLs. `lastmod` dates present and accurate. Priorities set correctly (1.0 homepage, 0.8 products, 0.6 policies). **Issue:** Only English-locale URLs included — no `/de/` or `/sl-SI/` URLs. Missing: blog posts partially included (5), but no German/Slovenian equivalents.

**Crawl depth** ✅ Max depth observed: 5 levels (`/t/categories/kitesurfing/kite-foil/foil-mast`). Homepage → categories → subcategory → product = 3 hops. Within acceptable range.

**Noindex** ✅ No erroneous noindex on indexable pages. No `X-Robots-Tag: noindex` observed.

---

### Category 2: Indexability — 7/12

**Canonical tags** ✅ Self-referencing canonicals on all pages. Correct.

**Duplicate content** ⚠️ Locale variants (`/sl-SI/`, `/de/`) accessible without hreflang = duplicate content risk. www vs non-www and HTTP vs HTTPS redirect correctly.

**Pagination** ✅ Category pages load all products in one request — no pagination duplicate content. (Performance tradeoff noted separately.)

**Hreflang** ❌ Missing entirely. Multilingual site with 3 locales has zero hreflang implementation.

**`<html lang>`** ❌ All locale variants return `lang="en"`. Must return correct language code per locale.

---

### Category 3: Security — 8/10

| Header | Value | Status |
|---|---|---|
| HTTPS | Enforced | ✅ |
| HSTS | `max-age=63072000; includeSubDomains` (2yr) | ✅ |
| CSP | Present but `unsafe-inline` in script-src | ⚠️ |
| X-Content-Type-Options | `nosniff` | ✅ |
| X-Frame-Options | `SAMEORIGIN` | ✅ |
| Referrer-Policy | `strict-origin-when-cross-origin` | ✅ |
| Permissions-Policy | `camera=(), microphone=(), geolocation=(), payment=(self)` | ✅ |

---

### Category 4: URL Structure — 7/8

✅ Clean, lowercase, hyphenated slugs. Logical hierarchy (`/products/`, `/t/categories/`, `/t/brands/`). No session IDs. No redirect chains on canonical URLs. HTTP/2 confirmed. Minor: locale path-based URLs require hreflang (see above).

---

### Category 5: Mobile Optimization — 9/10

✅ `viewport` meta tag present on all pages. Tailwind CSS responsive classes used throughout. Font `display=swap` on Google Fonts. Touch-friendly Stimulus controllers. Mobile slideover navigation.

⚠️ Category page 1.46 MB HTML is mobile performance concern.

---

### Category 6: Core Web Vitals — 9/15

| Vital | Risk | Evidence |
|---|---|---|
| **LCP** | Medium-High | Hero images lack `fetchpriority="high"` and explicit dimensions. No `<link rel="preload">` for hero. Google Fonts loaded as stylesheet (potential render-block). |
| **INP** | Medium | 1.46 MB category page HTML = large DOM parse task. Multiple inline scripts (non-blocking). Third-party: GTM (async ✅), Klaviyo (async ✅ but broken). |
| **CLS** | Medium | 18/20 product gallery images missing `width`/`height`. Swiper CSS and flag-icons CSS loaded async with `onload` pattern (FOUT risk). Product card images DO have dimensions ✅. |

**Positive signals:** HTTP 103 Early Hints for CSS preload. `modulepreload` for JS bundles. `preconnect` for Google Fonts and CDN origins.

---

### Category 7: Server-Side Rendering — 15/15 ✅

**This is the strongest aspect of the site for GEO.** All content is fully server-rendered in the initial HTML response. AI crawlers (GPTBot, ClaudeBot, PerplexityBot) see complete content.

- Homepage: Full header, trust bar, hero, product sections in raw HTML.
- Category page: 153 product cards fully rendered. All prices, images, brand names in raw HTML.
- Product page: Name, price, description, variant data, JSON-LD all in raw HTML.

No empty root `<div id="app">`. No `__NEXT_DATA__`. No CSR framework. Standard Rails SSR + Hotwire (progressive enhancement only).

---

### Category 8: Page Speed & Server — 8/15

| Check | Value | Status |
|---|---|---|
| TTFB | 30–33ms (cached) | ✅ Excellent |
| Rails render time (homepage) | 48ms | ✅ Excellent |
| Rails render time (category) | 2,500–2,900ms | ❌ Very slow |
| Rails render time (product) | 1,790ms | ⚠️ Slow |
| Compression | 88.7% gzip ratio confirmed | ✅ |
| CDN | Cloudflare (CF-Ray headers) | ✅ |
| HTTP 103 Early Hints | Present for CSS | ✅ |
| Cache-Control (HTML) | `public, max-age=30, s-maxage=120` | ✅ |
| Category CDN cache | HIT (52–101s age) | ✅ |
| Product CDN cache | DYNAMIC (not cached) | ⚠️ |
| Image formats | WebP confirmed | ✅ |
| Product card image dims | `width="360" height="360"` | ✅ |
| Hero image dims | Missing on gallery images | ❌ |

**Key issue:** Category pages at 2.5–2.9 seconds Rails render time are too slow. When the CDN cache misses (cold cache, cache invalidation, new visitor to specific sort/filter combination), users wait 2+ seconds for the first byte of meaningful content. This is the primary performance bottleneck and relates directly to the 1.46 MB single-response product loading strategy.

---

## Additional Notes

### Structured Data Quality

| Schema | Pages | Status |
|---|---|---|
| Organization | All | ✅ Complete with address, contact, sameAs |
| SportingGoodsStore | All | ✅ Includes geo, areaServed, currencies |
| WebSite + SearchAction | All | ✅ Sitelinks searchbox enabled |
| Product + Offers | Product pages | ✅ 4 variant offers with price, availability, return policy |
| BreadcrumbList | Product pages | ⚠️ URLs use `/sl-SI/` prefix — mismatch with canonical |
| ItemList | Category pages | ✅ Present (URL-only per item) |
| AggregateRating | Product pages | ❌ Missing — no star rating rich snippets |
| FAQ | Product pages | ❌ Missing — opportunity for Q&A markup |

### llms.txt
✅ Present at `https://www.surf-store.com/llms.txt` — correctly structured, cached for 1 year. One of the stronger GEO signals on the site.

### IndexNow
❌ Not implemented. No key file, no robots.txt reference.
