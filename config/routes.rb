Rails.application.routes.draw do
  scope format: true, constraints: { format: 'json' } do
    resources :publications
    resources :ratings
  	end
end
