Rails.application.routes.draw do

  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks'
  }
 resources :users, only: [:show, :edit, :update]

  get 'bookings/new', to: 'bookings#new', as: 'new_booking'
  post 'bookings', to: 'bookings#create', as: 'bookings'


  root "home#index"
  get 'calendar', to: 'calendar#index'
end
