json.extract! publication, :id, :doi, :title, :storage_path, :pdf_url, :pdf_download_path, :created_at, :updated_at
json.url publication_url(publication, format: :json)
