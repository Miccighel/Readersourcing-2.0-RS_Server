#!/bin/bash

# Start logrotate in the background
logrotate -f /etc/logrotate.conf


# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
bundle exec rails db:create RAILS_ENV=production
bundle exec rails db:migrate RAILS_ENV=production
bundle exec rails server -b 0.0.0.0 -p 3000 -e production