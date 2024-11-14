# ---------- SCENARIO 2: DEPLOY WITH LOCAL BUILD ----------

FROM ruby:2.6.10

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update && apt-get install -y build-essential nodejs default-jre logrotate && apt-get clean

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
RUN mkdir -p /rs_server
WORKDIR ./rs_server

# Copy your logrotate configuration file into the image
COPY logrotate.conf /etc/logrotate.conf
# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. This is a separate step so the dependencies
# will be cached unless changes to one of those two files
# are made.
COPY Gemfile Gemfile.lock ./
# Copy the main application.
COPY . ./

# Set environment variable for Yarn version
ENV YARN_VERSION=3.6.3

# Install Yarn and project dependencies
# Set the Yarn version to the latest
# Run yarn install to install project dependencies
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update -y && apt-get install -y yarn && \
    yarn set version $YARN_VERSION && yarn install

# Install Bundler and RubyGems
RUN gem update --system 3.2.3
RUN gem install bundler -v 2.4.22 && bundle install --jobs 20 --retry 5

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000

# Set the entry point script
RUN chmod +x entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]

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