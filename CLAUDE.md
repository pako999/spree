# Surf-Store Spree Project — Claude Code Context

## Project Overview

Spree Commerce-based surf/kitesurfing shop at **https://www.surf-store.com**
- Ruby on Rails 8 + Spree 5.4 (headless + custom storefront)
- Deployed via **Kamal** (Docker) on Hetzner server
- PostgreSQL 14 (running in Docker on production server)
- GitHub: https://github.com/pako999/spree

## Repository Structure

```
spree/
├── sandbox/          ← Main application (this is the Rails app)
│   ├── app/
│   ├── config/
│   │   ├── deploy.yml        ← Kamal deploy config
│   │   └── storage.yml       ← ActiveStorage (local disk service)
│   ├── lib/tasks/            ← Import/maintenance rake tasks
│   └── script/               ← One-off runner scripts
├── api/              ← Spree API engine (gem source)
├── core/             ← Spree Core engine (gem source)
└── admin/            ← Spree Admin engine (gem source)
```

## Production Server

- **IP:** 46.224.5.25 (Hetzner, Ubuntu 24.04)
- **SSH:** `ssh ubuntu@46.224.5.25`
- **Domain:** www.surf-store.com
- **Container name:** `surf-store`
- **App port:** 3000 (internal), Nginx proxies 80/443
- **Database:** `my_kite_shop_production` (PostgreSQL, user: ubuntu, pass: kite, host: 127.0.0.1)

## Deployment

### Deploy new code changes:
```bash
cd sandbox
bin/kamal deploy
```

### Quick: copy a file and restart (faster than full deploy):
```bash
# Copy single file to container
docker cp ./sandbox/lib/tasks/some_task.rb surf-store:/rails/lib/tasks/some_task.rb

# Restart app
ssh ubuntu@46.224.5.25 "docker restart surf-store"
```

### Run Rails commands on server:
```bash
ssh ubuntu@46.224.5.25 "docker exec surf-store bundle exec rails runner 'puts Spree::Product.count'"
ssh ubuntu@46.224.5.25 "docker exec surf-store bundle exec rake some:task"
```

### Run a script on server:
```bash
# Upload and run
scp sandbox/script/my_script.rb ubuntu@46.224.5.25:/tmp/
ssh ubuntu@46.224.5.25 "docker cp /tmp/my_script.rb surf-store:/rails/tmp/ && docker exec surf-store bundle exec rails runner /rails/tmp/my_script.rb"
```

### View logs:
```bash
ssh ubuntu@46.224.5.25 "docker logs surf-store --tail 100 -f"
ssh ubuntu@46.224.5.25 "docker exec surf-store tail -f /rails/log/production.log"
```

## Key Environment Variables (on server)

Set in Docker via Kamal secrets (`.kamal/secrets`):
- `RAILS_MASTER_KEY` — required for credential decryption
- `RAILS_STORAGE=cloudflare` — ActiveStorage service name
- `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` — Cloudflare R2 (legacy, now using local)
- `POSTGRES_PASSWORD=kite`
- `RAILS_ENV=production`

## ActiveStorage Configuration

- **Service:** Local disk (`/rails/storage/` inside container)
- **Docker volume:** `sandbox_storage` (persisted across restarts)
- **Volume path:** `/var/lib/docker/volumes/sandbox_storage/_data/` (on host)
- Files stored at: `storage/XX/YY/KEY` (2-level hash directory)

## Database Access

```bash
# From host:
ssh ubuntu@46.224.5.25 "PGPASSWORD=kite psql -h 127.0.0.1 -U ubuntu -d my_kite_shop_production"

# From inside container:
ssh ubuntu@46.224.5.25 "docker exec -it surf-store bash -c 'cd /rails && bundle exec rails dbconsole'"
```

## Key Product Import Sheets (Google Sheets)

These are all Shopify-format CSVs used to import product data and images.
Column `Variant Barcode` = EAN, `Image Src` = product image URL, `Variant Image` = variant image URL.

