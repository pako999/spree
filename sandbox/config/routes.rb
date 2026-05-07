Rails.application.routes.draw do
  # CSRF token refresh for pages served from Cloudflare cache (no session cookie)
  get '/csrf_token', to: 'csrf_tokens#show'

  Spree::Core::Engine.add_routes do
    # AI Description routes
    namespace :admin do
      resources :stock_syncs, only: [:index] do
        collection { post :run }
      end
      resources :waitlist_entries, only: [:index]
      post "products/:id/ai_description", to: "ai_descriptions#create", as: :product_ai_description
      get "ai_descriptions/bulk", to: "ai_descriptions#bulk", as: :ai_descriptions_bulk
      post "ai_descriptions/generate_bulk", to: "ai_descriptions#generate_bulk", as: :ai_descriptions_generate_bulk
    end

    # Saferpay payment callbacks
    get 'saferpay/success', to: 'saferpay#success', as: :saferpay_success
    get 'saferpay/fail', to: 'saferpay#fail', as: :saferpay_fail
    post 'saferpay/notify', to: 'saferpay#notify', as: :saferpay_notify

    # Admin authentication
    devise_for(
      Spree.admin_user_class.model_name.singular_route_key,
      class_name: Spree.admin_user_class.to_s,
      controllers: {
        sessions: 'spree/admin/user_sessions',
        passwords: 'spree/admin/user_passwords'
      },
      skip: :registrations,
      path: :admin_user,
      router_name: :spree
    )
  end
  # This line mounts Spree's routes at the root of your application.
  # This means, any requests to URLs such as /products, will go to
  # Spree::ProductsController.
  # If you would like to change where this engine is mounted, simply change the
  # :at option to something different.
  #
  # We ask that you don't use the :as option here, as Spree relies on it being
  # the default of "spree".
  # Redirect dead /de/ locale paths → /en/ (de locale was removed)
  # Google has cached 400+ /de/ URLs — 301s will clear them from the index
  get '/de',        to: redirect('/en', status: 301)
  get '/de/*path',  to: redirect('/en/%{path}', status: 301)

  mount Spree::Core::Engine, at: '/'
  devise_for :admin_users, class_name: "Spree::AdminUser"
  devise_for :users, class_name: "Spree::User",
             controllers: {
               sessions: 'spree/user_sessions',
               registrations: 'spree/user_registrations',
               passwords: 'spree/user_passwords'
             }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  post "waitlist", to: "waitlist#create"
  get "up" => "rails/health#show", as: :rails_health_check

  # Google Merchant Center product feed
  # Submit https://surf-store.com/feeds/google-shopping.xml to Google Merchant Center.
  get 'feeds/google-shopping.xml', to: 'feeds#google_shopping', as: :google_shopping_feed, defaults: { format: :xml }
  get 'sitemap-seo.xml', to: 'feeds#sitemap_seo', as: :seo_sitemap, defaults: { format: :xml }

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Old Shopify URLs → 301 redirects (preserves SEO)
  get 'blogs/news/:slug', to: redirect('/en/posts/%{slug}', status: 301)
  get 'blogs/:category/:slug', to: redirect('/en/posts/%{slug}', status: 301)
  get ':locale/blogs/news/:slug', to: redirect('/en/posts/%{slug}', status: 301)
  get ':locale/blogs/:category/:slug', to: redirect('/en/posts/%{slug}', status: 301)
  get 'pages/about-us', to: redirect('/en/policies/about-us', status: 301)

  # Old Shopify product URLs → smart redirect to matching Spree product or category
  get 'products/:slug', to: 'shopify_redirects#product'
  get 'collections/:slug', to: 'shopify_redirects#product'

  # Catch-all: redirect any unmatched URL to homepage
  # Handles old Shopify /collections/*, unsupported locale /sl/*, *.html URLs, etc.
  # Excludes API, admin, Rails internals, static assets, and product feeds
  match '*path', to: redirect('/'), via: :all,
        constraints: ->(req) { req.path !~ %r{\A/(api|admin|rails|assets|packs|images|icon|favicon|up|q1qf|olaf|cdn|feeds|sitemap|blogs|pages|login|logout|signup|users|account|cart|checkout|orders|wishlist|posts|policies|t/|products|locale)} }

  # Defines the root path route ("/")
  # root "posts#index"
end
