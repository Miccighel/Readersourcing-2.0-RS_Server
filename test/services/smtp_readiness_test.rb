require "test_helper"

class SmtpReadinessTest < ActiveSupport::TestCase

	test "opens an authenticated SMTP session without sending a message" do
		fake_smtp = FakeSmtpClass.new
		settings = {
			address: "smtp.example.test",
			port: 587,
			domain: "readersourcing.test",
			user_name: "reader",
			password: "secret",
			authentication: :plain,
			enable_starttls: :always,
			open_timeout: 5,
			read_timeout: 10
		}

		assert SmtpReadiness.new(settings: settings, smtp_class: fake_smtp).check!
		assert fake_smtp.instance.starttls_enabled
		assert_equal 5, fake_smtp.instance.open_timeout
		assert_equal 10, fake_smtp.instance.read_timeout
		assert_equal ["readersourcing.test", "reader", "secret", :plain], fake_smtp.instance.start_arguments
	end

	test "refuses an SMTP session without required STARTTLS" do
		settings = {
			address: "smtp.example.test",
			port: 587,
			domain: "readersourcing.test",
			user_name: "reader",
			password: "secret",
			authentication: :plain,
			enable_starttls: :auto,
			open_timeout: 5,
			read_timeout: 10
		}

		error = assert_raises(ArgumentError) do
			SmtpReadiness.new(settings: settings, smtp_class: FakeSmtpClass.new).check!
		end
		assert_equal "SMTP readiness requires STARTTLS", error.message
	end

	class FakeSmtpClass
		attr_reader :instance

		def new(address, port)
			@instance = FakeSmtp.new(address, port)
		end
	end

	class FakeSmtp
		attr_accessor :open_timeout, :read_timeout
		attr_reader :start_arguments, :starttls_enabled

		def initialize(_address, _port)
			@starttls_enabled = false
		end

		def enable_starttls
			@starttls_enabled = true
		end

		def start(*arguments)
			@start_arguments = arguments
			yield
		end
	end

end
