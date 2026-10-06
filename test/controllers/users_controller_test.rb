require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @headers = api_headers_for(@user)
  end

  test "should get index" do
    get users_url(format: :json), headers: @headers

    assert_response :success
    assert_equal 2, response.parsed_body.length
    response.parsed_body.each do |reader|
      assert reader.key?("score")
      assert_not reader.key?("email")
      assert_not reader.key?("subscribe")
    end
  end

  test "should create user" do
    assert_emails 1 do
      assert_difference("User.count") do
        post users_url(format: :json), params: {user: registration_attributes}, as: :json
      end
    end

    assert_response :created
    assert_equal({"message" => I18n.t("confirmations.messages.please_confirm")}, response.parsed_body)
    reader = User.find_by!(email: registration_attributes.fetch(:email))
    assert_not reader.email_confirmed
    assert_predicate reader.confirm_token, :present?
  end

  test "keeps a pending account after delivery failure and recovers through login and confirmation" do
    delivery = Object.new
    delivery.define_singleton_method(:deliver_now) { raise IOError, "Private SMTP details" }

    assert_difference("User.count") do
      assert_no_difference("AuthenticationToken.count") do
        UserMailer.stub(:registration_confirmation, ->(*) { delivery }) do
          assert_no_emails do
            post users_url(format: :json), params: {user: registration_attributes}, as: :json
          end
        end
      end
    end

    assert_response :created
    assert_equal "confirmation_pending", response.parsed_body.fetch("status")
    assert_equal I18n.t("information.messages.registration_saved_without_confirmation"), response.parsed_body.fetch("message")
    refute_includes response.body, "Private SMTP details"
    refute_includes response.body, "a-secure-password"
    reader = User.find_by!(email: registration_attributes.fetch(:email))
    confirmation_token = reader.confirm_token
    assert_not reader.email_confirmed
    assert_predicate confirmation_token, :present?

    assert_no_difference("User.count") do
      assert_no_difference("AuthenticationToken.count") do
        assert_emails 1 do
          post authenticate_path, params: {email: reader.email, password: registration_attributes.fetch(:password)}, as: :json
        end
      end
    end
    assert_response :unauthorized
    assert_equal [I18n.t("errors.messages.unconfirmed_mail")], response.parsed_body.fetch("errors")
    assert_equal confirmation_token, reader.reload.confirm_token
    assert_not reader.email_confirmed

    get confirm_path(reader.id, confirmation_token)
    assert_response :created
    assert reader.reload.email_confirmed
    assert_nil reader.confirm_token

    assert_difference("AuthenticationToken.count") do
      post authenticate_path, params: {email: reader.email, password: registration_attributes.fetch(:password)}, as: :json
    end
    assert_response :success
    assert response.parsed_body.fetch("auth_token").present?
  end

  test "does not replace a pending account when registration is submitted again" do
    reader = User.create!(registration_attributes)
    reader.generate_confirm_token
    reader.save!
    original_attributes = reader.attributes

    assert_no_difference("User.count") do
      assert_no_emails do
        post users_url(format: :json), params: {user: registration_attributes.merge(first_name: "Changed", password: "another-password", password_confirmation: "another-password")}, as: :json
      end
    end

    assert_response :unprocessable_entity
    assert_equal original_attributes, reader.reload.attributes
  end

  test "rejects invalid registration without creating an account or sending mail" do
    assert_no_difference("User.count") do
      assert_no_emails do
        post users_url(format: :json), params: {user: registration_attributes.merge(password_confirmation: "mismatch")}, as: :json
      end
    end

    assert_response :unprocessable_entity
    assert response.parsed_body.key?("password_confirmation")
  end

  test "confirmation links use the configured public origin rather than the request host" do
    previous_origin = ENV["PUBLIC_BASE_URL"]
    ENV["PUBLIC_BASE_URL"] = "https://readersourcing.example"
    host! "untrusted.example"

    assert_emails 1 do
      post users_url(format: :json), params: {user: registration_attributes}, as: :json
    end
    assert_response :created
    reader = User.find_by!(email: registration_attributes.fetch(:email))
    link = "https://readersourcing.example#{confirm_path(reader.id, reader.confirm_token)}"
    assert_includes ActionMailer::Base.deliveries.last.body.decoded, link
    refute_includes ActionMailer::Base.deliveries.last.body.decoded, "untrusted.example"

    assert_emails 1 do
      post authenticate_path, params: {email: reader.email, password: registration_attributes.fetch(:password)}, as: :json
    end
    assert_response :unauthorized
    assert_includes ActionMailer::Base.deliveries.last.body.decoded, link
    refute_includes ActionMailer::Base.deliveries.last.body.decoded, "untrusted.example"
  ensure
    previous_origin.nil? ? ENV.delete("PUBLIC_BASE_URL") : ENV["PUBLIC_BASE_URL"] = previous_origin
  end

  test "reports pending registration and delivery failures in the selected language" do
    delivery = Object.new
    delivery.define_singleton_method(:deliver_now) { raise IOError, "Private SMTP details" }

    I18n.with_locale(:it) do
      UserMailer.stub(:registration_confirmation, ->(*) { delivery }) do
        post users_url(format: :json), params: {user: registration_attributes}, as: :json
        assert_response :created
        assert_equal I18n.t("information.messages.registration_saved_without_confirmation"), response.parsed_body.fetch("message")
        refute_includes response.body, "translation missing"

        post authenticate_path,
          params: {email: registration_attributes.fetch(:email), password: registration_attributes.fetch(:password)},
          as: :json
        assert_response :service_unavailable
        assert_equal [I18n.t("errors.messages.confirmation_delivery_unavailable")], response.parsed_body.fetch("errors")
        refute_includes response.body, "translation missing"
      end
    end
  end

  test "registration does not accept activation or score attributes" do
    post users_url(format: :json),
      params: {user: registration_attributes.merge(email_confirmed: true, confirm_token: "supplied-token", score: 99)},
      as: :json

    assert_response :created
    reader = User.find_by!(email: registration_attributes.fetch(:email))
    assert_not reader.email_confirmed
    assert_not_equal "supplied-token", reader.confirm_token
    assert_equal User.column_defaults.fetch("score").to_d, reader.score
  end

  test "should show user" do
    get user_url(@user, format: :json), headers: @headers

    assert_response :success
    assert_equal @user.first_name, response.parsed_body.fetch("first_name")
    assert_not response.parsed_body.key?("email")
    assert_not response.parsed_body.key?("subscribe")
  end

  test "info should expose only the current user's private profile" do
    post info_users_url(format: :json), headers: @headers

    assert_response :success
    assert_equal @user.id, response.parsed_body.fetch("id")
    assert_equal @user.email, response.parsed_body.fetch("email")
    assert_equal @user.subscribe, response.parsed_body.fetch("subscribe")
    assert_not response.parsed_body.key?("password_digest")
    assert_not response.parsed_body.key?("confirm_token")
    assert_not response.parsed_body.key?("reset_password_token")
  end

  test "the server session authorizes requests from the web interface" do
    authenticate

    post info_users_url(format: :json), as: :json

    assert_response :success
    assert_equal @user.id, response.parsed_body.fetch("id")
  end

  test "should update user" do
    patch user_url(@user, format: :json),
      params: { user: { last_name: "Byron" } },
      headers: @headers,
      as: :json

    assert_response :ok
    assert_equal "Byron", @user.reload.last_name
  end

  test "web profile update ends and revokes the browser session" do
    authenticate
    auth_token = session[:auth_token]
    jti = JsonWebToken.decode(auth_token)[:jti]

    patch user_url(@user, format: :json),
      params: { user: { last_name: "Byron" } },
      as: :json

    assert_response :ok
    assert_nil session[:auth_token]
    assert_not AuthenticationToken.exists?(jti: jti)
    assert_nil Authorizer.new(auth_token, "127.0.0.1").call.result
  end

  test "should not update another user" do
    other_user = users(:two)

    patch user_url(other_user, format: :json),
      params: { user: { last_name: "Byron" } },
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_equal "Turing", other_user.reload.last_name
  end

  test "profile update should not accept credentials" do
    original_email = @user.email
    original_password_digest = @user.password_digest

    patch user_url(@user, format: :json),
      params: {
        user: {
          email: "changed@example.test",
          password: "changed-password",
          password_confirmation: "changed-password"
        }
      },
      headers: @headers,
      as: :json

    assert_response :ok
    assert_equal original_email, @user.reload.email
    assert_equal original_password_digest, @user.password_digest
  end

  test "unsubscribe link asks for confirmation without changing the profile" do
    authenticate

    get unsubscribe_url(@user)

    assert_response :success
    assert_select "form#unsubscribe-form[action='#{unsubscribe_path(@user)}'][method='post']"
    assert @user.reload.subscribe
  end

  test "unsubscribe submission changes the current reader profile" do
    post unsubscribe_url(@user, format: :json), headers: @headers, as: :json

    assert_response :success
    assert_equal I18n.t("mails.user.unsubscribe_successful"), response.parsed_body.fetch("message")
    assert_not @user.reload.subscribe
  end

  test "should destroy user" do
    user_storage = Publication.storage_root.join("user", @user.id.to_s)
    FileUtils.mkdir_p(user_storage)
    user_storage.join("prepared.pdf").write("prepared publication")

    assert_difference("User.count", -1) do
      assert_difference("AuthenticationToken.count", -1) do
        delete user_url(@user, format: :json), headers: @headers
      end
    end

    assert_response :no_content
    assert_not user_storage.exist?
  end

  test "should not destroy another user" do
    other_user = users(:two)

    assert_no_difference("User.count") do
      delete user_url(other_user, format: :json), headers: @headers
    end

    assert_response :not_found
    assert User.exists?(other_user.id)
  end

  private

  def registration_attributes
    {
      email: "grace@example.test",
      first_name: "Grace",
      last_name: "Hopper",
      password: "a-secure-password",
      password_confirmation: "a-secure-password"
    }
  end

  def authenticate
    post authenticate_path, params: {
      email: @user.email,
      password: "password"
    }, headers: {"REMOTE_ADDR" => "127.0.0.1"}, as: :json
    assert_response :success
  end
end
