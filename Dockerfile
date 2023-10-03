# ---------- SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------

FROM ruby:2.7.8

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

# Copy the main application.
COPY . ./

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update -y && apt-get install -y yarn
# Set the Yarn version to the latest
RUN yarn set version 3.6.3
# Run yarn install to install project dependencies
# You should uncomment and modify this line if you have a specific project to install
RUN yarn install

# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. This is a separate step so the dependencies
# will be cached unless changes to one of those two files
# are made.
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install --jobs 20 --retry 5

# Configure an entry point, so we don't need to specify
# "bundle exec" for each of our commands.
# ENTRYPOINT ["bundle", "exec"]

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.

# To run in development environment (default)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000", "-e", "development"]
# To run in production enviroment (default)
#CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000", "-e", "production"]

# ---------- SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------

# ---------- COMMANDS FOR A DOCKER DEPLOY ON HEROKU ----------

# heroku login
# heroku container:login
# heroku container:push web --app rs-server
# heroku container:release web --app rs-server
# heroku open --app rs-server
# heroku run rake db:create RAILS_ENV=production --app rs-server
# heroku run rake db:migrate RAILS_ENV=production --app rs-server
# heroku run rake db:seed RAILS_ENV=production --app rs-server
# heroku logs --tail --app rs-server

# ---------- END ----------