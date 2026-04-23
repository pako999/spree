# Translate entire shop using Claude Haiku API
# Translates: products, taxons, posts — names, descriptions, meta fields
# Uses Spree's Mobility translation tables
#
# Usage: kamal app exec --reuse "bin/rails runner /rails/script/translate_shop.rb"
# Env: ANTHROPIC_API_KEY must be set
# Cost: ~$15 total for DE + ES + SL (using Haiku)

require 'net/http'
require 'json'
require 'uri'

API_URL = URI('https://api.anthropic.com/v1/messages')
MODEL = 'claude-haiku-4-5-20251001'
API_KEY = ENV.fetch('ANTHROPIC_API_KEY')
STORE = Spree::Store.find(2)

LANGUAGES = {
  'de' => { name: 'German', instructions: 'Translate to German (Deutsch). Use formal "Sie" form. Keep brand names (Duotone, Cabrinha, ION, NeilPryde, etc.) untranslated. Keep technical watersport terms that are commonly used in German unchanged (e.g., Kite, Board, Foil, SUP). Use proper German compound nouns where appropriate.' },
  'es' => { name: 'Spanish', instructions: 'Translate to European Spanish (Espanol). Use formal "usted" for product descriptions. Keep brand names untranslated. Keep international watersport terms (kite, windsurf, SUP, foil) as-is since they are used in Spanish.' },
  'sl' => { name: 'Slovenian', instructions: 'Translate to Slovenian (Slovenscina). Keep brand names untranslated. Keep international watersport terms (kite, windsurf, SUP, foil, wing) as they are commonly used in Slovenian without translation.' }
}.freeze

$api_calls = 0
$errors = 0

def translate_text(text, lang_code, field_type = 'description')
  return nil if text.blank?

  lang = LANGUAGES[lang_code]
  max_tokens = case field_type
               when 'meta_title' then 100
               when 'meta_description' then 250
               when 'name' then 150
               else 4096
               end

  prompt = <<~PROMPT
    #{lang[:instructions]}

    Field type: #{field_type}
    #{"Keep under 60 characters." if field_type == 'meta_title'}
    #{"Keep under 155 characters." if field_type == 'meta_description'}
    #{"Keep HTML tags intact. Do not translate HTML attributes, URLs, or href values." if field_type == 'description' || field_type == 'content'}

    Return ONLY the translated text, nothing else. No quotes, no explanation.

    Text to translate:
    #{text}
  PROMPT

  http = Net::HTTP.new(API_URL.host, API_URL.port)
  http.use_ssl = true
  http.read_timeout = 30

  req = Net::HTTP::Post.new(API_URL)
  req['x-api-key'] = API_KEY
  req['anthropic-version'] = '2023-06-01'
  req['Content-Type'] = 'application/json'
  req.body = { model: MODEL, max_tokens: max_tokens, messages: [{ role: 'user', content: prompt }] }.to_json

  res = http.request(req)
  $api_calls += 1

  if res.is_a?(Net::HTTPSuccess)
    data = JSON.parse(res.body)
    data.dig('content', 0, 'text')&.strip
  else
    $errors += 1
    puts "    API error #{res.code}: #{res.body[0, 100]}"
    nil
  end
rescue => e
  $errors += 1
  puts "    Error: #{e.message[0, 80]}"
  nil
end

def translate_record(record, fields, lang_code, label)
  fields.each do |field|
    original = record.send(field)
    next if original.blank?

    # Skip if already translated
    Mobility.with_locale(lang_code) do
      existing = record.send(field)
      next if existing.present? && existing != original
    end

    field_type = field.to_s.include?('meta_title') ? 'meta_title' :
                 field.to_s.include?('meta_description') ? 'meta_description' :
                 field.to_s.include?('name') || field.to_s.include?('title') ? 'name' :
                 field.to_s.include?('content') ? 'content' : 'description'

    translated = translate_text(original, lang_code, field_type)
    next unless translated

    Mobility.with_locale(lang_code) do
      record.send("#{field}=", translated)
    end
  end

  record.save(validate: false)
  print '.'
rescue => e
  $errors += 1
  print 'E'
  puts "\n    #{label}: #{e.message[0, 80]}"
end

# Rate limiting
def rate_limit
  sleep(0.5) if $api_calls % 5 == 0
  sleep(3) if $api_calls % 50 == 0
end

# ─── Main ───────────────────────────────────────────────────────────────────

start = Time.current

LANGUAGES.each do |lang_code, lang|
  puts "\n#{'=' * 60}"
  puts "Translating to #{lang[:name]} (#{lang_code})"
  puts '=' * 60

  # 1. Taxons (names + descriptions + meta)
  taxons = Spree::Taxon.where.not(name: [nil, '']).where('depth > 0')
  puts "\nTaxons: #{taxons.count}"
  taxons.find_each do |t|
    translate_record(t, [:name, :description, :meta_title, :meta_description], lang_code, t.permalink)
    rate_limit
  end

  # 2. Products (names + descriptions + meta)
  products = STORE.products.where.not(name: [nil, ''])
  puts "\n\nProducts: #{products.count}"
  products.find_each do |p|
    translate_record(p, [:name, :description, :meta_title, :meta_description], lang_code, p.slug)
    rate_limit
  end

  # 3. Posts (titles + content + meta)
  posts = Spree::Post.where.not(published_at: nil)
  puts "\n\nPosts: #{posts.count}"
  posts.find_each do |p|
    translate_record(p, [:title, :content, :meta_title, :meta_description], lang_code, p.slug)
    rate_limit
  end

  puts "\n#{lang[:name]} complete!"
end

elapsed = (Time.current - start).round
puts "\n\n#{'=' * 60}"
puts "Translation complete in #{elapsed}s"
puts "  API calls: #{$api_calls}"
puts "  Errors: #{$errors}"
puts '=' * 60
