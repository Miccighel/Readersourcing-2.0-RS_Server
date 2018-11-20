json.id publication.id
json.doi publication.doi
json.title publication.title
json.subject publication.subject
json.author publication.author
json.creator publication.creator
json.producer publication.producer
json.pdf_url publication.pdf_url
json.pdf_storage_path "user/#{@user.id.to_s}/#{publication.pdf_storage_path}"
json.pdf_name publication.pdf_name
json.pdf_download_path "user/#{@user.id.to_s}/#{publication.pdf_download_path}"
json.pdf_download_url publication.pdf_download_url(@request_data[:host], @user)
json.pdf_name_link publication.pdf_name_link
json.pdf_download_path_link "user/#{@user.id.to_s}/#{publication.pdf_download_path_link}"
json.pdf_download_url_link publication.pdf_download_url_link(@request_data[:host], @user)
json.steadiness publication.steadiness
json.score_rsm publication.score_rsm
json.score_trm publication.score_trm
json.created_at publication.created_at
json.updated_at publication.updated_at
json.url publication_url(publication, format: :json)
