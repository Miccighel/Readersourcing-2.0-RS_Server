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
		resources :users do
            collection do
                post :password
            end
        end
	end

	post 'load', to: 'ratings#load', as: :load, constraints: {:format => 'html'}
	get 'rate/:pubId/:authToken/', to: 'ratings#rate', as: :rate, constraints: {:format => 'html'}

end
