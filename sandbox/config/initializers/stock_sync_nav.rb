Rails.application.config.after_initialize do
  next unless defined?(Spree::Admin) && Spree.respond_to?(:admin)

  sidebar_nav = Spree.admin.navigation.sidebar

  sidebar_nav.add :stock_syncs,
                  label: 'Stock Sync',
                  url: :admin_stock_syncs_path,
                  icon: 'refresh',
                  position: 75
end
