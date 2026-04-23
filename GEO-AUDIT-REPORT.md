# GEO Audit Report: Surf-store.com

**Audit Date:** 2026-04-02
**URL:** https://www.surf-store.com
**Business Type:** E-commerce (Water Sports Equipment)
**Company:** Sport group d.o.o., Maribor, Slovenia
**Pages Analyzed:** 30 (homepage, 7 categories, 14 subcategory/brand/policy pages, 5 product pages, 4 policy pages)

---

## Executive Summary

**Overall GEO Score: 33/100 — Critical**

Surf-store.com has solid technical infrastructure (server-side rendering, Cloudflare CDN, fast response times) but is almost entirely invisible to AI systems as a citable, authoritative source. The site scores in the critical range primarily because product descriptions are not visible to AI crawlers (JavaScript-rendered), there is no entity presence beyond a single Instagram link, no llms.txt, and the brand has a 2.1-star Trustpilot profile with 134 reviews that actively damages reputation when AI systems surface it. The good news: most gaps are fixable with 4–8 weeks of focused work, and the content that does exist (category descriptions, About Us, shipping policy) is well-written and citable once structural issues are resolved.

### Score Breakdown

| Category | Score | Weight | Weighted Score |
|---|---|---|---|
| AI Citability | 22/100 | 25% | 5.5 |
| Brand Authority | 22/100 | 20% | 4.4 |
| Content E-E-A-T | 38/100 | 20% | 7.6 |
| Technical GEO | 58/100 | 15% | 8.7 |
| Schema & Structured Data | 28/100 | 10% | 2.8 |
| Platform Optimization | 41/100 | 10% | 4.1 |
| **Overall GEO Score** | | | **33/100 — Critical** |

---

## Critical Issues (Fix Immediately)

### 1. Product descriptions not visible to AI crawlers
**All 1,128 product pages** render their descriptions via JavaScript `fetch()` calls. An AI crawler (GPTBot, ClaudeBot, PerplexityBot) receives only a product title and price — zero description, specifications, or context. A store selling a €1,463 kite cannot be cited by any AI for a query like "What is the Duotone Dice SLS 2025?" because the crawlable page contains no answer. This affects 100% of the product catalog.

**Fix:** Server-render product descriptions in the initial HTML response from Spree. The description, key specs, and "who is this for?" paragraph must be in the HTML `<body>` without JavaScript execution.

### 2. Trustpilot profile — 2.1/5 stars, 134 reviews
AI models that browse the web (ChatGPT, Perplexity, Gemini) will surface this Trustpilot profile in response to queries like "is surf-store.com reliable?" The dominant narrative — non-delivery, false tracking, payment disputes, non-responsive support — will be cited verbatim. No amount of schema or llms.txt work can neutralise this while the score remains at 2.1 stars. This is an operational problem, not a technical one, and must be addressed before investing heavily in other GEO work.

**Fix:** Resolve fulfilment issues operationally. Implement post-purchase review solicitation for satisfied customers. Respond to all existing negative reviews professionally. Target: 4.0+ stars within 6 months.

### 3. No llms.txt file
A request to `https://www.surf-store.com/llms.txt` returns 404. The llms.txt standard allows AI systems to understand the site's structure and locate authoritative content. For an e-commerce site with 1,448 URLs and 6 sport categories across 21 brands, this guidance is particularly valuable.

**Fix:** Create and deploy `/llms.txt` (see template in AI Visibility section below).

### 4. No entity presence for AI systems
The Organization schema has a single `sameAs` entry (Instagram). No Wikipedia article, no Wikidata entity, no LinkedIn company page. AI models cannot independently verify this organization's identity or link it to their training knowledge. This contributes to the low brand authority score across every platform.

**Fix:** Create a LinkedIn company page. Create a Wikidata Q-item. Update Organization schema `sameAs` to include all verified profiles.

---

## High Priority Issues

### 5. HTML `lang="sl-SI"` but content is in English
The `<html lang="sl-SI">` attribute declares the page as Slovenian, but all visible content is in English. AI crawlers that classify content by language will suppress this site from English-language AI responses about kiteboarding retailers — the primary target market.

