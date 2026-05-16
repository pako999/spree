require 'open-uri'
require 'fileutils'
require 'json'

puts "=== Comprehensive Image Restore by Filename ==="
puts "Time: #{Time.current}"
puts ""

STORAGE_ROOT = '/rails/storage'

def blob_path(key)
  File.join(STORAGE_ROOT, key[0, 2], key[2, 2], key)
end

# ── 1. Build filename → CDN URL index ────────────────────────────────────────
json_path = '/rails/tmp/filename_to_url.json'
puts "Loading filename→URL index..."
filename_to_url = JSON.parse(File.read(json_path))
puts "  #{filename_to_url.size} mappings loaded"
puts ""

# ── 2. Get missing blobs using SQL + filesystem check (batched) ──────────────
puts "Finding missing blob files..."

# Get all distinct asset blob keys+filenames in one query
rows = ActiveRecord::Base.connection.execute(<<~SQL)
  SELECT DISTINCT b.key, b.filename
  FROM active_storage_blobs b
  INNER JOIN active_storage_attachments a ON a.blob_id = b.id
  WHERE a.record_type = 'Spree::Asset'
  ORDER BY b.key
SQL

total = rows.count
puts "Total asset blobs in DB: #{total}"

missing = rows.select { |r| !File.exist?(blob_path(r['key'])) }
puts "Missing from disk:       #{missing.size}"
puts ""

# ── 3. Download missing files ─────────────────────────────────────────────────
puts "=== Downloading ==="

restored    = 0
no_url      = 0
failed      = 0
failed_list = []

missing.each_with_index do |row, idx|
  print "\r[#{idx+1}/#{missing.size}] ✓#{restored} ✗#{failed} ?#{no_url}" if (idx % 10).zero?

  key      = row['key']
  filename = row['filename']
  cdn_url  = filename_to_url[filename] || filename_to_url.find { |k, _| k.downcase == filename.downcase }&.last

  unless cdn_url
    no_url += 1
    failed_list << "#{key}|#{filename}|NO_URL"
    next
  end

  target = blob_path(key)
  FileUtils.mkdir_p(File.dirname(target))

  begin
    data = URI.open(cdn_url,
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
      read_timeout: 30, open_timeout: 10
    ).read
    File.binwrite(target, data)
    restored += 1
    print "✓"
  rescue OpenURI::HTTPError => e
    failed += 1
    failed_list << "#{key}|#{filename}|#{e.message[0,50]}"
    print "✗"
  rescue => e
    failed += 1
    failed_list << "#{key}|#{filename}|#{e.class}"
    print "!"
  end
  STDOUT.flush
end

puts "\n"
puts "=== DONE ==="
puts "Total missing:    #{missing.size}"
puts "Restored:         #{restored}"
puts "No URL in index:  #{no_url}"
puts "Download failed:  #{failed}"
puts "Finished: #{Time.current}"

if failed_list.any?
  File.write('/rails/tmp/restore_failed.txt', failed_list.join("\n"))
  puts "\nFailed list → /rails/tmp/restore_failed.txt"
  puts "Sample NO_URL (need to find CDN):"
  failed_list.select { |l| l.include?('NO_URL') }.first(8).each do |l|
    puts "  #{l.split('|')[1]}"
  end
end
