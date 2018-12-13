Rails.application.routes.draw do

	root to: 'application#home'

	scope format: true, constraints: {format: :json} do
		resources :publications do
			collection do
				get :random
				post :lookup
				post :is_fetchable
				post :fetch
			end
			member do
				get :refresh
				get :is_rated
				get :is_saved_for_later
			end
		end
		resources :ratings, except: [:destroy, :update] do
			collection do
				get :rate
			end
		end
		resources :users do
			collection do
				post :info
			end
		end
	end

	get 'login', to: 'authentication#login', as: :login, constraints: {:format => 'html'}
	post 'authenticate', to: 'authentication#authenticate', as: :authenticate, constraints: {:format => :json}

	get 'confirm/:id/:confirmToken', to: 'users#confirm_email', as: :confirm, constraints: {:format => 'html'}
	get 'unsubscribe/:id', to: 'users#unsubscribe', as: :unsubscribe, constraints: {:format => 'html'}
	get 'sign_up', to: 'users#sign_up', as: :sign_up, constraints: {:format => 'html'}

	post 'load', to: 'ratings#load', as: :load, constraints: {:format => 'html'}
	get 'rate/:pubId/:authToken/', to: 'ratings#rate', as: :rate, constraints: {:format => 'html'}

	post 'password/update', to: 'passwords#update', as: :password, constraints: {:format => /(html|json)/}
	get 'password/forgot', to: 'passwords#forgot', as: :forgot, constraints: {:format => /(html|json)/}
	post 'password/forgot', to: 'passwords#forgot', constraints: {:format => /(html|json)/}
	get 'password/reset', to: 'passwords#reset', as: :reset, constraints: {:format => /(html|json)/}

end