**Fix:** Change `<html lang="en">` in the application layout.

### 6. Homepage missing from XML sitemap
The sitemap contains 1,448 URLs but `https://www.surf-store.com/` is not among them. The homepage is the highest-priority URL for any sitemap.

**Fix:** Add homepage as first sitemap entry with `<priority>1.0</priority>`.

### 7. Product schema missing `brand` property
Every product page schema lacks `"brand": {"@type": "Brand", "name": "Duotone"}`. For a shop whose primary value proposition is official dealership of major brands, this is a critical schema gap.

**Fix:** Add `brand` to Product JSON-LD in the Spree product page template.

### 8. Homepage has no H1 tag
The most important page on the site has no H1. Only H2s appear ("New Arrivals", "Best Sellers"). AI crawlers rely on H1 as the primary content signal for a page.

**Fix:** Add an H1 to the homepage hero section, e.g. "Europe's Premier Water Sports Shop".

### 9. No named authors anywhere on the site
Not a single staff member, product expert, or author is named on any page. This eliminates Expertise signals from E-E-A-T entirely. AI systems cannot attribute content to a credentialed person.

**Fix:** Add a team section to the About Us page with at least 3 staff members, their roles, and water sports disciplines.

### 10. www vs non-www serves duplicate content
`https://surf-store.com` and `https://www.surf-store.com` both return HTTP 200 with identical content. Canonical tags point to www, but there is no server-level HTTP redirect to enforce this.

**Fix:** Configure Cloudflare or the server to 301-redirect `surf-store.com` → `www.surf-store.com`.

### 11. Homepage missing `og:image`
The homepage Open Graph block has title, description, URL, and type but no image. When AI systems preview or cite the homepage URL there is no image for rich display.

**Fix:** Add `<meta property="og:image" content="[store hero image URL]">` to the homepage head.

---

## Medium Priority Issues

### 12. No FAQPage schema on category pages
Zero question-based content or FAQ schema anywhere on the site. FAQ schema is one of the highest-leverage actions for Google AI Overviews and Gemini.

**Fix:** Add 4 Q&A pairs with FAQPage JSON-LD to the 5 highest-traffic category pages (Kitesurfing, Wingsurfing, Wetsuits, Windsurfing, SUP).

### 13. Product canonical URLs use locale prefix, category URLs do not
Products: `/sl-SI/products/slug` (locale-prefixed). Categories: `/t/categories/slug` (no locale). All 1,128 sitemap product URLs carry the `/sl-SI/` prefix — this is what Google indexes as canonical.

**Fix:** Decide on one URL convention. Either add locale prefix consistently everywhere (and implement hreflang), or remove it from products and use `/products/slug` throughout. Update sitemap accordingly.

### 14. BreadcrumbList schema uses locale-prefixed non-canonical URLs
BreadcrumbList `item` values reference `https://www.surf-store.com/sl-SI` as the homepage and `/sl-SI/t/categories/...` for category breadcrumbs. These mismatch the actual canonical URLs used by the rest of the site.

**Fix:** Generate breadcrumb URLs using canonical (non-locale-prefixed) routes in the Spree schema helper.

### 15. 195 tag/filter pages in sitemap dilute crawl budget
Tag pages like `/t/tags/ss23`, `/t/tags/2mm-men` are thin filter pages with minimal content. Having 195 of them in the sitemap wastes crawl budget.

**Fix:** Add `<meta name="robots" content="noindex, follow">` to tag pages and remove them from the sitemap.

### 16. No Bing Webmaster Tools verification or IndexNow
No `msvalidate.01` meta tag. No IndexNow API key. For an e-commerce store with frequent inventory/price changes, IndexNow delivers near-instant Bing indexing.

**Fix:** Verify site in Bing Webmaster Tools. Implement IndexNow and integrate pings into Spree's post-save callbacks for products.

### 17. Meta description 45 characters over guideline
Homepage meta description is 205 characters (recommended max: 160). Will be truncated in SERPs.

**Fix:** Trim to: `"Europe's premier shop for kiteboarding, windsurfing, wingsurfing & wetsuits. Official Duotone, ION, Cabrinha dealer. Free EU shipping from €99."` (148 characters).

