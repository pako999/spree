# frozen_string_literal: true
# Re-attach local images to existing DTW24 products by re-reading the CSV.
# Safe to re-run — skips products that already have images.
# Run: kamal app exec --reuse "bin/rails runner /rails/script/attach_dtw24_images.rb"
#
# IMPORTANT: must be run with `kamal app exec --reuse` (not plain `exec`).
# Plain `exec` spins up a fresh container that terminates as soon as the script
# finishes, which can race with Active Storage's after_commit file write hook
# and leave blob records in the DB while the bytes never reach disk.

require 'csv'
require 'open-uri'
require 'stringio'

CSV_URL   = 'https://docs.google.com/spreadsheets/d/1FmvOeLI-kAwTi1ekYIYieFBvwZlj7o7FHr3LUPyQg_Y/export?format=csv'
IMAGE_DIR = '/rails/tmp/dtw24_images'

pid_info = {}
csv_data = URI.open(CSV_URL, 'User-Agent' => 'Mozilla/5.0').read.force_encoding('UTF-8')
CSV.parse(csv_data, headers: true, encoding: 'UTF-8') do |row|
  pid = row['Product Id']
  next if pid.blank?
  pid_info[pid] ||= { name: row['BAMMAMItemName'], images: [] }
  image_src = row['Image Src'].to_s.strip
  next if image_src.empty?
  image_src.split(';').map(&:strip).reject(&:empty?).each do |fn|
    pid_info[pid][:images] << fn unless pid_info[pid][:images].include?(fn)
  end
end

puts "Products in sheet: #{pid_info.size}"

attached = 0
skipped  = 0
missing  = 0
errors   = 0

pid_info.each_with_index do |(pid, info), idx|
  product = Spree::Product.where("slug LIKE ?", "%#{pid}").first
  unless product
    puts "[#{idx+1}/#{pid_info.size}] NOT FOUND: #{pid} (#{info[:name]})"
    next
  end

  if product.master.images.any?
    print "."
    skipped += 1
    next
  end

  print "\n[#{idx+1}/#{pid_info.size}] #{product.slug}"

  info[:images].each do |fn|
    path = File.join(IMAGE_DIR, fn)
    unless File.exist?(path)
      print " [missing #{fn}]"
      missing += 1
      next
    end
    begin
      io = StringIO.new(File.binread(path))
      product.master.images.create!(attachment: { io: io, filename: fn, content_type: 'image/jpeg' })
      print " ✓"
      attached += 1
    rescue => e
      print " ✗(#{e.message.truncate(40)})"
      errors += 1
    end
  end
end

puts
puts "=" * 60
puts "Images attached : #{attached}"
puts "Products skipped: #{skipped} (already have images)"
puts "Missing files   : #{missing}"
puts "Errors          : #{errors}"
