json.extract! publication, :id, :doi, :title, :created_at, :updated_at
json.url publication_url(publication, format: :json)