### 18. About Us page too thin (320 words, generic content)
The About Us page is AI-generated in style — correct heading structure but zero specific claims, no founding story, no team details, no proprietary data. The most citable fact it contains is the founding year.

**Fix:** Rewrite with: founder name and story, why water sports, specific milestone years, named staff profiles, real customer win stories.

### 19. Product prices in schema use `http://schema.org/InStock` (not https)
A minor but validatable error: `availability` values use HTTP, not HTTPS schema.org URLs.

**Fix:** Replace `"http://schema.org/InStock"` with `"https://schema.org/InStock"` in the Spree Product schema template.

### 20. Missing Google Business Profile
No GBP found for Sport group d.o.o. in Maribor. A verified GBP is one of the strongest Google Gemini / Google AI Overviews entity signals for a regional retailer.

**Fix:** Create and verify a Google Business Profile at the Maribor address.

---

## Low Priority Issues

### 21. Category images missing width/height attributes (CLS risk)
All 6 above-fold category images have no explicit width/height, causing layout shift before images load.

**Fix:** Add CSS `aspect-ratio` values or explicit width/height attributes to category panel images.

### 22. CDN cache TTL is very short (s-maxage=120)
Cloudflare only caches pages for 2 minutes. Category and product pages with stable content should be cached for hours, not minutes.

**Fix:** Increase `s-maxage` to 3600 (1 hour) for product and category pages. Implement cache purging on product update via Spree webhook.

### 23. Homepage title 10 characters over recommended length
`Surf-store.com - Kiteboarding, Windsurfing, Wingsurfing & SUP Shop` is 70 characters. Recommended max: 60.

**Fix:** Shorten to `Kiteboarding, Windsurfing & SUP Shop | Surf-store.com` (52 chars).

### 24. One product has OG description referencing "Surfworld"
The `cabrinha-cab-prestige-wing-kit-2026` product's OG description contains "Surfworld" instead of "Surf-store.com". Brand name inconsistency confuses entity resolution in AI systems.

**Fix:** Audit all 1,128 product OG descriptions for brand name consistency.

---

## Category Deep Dives

### AI Citability — 22/100
The site's content is almost entirely either JavaScript-rendered (product pages) or present as tagline fragments (homepage trust bar). The five most-citable passages on the entire site are: the shipping thresholds (free EU from €99, worldwide from €299), the founding year (2003), the brand dealer list, the beginner kite size recommendation ("9–12m depending on weight"), and the same-day dispatch policy for orders before noon CET.

No content block on the site scores above 50/100 for AI citability. The About Us page is the best-performing page (44/100) simply because it contains verifiable facts about the legal entity.

**Best existing citable passage:**
> "Beginners should look for a stable, forgiving kite (9–12m depending on weight) that offers good depower and safety systems. As skills progress, riders can explore different kite shapes for freestyle or big air performance."

This is the only sentence on the site that an AI could plausibly cite for a substantive water sports query.

**To raise this score to 65+:** Every product page needs a server-rendered 100-150 word description. Every category page needs a 300-word buyer guide with question-based subheadings. The About Us needs a rewrite with real people and real data.

---

### Brand Authority — 22/100

| Platform | Status |
|---|---|
| Wikipedia | Absent |
| Wikidata | Absent |
| LinkedIn | Absent |
| Reddit | Not verifiable (blocked) |
| YouTube | Possible channel — unconfirmed |
| Trustpilot | 2.1/5 stars, 134 reviews — actively negative |
| Google Reviews | Not found |
| Industry press | No mentions found |
| Instagram | Present (@surfstore_com) |

The Trustpilot situation is the most urgent brand authority issue. AI systems that search for "surf-store.com reviews" will return this profile and its fraud-accusation narrative. All other brand authority work is secondary to resolving this.

**To raise this score to 60+:** Create LinkedIn and Wikidata entities (quick wins). Resolve operational issues driving Trustpilot reviews. Commission 2 water sports press mentions (Kiteboarder Magazine, Windsurf Magazine, etc.). Add a verified review widget to the site.

---

### Content E-E-A-T — 38/100

