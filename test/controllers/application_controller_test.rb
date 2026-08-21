require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest

	test "privacy policy describes the current service and links to the contact form" do
		get privacy_path

		assert_response :success
		assert_select "a[href='#{contact_path}']", text: "contact form"
		assert_select "time[datetime='2026-08-21']"
		assert_includes response.body, "does not send marketing newsletters"
		assert_includes response.body, "does not install analytics"
		refute_includes response.body, "http://readersourcing.org"
		refute_includes response.body, "Preference Cookies"
	end

end
