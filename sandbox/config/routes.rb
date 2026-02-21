Rails.application.routes.draw do
  Spree::Core::Engine.add_routes do
    # AI Description routes
    namespace :admin do
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
  mount Spree::Core::Engine, at: '/'
  devise_for :admin_users, class_name: "Spree::AdminUser"
  devise_for :users, class_name: "Spree::User"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  post "waitlist", to: "waitlist#create"
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
