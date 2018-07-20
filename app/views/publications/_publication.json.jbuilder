json.extract! publication, :id, :doi, :title, :subject, :pdf_url, :storage_url, :pdf_download_url, :created_at, :updated_at
json.url publication_url(publication, format: :json)
