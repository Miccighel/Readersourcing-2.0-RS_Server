class PublicationDownloadsController < ApplicationController

	before_action :authorize_server_request, only: :open

	def open
		publication = Publication.find(params[:id])
		download_url = publication.pdf_download_url_link(PublicBaseUrl.for(request), current_user)
		return head :not_found unless download_url

		response.set_header("Cache-Control", "private, no-store")
		response.set_header("Referrer-Policy", "no-referrer")
		redirect_to URI.parse(download_url).request_uri
	rescue ActiveRecord::RecordNotFound, ArgumentError
		head :not_found
	end

	def show
		publication = Publication.find(params[:id])
		filename = params[:filename].to_s
		copy = PublicationDownloadReference.resolve_copy(
			params[:reference],
			publication: publication,
			variant: params[:variant],
			filename: filename
		)
		return head :not_found unless copy

		path = copy.path(params[:variant])
		return head :not_found unless File.file?(path)

		response.set_header("Cache-Control", "private, no-store")
		response.set_header("Referrer-Policy", "no-referrer")
		response.set_header("X-Content-Type-Options", "nosniff")
		send_file path, filename: filename, type: "application/pdf", disposition: "inline"
	rescue ActiveRecord::RecordNotFound, ArgumentError
		head :not_found
	end

end
