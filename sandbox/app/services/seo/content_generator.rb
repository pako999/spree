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
    MODEL       = 'claude-sonnet-4-6'
    MAX_TOKENS  = 4096
    API_VERSION = '2023-06-01'

    TEMPLATES = {
      'brand_category' => <<~PROMPT,
        You are an expert SEO content writer for surf-store.com, a European water sports shop specialising in kitesurfing, windsurfing, wing foiling, wetsuits, and SUP.

        Write a complete brand/category page for: **%{name}** (URL: surf-store.com/%{permalink})

        Target keyword: %{keyword}

        Requirements:
        - meta_title: max 60 chars, include brand + year (2026) + category
        - meta_description: max 155 chars, end with a clear CTA ("Shop now at Surf Store")
        - title: H1 for the page (max 70 chars)
        - body_html: 650–800 words, HTML with <h2> subheadings, <p> paragraphs
          • H2 sections: "About [Brand]", "Why Buy [Category] at Surf Store", "Our [Brand] Range", "Expert Advice"
          • Include specific product benefits, materials, technology names
          • One FAQ block with 3 Q:/A: pairs at the end
        - excerpt: 1-sentence summary (max 160 chars)

        Respond ONLY with valid JSON matching this exact structure:
        {
          "meta_title": "...",
          "meta_description": "...",
          "title": "...",
          "body_html": "...",
          "excerpt": "...",
          "faq": [{"q": "...", "a": "..."}, ...]
        }
      PROMPT

      'buying_guide' => <<~PROMPT,
        You are an expert SEO content writer for surf-store.com, a European water sports shop.

        Write a complete buying guide for: **%{name}**

        Target keyword: %{keyword}

        Requirements:
        - meta_title: max 60 chars
        - meta_description: max 155 chars, end with CTA
        - title: H1 (max 70 chars)
        - body_html: 800–1000 words HTML with <h2> sections including:
          • "What to Look For", "Beginner vs Advanced", "Budget Guide", "Our Top Picks"
          • HowTo steps formatted as: <h2>Step 1: ...</h2><p>...</p>
        - excerpt: 1-sentence (max 160 chars)
        - faq: 5 Q:/A: pairs relevant to the topic

        Respond ONLY with valid JSON:
        {
          "meta_title": "...",
          "meta_description": "...",
          "title": "...",
          "body_html": "...",
          "excerpt": "...",
          "faq": [{"q": "...", "a": "..."}, ...]
        }
      PROMPT

      'location' => <<~PROMPT,
        You are an expert SEO content writer for surf-store.com.

        Write a local SEO page for water sports at: **%{name}**

        Target keyword: %{keyword}

        Requirements:
        - meta_title: max 60 chars, include location + sport + year
        - meta_description: max 155 chars, include location, end with CTA
        - title: H1 (max 70 chars)
        - body_html: 600–800 words HTML with <h2> sections:
          • "Kitesurfing/Windsurfing in [Location]", "Best Spots", "When to Go", "What to Pack", "Rent or Buy?"
        - excerpt: 1-sentence (max 160 chars)
        - faq: 3 Q:/A: pairs

        Respond ONLY with valid JSON:
        {
          "meta_title": "...",
          "meta_description": "...",
          "title": "...",
          "body_html": "...",
          "excerpt": "...",
          "faq": [{"q": "...", "a": "..."}, ...]
        }
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

    # Generate content for multiple pages, respecting rate limit (10 req/min).
    # Yields each result with its index.
    def generate_batch(items, &block)
      items.each_with_index do |item, i|
        result = generate(**item)
        block.call(result, i) if block

        # Rate limiting: 10 requests per minute → 6 second gap
        sleep(6) if (i + 1) % 10 == 0
      end
    end

    private

    def call_api(prompt)
      uri  = URI.parse(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.read_timeout = 60
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri.path)
      req['x-api-key']         = @api_key
      req['anthropic-version'] = API_VERSION
      req['Content-Type']      = 'application/json'

      req.body = {
        model:      MODEL,
        max_tokens: MAX_TOKENS,
        messages:   [{ role: 'user', content: prompt }]
      }.to_json

      res = http.request(req)
      raise "API error #{res.code}: #{res.body.truncate(200)}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    end

    def parse_response(api_response)
      text = api_response.dig('content', 0, 'text').to_s.strip

      # Extract JSON from response (Claude may add prose around it)
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
