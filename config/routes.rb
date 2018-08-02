Rails.application.routes.draw do

	post 'authenticate', to: 'authentication#authenticate'

	scope format: true, constraints: {format: 'json'} do
		resources :publications do
			collection do
				post :fetch
				get :random
				post :lookup
			end
			member do
				get :refresh
			end
		end
		resources :ratings
		resources :users
	end

end
