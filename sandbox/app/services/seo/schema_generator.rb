# frozen_string_literal: true
# Seo::SchemaGenerator — generates JSON-LD structured data for Spree::Post records.
#
# Usage:
#   schema = Seo::SchemaGenerator.for_post(@post)
#   # => Hash ready for .to_json in view
#
#   # In view:
#   <script type="application/ld+json"><%= Seo::SchemaGenerator.for_post(@post).to_json.html_safe %></script>

module Seo
  class SchemaGenerator
    SITE_NAME = 'Surf Store'
    SITE_URL  = 'https://surf-store.com'

    # Route to the correct schema type based on post public_metadata
    def self.for_post(post)
      schema_type = post.get_metafield('schema_type')&.value || 'Article'

      case schema_type
      when 'HowTo'    then how_to_schema(post)
      when 'FAQPage'  then faq_schema(post)
      else                 article_schema(post)
      end
    end

    # Basic Article / BlogPosting schema
    def self.article_schema(post)
      schema = {
        '@context'      => 'https://schema.org',
        '@type'         => 'Article',
        'headline'      => post.title,
        'datePublished' => post.published_at&.iso8601,
        'dateModified'  => post.updated_at&.iso8601,
        'author'        => author_block(post),
        'publisher'     => publisher_block,
        'mainEntityOfPage' => {
          '@type' => 'WebPage',
          '@id'   => "#{SITE_URL}/posts/#{post.slug}"
        }
      }

      if post.image.attached?
        begin
          image_url = Rails.application.routes.url_helpers.rails_blob_url(
            post.image,
            host: 'www.surf-store.com',
            protocol: 'https'
          )
          schema['image'] = {
            '@type'  => 'ImageObject',
            'url'    => image_url,
            'width'  => 1200,
            'height' => 675
          }
        rescue
          # skip image in schema if URL cannot be generated
        end
      end

      schema['description'] = post.meta_description if post.meta_description.present?
      schema
    end

    # HowTo schema — extracts steps from H2 headings in content
    def self.how_to_schema(post)
      body  = post.content.to_s
      steps = extract_h2_steps(body)

      {
        '@context'  => 'https://schema.org',
        '@type'     => 'HowTo',
        'name'      => post.title,
        'description' => post.meta_description.presence || '',
        'step'      => steps.map.with_index(1) do |step, i|
          {
            '@type'    => 'HowToStep',
            'position' => i,
            'name'     => step[:heading],
            'text'     => step[:text]
          }
        end,
        'author'    => author_block(post),
        'datePublished' => post.published_at&.iso8601
      }
    end

    # FAQPage schema — extracts Q:/A: pairs from content
    def self.faq_schema(post)
      body = post.content.to_s
      pairs = extract_qa_pairs(body)

      {
        '@context'    => 'https://schema.org',
        '@type'       => 'FAQPage',
        'mainEntity'  => pairs.map do |qa|
          {
            '@type'          => 'Question',
            'name'           => qa[:question],
            'acceptedAnswer' => {
              '@type' => 'Answer',
              'text'  => qa[:answer]
            }
          }
        end
      }
    end

    private

    # Extract H2 headings + following paragraph text for HowTo steps
    def self.extract_h2_steps(html)
      steps = []
      return steps if html.blank?

      parts = html.split(/<h2[^>]*>/i)
      parts.drop(1).each do |part|
        heading_match = part.match(%r{^(.*?)</h2>}i)
        next unless heading_match

        heading = heading_match[1].gsub(/<[^>]+>/, '').strip
        # Get text from first <p> after the H2
        text_match = part.match(/<p[^>]*>(.*?)<\/p>/im)
        text = text_match ? text_match[1].gsub(/<[^>]+>/, '').strip : ''

        steps << { heading: heading, text: text }
      end

      steps
    end

    # Extract Q:/A: pairs for FAQPage
    def self.extract_qa_pairs(html)
      pairs = []
      return pairs if html.blank?

      plain = html.gsub(/<[^>]+>/, "\n").gsub(/\n+/, "\n")
      lines = plain.split("\n").map(&:strip).reject(&:blank?)

      current_q = nil
      lines.each do |line|
        if line.start_with?('Q:')
          current_q = line.sub(/^Q:\s*/, '')
        elsif line.start_with?('A:') && current_q
          pairs << { question: current_q, answer: line.sub(/^A:\s*/, '') }
          current_q = nil
        end
      end

      pairs
    end

    def self.author_block(post)
      {
        '@type' => 'Person',
        'name'  => post.try(:author_name) || SITE_NAME
      }
    end

    def self.publisher_block
      {
        '@type' => 'Organization',
        'name'  => SITE_NAME,
        'logo'  => {
          '@type' => 'ImageObject',
          'url'   => "#{SITE_URL}/images/surfstore_logo.webp"
        }
      }
    end
  end
end
