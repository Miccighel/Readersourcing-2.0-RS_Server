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

	private

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
