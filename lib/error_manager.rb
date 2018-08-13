class ErrorManager

	@errors

	def initialize
		@errors = []
	end

	def add_error(message)
		error = Hash.new
		error["message"] = message
		@errors << error
	end

	def get_errors
		@errors
	end

end