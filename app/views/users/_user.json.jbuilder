json.extract! user, :id, :first_name, :last_name, :email, :orcid, :subscribe, :score, :steadiness, :bonus, :created_at, :updated_at
json.url user_url(user, format: :json)
