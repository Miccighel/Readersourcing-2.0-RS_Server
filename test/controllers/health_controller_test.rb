require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest

	test "readiness confirms the database and publication storage" do
		get deployment_readiness_path

		assert_response :success
		assert_equal({"status" => "ready"}, response.parsed_body)
	end

end
