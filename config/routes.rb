Rails.application.routes.draw do

	root to: 'application#home'
	get 'up', to: 'rails/health#show', as: :rails_health_check

	scope format: true, constraints: {format: :json} do
		resources :publications, only: [:index, :show, :create] do
			collection do
				get :random
				post :lookup
				post :is_fetchable
				post :fetch
				post :fetch_upload
				post :extract
			end
			member do
				post :refresh
				get :is_rated
				get :is_saved_for_later
			end
		end
		resources :ratings, except: [:destroy] do
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

	get 'unauthorized', to: 'application#unauthorized', as: :unauthorized, constraints: {:format => 'json'}
	get 'resources', to: 'application#resources', as: :resources, constraints: {:format => 'html'}
	get 'software', to: 'application#software', as: :software, constraints: {:format => 'html'}
	get 'privacy', to: 'application#privacy', as: :privacy, constraints: {:format => 'html'}
	get 'contact', to: 'application#contact', as: :contact, constraints: {:format => 'html'}
	post 'message', to: 'application#message', as: :ask, constraints: {:format => 'json'}

	get 'login', to: 'authentication#login', as: :login, constraints: {:format => 'html'}
	post 'logout', to: 'authentication#logout', as: :logout, constraints: {:format => :json}
	post 'logout', to: 'authentication#logout', constraints: {:format => :html}
	post 'authenticate', to: 'authentication#authenticate', as: :authenticate, constraints: {:format => :json}

	get 'publications/list/', to: 'publications#list', as: :publications_list, constraints: {:format => 'html'}
	get 'publications/:id/download/:variant/:reference/:filename',
		to: 'publication_downloads#show',
		as: :publication_download,
		constraints: {variant: /original|annotated/, filename: /[^\/]+\.pdf/i}

	get 'readers/list/', to: 'users#list', as: :users_list, constraints: {:format => 'html'}
	get 'profile/edit/', to: 'users#edit', as: :profile, constraints: {:format => 'html'}
	get 'confirm/:id/:confirmToken', to: 'users#confirm_email', as: :confirm, constraints: {:format => 'html'}
	get 'unsubscribe/:id', to: 'users#unsubscribe_confirmation', as: :unsubscribe, constraints: {:format => 'html'}
	post 'unsubscribe/:id', to: 'users#unsubscribe', constraints: {:format => /(html|json)/}
	get 'sign_up', to: 'users#sign_up', as: :sign_up, constraints: {:format => 'html'}

	post 'load', to: 'ratings#load', as: :load, constraints: {:format => 'html'}
	get 'rate/:pubId/:reference/', to: 'ratings#rate_paper', as: :rate_paper, constraints: {:format => 'html'}
	get 'rate/', to: 'ratings#rate_web', as: :rate_web, constraints: {:format => 'html'}

	get 'password/edit/', to: 'passwords#edit', as: :edit, constraints: {:format => 'html'}
	post 'password/update', to: 'passwords#update', constraints: {:format => /(html|json)/}
	get 'password/forgot', to: 'passwords#forgot', as: :forgot, constraints: {:format => :html}
	post 'password/forgot', to: 'passwords#forgot', constraints: {:format => /(html|json)/}
	get 'password/reset', to: 'passwords#reset', as: :reset, constraints: {:format => /(html|json)/}
	post 'password/reset', to: 'passwords#reset', constraints: {:format => /(html|json)/}

end
