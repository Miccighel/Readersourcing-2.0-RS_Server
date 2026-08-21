class PublicationDownloadsController < ApplicationController

	def show
		publication = Publication.find(params[:id])
		filename = params[:filename].to_s
		user = PublicationDownloadReference.resolve(
			params[:reference],
			publication: publication,
			variant: params[:variant],
			filename: filename
		)
		return head :not_found unless user

		path = publication.pdf_file_path(user, variant: params[:variant])
		return head :not_found unless File.file?(path)

		response.set_header("Cache-Control", "private, no-store")
		response.set_header("Referrer-Policy", "no-referrer")
		response.set_header("X-Content-Type-Options", "nosniff")
		send_file path, filename: filename, type: "application/pdf", disposition: "inline"
	rescue ActiveRecord::RecordNotFound, ArgumentError
		head :not_found
	end

end
