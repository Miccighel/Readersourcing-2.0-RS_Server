class ErrorManager

	@errors

	def initialize
		@errors = []
	end

	def add_error(message)
		@errors << message
	end

	def get_errors
		@errors
	end

end