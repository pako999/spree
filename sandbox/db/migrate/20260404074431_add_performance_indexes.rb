class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    # spree_products_taxons — the existing taxon_id index exists but there is no
    # (taxon_id, position) composite. Category pages ORDER BY position, so Postgres
    # needs both columns to avoid a sort step after the index scan.
    unless index_exists?(:spree_products_taxons, [:taxon_id, :position],
                         name: 'index_spree_products_taxons_on_taxon_id_and_position')
      add_index :spree_products_taxons, [:taxon_id, :position],
                name: 'index_spree_products_taxons_on_taxon_id_and_position'
    end

    # spree_variants — (product_id, is_master) composite so product.master can be
    # resolved in one index-only scan instead of filtering the product_id index.
    unless index_exists?(:spree_variants, [:product_id, :is_master],
                         name: 'index_spree_variants_on_product_id_and_is_master')
      add_index :spree_variants, [:product_id, :is_master],
                name: 'index_spree_variants_on_product_id_and_is_master'
    end

    # spree_variants — (product_id, deleted_at) so soft-delete filtering on
    # product.variants (which adds WHERE deleted_at IS NULL) uses an index.
    unless index_exists?(:spree_variants, [:product_id, :deleted_at],
                         name: 'index_spree_variants_on_product_id_and_deleted_at')
      add_index :spree_variants, [:product_id, :deleted_at],
                name: 'index_spree_variants_on_product_id_and_deleted_at'
    end

    # spree_taxons — taxonomy_id standalone for queries that fetch all taxons
    # within a taxonomy (e.g. navigation mega-menu, brand pages).
    # The existing composite (name, parent_id, taxonomy_id) cannot be used for
    # taxonomy_id-only lookups because name is the leftmost column.
    unless index_exists?(:spree_taxons, :taxonomy_id,
                         name: 'index_spree_taxons_on_taxonomy_id')
      add_index :spree_taxons, :taxonomy_id,
                name: 'index_spree_taxons_on_taxonomy_id'
    end
  end
end
