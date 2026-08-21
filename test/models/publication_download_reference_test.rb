require "test_helper"

class PublicationDownloadReferenceTest < ActiveSupport::TestCase

	include ActiveSupport::Testing::TimeHelpers

	setup do
		@publication = publications(:one)
		@user = users(:one)
		@filename = @publication.pdf_filename(variant: "annotated")
	end

	test "resolves a valid bounded download reference" do
		reference = issue_reference

		assert_equal @user, PublicationDownloadReference.resolve(
			reference,
			publication: @publication,
			variant: "annotated",
			filename: @filename
		)
	end

	test "rejects a modified download reference" do
		reference = "#{issue_reference}modified"

		assert_nil resolve_reference(reference)
	end

	test "binds a download reference to its publication variant and filename" do
		assert_nil PublicationDownloadReference.resolve(
			issue_reference,
			publication: publications(:two),
			variant: "annotated",
			filename: @filename
		)
		assert_nil PublicationDownloadReference.resolve(
			issue_reference,
			publication: @publication,
			variant: "original",
			filename: @filename
		)
		assert_nil PublicationDownloadReference.resolve(
			issue_reference,
			publication: @publication,
			variant: "annotated",
			filename: "another-Link.pdf"
		)
	end

	test "rejects an expired download reference" do
		reference = issue_reference(expires_in: 1.second)
		travel 2.seconds

		assert_nil resolve_reference(reference)
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

	def resolve_reference(reference)
		PublicationDownloadReference.resolve(
			reference,
			publication: @publication,
			variant: "annotated",
			filename: @filename
		)
	end

end
