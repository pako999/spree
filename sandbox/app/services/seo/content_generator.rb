# frozen_string_literal: true
# Seo::ContentGenerator — calls Anthropic Claude API to generate SEO page content.
#
# Usage:
#   gen = Seo::ContentGenerator.new
#   result = gen.generate(
#     keyword:  'Duotone Kiteboarding kites',
#     template: 'brand_category',
#     variables: { name: 'Duotone Kiteboarding', permalink: 'brands/duotone-kiteboarding' }
#   )
#   # => { title:, meta_title:, meta_description:, body_html:, excerpt:, faq: [] }

require 'net/http'
require 'uri'
require 'json'

module Seo
  class ContentGenerator
    API_URL     = 'https://api.anthropic.com/v1/messages'
    MODEL       = ENV.fetch('SEO_MODEL', 'claude-haiku-4-5-20251001')
    MAX_TOKENS  = 4096
    API_VERSION = '2023-06-01'

    # Cached system prompt — shared across all template types.
    # Sent as a system message with cache_control so it's reused after the first call.
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an expert SEO content writer for surf-store.com, a European water sports shop based in Slovenia specialising in kitesurfing, windsurfing, wing foiling, wetsuits, and SUP.

      About the shop:
      - Carries top brands: Duotone, Cabrinha, NeilPryde, ION, Gaastra, JP Australia, Fanatic, Nobile, Point7, Tabou
      - Ships across Europe; prices in EUR
      - Expert staff with real on-water experience
      - Target audience: serious water sports enthusiasts, beginners looking for expert guidance

      Content standards:
      - European English spelling (colour, favourite, specialise, etc.)
      - Lead with outcomes for the customer, not product specifications
      - Recommend by brand + type/size, NOT by made-up model names
      - Example GOOD: "a Duotone or Cabrinha freestyle board in the 135-150cm range"
      - Example BAD: "a Duotone Twintip 140cm" (avoid specific SKUs unless you know they exist)
      - Include natural calls-to-action pointing to surf-store.com
      - Write as a knowledgeable shop owner and water sports instructor, not a copywriter
      - Target keyword should appear naturally 2–4 times in body_html
      - All HTML must be valid: use <h2>, <h3>, <p>, <ul>, <li>, <strong>, <table>, <thead>, <tbody>, <tr>, <th>, <td> tags only

      JSON response requirements:
      - meta_title: max 60 characters — include keyword + year (2026) where natural
      - meta_description: max 155 characters — end with a CTA ("Shop now at Surf Store" or "Find it at Surf Store")
      - title: H1 text for the page — max 70 characters
      - body_html: valid HTML, length as specified per template
      - excerpt: one sentence, max 160 characters
      - faq: array of {"q": "...", "a": "..."} objects

      IMPORTANT: Respond ONLY with a valid JSON object. No prose, no markdown fences, no explanation — just the JSON.
    PROMPT

    TEMPLATES = {
      'brand_category' => <<~PROMPT,
        Write a brand/category page for: **%{name}**
        URL: surf-store.com/%{permalink}
        Target keyword: %{keyword}

        Required body_html sections (650–800 words total):
        - <h2>About %{name}</h2> — brand story, heritage, what makes them stand out
        - <h2>Why Buy %{name} at Surf Store?</h2> — our expertise, stock depth, after-sales
        - <h2>Our %{name} Range</h2> — product categories with specific model mentions
        - <h2>Expert Advice</h2> — buying tips specific to this brand/category
        - <h2>FAQ</h2> — 3 inline Q/A pairs formatted as <p><strong>Q: ...</strong><br>A: ...</p>

        faq: 3 Q/A pairs
      PROMPT

      'buying_guide' => <<~PROMPT,
        Write a buying guide for: **%{name}**
        Target keyword: %{keyword}

        Required body_html sections (800–1000 words total):
        - <h2>What to Look For</h2> — key buying criteria
        - <h2>Beginner vs Advanced</h2> — how needs differ by skill level
        - <h2>Budget Guide</h2> — entry/mid/premium price bands with examples
        - <h2>Our Top Picks</h2> — 3–4 specific product recommendations with reasons
        - <h2>Common Mistakes to Avoid</h2>

        faq: 5 Q/A pairs relevant to the buying decision
      PROMPT

      'location' => <<~PROMPT,
        Write a local water sports spot guide for: **%{name}**
        Target keyword: %{keyword}

        Required body_html sections (650–800 words total):
        - <h2>Why %{name} Is Worth the Trip</h2> — unique selling points of the spot
        - <h2>Best Spots & Access</h2> — specific launch points, parking, hazards
        - <h2>Wind & Weather by Season</h2> — monthly wind chart as HTML table (Month | Avg Wind | Direction | Water Temp | Rating)
        - <h2>What Gear to Bring</h2> — kite/sail sizes, board type, wetsuit thickness
        - <h2>Rent or Buy? Advice from Surf Store</h2>

        faq: 3 Q/A pairs (travel logistics, best season, gear questions)
      PROMPT

      'comparison' => <<~PROMPT,
        Write a comparison page for: **%{name}**
        Target keyword: %{keyword}

        Required body_html sections (750–900 words total):
        - <h2>Quick Verdict</h2> — 2–3 sentences declaring a winner and who should pick each
        - <h2>Side-by-Side Comparison</h2> — HTML table (Feature | Option A | Option B) with 6–8 rows
        - <h2>Option A — Full Review</h2> — strengths and weaknesses
        - <h2>Option B — Full Review</h2> — strengths and weaknesses
        - <h2>Who Should Choose Each?</h2> — clear rider profiles for each option
        - <h2>Our Recommendation</h2> — direct advice from Surf Store experts

        faq: 4 Q/A pairs about the comparison topic
      PROMPT

      'model_review' => <<~PROMPT,
        Write a 2026 product review page for: **%{name}** by %{brand}
        Target keyword: %{keyword}

        Required body_html sections (750–950 words total):
        - <h2>What's New for 2026</h2> — changes from previous year
        - <h2>Key Features & Technology</h2> — specific tech names, materials, construction
        - <h2>Who Is It For?</h2> — rider profile, skill level, use case
        - <h2>On the Water — Performance</h2> — detailed riding characteristics
        - <h2>Specs & Sizing Guide</h2> — size range, weight recommendations as table
        - <h2>Verdict: Worth Buying in 2026?</h2> — honest summary with score

        faq: 4 Q/A pairs about this specific model
      PROMPT

      'qna' => <<~PROMPT,
        Write a question-and-answer page for: **%{name}**
        Target keyword: %{keyword}

        Required body_html structure (600–800 words total):
        - Opening <p>: direct 2–3 sentence answer to the question
        - <h2>The Full Answer</h2> — detailed explanation with context
        - <h2>Practical Guide</h2> — step-by-step or scenario-based actionable advice
        - <h2>Common Mistakes</h2> — what beginners get wrong
        - <h2>Surf Store Recommendation</h2> — recommend by BRAND + TYPE only. Do NOT invent specific model names. Example: "We stock freestyle boards from Duotone, Cabrinha, and Nobile in various sizes" NOT "Duotone Twintip 140cm"

        excerpt: the direct one-sentence answer to the question
        faq: 5 related Q/A pairs on the same topic
      PROMPT

      'conditions' => <<~PROMPT,
        Write a wind/conditions guide for: **%{name}**
        Target keyword: %{keyword}

        Required body_html sections (650–850 words total):
        - <h2>Understanding These Conditions</h2> — what defines this wind/weather scenario
        - <h2>Best Gear for These Conditions</h2> — kite/sail sizes (e.g. 12m, 15m), board type & size (e.g. 135-150cm freestyle board), wetsuit thickness (e.g. 3/2mm, 4/3mm). Use brand names + type only, NOT fake model names. Example: "a Duotone or Cabrinha freestyle board, 135-150cm" not "Duotone Twintip 140cm"
        - <h2>Technique Tips</h2> — how to adjust riding technique for this scenario
        - <h2>Safety Checklist</h2> — specific risks and how to manage them
        - <h2>Our Gear Recommendations at Surf Store</h2> — recommend by BRAND + TYPE + SIZE only. Example: "We stock Duotone, Cabrinha, and Nobile freestyle boards in the 135-150cm range suitable for this wind. Pair with a 14-15m kite from Duotone or Cabrinha, and a 3/2 or 4/3mm wetsuit from ION or NeilPryde." Do NOT invent specific model names.

        faq: 3 Q/A pairs about this wind/conditions scenario
      PROMPT
    }.freeze

    def initialize
      @api_key = ENV['ANTHROPIC_API_KEY']
      raise 'ANTHROPIC_API_KEY not set' if @api_key.blank?
    end

    # Generate content for a single page.
    # Returns hash with :meta_title, :meta_description, :title, :body_html, :excerpt, :faq
    def generate(keyword:, template: 'brand_category', variables: {})
      template_str = TEMPLATES[template] || TEMPLATES['brand_category']
      prompt = template_str % variables.merge(keyword: keyword)

      response = call_api(prompt)
      parse_response(response)
    rescue => e
      Rails.logger.error("[Seo::ContentGenerator] #{e.message}")
      { meta_title: '', meta_description: '', title: keyword, body_html: '', excerpt: '', faq: [] }
    end

    # Generate content for multiple pages, respecting rate limit.
    # Yields each result with its index.
    def generate_batch(items, &block)
      items.each_with_index do |item, i|
        result = generate(**item)
        block.call(result, i) if block

        sleep(6) if (i + 1) % 10 == 0
      end
    end

    private

    def call_api(prompt)
      uri  = URI.parse(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 90
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri.path)
      req['x-api-key']         = @api_key
      req['anthropic-version'] = API_VERSION
      req['anthropic-beta']    = 'prompt-caching-2024-07-31'
      req['Content-Type']      = 'application/json'

      req.body = {
        model:      MODEL,
        max_tokens: MAX_TOKENS,
        system: [
          {
            type:          'text',
            text:          SYSTEM_PROMPT,
            cache_control: { type: 'ephemeral' }
          }
        ],
        messages: [{ role: 'user', content: prompt }]
      }.to_json

      res = http.request(req)
      raise "API error #{res.code}: #{res.body.truncate(200)}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    end

    def parse_response(api_response)
      text = api_response.dig('content', 0, 'text').to_s.strip

      json_match = text.match(/\{.*\}/m)
      raise 'No JSON found in API response' unless json_match

      data = JSON.parse(json_match[0])

      {
        meta_title:       data['meta_title'].to_s.truncate(60),
        meta_description: data['meta_description'].to_s.truncate(155),
        title:            data['title'].to_s,
        body_html:        data['body_html'].to_s,
        excerpt:          data['excerpt'].to_s.truncate(160),
        faq:              Array(data['faq'])
      }
    end
  end
end
