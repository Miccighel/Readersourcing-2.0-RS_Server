class JsonWebToken

	class << self

		def encode(payload, exp = 168.hours.from_now)
			payload[:expiration_time] = exp.to_i
			JWT.encode(payload, Rails.application.secrets.secret_key_base)
		end

		def decode(token)
			body = JWT.decode(token, Rails.application.secrets.secret_key_base)[0]
			HashWithIndifferentAccess.new body
		rescue
			nil
		end

	end

end