source "https://rubygems.org"

ruby "3.4.10"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "pg", "~> 1.6"
gem "puma", ">= 6.0"
gem "rack", "~> 2.2", ">= 2.2.24"

# Keep the existing asset graph during the framework migration. Moving the UI
# to Propshaft/Hotwire is intentionally a separate, observable change.
gem "sprockets", "~> 3.7"
gem "sprockets-rails"
gem "turbolinks"

gem "bcrypt", "~> 3.1", ">= 3.1.22"
gem "bootsnap", require: false
gem "config"
gem "dotenv-rails"
gem "http"
gem "jbuilder"
gem "jwt", "~> 2.10", ">= 2.10.3"
gem "lograge"
gem "pdf-reader"
gem "rack-cors"
gem "sendgrid-ruby"
gem "simple_command"

gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "bundler-audit", "~> 0.9", ">= 0.9.3", require: false
end

group :development do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "letter_opener"
end

group :test do
  gem "minitest", "~> 5.27"
end