| Brand | Sheet URL |
|-------|-----------|
| ION Water (main) | `1I0HNNCyuTl1PJFV-3n5kn6Fz6Bk-02BFz7nlB4hjIHg` |
| ION Full | `1eo5WMuZzw6sM_4b40lOf6Dlw6IT0v59RU61xnyxbRz0` |
| Duotone Wing 2026 | `1nK_RowVZP5KDYU1WKjIyJGeOPgVJm-uIspuXPcQjOS0` |
| Duotone Wingfoil 2026 | `1OXb4No4pzBs8hwbMB7q17jMV17HTV37Nl7kwagn2OjY` |
| Duotone Windsurf DTW26 | `1fNVzmPICVpOb6CnpqFMAT-s8VueeDyZajXL0r8Qf5RQ` |
| Gaastra/Tabou | `1WQpNTIi5xcZi4pmjZoaokliFEmwxiKLCJvLdSXp3bC4` |
| Cabrinha | `1nk-NW2QXQo6uTGr00AJ2q62svZS_q3muS7_SKQVZc_s` |

To download: `curl -sL "https://docs.google.com/spreadsheets/d/SHEET_ID/export?format=csv" -o /tmp/sheet.csv`

## Image Restore Workflow

If product images are missing (ENOENT 500 errors):

```bash
# 1. Find missing blobs
ssh ubuntu@46.224.5.25 "docker run --rm -v sandbox_storage:/storage:ro -v /tmp/blobs.txt:/blobs.txt python:3.11-slim python3 -c '...'"

# 2. Build filename→URL index from all CSVs (local)
python3 sandbox/lib/tasks/restore_images.rb  # see script for details

# 3. Run Python restore container
docker run -v sandbox_storage:/storage -v /tmp/missing.txt:/missing.txt -v /tmp/urls.json:/urlindex.json python:3.11-slim python3 /restore.py
```

Key scripts:
- `sandbox/lib/tasks/restore_images.rb` — Rails runner: find+restore missing blobs
- `sandbox/lib/tasks/redownload_missing_images.rb` — EAN-based restore from CSVs
- `/tmp/restore_missing_images.py` — Pure Python restore (no Rails, faster)

## Backups

- **Database:** Daily at 3am via cron → `/home/ubuntu/backups/` (7-day retention)
- **Storage:** Included in `full_backup.sh` → `/home/ubuntu/backups/storage-YYYY-MM-DD.tar.gz`

```bash
# Manual DB backup:
ssh ubuntu@46.224.5.25 "~/backup_db.sh"

# Manual full backup (DB + storage):
ssh ubuntu@46.224.5.25 "~/full_backup.sh"
```

## Common Tasks

### Add images to products from a Google Sheet:
```bash
curl -sL "https://docs.google.com/spreadsheets/d/SHEET_ID/export?format=csv" -o /tmp/sheet.csv
scp /tmp/sheet.csv ubuntu@46.224.5.25:/tmp/products_sheet.csv
ssh ubuntu@46.224.5.25 "docker cp /tmp/products_sheet.csv surf-store:/rails/tmp/ && docker exec surf-store bundle exec rake images:import_from_csv CSV_PATH=/rails/tmp/products_sheet.csv"
```

### Check 500 image errors:
```bash
ssh ubuntu@46.224.5.25 "docker logs surf-store --since 1h 2>&1 | grep ENOENT | head -20"
```

### Purge orphaned variant records:
```bash
ssh ubuntu@46.224.5.25 "docker exec surf-store bundle exec rails runner 'ActiveStorage::VariantRecord.joins(\"LEFT JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_variant_records.blob_id\").where(active_storage_blobs: {id: nil}).delete_all'"
```

## Code Style (AGENTS.md rules apply)

See `AGENTS.md` at repo root for full Spree coding conventions.
Key rules:
- All models/controllers under `Spree::` namespace
- Use `Spree.user_class` not `Spree::User` directly  
- No foreign key constraints in migrations
- Use `Spree.base_class` for model inheritance
- `spree.` route prefix in views/controllers
- Tests in RSpec with Factory Bot
