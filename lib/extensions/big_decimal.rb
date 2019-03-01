module Extensions::BigDecimal

	def prettify
		to_i == self ? to_i : self
	end

end