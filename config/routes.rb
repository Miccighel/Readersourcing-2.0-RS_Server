Rails.application.routes.draw do

	scope format: true, constraints: {format: 'json'} do
		resources :publications do
			member do
				post :fetch
			end
		end
		resources :ratings
		resources :users
	end

end
