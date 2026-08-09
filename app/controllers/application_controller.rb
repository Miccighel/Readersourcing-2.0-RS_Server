class ApplicationController < ActionController::API

	include ActionController::Cookies
	include ActionController::ContentSecurityPolicy
	include ::ActionController::RequestForgeryProtection

	self.allow_forgery_protection = ActionController::Base.allow_forgery_protection
	protect_from_forgery with: :exception, unless: :api_json_request?
	before_action :discard_legacy_authentication_cookie

	attr_reader :current_user

	rate_limit(
		**RequestRateLimit::CONTACT.rails_options,
		by: -> { RequestRateLimit.for_ip(request) },
		with: -> { render_rate_limited(RequestRateLimit::CONTACT) },
		only: :message
	)

	# GET /
	def home
	end

	# GET /resources
	def resources
	end

	# GET /software
	def software
	end

	# GET /privacy
	def privacy
	end

	# GET /contact
	def contact
	end

	# POST /message.json
	def message
		if params[:bug_report]
			ApplicationMailer.report(params[:email], params[:message]).deliver_now
			render json: {message: I18n.t("confirmations.messages.bug_report_sent")}, status: :ok
		else
			ApplicationMailer.send_message(params[:email], params[:message]).deliver_now
			render json: {message: I18n.t("confirmations.messages.message_sent")}, status: :ok
		end
	end

	# GET /unauthorized
	def unauthorized
		@error_manager = ErrorManager.new
		@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
		render "shared/errors", status: 401, locals: {errors: @error_manager.get_errors}, layout: false
	end

	protected

	def render_rate_limited(policy)
		response.set_header("Retry-After", policy.period.to_i.to_s)
		errors = [I18n.t("errors.messages.too_many_requests")]
		if request.format.json? || request.post?
			render json: {errors: errors}, status: :too_many_requests
		else
			render "shared/errors", status: :too_many_requests, locals: {errors: errors}, layout: false
		end
	end

	def store_token(auth_token)
		session[:auth_token] = auth_token
	end

	def fetch_token
		session[:auth_token]
	end

	def delete_token
		AuthenticationTokenRevoker.new(fetch_token).call if fetch_token.present?
		cookies.delete :authToken
		reset_session
	end

	def browser_session_request?
		authorization_token.blank? && fetch_token.present?
	end

	private

	def authorize_server_request
		# Authorize the token stored by the server-rendered workflow.
		authorizer = Authorizer.new(fetch_token, request.remote_ip)
		@current_user = authorizer.call.result
		render "login", status: :ok, locals: {message: I18n.t("information.messages.login")} unless @current_user
	end

	def authorize_api_request
		auth_token = authorization_token || fetch_token

		# API clients supply the token explicitly. The web interface relies on the
		# same token through its encrypted server session.
		authorizer = Authorizer.new(auth_token, request.remote_ip)
		@current_user = authorizer.call.result

		@error_manager = ErrorManager.new
		@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
		render "shared/errors", status: 401, locals: {errors: @error_manager.get_errors}, layout: false unless @current_user
	end

	def authorization_token
		authorization = request.headers["Authorization"].to_s.strip
		return if authorization.blank?

		parts = authorization.split(/\s+/)
		return parts.first if parts.one?
		return parts.last if parts.length == 2 && parts.first.casecmp?("Bearer")
	end

	def api_json_request?
		return false if browser_session_request?
		return true if request.content_mime_type == Mime[:json]
		return false unless request.format.json?
		return true if request.get? || request.head?

		authorization_token.present?
	end

	def discard_legacy_authentication_cookie
		cookies.delete :authToken if cookies[:authToken].present?
	end

end
