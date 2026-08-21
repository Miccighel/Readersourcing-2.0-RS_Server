class HealthController < ActionController::API

	def ready
		result = DeploymentReadiness.new.check
		if result.ready?
			render json: {status: "ready"}, status: :ok
		else
			Rails.logger.error("Deployment readiness failed: #{result.failures.join(", ")}")
			render json: {status: "not_ready"}, status: :service_unavailable
		end
	end

end
