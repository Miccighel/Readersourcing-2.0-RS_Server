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
		if BCrypt::Password.new(current_user.password) == current_password
			if new_password == new_password_confirmation
				current_user.password = new_password
				if current_user.save
					PasswordMailer.update(current_user).deliver
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
				render json: {errors: @error_manager.get_errors}, status: :not_found
			end
			user = User.find_by(email: email)
			if user.present?
				delete_token
				user.generate_password_token!
				reset_url = "#{request.protocol}#{request.host_with_port}#{reset_path(email: user.email, reset_token: user.reset_password_token)}"
				PasswordMailer.forgot(user, reset_url).deliver
				render json: {message: I18n.t("confirmations.messages.reset_mail_sent")}, status: :ok
			else
				@error_manager.add_error(I18n.t("errors.messages.email_not_present"))
				render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
			end
		else
			render :forgot
		end
	end

	# GET /password/reset.json
	def reset
		email = params[:email]
		reset_token = params[:reset_token]
		# Has the user inserted an email?
		if email.blank?
			@error_manager.add_error('Email not present')
			render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}, layout: false
		else
			# Is the reset token present?
			if reset_token.blank?
				@error_manager.add_error('Reset token not present')
				render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}, layout: false
			else
				user = User.find_by(reset_password_token: reset_token)
				if user.present? && user.password_token_valid?
					new_password = SecureRandom.hex (rand(6..10))
					if user.reset_password!(new_password)
						delete_token
						PasswordMailer.reset(user, new_password).deliver
						render "shared/success", locals: {message: I18n.t("confirmations.messages.reset_mail_sent")}, status: :ok, layout: false
					else
						render "shared/errors", status: :unprocessable_entity, locals: {errors: user.errors}, layout: false
					end
				else
					@error_manager.add_error(I18n.t("errors.messages.invalid_link"))
					render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}, layout: false
				end
			end
		end
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

end
