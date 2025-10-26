Rails.application.routes.draw do
  # Health check endpoints
  get "health" => "health#index"
  get "health/detailed" => "health#detailed"
  get "health/ready" => "health#ready"
  get "health/live" => "health#live"

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # RESTful resources
  resources :activities
  resources :playlists

  # Activity scheduling
  resource :schedule, only: [:show], controller: 'activity_scheduling' do
    post 'events', to: 'activity_scheduling#create', as: :events
    post 'events/batch', to: 'activity_scheduling#batch', as: :batch_events
  end

  get "home/index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  # Redirect authenticated users to activities
  authenticated :user do
    root to: "activities#index", as: :authenticated_root
  end
end
