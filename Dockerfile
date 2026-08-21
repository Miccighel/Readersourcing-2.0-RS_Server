# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.10

FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rs_server

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y openjdk-21-jre-headless libpq5 && \
    rm -rf /var/lib/apt/lists/*

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev nodejs && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf /root/.bundle "${BUNDLE_PATH}"/ruby/*/cache

COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn
RUN node .yarn/releases/yarn-3.6.3.cjs install --immutable

COPY . .
RUN PUBLIC_BASE_URL=http://localhost:3000 SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && \
    rm -rf node_modules

FROM base

COPY --from=build /usr/local/bundle /usr/local/bundle
RUN groupadd --system --gid 1000 rails && \
    useradd --uid 1000 --gid rails --create-home --shell /bin/sh rails
COPY --from=build /rs_server /rs_server
RUN mkdir -p log tmp/pids storage/publications/user && \
    chown -R rails:rails log tmp storage

USER rails:rails

ENTRYPOINT ["./entrypoint.sh"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-e", "production"]
