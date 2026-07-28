#!/bin/sh
set -e

if [ "$1" = "./bin/rails" ] && [ "$2" = "server" ]; then
  bundle exec rails db:prepare
fi

exec "$@"
