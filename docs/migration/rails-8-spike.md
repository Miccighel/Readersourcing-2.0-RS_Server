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
- the Docker Compose file is syntactically valid.

## Deliberately unchanged

- `Readersourcing`, `ReadersourcingStrategy`, `RsmStrategy`, and `TrmStrategy`;
- the RSM/TRM invocation order in `Rating#compute_scores`;
- database tables and migrations;
- routes and JSON response shapes;
- the legacy frontend architecture.

See `domain-fidelity.md` for the protected behavior and known numerical
differences between Ruby runtimes.

## Remaining integration work

A PostgreSQL service was not available during this spike, and the local Docker
daemon was not running. The complete database-backed test suite and the image
build therefore still need to be exercised with:

```sh
docker compose up --build
docker compose exec rs_server_webapp bin/rails test
```

After that, the next checkpoint is an end-to-end contract test from RS_Rate to
the rating endpoint. Modernizing the frontend or changing the TRM formula must
remain separate changes so that either can be assessed independently from the
framework migration.