**Strongest dimension:** Trustworthiness (18/25) — SSL, full address, VAT ID, named carriers (DPD/GLS/DHL), named payment processor (Saferpay/Worldline), GDPR-compliant privacy policy.

**Weakest dimension:** Experience (7/25) — "Since 2003" and "+6000 customers" are stated but never demonstrated. No staff names, no gear test content, no session reports, no photos of team members in the water.

**Content that exists and is good:**
- Category descriptions are substantive and include real buying guidance
- Product prose descriptions (when visible) are high-quality and specific
- Shipping and returns policies are clearly documented with named carriers
- Privacy policy is GDPR-complete

**Content that is missing entirely:**
- Named authors on any page
- Founder or team profiles
- Buying guides (800+ words) for any sport category
- Comparison content ("Duotone Dice vs. Duotone Neo — which kite is right for you?")
- Customer success stories or case studies
- Product reviews from verified purchasers

---

### Technical GEO — 58/100

**Strengths:**
- Server-side rendering: all structural content (categories, navigation, footer, schema) is in the initial HTML response — AI crawlers do not need JavaScript
- Fast server response: TTFB 32ms, Cloudflare CDN, HTTP/2
- Security headers: HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy all present
- Sitemap: 1,448 URLs with lastmod dates
- Clean robots.txt: no AI crawlers blocked

**Weaknesses:**
- Homepage "New Arrivals" and "Best Sellers" are empty containers filled by JavaScript API calls — invisible to AI crawlers
- `lang="sl-SI"` vs English content mismatch — language classification error
- www/non-www both serve content without redirect
- Locale URL inconsistency (`/sl-SI/` on products, none on categories)
- 2-minute CDN cache TTL — most pages served from origin, not edge

---

### Schema & Structured Data — 28/100

**What exists:**
- Organization schema on all pages (valid syntax, critically thin)
- Product schema on product pages (functional but missing: brand, aggregateRating, gtin, priceValidUntil, seller, shippingDetails)
- BreadcrumbList on product/category pages (valid but uses wrong URLs — locale-prefixed instead of canonical)
- ItemList on category pages (URL-only, no names or descriptions)

**What is entirely absent:**
- LocalBusiness / SportingGoodsStore schema with physical address
- WebSite + SearchAction (sitelinks search box signal)
- FAQPage schema
- AggregateRating on products
- Author / Person schema
- speakable markup
- sameAs links beyond Instagram (no Wikidata, LinkedIn, Wikipedia)

---

### Platform Optimization — 41/100

| Platform | Score | Primary Gap |
|---|---|---|
| Google AI Overviews | 48/100 | No FAQPage schema, no question-based headings |
| Google Gemini | 46/100 | No Product JSON-LD with Offers (only OG tags), no GBP |
| ChatGPT Web Search | 35/100 | No Wikidata entity, no Wikipedia, no LinkedIn |
| Perplexity AI | 38/100 | No Reddit/forum presence, no verified reviews |
| Bing Copilot | 38/100 | No IndexNow, no Bing Webmaster Tools, no LinkedIn |

**Cross-platform quick wins** (improve all platforms at once):
1. Add Product JSON-LD to all product pages
2. Create Wikidata entity + update Organization `sameAs`
3. Create LinkedIn company page
4. Add FAQPage schema to category pages
5. Implement IndexNow

---

## Recommended llms.txt

Create this file at `https://www.surf-store.com/llms.txt`:

