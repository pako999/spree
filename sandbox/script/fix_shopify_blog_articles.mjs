#!/usr/bin/env node
/**
 * Fixes broken images and links in Shopify blog articles migrated from Spree.
 *
 * Usage:
 *   export SHOPIFY_STORE="surf-store-europe.myshopify.com"
 *   export SHOPIFY_ADMIN_TOKEN="shpat_..."
 *   node sandbox/script/fix_shopify_blog_articles.mjs            # run for real
 *   node sandbox/script/fix_shopify_blog_articles.mjs --dry-run  # show diffs, no PUT
 *
 * What it does (idempotent — safe to re-run):
 *   1. Backs up every article body to backup_articles_<timestamp>.json
 *   2. For each body_html, rewrites:
 *      - Spree active_storage proxy/redirect <img src> → Shopify product CDN
 *        (matches product by <img alt> via GraphQL product search; cached)
 *      - href="/posts/<slug>"           → "/blogs/news/<slug>"
 *      - href="/posts" (breadcrumb)     → "/blogs/news"
 *      - href="/t/categories/<path>"    → "/collections/<handle>" (mapping below)
 *      - "/images/categories/<file>"    → matching collection image URL
 *   3. PUTs the new body via REST Admin API
 *   4. Writes unresolved.json listing images it could not match (manual review)
 *
 * Notes:
 *   - Titles, handles, slugs, publish dates are never modified.
 *   - /products/... links are left alone (Spree slugs == Shopify handles per CLAUDE.md).
 *   - 250ms throttle between API calls. Honors 429/503 with exponential backoff.
 *   - Requires Node 18+ (uses built-in fetch).
 */

import fs from 'node:fs/promises';

const STORE    = process.env.SHOPIFY_STORE;
const TOKEN    = process.env.SHOPIFY_ADMIN_TOKEN;
const BLOG_ID  = process.env.SHOPIFY_BLOG_ID || '90090832112';
const API_VER  = '2024-10';
const DELAY_MS = 250;
const DRY_RUN  = process.argv.includes('--dry-run');

if (!STORE || !TOKEN) {
  console.error('Set SHOPIFY_STORE and SHOPIFY_ADMIN_TOKEN env vars first.');
  process.exit(1);
}

