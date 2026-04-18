Rails.application.routes.draw do
  resource :session
  resource :settings, only: [ :show, :update ]
  resources :connected_apps, only: [ :index, :destroy ]
  resources :passwords, param: :token
  resources :registrations, only: [ :new, :create ]

  get "shared/budgets/:token", to: "shared_budgets#show", as: :shared_budget

  get "dashboard", to: "dashboard#show"
  root "pages#home"

  resources :salary_entries do
    collection do
      get :summary
    end
  end

  resources :budgets, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    resources :budget_items, only: [ :create, :update, :destroy ] do
      member do
        patch :toggle_paid
      end
    end
    resources :budget_shares, only: [ :create, :destroy ]
    resources :income_source_overrides, only: [ :create, :destroy ]
  end

  resources :income_sources, only: [ :index, :create, :update, :destroy ]

  resources :households, only: [ :create ] do
    collection do
      post :join
    end
    member do
      delete :leave
      post :regenerate_code
    end
  end
  resource :household, only: [ :show ], controller: "household"

  namespace :oauth do
    get "authorize", to: "authorize#show"
    post "authorize", to: "authorize#create"
    post "token", to: "token#create"
  end

  namespace :api do
    namespace :v1 do
      get "monthly_budgets/current", to: "monthly_budgets#current"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
