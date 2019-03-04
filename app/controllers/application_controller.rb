class ApplicationController < ActionController::API

	include ::ActionController::RequestForgeryProtection
	include ::ActionView::Layouts

	layout "application", only: [:home]

	before_action :authorize_api_request, except: [
		:home,
		:resources,
		:bug,
		:report,
		:request_authorization,
		:unauthorized
	]
	attr_reader :current_user

	# GET /
	def home
	end

	# GET /resources
	def resources
	end

	# GET /bug
	def bug
	end

	# POST /report.json
	def report
		ApplicationMailer.report(params[:email], params[:message]).deliver_now
		render json: {message: I18n.t("confirmations.messages.bug_report_sent")}, status: :ok
	end

	# POST /request_authorization.json
	def request_authorization
		request.headers['Authorization'] = unescape_jwt(request.headers['Authorization'])
		@current_user = AuthorizeApiRequest.call(request.headers, request.remote_ip).result
		if @current_user
			render json: {message: I18n.t("confirmations.messages.authorization_completed")}, status: :ok
		else
			@error_manager = ErrorManager.new
			@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
			render json: {errors: @error_manager.get_errors}, status: 401
		end
	end

	# GET /unauthorized
	def unauthorized
		@error_manager = ErrorManager.new
		@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
		render "shared/errors", status: 401, locals: {errors: @error_manager.get_errors}, layout: false
	end

	protected

	def escape_jwt(unescaped_auth_token)
		CGI.escape(unescaped_auth_token.to_s.gsub!(/\./,"/"))
	end

	def unescape_jwt(escape_auth_token)
		CGI.unescape(escape_auth_token).gsub!(/\//,".")
	end

	private

	def authorize_api_request
		request.headers['Authorization'] = unescape_jwt(request.headers['Authorization'])
		@current_user = AuthorizeApiRequest.call(request.headers, request.remote_ip).result
		@error_manager = ErrorManager.new
		@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
		render "shared/errors", status: 401, locals: {errors: @error_manager.get_errors}, layout: false unless @current_user
	end

end
