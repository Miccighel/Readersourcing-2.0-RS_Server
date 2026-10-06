require "test_helper"
require "stringio"

class RegistrationConfirmationTest < ActiveSupport::TestCase

	include ActionMailer::TestHelper

	test "sends the supplied confirmation without changing the account" do
		reader = users(:one)
		original_attributes = reader.attributes
		link = "https://readersourcing.test/confirm/#{reader.id}/confirmation-reference"
		confirmation = RegistrationConfirmation.new(reader, link: link)

		assert_emails 1 do
			assert confirmation.call
		end
		assert_equal original_attributes, reader.reload.attributes
	end

	test "reports a transport failure without logging mail content or changing the account" do
		reader = users(:one)
		original_attributes = reader.attributes
		output = StringIO.new
		logger = ActiveSupport::Logger.new(output)
		delivery = Object.new
		delivery.define_singleton_method(:deliver_now) { raise IOError, "Private SMTP credentials and reference" }

		Rails.stub(:logger, logger) do
			UserMailer.stub(:registration_confirmation, ->(*) { delivery }) do
				assert_not RegistrationConfirmation.new(reader, link: "private-confirmation-reference").call
			end
		end

		assert_includes output.string, "reader #{reader.id}"
		assert_includes output.string, "IOError"
		refute_includes output.string, "Private SMTP"
		refute_includes output.string, "private-confirmation-reference"
		refute_includes output.string, reader.email
		assert_equal original_attributes, reader.reload.attributes
	end

end
