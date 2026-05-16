Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Auth
      post 'auth/login', to: 'auth#login'
      get 'auth/me', to: 'auth#me'

      # Club schedules
      resources :club_schedules, only: [:index, :show, :create, :update, :destroy]

      # ── Rental System ──
      resources :racket_types, only: [:index, :show, :create, :update, :destroy]

      resources :rackets, only: [:index, :show, :create, :update, :destroy] do
        collection do
          get 'scan/:qr_code', to: 'rackets#scan', as: :scan
        end
        member do
          get :label_pdf
          get :qr_code_png
        end
      end

      resources :customers, only: [:index, :show, :create, :update] do
        collection { get :search }
      end

      resources :rentals, only: [:index, :show, :create] do
        member do
          post :add_photo
          put :extend_rental
          put :return_racket
        end
      end

      # Stats
      get 'stats/dashboard', to: 'stats#dashboard'

      # ── Stringing Service ──
      resources :stringing_customers, only: [:index, :show, :create, :update] do
        collection { get :search }
        member { put :unsubscribe }
      end

      resources :stringing_orders, only: [:index, :show, :create, :update] do
        member do
          put :start
          put :complete
          put :pickup
          put :cancel
        end
      end

      resources :email_flows, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :send_to_customers
          get :history
        end
        collection do
          post :bulk_send
        end
      end
    end
  end

  # Unsubscribe (public, no auth)
  get 'unsubscribe/:token', to: 'unsubscribe#show', as: :unsubscribe
  post 'unsubscribe/:token', to: 'unsubscribe#update'

  # Email open tracking pixel
  get 'track/open/:token', to: 'tracking#open', as: :tracking_open
end