```
# Surf-store.com

> Surf-store.com is a European water sports equipment retailer specialising in
> kitesurfing, windsurfing, wingsurfing, SUP, and electric foiling gear.
> Operated by Sport group d.o.o., Maribor, Slovenia. Trading since 2003.
> Official dealer of Duotone, ION, Fanatic, Neilpryde, Cabrinha, Nobile,
> Point7, Tabou, JP Australia, and Gaastra.

## About

- [About Surf-store.com](https://www.surf-store.com/policies/about-us): Company history, mission, and team
- [Contact](https://www.surf-store.com/policies/contact): info@surf-store.com

## Shopping Policies

- [Shipping Policy](https://www.surf-store.com/policies/shipping-policy): EU free shipping from €99, worldwide from €299
- [Returns Policy](https://www.surf-store.com/policies/returns-refund-policy): 30-day free returns
- [Terms & Conditions](https://www.surf-store.com/policies/terms-and-conditions): Full legal terms
- [Privacy Policy](https://www.surf-store.com/policies/privacy-policy): GDPR-compliant data policy

## Product Categories

- [Kitesurfing](https://www.surf-store.com/t/categories/kitesurfing): Kites, boards, bars, harnesses, foils, and accessories
- [Windsurfing](https://www.surf-store.com/t/categories/windsurf): Boards, sails, foils, and accessories
- [Wingsurfing](https://www.surf-store.com/t/categories/wingfoil): Wings, boards, and foil packages
- [SUP](https://www.surf-store.com/t/categories/sup-board): Stand-up paddleboards and paddles
- [Wetsuits](https://www.surf-store.com/t/categories/wetsuits): Wetsuits for men, women, and kids
- [E-Foil](https://www.surf-store.com/t/categories/e-foil): Electric foil boards
- [Apparel](https://www.surf-store.com/t/categories/apparel): Water sports clothing

## Brands

- [Duotone](https://www.surf-store.com/t/brands/duotone-kiteboarding): Kites, boards, wings, and accessories
- [ION](https://www.surf-store.com/t/brands/ion): Wetsuits, harnesses, and protection
- [Fanatic](https://www.surf-store.com/t/brands/fanatic-windsurfing): Boards for SUP and windsurfing
- [Neilpryde](https://www.surf-store.com/t/brands/neilpryde): Sails, kites, and wetsuits
- [Cabrinha](https://www.surf-store.com/t/brands/cabrinha): Kite systems and foils
- [Nobile](https://www.surf-store.com/t/brands/nobile): Kiteboards and snowkite equipment
```

---

## Quick Wins (Implement This Week)

1. **Add `<html lang="en">`** — Change from `sl-SI` to `en` in application layout. 5-minute fix. Stops AI systems classifying the site as Slovenian.

2. **Create `/llms.txt`** — Copy the template above. Deploy as a static file served at the domain root. 30-minute task. Directly raises AI Visibility score.

3. **Add `brand` to Product schema** — One line change in the Spree product JSON-LD template: `"brand": {"@type": "Brand", "name": "<%= product.brand_name %>"}`. Affects all 1,128 product pages.

4. **Add homepage H1** — Add `<h1 class="sr-only">Europe's Water Sports Shop — Kiteboarding, Windsurfing, Wingsurfing & SUP</h1>` to the homepage layout. If preferred, make it visible in the hero section.

5. **Add homepage to sitemap** — Add one `<url>` entry for `https://www.surf-store.com/` with `<priority>1.0</priority>` to the sitemap generator.

6. **Create LinkedIn company page** — Create Sport group d.o.o. / Surf-store.com on LinkedIn with complete profile. 60 minutes. Update Organization schema `sameAs` to include the URL.

7. **Fix www/non-www redirect** — Configure Cloudflare Page Rule: `surf-store.com/*` → 301 to `https://www.surf-store.com/$1`.

8. **Add Bing Webmaster Tools verification** — Add `<meta name="msvalidate.01" content="[code]">` to application layout after verifying in Bing Webmaster Tools.

---

## 30-Day Action Plan

### Week 1: Technical Foundations
- [ ] Change `<html lang="en">` in application layout
- [ ] Add H1 to homepage
- [ ] Add homepage to XML sitemap
- [ ] Fix www → non-www 301 redirect via Cloudflare
- [ ] Shorten homepage meta description to under 160 characters
- [ ] Fix `lang` in Open Graph on homepage
- [ ] Create and deploy `/llms.txt`
- [ ] Verify site in Bing Webmaster Tools, add `msvalidate.01` meta tag

### Week 2: Schema Fixes
- [ ] Expand Organization `sameAs`: add LinkedIn, Facebook, YouTube (once profiles created)
- [ ] Add `address`, `telephone`, `foundingDate` to Organization schema
- [ ] Add `brand` property to all Product schemas
- [ ] Fix `http://` → `https://` in Product schema `availability` values
- [ ] Fix BreadcrumbList to use canonical (non-locale-prefixed) URLs
- [ ] Add `LocalBusiness` / `SportingGoodsStore` schema to homepage
- [ ] Add `WebSite` + `SearchAction` schema to homepage
- [ ] Add `seller` and `priceValidUntil` to all Offer objects in Product schema

