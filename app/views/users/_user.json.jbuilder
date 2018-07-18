json.extract! user, :id, :firstName, :lastName, :email, :created_at, :updated_at
json.url user_url(user, format: :json)
