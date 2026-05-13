# frozen_string_literal: true
# Seo::ContentGenerator — calls Anthropic Claude API to generate SEO page content.
# Injects a real product catalog from the DB into every prompt so the model
# only recommends products that actually exist in the store.
# Outputs styled HTML using the surf-store blog design system CSS classes.

require 'net/http'
require 'uri'
require 'json'

module Seo
  class ContentGenerator
    API_URL     = 'https://api.anthropic.com/v1/messages'
    MODEL       = ENV.fetch('SEO_MODEL', 'claude-haiku-4-5-20251001')
    MAX_TOKENS  = 5000
    API_VERSION = '2023-06-01'

    CATALOG_TAXONS = {
      kite:              'categories/kitesurfing/kites',
      kiteboard_twin:    'categories/kitesurfing/kiteboards/twintip-kiteboards',
      kiteboard_wave:    'categories/kitesurfing/kiteboards/wave-kiteboards',
      kiteboard_foil:    'categories/kitesurfing/kiteboards/foil-kiteboards',
      kite_harness:      'categories/kitesurfing/kitesurfing-harnesses',
      windsurf_sail:     'categories/windsurf/windsurf-sails/windsurfing-sails',
      windsurf_board:    'categories/windsurf/windsurf-boards',
      windsurf_mast:     'categories/windsurf/windsurf-gear/windsurf-mast',
      windsurf_boom:     'categories/windsurf/windsurf-gear/windsurf-boom',
      windsurf_harness:  'categories/windsurf/windsurf-accessories/windsurf-harnesses',
      wing:              'categories/wingfoil/wings',
      wing_board:        'categories/wingfoil/wing-boards',
      wing_foil:         'categories/wingfoil/wing-foils',
      wetsuit_men:       'categories/wetsuits/men-wetsuits',
      wetsuit_women:     'categories/wetsuits/women-wetsuits',
    }.freeze

    SPORT_CATALOG_KEYS = {
      'kitesurfing' => %i[kite kiteboard_twin kiteboard_wave kiteboard_foil kite_harness],
      'windsurfing' => %i[windsurf_sail windsurf_board windsurf_harness],
      'wing'        => %i[wing wing_board wing_foil],
      'wetsuit'     => %i[wetsuit_men wetsuit_women],
      'all'         => %i[kite kiteboard_twin kiteboard_wave windsurf_sail windsurf_board wing wing_board wetsuit_men wetsuit_women],
    }.freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an expert SEO content writer for surf-store.com, a European water sports shop in Slovenia (Maribor) specialising in kitesurfing, windsurfing, wing foiling, wetsuits, and SUP. Founded 2003. 6,000+ customers. Free EU shipping from €99.

      Brands stocked: Duotone, Cabrinha, NeilPryde, ION, Gaastra, JP Australia, Fanatic, Nobile, Point7, Tabou, Mystic.
      NEVER mention: North, Core, F-One, Eleveight (not stocked).
      NeilPryde = wetsuits/accessories ONLY — no kites.
      Fanatic = boards ONLY — no kites.

      Content standards:
      - European English spelling (colour, favourite, specialise, etc.)
      - Write as a knowledgeable shop owner who rides the gear — not a copywriter
      - Lead with outcomes for the customer, not specs
      - PRODUCT RECOMMENDATIONS: A REAL PRODUCT CATALOG will be provided. Only recommend products from it. Never invent names. If no exact match, say "a Duotone freeride kite" etc.
      - Target keyword should appear naturally 2–4 times

      HTML DESIGN SYSTEM — use these CSS classes for rich layout. All classes are defined in the page CSS.

      PRODUCT CARDS (use for every specific product recommendation):
      <div class="blog-card featured">
        <div class="blog-card-header">
          <div class="blog-card-name">EXACT PRODUCT NAME FROM CATALOG</div>
          <span class="blog-badge top">⭑ Top Pick</span>
        </div>
        <div class="blog-specs">
          <span class="blog-pill">Sizes: <strong>7–17m</strong></span>
          <span class="blog-pill">Wind: <strong>10–25 kts</strong></span>
          <span class="blog-pill">Build: <strong>Penta TX</strong></span>
        </div>
        <p class="blog-card-desc">2–3 sentence description from your expertise.</p>
        <div class="blog-card-footer">
          <a href="https://www.surf-store.com/products/REAL-SLUG-FROM-CATALOG" class="blog-btn">Shop PRODUCT NAME →</a>
        </div>
      </div>
      Badge classes: top (cyan) / premium (gold) / value (green) / alt (grey)
      Card classes: featured (cyan top border) / premium-card (gold) / value-card (green)

      SECTION LABELS (add before every h2):
      <div class="blog-label">01 — CRITERIA</div>
      <h2>What to Look For</h2>

      FEATURE LIST (for key points, criteria, etc.):
      <ul class="blog-flist">
        <li><span class="blog-flist-icon">◈</span><div><strong>Feature name</strong> — explanation</div></li>
      </ul>

      SKILL CARDS (for beginner/advanced breakdown):
      <div class="blog-skills">
        <div class="blog-skill beginner"><div class="blog-skill-tag">Beginner</div><h4>Title</h4><p>Description</p></div>
        <div class="blog-skill advanced"><div class="blog-skill-tag">Advanced</div><h4>Title</h4><p>Description</p></div>
      </div>

      STATS BANNER (4 key numbers, use after first h2):
      <div class="blog-stats">
        <div class="blog-stat"><div class="blog-stat-val">12–25</div><div class="blog-stat-lbl">Wind range (kts)</div></div>
        <div class="blog-stat"><div class="blog-stat-val">7–17</div><div class="blog-stat-lbl">Kite sizes (m)</div></div>
        <div class="blog-stat"><div class="blog-stat-val">3</div><div class="blog-stat-lbl">Models compared</div></div>
        <div class="blog-stat"><div class="blog-stat-val">2026</div><div class="blog-stat-lbl">Season</div></div>
      </div>

      BUDGET TABLE:
      <table><thead><tr><th>Tier</th><th>Price Range</th><th>Best For</th><th>Our Pick</th></tr></thead>
      <tbody>
        <tr><td><span class="blog-tier entry">Entry</span></td><td>€500–800</td><td>Beginners</td><td>Product name from catalog</td></tr>
        <tr><td><span class="blog-tier mid">Mid</span></td><td>€800–1500</td><td>Intermediate</td><td>Product name from catalog</td></tr>
        <tr><td><span class="blog-tier premium">Premium</span></td><td>€1500+</td><td>Advanced</td><td>Product name from catalog</td></tr>
      </tbody></table>

      MISTAKES SECTION:
      <div class="blog-mistakes">
        <div class="blog-mistake"><div class="blog-mistake-title">✗ Mistake title</div><p>Two sentence explanation.</p></div>
      </div>

      CTA BOX (end of every post):
      <div class="blog-cta">
        <h3>Ready to Gear Up?</h3>
        <p>Expert advice, authorized stock, ships across Europe within 24h.</p>
        <div class="blog-cta-btns">
          <a href="https://www.surf-store.com/t/categories/CATEGORY-PATH" class="blog-btn">Browse All [CATEGORY] →</a>
          <a href="https://www.surf-store.com/policies/contact" class="blog-btn outline">Ask Our Experts</a>
        </div>
      </div>

      TRUST BAR (after CTA, always last element):
      <div class="blog-trust">
        <span>🚚 Free EU Shipping from €99</span>
        <span>↩ 30-Day Returns</span>
        <span>🛡 Secure Checkout</span>
        <span>⭐ 6,000+ Customers</span>
        <span>📅 Since 2003</span>
      </div>

      JSON response requirements:
      - meta_title: max 60 chars — keyword + year (2026) where natural
      - meta_description: max 155 chars — end with CTA ("Shop at Surf Store")
      - title: H1 text, max 70 chars
      - body_html: valid HTML using the design system classes above
      - excerpt: one sentence, max 160 chars
      - faq: array of {"q": "...", "a": "..."} objects

      IMPORTANT: Respond ONLY with a valid JSON object. No markdown fences, no prose — just JSON.
    PROMPT

    TEMPLATES = {
      'brand_category' => <<~PROMPT,
        Write a brand/category page for: **%{name}**
        URL: surf-store.com/%{permalink}
        Target keyword: %{keyword}

        body_html structure (700–900 words):
        <div class="blog-label">01 — BRAND</div>
        <h2>About %{name}</h2>
        [brand story, heritage, what makes them stand out — 2 paragraphs]

        <div class="blog-label">02 — WHY US</div>
        <h2>Why Buy %{name} at Surf Store?</h2>
        <ul class="blog-flist">[4–5 key reasons using blog-flist-icon ◈]</ul>

        <div class="blog-label">03 — RANGE</div>
        <h2>Our %{name} Range</h2>
        [2–3 product cards using blog-card for real products from REAL PRODUCT CATALOG]

        <div class="blog-label">04 — ADVICE</div>
        <h2>Expert Buying Tips</h2>
        [buying tips specific to this brand — 2 paragraphs]

        [CTA box — link to correct category]
        [Trust bar]

        faq: 3 Q/A pairs
      PROMPT

      'buying_guide' => <<~PROMPT,
        Write a buyer's guide for: **%{name}**
        Target keyword: %{keyword}

        body_html structure (900–1100 words):
        <div class="blog-label">01 — CRITERIA</div>
        <h2>What to Look For</h2>
        [stats banner with 4 key numbers relevant to this gear]
        <ul class="blog-flist">[5–6 key criteria with ◈ icons]</ul>

        <div class="blog-label">02 — SKILL LEVEL</div>
        <h2>Beginner vs Advanced</h2>
        [blog-skills grid with beginner + advanced cards]

        <div class="blog-label">03 — BUDGET</div>
        <h2>Budget Guide</h2>
        [budget table with blog-tier entry/mid/premium — use ONLY real products from catalog]

        <div class="blog-label">04 — TOP PICKS</div>
        <h2>Our Top Picks for 2026</h2>
        [3–4 blog-card product cards — ONLY products from REAL PRODUCT CATALOG. First card = featured]

        <div class="blog-label">05 — MISTAKES</div>
        <h2>Common Mistakes to Avoid</h2>
        <div class="blog-mistakes">[4–5 blog-mistake items]</div>

        [CTA box linking to relevant category]
        [Trust bar]

        faq: 5 Q/A pairs
      PROMPT

      'location' => <<~PROMPT,
        Write a local water sports spot guide for: **%{name}**
        Target keyword: %{keyword}

        body_html structure (700–900 words):
        <div class="blog-label">01 — THE SPOT</div>
        <h2>Why %{name} Is Worth the Trip</h2>
        [stats banner: avg wind, peak season, water temp, session length]
        [2 paragraphs — unique selling points]

        <div class="blog-label">02 — ACCESS</div>
        <h2>Best Spots & Getting There</h2>
        <ul class="blog-flist">[4–5 specific spots/tips with ◈ icons]</ul>

        <div class="blog-label">03 — CONDITIONS</div>
        <h2>Wind & Weather by Season</h2>
        [HTML table: Month | Avg Wind | Direction | Rating]

        <div class="blog-label">04 — GEAR</div>
        <h2>What Gear to Bring</h2>
        [blog-skills grid: beginner setup vs advanced setup]
        [1–2 product cards for key gear — ONLY from REAL PRODUCT CATALOG]

        <div class="blog-label">05 — RENT OR BUY</div>
        <h2>Rent or Buy? Advice from Surf Store</h2>
        [2 paragraphs]

        [CTA box]
        [Trust bar]

        faq: 3 Q/A pairs
      PROMPT

      'comparison' => <<~PROMPT,
        Write a comparison page for: **%{name}**
        Target keyword: %{keyword}

        body_html structure (800–1000 words):
        <div class="blog-label">01 — VERDICT</div>
        <h2>Quick Verdict</h2>
        [2–3 sentences declaring a winner and who should pick each. Bold the winner.]

        <div class="blog-label">02 — SIDE BY SIDE</div>
        <h2>Side-by-Side Comparison</h2>
        [HTML table: Feature | Option A | Option B — 7–8 rows. Use ✓ and — symbols]

        <div class="blog-label">03 — OPTION A</div>
        <h2>[Option A Name] — Full Review</h2>
        [blog-card for Option A if it's in the REAL PRODUCT CATALOG, otherwise just paragraphs]
        [strengths and weaknesses]

        <div class="blog-label">04 — OPTION B</div>
        <h2>[Option B Name] — Full Review</h2>
        [blog-card for Option B if in catalog]
        [strengths and weaknesses]

        <div class="blog-label">05 — WHO IT'S FOR</div>
        <h2>Who Should Choose Each?</h2>
        [blog-skills grid: Option A profile vs Option B profile]

        <div class="blog-label">06 — RECOMMENDATION</div>
        <h2>Our Recommendation</h2>
        [2 paragraphs with direct advice — ONLY real product names from catalog]

        [CTA box]
        [Trust bar]

        faq: 4 Q/A pairs
      PROMPT

      'model_review' => <<~PROMPT,
        Write a 2026 product review for: **%{name}** by %{brand}
        Target keyword: %{keyword}

        body_html structure (800–1000 words):
        [1 featured blog-card for this product — include real specs, link to surf-store.com/products/SLUG, use ONLY data from REAL PRODUCT CATALOG]

        <div class="blog-label">01 — WHAT'S NEW</div>
        <h2>What's New for 2026</h2>
        [changes from previous year — 2 paragraphs]

        <div class="blog-label">02 — FEATURES</div>
        <h2>Key Features & Technology</h2>
        <ul class="blog-flist">[5–6 specific tech features with ◈ icons]</ul>

        <div class="blog-label">03 — WHO IT'S FOR</div>
        <h2>Who Is It For?</h2>
        [blog-skills grid: beginner suitability vs advanced suitability]

        <div class="blog-label">04 — ON THE WATER</div>
        <h2>On the Water — Performance</h2>
        [2–3 paragraphs on riding characteristics]

        <div class="blog-label">05 — SIZING</div>
        <h2>Specs & Sizing Guide</h2>
        [HTML table: Size | Weight Recommendation | Wind Range | Notes]

        <div class="blog-label">06 — VERDICT</div>
        <h2>Verdict: Worth Buying in 2026?</h2>
        [honest summary — 2 paragraphs]

        <div class="blog-label">07 — ALTERNATIVES</div>
        <h2>Also Consider</h2>
        [2 product cards — ONLY from REAL PRODUCT CATALOG]

        [CTA box]
        [Trust bar]

        faq: 4 Q/A pairs
      PROMPT

      'qna' => <<~PROMPT,
        Write a question-and-answer page for: **%{name}**
        Target keyword: %{keyword}

        body_html structure (650–850 words):
        [Opening paragraph: direct 2–3 sentence answer to the question]

        <div class="blog-label">01 — FULL ANSWER</div>
        <h2>The Full Answer</h2>
        [detailed explanation with context — 3–4 paragraphs]

        <div class="blog-label">02 — PRACTICAL GUIDE</div>
        <h2>Practical Guide</h2>
        <ul class="blog-flist">[5–6 actionable steps or tips with ◈ icons]</ul>

        <div class="blog-label">03 — COMMON MISTAKES</div>
        <h2>Common Mistakes</h2>
        <div class="blog-mistakes">[3–4 blog-mistake items]</div>

        <div class="blog-label">04 — GEAR RECOMMENDATION</div>
        <h2>Surf Store Recommendation</h2>
        [If the topic is about a specific gear type, add 1–2 blog-card product cards from REAL PRODUCT CATALOG. Otherwise write 1–2 paragraphs recommending by brand + category only.]

        [CTA box]
        [Trust bar]

        excerpt: the direct one-sentence answer
        faq: 5 related Q/A pairs
      PROMPT

      'conditions' => <<~PROMPT,
        Write a wind/conditions guide for: **%{name}**
        Target keyword: %{keyword}

        CRITICAL — IDENTIFY THE SPORT FIRST:
        - "windsurfing"/"windsurf" in title → WINDSURFING guide. Never mention kites, twintip boards, or kite brands.
        - "wing foiling"/"wing" → WING FOILING guide. Wings + foil boards only.
        - "kitesurfing"/"kite" → KITESURFING guide. Kites + twintip/wave kiteboards.

        SPORT-CORRECT GEAR SIZES:
        Kitesurfing: light wind (8–14 kts) = 14–17m kite; medium (14–20 kts) = 10–14m; strong (20–30 kts) = 7–10m
        Windsurfing: light (10–15 kts) = 7.5–10m² sail; medium (15–20 kts) = 5.5–7.5m²; strong (20–30 kts) = 4.0–5.5m²
        Wing foiling: light (8–13 kts) = 5–7m wing; medium (13–18 kts) = 4–5m; strong (18–25 kts) = 3–4m

        body_html structure (700–900 words):
        <div class="blog-label">01 — CONDITIONS</div>
        <h2>Understanding These Conditions</h2>
        [stats banner: wind range, typical gusts, wave height, season rating]
        [what defines this wind/weather scenario — 2 paragraphs]

        <div class="blog-label">02 — BEST GEAR</div>
        <h2>Best Gear for These Conditions</h2>
        [blog-skills grid: light end of range setup vs strong end of range setup]
        [1–2 product cards — ONLY from REAL PRODUCT CATALOG, sport-correct gear only]

        <div class="blog-label">03 — TECHNIQUE</div>
        <h2>Technique Tips</h2>
        <ul class="blog-flist">[5 technique tips with ◈ icons]</ul>

        <div class="blog-label">04 — SAFETY</div>
        <h2>Safety Checklist</h2>
        <div class="blog-mistakes">[4–5 specific risks as blog-mistake items with red styling]</div>

        <div class="blog-label">05 — OUR PICKS</div>
        <h2>Our Gear Recommendations at Surf Store</h2>
        [1–2 product cards — ONLY from REAL PRODUCT CATALOG. DO NOT mix sports.]

        [CTA box]
        [Trust bar]

        faq: 3 Q/A pairs
      PROMPT
    }.freeze

    def initialize
      @api_key       = ENV['ANTHROPIC_API_KEY']
      raise 'ANTHROPIC_API_KEY not set' if @api_key.blank?
      @catalog_cache = {}
    end

    def generate(keyword:, template: 'brand_category', variables: {})
      template_str = TEMPLATES[template] || TEMPLATES['brand_category']
      prompt = template_str % variables.merge(keyword: keyword)

      sport   = detect_sport(keyword, variables)
      catalog = build_catalog_context(sport)

      response = call_api(prompt, catalog_context: catalog)
      parse_response(response)
    rescue => e
      Rails.logger.error("[Seo::ContentGenerator] #{e.message}")
      { meta_title: '', meta_description: '', title: keyword, body_html: '', excerpt: '', faq: [] }
    end

    def generate_batch(items, &block)
      items.each_with_index do |item, i|
        result = generate(**item)
        block.call(result, i) if block
        sleep(6) if (i + 1) % 10 == 0
      end
    end

    private

    def detect_sport(keyword, variables)
      text = [keyword, variables[:name].to_s, variables[:keyword].to_s].join(' ').downcase
      return 'windsurfing' if text.match?(/windsurf/)
      return 'wing'        if text.match?(/wing.?foil|wingsur/)
      return 'kitesurfing' if text.match?(/kite/)
      return 'wetsuit'     if text.match?(/wetsuit/)
      'all'
    end

    def build_catalog_context(sport)
      @catalog_cache[sport] ||= begin
        keys = SPORT_CATALOG_KEYS[sport] || SPORT_CATALOG_KEYS['all']

        sections = keys.filter_map do |key|
          permalink = CATALOG_TAXONS[key]
          next unless permalink

          taxon = Spree::Taxon.find_by(permalink: permalink)
          next unless taxon

          items = Spree::Product
            .joins(:taxons)
            .where(spree_taxons: { id: taxon.id })
            .where(status: 'active')
            .distinct
            .order(:name)
            .limit(20)
            .pluck(:name, :slug)

          next if items.empty?

          label = key.to_s.split('_').map(&:capitalize).join(' ')
          lines = items.map { |name, slug| "  - #{name} (slug: #{slug})" }
          "#{label}:\n#{lines.join("\n")}"
        end

        if sections.any?
          "REAL PRODUCT CATALOG — for specific product recommendations, use ONLY names and slugs from this list. " \
          "Product URLs are: https://www.surf-store.com/products/[slug]. " \
          "If no suitable product is listed, recommend by brand + category only, never invent names.\n\n" +
          sections.join("\n\n")
        else
          "No product catalog available — recommend by brand + category only, never invent model names."
        end
      end
    end

    def call_api(prompt, catalog_context: nil)
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

      system_blocks = [
        { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }
      ]
      system_blocks << { type: 'text', text: catalog_context } if catalog_context.present?

      req.body = {
        model:      MODEL,
        max_tokens: MAX_TOKENS,
        system:     system_blocks,
        messages:   [{ role: 'user', content: prompt }]
      }.to_json

      res = http.request(req)
      raise "API error #{res.code}: #{res.body.truncate(200)}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    end

    def parse_response(api_response)
      text = api_response.dig('content', 0, 'text').to_s.strip
      text = text.gsub(/```json\s*/i, '').gsub(/```/, '')

      json_match = text.match(/\{.*\}/m)
      raise 'No JSON found in API response' unless json_match

      json_str = json_match[0]
        .gsub("‘", "'").gsub("’", "'")
        .gsub("“", '"').gsub("”", '"')
        .gsub("–", '-').gsub("—", '--')

      data = JSON.parse(json_str)

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
