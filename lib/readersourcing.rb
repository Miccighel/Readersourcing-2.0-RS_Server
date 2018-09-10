class Readersourcing

	@strategy = ReadersourcingStrategy.new

	def initialize(strategy)
		@strategy = strategy
	end

	def compute_scores
		@strategy.compute
	end

end