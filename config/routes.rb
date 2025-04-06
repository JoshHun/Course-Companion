Rails.application.routes.draw do
  get "accounts/new"
  get "dashboard/index"
  get "sessions/create"

  root 'landing#index'
  get "landing/index"

  post 'login', to: 'sessions#create'

  get 'dashboard', to: 'dashboard#index'

  get 'createaccount', to: 'create_account#new'
  post 'createaccount', to: 'create_account#create'

  get 'canvas_auth', to: 'canvas_auth#start'

  get 'canvas_callback', to: 'canvas_auth#callback', as: :canvas_callback

  delete '/logout', to: 'sessions#destroy', as: :logout

  get '/dashboard/:course_name', to: 'courses#show', as: :dashboard_course

  get '/files/summary', to: 'files#summary', as: :study_file


  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
