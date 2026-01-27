Rails.application.routes.draw do
  resource :session
  resource :settings, only: [ :show, :update ]
  resources :passwords, param: :token
  resources :registrations, only: [ :new, :create ]

  get "dashboard", to: "dashboard#show"
  root "dashboard#show"

  resources :salary_entries do
    collection do
      get :summary
    end
  end

  resources :households, only: [:create] do
    collection do
      post :join
    end
    member do
      delete :leave
      post :regenerate_code
    end
  end
  resource :household, only: [:show], controller: 'household'

  get "up" => "rails/health#show", as: :rails_health_check
end
