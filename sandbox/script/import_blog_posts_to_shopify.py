#!/usr/bin/env python3
"""
Imports a Spree blog-posts JSON export into Shopify via the Admin REST API.

Usage:
  export SHOPIFY_STORE="surf-store-europe.myshopify.com"
  export SHOPIFY_ADMIN_TOKEN="shpat_xxxxxxxxxxxxx"
  python3 sandbox/script/import_blog_posts_to_shopify.py path/to/blog_posts_export.json

Accepts the Spree export shape (slug, category, excerpt, meta_title, ...).

Behaviour:
  - Looks up the target Shopify blog by handle (creates a "news" blog if missing).
  - For each post, POSTs an Article with body_html, image (fetched from URL),
    tags, author, published_at, and SEO metafields (title_tag, description_tag).
  - Idempotent: skips articles whose handle already exists in the blog.
  - Handles 429 rate-limits with exponential backoff.
  - The Spree slug becomes the Shopify article handle (same URL slug).
"""

import json
import os
import re
import sys
import time
from urllib import request, parse, error

STORE = os.environ.get("SHOPIFY_STORE", "").rstrip("/")
TOKEN = os.environ.get("SHOPIFY_ADMIN_TOKEN", "")
API   = "2024-10"

if not STORE or not TOKEN:
    sys.exit("Set SHOPIFY_STORE and SHOPIFY_ADMIN_TOKEN env vars first.")

if len(sys.argv) < 2:
    sys.exit(f"Usage: {sys.argv[0]} path/to/blog_posts_export.json")

INPUT = sys.argv[1]
BASE  = f"https://{STORE}/admin/api/{API}"
HEADERS = {
    "X-Shopify-Access-Token": TOKEN,
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def api(method, path, body=None):
    url  = f"{BASE}{path}"
    data = json.dumps(body).encode("utf-8") if body else None
    req  = request.Request(url, data=data, method=method, headers=HEADERS)
    for attempt in range(6):
        try:
            with request.urlopen(req, timeout=60) as resp:
                return json.loads(resp.read().decode("utf-8")) if resp.status != 204 else {}
        except error.HTTPError as e:
            if e.code in (429, 503):
                wait = 2 ** attempt
                print(f"  {e.code} rate-limited, sleeping {wait}s...")
                time.sleep(wait); continue
            print(f"  HTTP {e.code} {url}: {e.read().decode('utf-8','ignore')[:400]}")
            raise
    raise RuntimeError("Too many retries")


def find_or_create_blog(handle):
    blogs = api("GET", f"/blogs.json?handle={parse.quote(handle)}").get("blogs", [])
    if blogs:
        return blogs[0]["id"]
    print(f"  Creating blog '{handle}'")
    title = handle.replace("-", " ").title()
    return api("POST", "/blogs.json", {"blog": {"title": title, "handle": handle}})["blog"]["id"]


def find_existing_article(blog_id, handle):
    arts = api("GET", f"/blogs/{blog_id}/articles.json?handle={parse.quote(handle)}").get("articles", [])
    return arts[0] if arts else None


def split_tags(raw):
    if not raw: return []
    if isinstance(raw, list): return [str(t).strip() for t in raw if str(t).strip()]
    return [s.strip() for s in re.split(r"[,]", str(raw)) if s.strip()]


def normalize(post):
    """Map Spree-export keys → importer keys. Tolerates both shapes."""
    slug = post.get("handle") or post.get("slug")
    return {
        "blog_handle":     post.get("blog_handle") or post.get("category") or "news",
        "handle":          slug,
        "title":           post.get("title") or slug,
        "author":          post.get("author") or "Surf Store Team",
        "body_html":       post.get("body_html") or "",
        "summary_html":    post.get("summary_html") or post.get("excerpt") or "",
        "image_url":       post.get("image_url"),
        "tags":            split_tags(post.get("tags")),
        "published_at":    post.get("published_at"),
        "seo_title":       post.get("seo_title") or post.get("meta_title") or post.get("title") or "",
        "seo_description": post.get("seo_description") or post.get("meta_description") or "",
    }


def set_metafield(article_id, key, value):
    if not value: return
    api("POST", f"/articles/{article_id}/metafields.json", {
        "metafield": {
            "namespace": "global", "key": key,
            "type": "single_line_text_field", "value": value
        }
    })


def main():
    with open(INPUT) as f:
        raw_posts = json.load(f)

    posts = [normalize(p) for p in raw_posts if p.get("slug") or p.get("handle")]
    print(f"Loaded {len(posts)} posts from {INPUT}")
    print(f"Target store: {STORE}")
    print()

    blog_cache, created, skipped, failed = {}, 0, 0, 0

    for i, p in enumerate(posts, 1):
        handle, blog_handle = p["handle"], p["blog_handle"]
        try:
            blog_id = blog_cache.get(blog_handle) or find_or_create_blog(blog_handle)
            blog_cache[blog_handle] = blog_id

            if find_existing_article(blog_id, handle):
                print(f"[{i}/{len(posts)}] SKIP {handle}")
                skipped += 1; continue

            article = {
                "title":        p["title"],
                "author":       p["author"],
                "handle":       handle,
                "body_html":    p["body_html"],
                "summary_html": p["summary_html"],
                "tags":         ", ".join(p["tags"]),
                "published":    bool(p.get("published_at")),
                "published_at": p.get("published_at"),
            }
            if p.get("image_url"):
                article["image"] = {"src": p["image_url"]}

            res = api("POST", f"/blogs/{blog_id}/articles.json", {"article": article})
            article_id = res["article"]["id"]

            set_metafield(article_id, "title_tag", p["seo_title"])
            set_metafield(article_id, "description_tag", p["seo_description"])

            print(f"[{i}/{len(posts)}] OK   {handle} -> blog {blog_handle} (id {article_id})")
            created += 1
            time.sleep(0.6)  # gentle pacing — Shopify allows 2 req/s on REST

        except Exception as e:
            print(f"[{i}/{len(posts)}] FAIL {handle}: {e}")
            failed += 1

    print()
    print("=" * 50)
    print(f"Created: {created}   Skipped: {skipped}   Failed: {failed}")


if __name__ == "__main__":
    main()
