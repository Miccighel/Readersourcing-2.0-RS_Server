# ---------- SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------

FROM ruby:2.5.3

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update && apt-get install -y build-essential nodejs
# Install java since it is required to run rs-server
RUN apt-get install default-jre -y

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
RUN mkdir -p /rs_server
WORKDIR ./rs_server

# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. This is a separate step so the dependencies
# will be cached unless changes to one of those two files
# are made.
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install --jobs 20 --retry 5

# Configure an entry point, so we don't need to specify
# "bundle exec" for each of our commands.
ENTRYPOINT ["bundle", "exec"]

# Copy the main application.
COPY . ./

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.

# DEVELOPMENT MODE
#CMD ["bundle", "exec", "rails", "server", "-b", "-p", "3000", "-e", "development"]
# PRODUCTION MODE
CMD ["bundle", "exec", "rails", "server", "-e", "production"]

# ---------- SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------

# ---------- COMMANDS FOR A DOCKER DEPLOY ON HEROKU ----------

# heroku login
# heroku container:login
# heroku container:push web --app rs-server
# heroku container:release web --app rs-server
# heroku open --app rs-server
# heroku run rake db:create --app rs-server
# heroku run rake db:migrate --app rs-server
# heroku logs --tail --app rs-server

# ---------- END ----------