require "test_helper"
require "tmpdir"

class PublicationDownloadsControllerTest < ActionDispatch::IntegrationTest

	include ActiveSupport::Testing::TimeHelpers

	setup do
		@publication = publications(:one)
		@user = users(:one)
		@storage_root = Dir.mktmpdir("rs-server-publications-")
		@previous_storage_root = ENV["RS_PDF_STORAGE_ROOT"]
		ENV["RS_PDF_STORAGE_ROOT"] = @storage_root
		@filename = @publication.pdf_filename(variant: "annotated")
		@path = @publication.pdf_file_path(@user, variant: "annotated")
		FileUtils.mkdir_p(@path.dirname)
		FileUtils.cp(file_fixture("Reader.pdf"), @path)
	end

	teardown do
		@previous_storage_root.nil? ? ENV.delete("RS_PDF_STORAGE_ROOT") : ENV["RS_PDF_STORAGE_ROOT"] = @previous_storage_root
		FileUtils.remove_entry(@storage_root) if File.exist?(@storage_root)
	end

	test "serves a private PDF through a valid short lived reference" do
		get download_path

		assert_response :success
		assert_equal "application/pdf", response.media_type
		assert_includes response.headers.fetch("Cache-Control"), "private"
		assert_includes response.headers.fetch("Cache-Control"), "no-store"
		assert_equal "no-referrer", response.headers["Referrer-Policy"]
		assert_equal "nosniff", response.headers["X-Content-Type-Options"]
		assert_includes response.headers.fetch("Content-Disposition"), "inline"
		assert_equal File.binread(file_fixture("Reader.pdf")), response.body
	end

	test "rejects a modified reference" do
		get download_path(reference: "#{issue_reference}modified")

		assert_response :not_found
	end

	test "rejects a reference used with another filename" do
		get download_path(filename: "another-Link.pdf")

		assert_response :not_found
	end

	test "rejects an expired reference" do
		reference = issue_reference(expires_in: 1.second)
		travel 2.seconds

		get download_path(reference: reference)

		assert_response :not_found
	end

	test "opening a prepared publication requires a browser session" do
		get publication_open_path(@publication), headers: {"REMOTE_ADDR" => "127.0.0.1"}

		assert_response :success
		assert_select "#login-form"
		assert_includes response.body, I18n.t("information.messages.login")
		assert_nil response.headers["Location"]
	end

	test "opening a prepared publication renews an expired download without fetching or annotating again" do
		authenticate_as(@user)
		reference = issue_reference
		before = File.binread(@path)
		travel PublicationDownloadReference.ttl + 1.second
		get download_path(reference: reference)
		assert_response :not_found

		unexpected_preparation = ->(*) { flunk "Opening a retained copy must not prepare the PDF again" }
		PdfFetcher.stub(:new, unexpected_preparation) do
			RsPdfRunner.stub(:new, unexpected_preparation) do
				get publication_open_path(@publication), headers: {"REMOTE_ADDR" => "127.0.0.1"}
			end
		end

		assert_response :redirect
		assert_includes response.headers.fetch("Cache-Control"), "no-store"
		assert_equal "no-referrer", response.headers["Referrer-Policy"]
		renewed_path = URI.parse(response.location).request_uri
		follow_redirect!
		assert_response :success
		assert_equal before, response.body
		assert_equal before, File.binread(@path)
		travel PublicationDownloadReference.ttl + 1.second
		get renewed_path
		assert_response :not_found
	end

	test "opening a publication never exposes another reader's retained copy" do
		authenticate_as(users(:two))
		get publication_open_path(@publication), params: {user_id: @user.id}, headers: {"REMOTE_ADDR" => "127.0.0.1"}

		assert_response :not_found
		assert_nil response.headers["Location"]
	end

	test "opening an unknown publication does not expose an application error" do
		authenticate_as(@user)
		get publication_open_path(Publication.maximum(:id) + 1), headers: {"REMOTE_ADDR" => "127.0.0.1"}

		assert_response :not_found
	end

	test "the publication list uses the authenticated opening path instead of caching a download reference" do
		authenticate_as(@user)
		get publications_list_path, headers: {"REMOTE_ADDR" => "127.0.0.1"}

		assert_response :success
		assert_select "a#open-list-btn[href=?]", publication_open_path(@publication), count: 1
	end

	private

	def authenticate_as(user)
		post authenticate_path(format: :json),
			params: {email: user.email, password: "password"}, headers: {"REMOTE_ADDR" => "127.0.0.1"}, as: :json
		assert_response :success
	end

	def issue_reference(expires_in: PublicationDownloadReference.ttl)
		PublicationDownloadReference.issue(
			user: @user,
			publication: @publication,
			variant: "annotated",
			filename: @filename,
			expires_in: expires_in
		)
	end

	def download_path(reference: issue_reference, filename: @filename)
		publication_download_path(
			id: @publication.id,
			variant: "annotated",
			reference: reference,
			filename: filename
		)
	end

end
