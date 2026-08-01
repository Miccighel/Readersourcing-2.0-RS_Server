class PasswordsController < ApplicationController

	before_action :authorize_api_request, only: [:update]
	before_action :authorize_server_request, only: [:edit]

	before_action :set_error_manager, only: [:update, :forgot, :reset]

	# GET /password/edit/
	def edit
		render :update
	end

	# POST /password/update.json
	def update
		current_password = params[:current_password]
		new_password = params[:new_password]
		new_password_confirmation = params[:new_password_confirmation]
		if current_user.authenticate(current_password)
			if new_password == new_password_confirmation
				current_user.password = new_password
				current_user.password_confirmation = new_password_confirmation
				if current_user.save
					PasswordMailer.update(current_user).deliver_now
					render json: {message: I18n.t("confirmations.messages.password_update_successful")}, status: :ok
				else
					current_user.errors.each {|error| @error_manager.add_error(error)}
					render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
				end
			else
				@error_manager.add_error(I18n.t("errors.messages.password_do_not_match"))
				render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
			end
		else
			@error_manager.add_error(I18n.t("errors.messages.current_password_does_not_match"))
			unless new_password == new_password_confirmation
				@error_manager.add_error(I18n.t("errors.messages.password_do_not_match"))
			end
			render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
		end
	end

	# POST /password/forgot.json or GET /password/forgot
	def forgot
		if params.key?(:email)
			email = params[:email]
			if email.blank?
				@error_manager.add_error(I18n.t("errors.messages.email_not_present"))
				return render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
			end
			user = User.find_by(email: email)
			if user.present?
				delete_token
				reset_token = user.generate_password_token!
				reset_url = "#{request.protocol}#{request.host_with_port}#{reset_path(email: user.email, reset_token: reset_token)}"
				PasswordMailer.forgot(user, reset_url).deliver_now
			end
			render json: {message: I18n.t("confirmations.messages.reset_mail_sent")}, status: :ok
		else
			render :forgot
		end
	end

	# GET or POST /password/reset
	def reset
		@email = params[:email]
		@reset_token = params[:reset_token]
		@user = User.find_by_password_reset_token(@reset_token)

		unless valid_password_reset_link?
			@error_manager.add_error(I18n.t("errors.messages.invalid_link"))
			return render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}, layout: false
		end

		return render :reset if request.get?

		new_password = params[:new_password]
		new_password_confirmation = params[:new_password_confirmation]
		if @user.reset_password!(@reset_token, new_password, new_password_confirmation)
			delete_token
			PasswordMailer.reset(@user).deliver_now
			render "shared/success", locals: {message: I18n.t("confirmations.messages.password_reset_successful")}, status: :ok, layout: false
		else
			@user.errors.each {|error| @error_manager.add_error(error)}
			render :reset, status: :unprocessable_entity
		end
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

	def valid_password_reset_link?
		@email.present? &&
			@user.present? &&
			@user.email.casecmp?(@email) &&
			@user.password_token_valid?
	end

end
