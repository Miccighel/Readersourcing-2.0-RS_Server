class JsonWebToken

	ALGORITHM = "HS256".freeze

	class << self

		def encode(payload, exp = 168.hours.from_now)
			expiration_time = exp.to_i
			payload = payload.merge(expiration_time: expiration_time, exp: expiration_time)
			JWT.encode(payload, Rails.application.secret_key_base, ALGORITHM)
		end

		def decode(token)
			body = JWT.decode(
				token,
				Rails.application.secret_key_base,
				true,
				algorithm: ALGORITHM,
				verify_expiration: true
			)[0]
			HashWithIndifferentAccess.new body
		rescue JWT::DecodeError, ArgumentError, TypeError
			nil
		end

	end

end