const BASE = `https://${STORE}/admin/api/${API_VER}`;
const HEADERS = {
  'X-Shopify-Access-Token': TOKEN,
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ────────────────────────────────────────────────────────────────────────────
// API helpers
// ────────────────────────────────────────────────────────────────────────────

async function rest(method, path, body) {
  for (let attempt = 0; attempt < 6; attempt++) {
    const res = await fetch(`${BASE}${path}`, {
      method,
      headers: HEADERS,
      body: body ? JSON.stringify(body) : undefined,
    });
    if (res.status === 429 || res.status === 503) {
      const wait = 2 ** attempt * 1000;
      console.log(`  ${res.status} rate-limited, waiting ${wait}ms`);
      await sleep(wait);
      continue;
    }
    const text = await res.text();
    if (!res.ok) throw new Error(`${res.status} ${method} ${path}: ${text.slice(0, 300)}`);
    return { json: text ? JSON.parse(text) : {}, headers: res.headers };
  }
  throw new Error('Too many retries');
}

async function graphql(query, variables = {}) {
  for (let attempt = 0; attempt < 6; attempt++) {
    const res = await fetch(`${BASE}/graphql.json`, {
      method: 'POST',
      headers: HEADERS,
      body: JSON.stringify({ query, variables }),
    });
    if (res.status === 429 || res.status === 503) {
      await sleep(2 ** attempt * 1000); continue;
    }
    const data = await res.json();
    if (data.errors) throw new Error(JSON.stringify(data.errors));
    return data.data;
  }
  throw new Error('Too many retries');
}

// ────────────────────────────────────────────────────────────────────────────
// Fetch articles + collections
// ────────────────────────────────────────────────────────────────────────────

async function fetchAllArticles() {
  const all = [];
  let url = `${BASE}/blogs/${BLOG_ID}/articles.json?limit=50`;
  while (url) {
    const res = await fetch(url, { headers: HEADERS });
    const data = await res.json();
    all.push(...(data.articles || []));
    const link = res.headers.get('link') || '';
    const m = link.match(/<([^>]+)>;\s*rel="next"/);
    url = m ? m[1] : null;
    await sleep(DELAY_MS);
  }
  return all;
}

async function fetchCollections() {
  const out = [];
  let cursor = null;
  while (true) {
    const data = await graphql(
      `query($cursor: String) {
         collections(first: 250, after: $cursor) {
           edges { cursor node { id handle title image { url } } }
           pageInfo { hasNextPage }
         }
       }`,
      { cursor },
    );
    for (const e of data.collections.edges) out.push(e.node);
    if (!data.collections.pageInfo.hasNextPage) break;
    cursor = data.collections.edges.at(-1).cursor;
    await sleep(DELAY_MS);
  }
  return out;
}

const productCache = new Map();
async function findProductImage(altText) {
  if (!altText) return null;
  const key = altText.trim().toLowerCase();
  if (productCache.has(key)) return productCache.get(key);
  const data = await graphql(
    `query($q: String!) {
       products(first: 1, query: $q) {
         edges { node { title handle featuredImage { url } } }
       }
     }`,
    { q: altText.trim() },
  );
  const url = data.products.edges[0]?.node?.featuredImage?.url || null;
  productCache.set(key, url);
  await sleep(DELAY_MS);
  return url;
}

// ────────────────────────────────────────────────────────────────────────────
// HTML rewrites
// ────────────────────────────────────────────────────────────────────────────

// Old Spree path → new Shopify path. Longest first wins (sorted at apply time).
const CATEGORY_MAP = {
  '/t/categories/kitesurfing/kiteboards/kiteboard': '/collections/kiteboards',
  '/t/categories/kitesurfing/kiteboards':           '/collections/kiteboards',
  '/t/categories/kitesurfing/kites':                '/collections/kites',
  '/t/categories/kitesurfing':                      '/collections/kitesurfing',
  '/t/categories/wingfoil/wings':                   '/collections/wings',
  '/t/categories/wingfoil/boards':                  '/collections/wing-foil-boards',
  '/t/categories/wingfoil/foils':                   '/collections/foils',
  '/t/categories/wingfoil':                         '/collections/wing-foil',
  '/t/categories/windsurf/windsurf-sails':          '/collections/windsurf-sails',
  '/t/categories/windsurf/windsurf-boards':         '/collections/windsurf-boards',
  '/t/categories/windsurf/sails':                   '/collections/windsurf-sails',
  '/t/categories/windsurf/boards':                  '/collections/windsurf-boards',
  '/t/categories/windsurf':                         '/collections/windsurf',
  '/t/categories/sup':                              '/collections/sup',
  '/t/categories/wetsuits':                         '/collections/wetsuits',
  '/t/categories/harnesses':                        '/collections/harnesses',
};

// /images/categories/<basename>.<ext>  →  collection handle to use
const CATEGORY_IMAGE_MAP = {
  kiteboarding: 'kitesurfing',
  kitesurfing:  'kitesurfing',
  windsurfing:  'windsurf',
  wingsurfing:  'wing-foil',
  wingfoil:     'wing-foil',
  sup:          'sup',
};

function rewritePostLinks(html) {
  // href to /posts/<slug>  (with or without /en, with or without surf-store.com host)
  let n = 0;
  const out = html.replace(
    /(href=["'])(?:https?:\/\/[^\/"']*surf-store\.com)?(?:\/en)?\/posts\/([^"'?#]+)/gi,
    (_, p, slug) => { n++; return `${p}/blogs/news/${slug}`; },
  );
  return [out, n];
}

function rewriteBlogBreadcrumb(html) {
  // href ending exactly at /posts (no trailing slug)
  let n = 0;
  const out = html.replace(
    /(href=["'])(?:https?:\/\/[^\/"']*surf-store\.com)?(?:\/en)?\/posts(["'\?#])/gi,
    (_, p, end) => { n++; return `${p}/blogs/news${end}`; },
  );
  return [out, n];
}

function rewriteCategoryLinks(html) {
  let n = 0;
  const entries = Object.entries(CATEGORY_MAP).sort((a, b) => b[0].length - a[0].length);
  let out = html;
  for (const [from, to] of entries) {
    const escaped = from.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp(
      `(href=["'])(?:https?:\\/\\/[^\\/"']*surf-store\\.com)?(?:\\/en)?${escaped}(?=["'?#\\/])`,
      'gi',
    );
    out = out.replace(re, (_, prefix) => { n++; return `${prefix}${to}`; });
  }
  return [out, n];
}

function findBrokenImages(html) {
  const re = /<img\b[^>]*\bsrc=["']([^"']*\/rails\/active_storage\/blobs\/(?:proxy|redirect)\/[^"']+)["'][^>]*>/gi;
  const out = [];
  let m;
  while ((m = re.exec(html)) !== null) {
    const fullTag = m[0];
    const src = m[1];
    const altMatch = fullTag.match(/\balt=["']([^"']*)["']/i);
    out.push({ fullTag, src, alt: altMatch?.[1] || '' });
  }
  return out;
}

async function rewriteBrokenImages(html, unresolvedSink) {
  const tags = findBrokenImages(html);
  let fixed = 0, failed = 0;
  let out = html;
  for (const tag of tags) {
    const newUrl = await findProductImage(tag.alt);
    if (newUrl) {
      const updated = tag.fullTag.replace(/\bsrc=["'][^"']+["']/i, `src="${newUrl}"`);
      out = out.replaceAll(tag.fullTag, updated);
      fixed++;
    } else {
      failed++;
      unresolvedSink.push({ alt: tag.alt, src: tag.src });
    }
  }
  return [out, fixed, failed];
}

function rewriteCategoryImages(html, collectionsByHandle) {
  // Matches /images/categories/<base>.<ext> inside any quoted attribute
  const re = /["'](\/images\/categories\/([^"'?#\s]+))["']/g;
  let fixed = 0, failed = 0;
  const out = html.replace(re, (_, full, file) => {
    const base = file.replace(/\.[a-z0-9]+$/i, '').toLowerCase();
    const handle = CATEGORY_IMAGE_MAP[base] || base;
    const coll = collectionsByHandle.get(handle);
    if (coll?.image?.url) { fixed++; return `"${coll.image.url}"`; }
    failed++;
    return `"${full}"`;
  });
  return [out, fixed, failed];
}

// ────────────────────────────────────────────────────────────────────────────
// Main
// ────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`Store: ${STORE}`);
  console.log(`Blog:  ${BLOG_ID}`);
  console.log(`Mode:  ${DRY_RUN ? 'DRY RUN (no writes)' : 'LIVE — will PUT to Shopify'}`);
  console.log('');

  console.log('Fetching collections...');
  const collections = await fetchCollections();
  const collByHandle = new Map(collections.map((c) => [c.handle, c]));
  console.log(`  ${collections.length} collections loaded.`);

  console.log('Fetching articles...');
  const articles = await fetchAllArticles();
  console.log(`  ${articles.length} articles loaded.`);

  // Backup
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = `backup_articles_${ts}.json`;
  await fs.writeFile(
    backupPath,
    JSON.stringify(
      articles.map((a) => ({
        id: a.id, title: a.title, handle: a.handle, body_html: a.body_html,
      })),
      null, 2,
    ),
  );
  console.log(`  Backup → ${backupPath}\n`);

  const unresolved = [];
  const stats = {
    articles: 0, updated: 0, unchanged: 0,
    imagesFixed: 0, imagesFailed: 0,
    blogLinksFixed: 0, breadcrumbsFixed: 0,
    categoryLinksFixed: 0,
    categoryImagesFixed: 0, categoryImagesFailed: 0,
    errors: 0,
  };

  for (let i = 0; i < articles.length; i++) {
    const a = articles[i];
    stats.articles++;
    console.log(`[${i + 1}/${articles.length}] "${a.title}"`);
    try {
      const failedImagesForArticle = [];
      let html = a.body_html || '';
      let imgFixed, imgFailed, postCount, breadCount, catCount, catImgFixed, catImgFailed;

      [html, imgFixed, imgFailed] = await rewriteBrokenImages(html, failedImagesForArticle);
      [html, postCount]           = rewritePostLinks(html);
      [html, breadCount]          = rewriteBlogBreadcrumb(html);
      [html, catCount]            = rewriteCategoryLinks(html);
      [html, catImgFixed, catImgFailed] = rewriteCategoryImages(html, collByHandle);

      stats.imagesFixed         += imgFixed;
      stats.imagesFailed        += imgFailed;
      stats.blogLinksFixed      += postCount;
      stats.breadcrumbsFixed    += breadCount;
      stats.categoryLinksFixed  += catCount;
      stats.categoryImagesFixed += catImgFixed;
      stats.categoryImagesFailed += catImgFailed;

      if (failedImagesForArticle.length) {
        unresolved.push({ id: a.id, handle: a.handle, broken: failedImagesForArticle });
      }

      console.log(`  Images fixed: ${imgFixed}  (failed ${imgFailed})`);
      console.log(`  /posts → /blogs/news: ${postCount}    breadcrumbs: ${breadCount}`);
      console.log(`  /t/categories → /collections: ${catCount}`);
      console.log(`  /images/categories → CDN: ${catImgFixed}  (failed ${catImgFailed})`);

      if (html === a.body_html) {
        console.log('  No changes — skipped.');
        stats.unchanged++;
        continue;
      }
      if (DRY_RUN) {
        console.log('  [dry-run] would PUT updated body.');
        continue;
      }
      await rest('PUT', `/blogs/${BLOG_ID}/articles/${a.id}.json`, {
        article: { id: a.id, body_html: html },
      });
      console.log('  Updated.');
      stats.updated++;
      await sleep(DELAY_MS);
    } catch (e) {
      console.error(`  ERROR: ${e.message}`);
      stats.errors++;
    }
  }

  if (unresolved.length) {
    await fs.writeFile('unresolved.json', JSON.stringify(unresolved, null, 2));
    console.log(`\n${unresolved.length} articles have images that could not be matched → unresolved.json`);
  }

  console.log('\n' + '='.repeat(56));
  console.log('Summary');
  for (const [k, v] of Object.entries(stats)) console.log(`  ${k.padEnd(22)} ${v}`);
}

main().catch((e) => { console.error('Fatal:', e); process.exit(1); });
