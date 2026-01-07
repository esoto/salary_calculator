Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: [:new, :create]

  resources :salary_entries do
    collection do
      get :summary
    end
  end

  root "salary_entries#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
