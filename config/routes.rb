Rails.application.routes.draw do

	post 'authenticate', to: 'authentication#authenticate'

	scope format: true, constraints: {format: 'json'} do
		resources :publications do
			collection do
				get :random
				post :lookup
				post :fetch
			end
			member do
				get :refresh
				get :is_rated
			end
		end
		resources :ratings do
			collection do
				get :rate
			end
		end
		resources :users
	end

	post 'load', to: 'ratings#load', as: :load, constraints: {:format => 'html'}
	get 'rate/:pubId/:authToken/', to: 'ratings#rate', as: :rate, constraints: {:format => 'html'}

	post 'password/update', to: 'passwords#update', as: :password, constraints: {:format => 'json'}
	post 'password/forgot', to: 'passwords#forgot', as: :forgot, constraints: {:format => 'json'}
	get 'password/reset', to: 'passwords#reset', as: :reset, constraints: {:format => 'json'}

end