### Week 3: Content & Authority
- [ ] Create LinkedIn company page for Sport group d.o.o.
- [ ] Create Wikidata Q-item for the company
- [ ] Rewrite About Us page: add founder story, 3 staff profiles with names and disciplines, real company milestones
- [ ] Add 4 Q&A pairs with FAQPage JSON-LD to Kitesurfing category page
- [ ] Add 4 Q&A pairs with FAQPage JSON-LD to Wetsuits category page
- [ ] Expand each category description from ~200 words to 400+ words with question-based H3 subheadings
- [ ] Create Google Business Profile for Maribor location

### Week 4: Product Pages & Reviews
- [ ] Investigate and fix JavaScript-rendered product descriptions (server-render in Spree template)
- [ ] Implement IndexNow API integration for product/category updates
- [ ] Set up Trustpilot Business account and begin review recovery program
- [ ] Implement post-purchase review request emails
- [ ] Add `noindex` meta tag to 195 tag filter pages
- [ ] Remove tag pages from XML sitemap
- [ ] Increase Cloudflare cache TTL to 3600s for product/category pages

---

## Appendix: Pages Analyzed

| URL | Title | Key Issues Found |
|---|---|---|
| https://www.surf-store.com/ | Surf-store.com - Kiteboarding... | No H1, no og:image, no homepage in sitemap, JS-only product carousels |
| https://www.surf-store.com/t/categories/kitesurfing | Kitesurfing | No FAQ schema, no H3 question headings, thin category description |
| https://www.surf-store.com/t/categories/windsurf | Windsurfing | Same as kitesurfing |
| https://www.surf-store.com/t/categories/wingfoil | Wingsurfing / Wing Foiling | Same as kitesurfing |
| https://www.surf-store.com/t/categories/wetsuits | Wetsuits | Same as kitesurfing |
| https://www.surf-store.com/t/categories/sup-board | SUP | Same as kitesurfing |
| https://www.surf-store.com/t/categories/e-foil | E-Foil | Same as kitesurfing |
| https://www.surf-store.com/t/categories/apparel | Apparel | Same as kitesurfing |
| https://www.surf-store.com/t/categories/kitesurfing/kites | Kitesurfing Kites | No FAQ, ItemList has URL-only ListItems |
| https://www.surf-store.com/t/brands/duotone-foiling-and-electric | Duotone | No brand entity schema |
| https://www.surf-store.com/t/brands | Brands | No schema, thin content |
| https://www.surf-store.com/sl-SI/products/duotone-dice-sls-2025 | Duotone Dice SLS 2025 | Product schema missing brand/aggregateRating/gtin, BreadcrumbList locale URL bug |
| https://www.surf-store.com/sl-SI/products/cabrinha-cab-prestige-wing-kit-2026 | Cabrinha Prestige Wing Kit | OG description references "Surfworld" brand name error |
| https://www.surf-store.com/policies/about-us | About Us | 320 words, no author names, generic content |
| https://www.surf-store.com/policies/contact | Contact | Minimal content, no phone number |
| https://www.surf-store.com/policies/shipping-policy | Shipping Policy | Not in sitemap |
| https://www.surf-store.com/policies/returns-refund-policy | Returns Policy | Not in sitemap |
| https://www.surf-store.com/policies/privacy-policy | Privacy Policy | Not in sitemap |
| https://www.surf-store.com/policies/terms-and-conditions | Terms & Conditions | Not in sitemap |
| https://www.surf-store.com/robots.txt | robots.txt | Sitemap references .gz only, no AI-specific allow rules |

---

*Report generated by GEO Audit — Generative Engine Optimization analysis for AI search visibility.*
*Score methodology: AI Citability 25% + Brand Authority 20% + Content E-E-A-T 20% + Technical GEO 15% + Schema 10% + Platform Optimization 10%*
