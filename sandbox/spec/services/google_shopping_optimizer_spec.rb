# frozen_string_literal: true

# GoogleShoppingOptimizer is a pure Ruby module (no DB / Rails dependencies).
# We load it directly so the spec runs without the full Rails stack.
require 'spec_helper'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/filters'
require_relative '../../app/services/google_shopping_optimizer'

RSpec.describe GoogleShoppingOptimizer do
  # ── Brand normalisation ────────────────────────────────────────────────────

  describe '.normalize_brand' do
    it 'consolidates ION sub-brands' do
      expect(described_class.normalize_brand('ION Water')).to eq('ION')
      expect(described_class.normalize_brand('ION Bike')).to  eq('ION')
      expect(described_class.normalize_brand('ION')).to        eq('ION')
    end

    it 'consolidates Duotone sub-brands' do
      expect(described_class.normalize_brand('Duotone Kiteboarding')).to eq('Duotone')
      expect(described_class.normalize_brand('Duotone Windsurfing')).to  eq('Duotone')
      expect(described_class.normalize_brand('Duotone Wing Foiling')).to eq('Duotone')
      expect(described_class.normalize_brand('Duotone Foilwing')).to     eq('Duotone')
    end

    it 'consolidates Fanatic sub-brands' do
      expect(described_class.normalize_brand('Fanatic SUP')).to         eq('Fanatic')
      expect(described_class.normalize_brand('Fanatic Windsurfing')).to eq('Fanatic')
    end

    it 'fixes NeilPryde capitalisation variants' do
      expect(described_class.normalize_brand('Neilpryde')).to  eq('NeilPryde')
      expect(described_class.normalize_brand('NEILPRYDE')).to  eq('NeilPryde')
      expect(described_class.normalize_brand('neilpryde')).to  eq('NeilPryde')
    end

    it 'fixes Tabou capitalisation variants' do
      expect(described_class.normalize_brand('TABOU')).to eq('Tabou')
      expect(described_class.normalize_brand('tabou')).to eq('Tabou')
    end

    it 'returns empty string for blank input' do
      expect(described_class.normalize_brand(nil)).to   eq('')
      expect(described_class.normalize_brand('')).to    eq('')
      expect(described_class.normalize_brand('  ')).to  eq('')
    end

    it 'passes through unknown brands unchanged' do
      expect(described_class.normalize_brand('CustomBrand X')).to eq('CustomBrand X')
    end
  end

  # ── Exclusion rules ────────────────────────────────────────────────────────

  describe '.exclude?' do
    it 'excludes gift cards' do
      expect(described_class.exclude?('Gift Card €50', 10, false)).to be true
    end

    it 'excludes shipping insurance products' do
      expect(described_class.exclude?('Worry-Free Delivery', 5, false)).to  be true
      expect(described_class.exclude?('Shipping Insurance', 5, false)).to   be true
      expect(described_class.exclude?('Shipping Protection', 5, false)).to  be true
    end

    it 'excludes 2023/2024/2025 products that are out of stock and not backorderable' do
      expect(described_class.exclude?('Duotone Evo 2024', 0, false)).to be true
      expect(described_class.exclude?('ION Impact Vest 2023', 0, false)).to be true
      expect(described_class.exclude?('Cabrinha Switchblade 2025', 0, false)).to be true
    end

    it 'keeps 2024/2025 products that are backorderable' do
      expect(described_class.exclude?('Duotone Evo 2024', 0, true)).to be false
    end

    it 'keeps 2024/2025 products that are in stock' do
      expect(described_class.exclude?('Duotone Evo 2024', 3, false)).to be false
    end

    it 'keeps 2026 products that are out of stock' do
      expect(described_class.exclude?('Duotone Neo SLS 2026', 0, false)).to be false
    end

    it 'keeps evergreen products that are out of stock' do
      expect(described_class.exclude?('ION Wetsuit', 0, false)).to be false
    end
  end

  # ── Year extraction ────────────────────────────────────────────────────────

  describe '.extract_year' do
    it 'extracts 4-digit year from title' do
      expect(described_class.extract_year('Duotone Evo 2026')).to eq('2026')
      expect(described_class.extract_year('ION Harness 2023')).to eq('2023')
    end

    it 'returns nil when no year present' do
      expect(described_class.extract_year('ION Wetsuit')).to be_nil
    end
  end

  # ── Availability ───────────────────────────────────────────────────────────

  describe '.availability' do
    it 'returns in_stock when stock > 0' do
      expect(described_class.availability(5, false)).to eq('in_stock')
    end

    it 'returns preorder when backorderable and stock = 0' do
      expect(described_class.availability(0, true)).to eq('preorder')
    end

    it 'returns out_of_stock when stock = 0 and not backorderable' do
      expect(described_class.availability(0, false)).to eq('out_of_stock')
    end
  end

  # ── Product type detection ─────────────────────────────────────────────────

  describe '.detect_product_type' do
    def detect(title, brand: '', taxons: [])
      described_class.detect_product_type(title, brand, taxons)
    end

    context 'from taxon paths (primary signal)' do
      it 'detects kitesurfing kites' do
        expect(detect('Duotone Evo SLS 2026', taxons: ['categories/kitesurfing/kites/kite'])).to eq('Kitesurfing Kite')
      end

      it 'detects kiteboards' do
        expect(detect('Nobile NHP', taxons: ['categories/kitesurfing/kiteboards/kiteboard'])).to eq('Kiteboard')
        expect(detect('Nobile NHP Foil', taxons: ['categories/kitesurfing/kiteboards/kite-foil-board'])).to eq('Kite Foil Board')
      end

      it 'detects kite control bars' do
        expect(detect('Duotone Trust Bar 2026', taxons: ['categories/kitesurfing/kite-accessories/kite-bar'])).to eq('Kite Control Bar')
      end

      it 'detects windsurfing sails' do
        expect(detect('Gaastra Manic', taxons: ['categories/windsurf/windsurf-sails/windsurfing-sails'])).to eq('Windsurfing Sail')
      end

      it 'detects windsurfing masts' do
        expect(detect('NeilPryde X9 Mast', taxons: ['categories/windsurf/windsurf-gear/windsurf-mast'])).to eq('Windsurfing Mast')
      end

      it 'detects windsurfing booms' do
        expect(detect('Gaastra Carbon Boom', taxons: ['categories/windsurf/windsurf-gear/windsurf-boom'])).to eq('Windsurfing Boom')
      end

      it 'detects wing foiling wings' do
        expect(detect('Duotone Unit 2026', taxons: ['categories/wingfoil/wings/wing'])).to eq('Wing Foiling Wing')
      end

      it 'detects wing foiling boards' do
        expect(detect('Fanatic Sky Wing', taxons: ['categories/wingfoil/wing-boards/wingboard'])).to eq('Wing Foiling Board')
      end

      it 'detects hydrofoils from wing-foils taxon' do
        expect(detect('Duotone Foil', taxons: ['categories/wingfoil/wing-foils/foil'])).to eq('Hydrofoil')
      end

      it 'detects SUP boards' do
        expect(detect('Fanatic Ray Air', taxons: ['categories/sup-board/sup-boards'])).to eq('SUP Board')
      end

      it 'detects SUP paddles' do
        expect(detect('Fanatic Paddle', taxons: ['categories/sup-board/sup-paddles'])).to eq('SUP Paddle')
      end

      it 'detects wetsuits' do
        expect(detect('ION Seek Select 4/3', taxons: ['categories/wetsuits'])).to eq('Wetsuit')
      end

      it 'detects shorty wetsuits' do
        expect(detect('ION Strike Shorty', taxons: ['categories/wetsuits'])).to eq('Shorty Wetsuit')
      end

      it 'detects neoprene gloves' do
        expect(detect('ION Claw 3/2mm Gloves', taxons: ['categories/wetsuits/neoprene-accessories/gloves'])).to eq('Neoprene Gloves')
      end

      it 'detects boardshorts' do
        expect(detect('ION Boardies', taxons: ['categories/apparel/boardshorts'])).to eq('Boardshorts')
      end

      it 'detects caps' do
        expect(detect('ION Logo Cap', taxons: ['categories/apparel/cap'])).to eq('Cap')
      end

      it 'detects e-foil' do
        expect(detect('Fliteboard Air', taxons: ['categories/e-foil/e-foil-sets'])).to eq('E-Foil')
      end
    end

    context 'keyword fallback (no taxon)' do
      it 'detects a kite from title' do
        expect(detect('Cabrinha Switchblade Kite')).to eq('Kitesurfing Kite')
      end

      it 'detects a windsurfing sail from title' do
        expect(detect('Gaastra Manic Sail')).to eq('Windsurfing Sail')
      end

      it 'detects a wetsuit from title' do
        expect(detect('ION Wetsuit 5/4mm')).to eq('Wetsuit')
      end
    end
  end

  # ── Custom labels ──────────────────────────────────────────────────────────

  describe '.custom_label_0_margin' do
    it 'classifies leashes as high margin' do
      expect(described_class.custom_label_0_margin('Kite Leash')).to eq('high_margin')
    end

    it 'classifies caps as high margin' do
      expect(described_class.custom_label_0_margin('Cap')).to eq('high_margin')
    end

    it 'classifies kites as low margin' do
      expect(described_class.custom_label_0_margin('Kitesurfing Kite')).to eq('low_margin')
    end

    it 'classifies sails as low margin' do
      expect(described_class.custom_label_0_margin('Windsurfing Sail')).to eq('low_margin')
    end

    it 'classifies harnesses as mid margin' do
      expect(described_class.custom_label_0_margin('Kite Harness')).to eq('mid_margin')
    end

    it 'returns mid_margin for blank input' do
      expect(described_class.custom_label_0_margin(nil)).to   eq('mid_margin')
      expect(described_class.custom_label_0_margin('')).to    eq('mid_margin')
    end
  end

  describe '.custom_label_2_season' do
    it 'returns the year found in the title' do
      expect(described_class.custom_label_2_season('Duotone Evo 2026')).to eq('2026')
      expect(described_class.custom_label_2_season('ION Cap 2024')).to     eq('2024')
    end

    it 'returns evergreen when no year present' do
      expect(described_class.custom_label_2_season('ION Wetsuit')).to eq('evergreen')
    end
  end

  describe '.custom_label_3_price_bucket' do
    it 'buckets prices correctly' do
      expect(described_class.custom_label_3_price_bucket(49.99)).to   eq('under_100')
      expect(described_class.custom_label_3_price_bucket(199)).to     eq('100_to_300')
      expect(described_class.custom_label_3_price_bucket(550)).to     eq('300_to_800')
      expect(described_class.custom_label_3_price_bucket(999)).to     eq('800_to_1500')
      expect(described_class.custom_label_3_price_bucket(2500)).to    eq('1500_plus')
      expect(described_class.custom_label_3_price_bucket(0)).to       eq('unknown')
      expect(described_class.custom_label_3_price_bucket(nil)).to     eq('unknown')
    end
  end

  # ── Title builder ──────────────────────────────────────────────────────────

  describe '.build_title' do
    def title(name, brand: '', type: '', color: nil, size: nil)
      described_class.build_title(name, brand, type, color, size)
    end

    it 'builds a full optimized title' do
      result = title('ION Water Seek Select 4/3 2026', brand: 'ION Water', type: 'Wetsuit', color: 'Black', size: 'M')
      expect(result).to include('ION')
      expect(result).to include('Seek Select 4/3')
      expect(result).to include('Wetsuit')
      expect(result).to include('2026')
      expect(result).to include('Black')
      expect(result).to include('M')
      expect(result).not_to include('ION Water ION') # no double brand
    end

    it 'strips brand noise words from model name' do
      result = title('Duotone Kiteboarding Evo SLS 2026', brand: 'Duotone Kiteboarding', type: 'Kitesurfing Kite')
      expect(result).not_to include('Kiteboarding Kiteboarding')
      expect(result).to     include('Evo SLS')
    end

    it 'strips year from model name to avoid duplication' do
      result = title('Duotone Evo 2026', brand: 'Duotone', type: 'Kitesurfing Kite')
      expect(result.scan('2026').count).to eq(1)
    end

    it 'handles missing color and size gracefully' do
      result = title('Nobile NHP 2026', brand: 'Nobile', type: 'Kiteboard')
      expect(result).not_to match(/\s{2,}/)  # no double spaces
    end

    it 'truncates to 150 chars with ellipsis' do
      long_name = 'A' * 200
      result = title(long_name, brand: 'Brand', type: 'Type')
      expect(result.length).to be <= 150
      expect(result).to end_with('...')
    end
  end
end
