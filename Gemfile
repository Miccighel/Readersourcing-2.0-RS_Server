source "https://rubygems.org"

ruby "3.4.10"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.6"
gem "puma", ">= 6.0"

# Keep the existing asset graph during the framework migration. Moving the UI
# to Propshaft/Hotwire is intentionally a separate, observable change.
gem "sprockets", "~> 3.7"
gem "sprockets-rails"
gem "turbolinks"

gem "bcrypt", "~> 3.1"
gem "bootsnap", require: false
gem "config"
gem "dotenv-rails"
gem "http"
gem "jbuilder"
gem "jwt"
gem "lograge"
gem "pdf-reader"
gem "rack-cors"
gem "sendgrid-ruby"
gem "simple_command"

gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end

group :development do
  gem "letter_opener"
end

