# Rails 8 verification

## Target

- Ruby 3.4.10
- Rails 8.1.3.1
- PostgreSQL 17 in Docker Compose
- the Sprockets and Turbolinks asset graph used by the application

These runtime choices support the application without redesigning its
Readersourcing domain model.

## Verified

- the application boots in test and production environments;
- the existing routes load;
- Zeitwerk eager loading succeeds;
- the existing JavaScript and CSS asset graph compiles;
- the root page renders successfully in the test environment;
- HS256 JWTs and encrypted session payloads can be encoded and decoded correctly;
- password recovery uses a digested token that can be used once and a trusted public origin;
- the RSM/TRM characterization suite passes;
- the Docker image builds for Linux ARM and includes compiled production assets;
- PostgreSQL 17 becomes healthy and the production container starts without
  implicitly seeding data;
- the production home page responds with HTTP 200;
- the complete suite passes against PostgreSQL.

## Domain invariants

- `Readersourcing`, `ReadersourcingStrategy`, `RsmStrategy`, and `TrmStrategy`;
- the RSM/TRM invocation order in `Rating#compute_scores`;
- database tables and migrations;
- routes and JSON response shapes;
- the frontend interaction architecture.

See `domain-fidelity.md` for the protected behavior and numerical tolerances.

## Docker compatibility decisions

- Linux ARM and x86-64 are explicit Bundler lockfile platforms.
- PostgreSQL is available only on the internal Compose network, avoiding a
  conflict with an existing database on host port 5432.
- The database service uses the hostname `database`, which conforms to the relevant RFC requirements.
- PostgreSQL creates the configured application database and the dedicated
  setup service runs `db:migrate`; the application entrypoint does not alter
  the database and sample data seeding remains an explicit, optional action.

The stack and test suite can be reproduced with:

```sh
docker compose up --build --wait
curl --fail http://localhost:3000/up
docker compose down
docker compose up -d database
docker compose run --rm --no-deps \
  -e RAILS_ENV=test \
  -v "$PWD/test:/rs_server/test:ro" \
  rs_server_webapp ./bin/rails db:create db:schema:load test
docker compose down --volumes
```

## Integration contract

RS_Rate retains the route, JSON, authentication header, and publication
extraction contracts exercised by the client tests. Changes to the frontend
interaction model or to the TRM formula remain separate domain decisions.
