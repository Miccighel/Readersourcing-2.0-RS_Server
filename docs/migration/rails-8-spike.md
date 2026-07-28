# Rails 8 migration spike

## Target

- Ruby 3.4.10
- Rails 8.1.3
- PostgreSQL 17 in Docker Compose
- the existing Sprockets and Turbolinks asset graph as a transitional bridge

The spike changes the framework and runtime around the application without
redesigning its Readersourcing domain model.

## Verified

- the application boots in test and production environments;
- the existing routes load;
- Zeitwerk eager loading succeeds;
- the existing JavaScript and CSS asset graph compiles;
- the root page renders successfully in the test environment;
- JWT encoding/decoding and the existing encrypted session payload round-trip;
- the RSM/TRM characterization suite passes with 67 assertions;
- the Docker image builds for Linux ARM and includes compiled production assets;
- PostgreSQL 17 becomes healthy and the production container starts without
  implicitly seeding data;
- the production home page responds with HTTP 200;
- the complete database-backed suite passes with 17 tests and 98 assertions.

## Deliberately unchanged

- `Readersourcing`, `ReadersourcingStrategy`, `RsmStrategy`, and `TrmStrategy`;
- the RSM/TRM invocation order in `Rating#compute_scores`;
- database tables and migrations;
- routes and JSON response shapes;
- the legacy frontend architecture.

See `domain-fidelity.md` for the protected behavior and known numerical
differences between Ruby runtimes.

## Docker compatibility decisions

- Linux ARM and x86-64 are explicit Bundler lockfile platforms.
- PostgreSQL is available only on the internal Compose network, avoiding a
  conflict with an existing database on host port 5432.
- The database service uses the RFC-valid hostname `database`; Ruby 3.4's URI
  parser rejects the underscore in the former `rs_server_database` hostname.
- The entrypoint uses `db:create` followed by `db:migrate`. Unlike
  `db:prepare` on a new database, this preserves the old behavior in which
  sample-data seeding is an explicit, optional action.

The stack and test suite can be reproduced with:

```sh
docker compose up --build
docker compose run --rm --no-deps \
  -e RAILS_ENV=test \
  -v "$PWD:/rs_server" \
  rs_server_webapp ./bin/rails db:create db:schema:load
docker compose run --rm --no-deps \
  -e RAILS_ENV=test \
  -v "$PWD:/rs_server" \
  rs_server_webapp ./bin/rails test
```

## Remaining integration work

The next checkpoint is an end-to-end contract test from RS_Rate to the rating
endpoint. Modernizing the frontend or changing the TRM formula must remain
separate changes so that either can be assessed independently from the
framework migration.
