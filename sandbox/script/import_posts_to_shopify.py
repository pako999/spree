#!/usr/bin/env python3
"""
Imports the spree_posts_export.json file (produced by
script/export_posts_to_shopify.rb) into a Shopify store via the Admin REST
API.

Usage:
  export SHOPIFY_STORE="your-store.myshopify.com"
  export SHOPIFY_ADMIN_TOKEN="shpat_xxxxxxxxxxxxx"
  python3 import_posts_to_shopify.py spree_posts_export.json

Behaviour:
  - Looks up the target blog by handle (creates a "news" blog if missing).
  - For each post, POSTs an Article with body_html, image (fetched from URL),
    tags, author, published_at, SEO fields.
  - Skips posts already imported (matched by handle inside the same blog).

Get an admin API token at: Shopify Admin → Settings → Apps and sales channels
  → Develop apps → Create app → Configure Admin API scopes → write_content
"""

import json
import os
import sys
import time
from urllib import request, parse, error

STORE  = os.environ.get("SHOPIFY_STORE", "").rstrip("/")
TOKEN  = os.environ.get("SHOPIFY_ADMIN_TOKEN", "")
API    = "2024-10"

if not STORE or not TOKEN:
    print("Set SHOPIFY_STORE and SHOPIFY_ADMIN_TOKEN env vars first.")
    sys.exit(1)

if len(sys.argv) < 2:
    print(__doc__)
    sys.exit(1)

INPUT = sys.argv[1]
BASE  = f"https://{STORE}/admin/api/{API}"
HEADERS = {
    "X-Shopify-Access-Token": TOKEN,
    "Content-Type": "application/json",
    "Accept": "application/json",
}


def api(method, path, body=None):
    """Call Shopify Admin API with simple retry + rate-limit handling."""
    url = f"{BASE}{path}"
    data = json.dumps(body).encode("utf-8") if body else None
    req = request.Request(url, data=data, method=method, headers=HEADERS)

    for attempt in range(5):
        try:
            with request.urlopen(req) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except error.HTTPError as e:
            if e.code == 429:
                wait = 2 ** attempt
                print(f"  Rate limited, sleeping {wait}s...")
                time.sleep(wait)
                continue
            body_text = e.read().decode("utf-8", errors="ignore")
            print(f"  HTTP {e.code} {url}: {body_text}")
            raise
    raise RuntimeError("Too many retries")


def find_or_create_blog(handle):
    """Return blog id by handle, creating the blog if it doesn't exist."""
    blogs = api("GET", f"/blogs.json?handle={parse.quote(handle)}").get("blogs", [])
    if blogs:
        return blogs[0]["id"]
    print(f"  Blog '{handle}' not found — creating")
    title = handle.replace("-", " ").title()
    created = api("POST", "/blogs.json", {"blog": {"title": title, "handle": handle}})
    return created["blog"]["id"]


def find_existing_article(blog_id, handle):
    res = api("GET", f"/blogs/{blog_id}/articles.json?handle={parse.quote(handle)}")
    arts = res.get("articles", [])
    return arts[0] if arts else None


def main():
    with open(INPUT) as f:
        posts = json.load(f)

    print(f"Loaded {len(posts)} posts from {INPUT}")
    print(f"Target store: {STORE}")
    print()

    blog_cache = {}
    created, skipped, failed = 0, 0, 0

    for i, p in enumerate(posts, 1):
        handle = p["handle"]
        blog_handle = p["blog_handle"]

        try:
            blog_id = blog_cache.get(blog_handle) or find_or_create_blog(blog_handle)
            blog_cache[blog_handle] = blog_id

            if find_existing_article(blog_id, handle):
                print(f"[{i}/{len(posts)}] SKIP {handle} (already in blog {blog_handle})")
                skipped += 1
                continue

            article = {
                "title":            p["title"],
                "author":           p["author"],
                "handle":           handle,
                "body_html":        p["body_html"] or "",
                "summary_html":     p["summary_html"] or "",
                "tags":             ", ".join(p.get("tags", [])),
                "published":        bool(p.get("published_at")),
                "published_at":     p.get("published_at"),
            }

            if p.get("image_url"):
                article["image"] = {"src": p["image_url"]}

            res = api("POST", f"/blogs/{blog_id}/articles.json", {"article": article})
            article_id = res["article"]["id"]

            # SEO metafields (title + description)
            if p.get("seo_title"):
                api("POST", f"/articles/{article_id}/metafields.json", {
                    "metafield": {
                        "namespace": "global",
                        "key":       "title_tag",
                        "type":      "single_line_text_field",
                        "value":     p["seo_title"]
                    }
                })
            if p.get("seo_description"):
                api("POST", f"/articles/{article_id}/metafields.json", {
                    "metafield": {
                        "namespace": "global",
                        "key":       "description_tag",
                        "type":      "single_line_text_field",
                        "value":     p["seo_description"]
                    }
                })

            print(f"[{i}/{len(posts)}] OK   {handle} -> blog {blog_handle} (id {article_id})")
            created += 1

        except Exception as e:
            print(f"[{i}/{len(posts)}] FAIL {handle}: {e}")
            failed += 1

    print()
    print("=" * 50)
    print(f"Created: {created}  Skipped: {skipped}  Failed: {failed}")


if __name__ == "__main__":
    main()
