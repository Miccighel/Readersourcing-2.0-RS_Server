json.extract! publication,
			  :id,
			  :doi,
			  :title,
			  :subject,
			  :pdf_url,
			  :pdf_storage_url,
			  :pdf_name,
			  :pdf_download_url,
			  :pdf_name_link,
			  :pdf_download_url_link,
			  :created_at,
			  :updated_at
json.url publication_url(publication, format: :json)
