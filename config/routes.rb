Rails.application.routes.draw do
  resource :session
  resource :settings, only: [ :show, :update ]
  resources :passwords, param: :token
  resources :registrations, only: [ :new, :create ]

  get "shared/budgets/:token", to: "shared_budgets#show", as: :shared_budget

  get "dashboard", to: "dashboard#show"
  root "dashboard#show"

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

  get "up" => "rails/health#show", as: :rails_health_check
end
