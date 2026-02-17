require 'net/http'
require 'json'
require 'uri'

module Spree
  class AiDescriptionService
    GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent'.freeze

    def initialize(product)
      @product = product
    end

    def call
      prompt = build_prompt
      response = make_request(prompt)
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error("[AI Description] Error: #{e.message}")
      { error: e.message }
    end

    private

    def api_key
      ENV.fetch('GEMINI_API_KEY') { raise 'GEMINI_API_KEY environment variable is not set' }
    end

    def build_prompt
      product_info = []
      product_info << "Product Name: #{@product.name}"
      product_info << "Brand: #{@product.brand&.name}" if @product.respond_to?(:brand) && @product.brand.present?

      if @product.taxons.any?
        categories = @product.taxons.map(&:pretty_name).join(', ')
        product_info << "Categories: #{categories}"
      end

      if @product.product_properties.any?
        props = @product.product_properties.includes(:property).map { |pp| "#{pp.property.presentation}: #{pp.value}" }.join(', ')
        product_info << "Properties: #{props}"
      end

      if @product.has_variants?
        variant_info = @product.variants.map { |v| v.options_text }.compact.reject(&:blank?).first(5)
        product_info << "Variant Options: #{variant_info.join(', ')}" if variant_info.any?
      end

      price = @product.price_in(@product.cost_currency.presence || 'EUR')
      product_info << "Price: #{price.display_price}" if price.amount.present?

      if @product.description.present?
        product_info << "Existing description (rewrite and improve this): #{strip_html(@product.description)}"
      end

      system_prompt = <<~PROMPT
        You are an expert e-commerce copywriter for Surfworld, a premium water sports equipment shop.
        Write compelling, SEO-optimized product content for water sports gear (kitesurfing, windsurfing, wingfoil, SUP, wetsuits, etc.).

        Your writing style:
        - Professional but approachable, gear-enthusiast tone
        - Focus on benefits and real-world performance, not just specs
        - Use HTML formatting: <h2>, <h3>, <p>, <ul>, <li>, <strong>
        - Include relevant keywords naturally for SEO
        - Never mention competitors by name
        - Never mention "Surf-Store" or "surf-store.com"
        - Reference "Surfworld" as the shop name where appropriate
        - Write in English

        Given the following product information, return a valid JSON object with exactly these keys:
        {
          "description": "HTML product description (200-300 words, with headings and bullet points)",
          "meta_title": "SEO meta title (max 60 characters, include product name and key feature)",
          "meta_description": "SEO meta description (max 155 characters, compelling call-to-action)"
        }

        Return ONLY the raw JSON object. No markdown code fences, no explanation.
      PROMPT

      { system: system_prompt, user: product_info.join("\n") }
    end

    def make_request(prompt)
      uri = URI("#{GEMINI_URL}?key=#{api_key}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        contents: [
          {
            role: 'user',
            parts: [{ text: "#{prompt[:system]}\n\nProduct Information:\n#{prompt[:user]}" }]
          }
        ],
        generationConfig: {
          temperature: 0.7,
          responseMimeType: 'application/json'
        }
      }.to_json

      http.request(request)
    end

    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        error_body = JSON.parse(response.body) rescue {}
        raise "Gemini API error (#{response.code}): #{error_body.dig('error', 'message') || response.body}"
      end

      data = JSON.parse(response.body)
      content = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
      raise 'Empty response from Gemini' if content.blank?

      # Clean any markdown fences if present
      cleaned = content.gsub(/\A```json\s*/, '').gsub(/\s*```\z/, '').strip
      result = JSON.parse(cleaned)

      {
        description: result['description'],
        meta_title: result['meta_title']&.truncate(60),
        meta_description: result['meta_description']&.truncate(155)
      }
    end

    def strip_html(html)
      ActionController::Base.helpers.strip_tags(html).squish.truncate(500)
    end
  end
end
