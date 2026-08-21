# Production deployment

This document complements the deployment instructions in the main README. It describes the checks that must be completed before an RS_Server instance is exposed to the Internet.

## Configuration

Copy `.env.example` to `.env` and replace every example value. Generate `SECRET_PROD_KEY` with `bin/rails secret` and keep the value stable while issued references must remain valid. The production process refuses to start when a required secret, database, SMTP, privacy, or public origin setting is absent or still contains an example value.

For a public instance:

1. set `PUBLIC_BASE_URL` to its final HTTPS origin;
2. set `FORCE_SSL=true`;
3. set `ASSUME_SSL=true` only when every request reaches Rails through a proxy that terminates HTTPS;
4. list only trusted browser origins in `CORS_ALLOWED_ORIGINS`;
5. identify the data controller and service providers through the `PRIVACY_` variables;
6. configure the log and backup systems to respect the declared retention periods.

The privacy variables are public information. Secrets and database or SMTP credentials should be supplied by the secret manager of the selected hosting service when one is available. They must not be stored in the repository or included in an image.

## HTTPS proxy

The Compose service listens on `127.0.0.1` by default. A proxy on the same host can publish the service after obtaining a valid certificate. The following NGINX fragment shows the application requirements; certificate paths and TLS policy remain specific to the selected host.

```nginx
location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Request-Id $request_id;

    client_max_body_size 55m;
    proxy_connect_timeout 10s;
    proxy_send_timeout 75s;
    proxy_read_timeout 75s;
}
```

`client_max_body_size` must remain slightly larger than `RS_PDF_MAX_DOWNLOAD_BYTES` so multipart form data can be received, while the application still applies its exact PDF limit. Proxy timeouts must remain longer than `RS_PDF_PROCESS_TIMEOUT`. If these application values change, update the proxy values in the same release.

## Starting the service

The normal Compose sequence is:

```console
docker compose pull
docker compose up -d
docker compose exec rs_server_webapp bin/rails deployment:check
```

The setup service waits for PostgreSQL and applies pending migrations before the web process starts. `deployment:check` then verifies the production configuration, migration state, database connection, publication storage, and an authenticated SMTP connection. It opens an SMTP session but sends no email.

`GET /up` is the liveness endpoint. It confirms that Rails completed its boot sequence. `GET /ready` is the readiness endpoint. It confirms that PostgreSQL responds and that the private publication volume accepts a temporary file. The Compose health check uses `/ready`; a process monitor may use `/up` separately.

After every deployment, exercise the following paths with a dedicated test reader:

1. registration and email confirmation;
2. authentication and logout;
3. password recovery;
4. remote PDF inspection and preparation;
5. PDF upload as the browser assisted alternative;
6. annotated PDF download and QR Code rating;
7. account deletion and removal of the reader's private PDF directory.

## Capacity and process model

The Compose file supplies initial CPU, memory, process, temporary file, and log limits. They are conservative starting values rather than capacity guarantees. Observe Java and Rails memory while preparing PDFs near the configured size limit, then adjust the `RS_SERVER_` limits if the chosen host requires it.

The supplied Puma configuration uses one process. Request counters consequently remain consistent in the in memory Rails cache. Before adding Puma workers or application replicas, configure a shared Active Support cache and validate that every instance uses it.

Run `bin/rails security:prune_expired_authentication_tokens` on a regular maintenance schedule. Token expiry is enforced when a token is used; this task removes expired database records that are no longer needed.

## Data recovery and security review

Create and verify a backup before migrations or image changes. The complete procedure is in [backups.md](backups.md). Review the current container assessment in [security.md](security.md) before promoting an image. A successful application dependency audit does not replace a scan of the operating system packages contained in the image.
