require "aws-sdk-s3"

client = Aws::S3::Client.new(
  access_key_id: ENV["R2_ACCESS_KEY_ID"],
  secret_access_key: ENV["R2_SECRET_ACCESS_KEY"],
  region: "auto",
  endpoint: "https://8b7e078431b06069d14ce4bd18839679.r2.cloudflarestorage.com"
)

# Get current blob keys
db_keys = Set.new(ActiveStorage::Blob.pluck(:key))

# Collect ALL orphaned R2 objects
orphans = []
token = nil
loop do
  opts = { bucket: "surf-store-storage", max_keys: 1000 }
  opts[:continuation_token] = token if token
  resp = client.list_objects_v2(**opts)
  resp.contents.each do |obj|
    key = obj.key.split("/").last
    next if key == ".keep" || key.nil? || key.empty?
    unless db_keys.include?(key)
      orphans << { r2_key: obj.key, key: key, size: obj.size }
    end
  end
  break unless resp.is_truncated
  token = resp.next_continuation_token
end

puts "Total orphaned R2 objects: #{orphans.size}"

# Identify original images (not processed variants - variants are typically small webp files)
# Original images are usually JPEG/PNG/WEBP > 10KB
original_images = []
variant_files = []

orphans.each_with_index do |o, i|
  begin
    resp = client.get_object(bucket: "surf-store-storage", key: o[:r2_key], range: "bytes=0-15")
    magic = resp.body.read

    is_jpeg = magic.bytes[0..2] == [0xFF, 0xD8, 0xFF]
    is_png = magic.bytes[0..3] == [0x89, 0x50, 0x4E, 0x47]
    is_webp = magic.bytes[0..3] == [0x52, 0x49, 0x46, 0x46] && magic.bytes[8..11] == [0x57, 0x45, 0x42, 0x50]

    content_type = if is_jpeg then "image/jpeg"
    elsif is_png then "image/png"
    elsif is_webp then "image/webp"
    else nil
    end

    if content_type
      if o[:size] > 10000 || !is_webp # Large files or non-webp are originals
        original_images << o.merge(content_type: content_type)
      else
        variant_files << o
      end
    end
  rescue => e
    # skip
  end

  print "\rScanned #{i+1}/#{orphans.size}..." if (i+1) % 100 == 0
end

puts "\nOriginal images (can be restored): #{original_images.size}"
puts "Variant/processed files: #{variant_files.size}"
puts "Non-image files: #{orphans.size - original_images.size - variant_files.size}"

# Now try to restore: create blob records for orphaned originals
# We need to find which product they belong to
# Strategy: download the image, create a blob, and let admin re-assign later
# For now, save the list to a file
File.write("/tmp/orphan_originals.json", original_images.to_json)
puts "Saved orphan original images to /tmp/orphan_originals.json"
