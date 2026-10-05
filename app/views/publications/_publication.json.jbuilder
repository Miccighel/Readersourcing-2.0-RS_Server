json.id publication.id
json.doi publication.doi
json.title publication.title
json.subject publication.subject
json.author publication.author
json.creator publication.creator
json.producer publication.producer
json.pdf_url publication.pdf_url
copy = publication.copy_for(@user)
json.pdf_storage_path copy&.logical_directory
json.pdf_name copy&.available?("original") ? copy.name("original") : nil
json.pdf_download_path copy&.logical_path("original")
json.pdf_download_url publication.pdf_download_url(@request_data[:host], @user, copy: copy)
json.pdf_name_link copy&.available?("annotated") ? copy.name("annotated") : nil
json.pdf_download_path_link copy&.logical_path("annotated")
json.pdf_download_url_link publication.pdf_download_url_link(@request_data[:host], @user, copy: copy)
json.preparation_status copy&.available?("annotated") ? "complete" : "not_prepared"
json.steadiness publication.steadiness
json.score_rsm publication.score_rsm
json.score_trm publication.score_trm
json.created_at publication.created_at
json.updated_at publication.updated_at
json.url publication_url(publication, format: :json)
