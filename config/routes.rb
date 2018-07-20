Rails.application.routes.draw do

	scope format: true, constraints: {format: 'json'} do
		resources :publications do
			collection do
				post :fetch
				get :random
			end
			member do
				get :refresh
			end
		end
		resources :ratings
		resources :users
	end

end
