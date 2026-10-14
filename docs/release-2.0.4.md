# RS_Server 2.0.4 candidate

Version 2.0.4 prepares the interface corrections found during the private trial. It is not yet a published
container release. Docker Hub, the normal Compose configuration, and `bin/private_trial` still select version 2.0.3.
The existing trial must not be replaced before the candidate image has been verified and its data backed up.

## Scope

The candidate contains three corrections:

- PDF title metadata encoded with PDFDocEncoding is converted to UTF-8 when imported into the publication record.
  The inspected metadata and original PDF bytes remain unchanged.
- The publication list opens an existing reader copy through an authenticated route that issues a fresh signed
  download URL. The source is not retrieved or annotated again. API download URLs retain their existing lifetime.
- The rating confirmation notice mentions email only when the reader is subscribed.

The source corrections are retained in commit `2b851e3b591d139cf198087e85ccbe6e504f1c40`. They do not change the
domain models, scoring formulas, database schema, declared dependencies, lockfiles, or bundled RS_PDF JAR.
The existing regression tests cover the metadata conversion, ownership and authentication of copy opening,
expired and renewed download links, and subscribed and unsubscribed rating notices.

## Image preparation

Use a dedicated checkout or a clean source snapshot from `codex/development`, with no private configuration,
reader files, or credentials. On a Linux amd64 host, build a new local tag from the existing Dockerfile:

```console
sudo docker buildx build --pull --no-cache-filter base --platform linux/amd64 --load --tag rs-server-candidate:v2.0.4-amd64 .
```

This builds an image only. It does not start or replace any service and does not push to Docker Hub. The base stage
refreshes official packages; its resulting package versions and scanner findings require a new assessment rather
than inheriting the counts recorded for version 2.0.3. Do not retag or overwrite the retained release images.

## Verification and private trial

Before a trial update:

1. record the source commit, image ID, platform, lockfile hashes, and RS_PDF hash;
2. check the locked JSON and resolver libraries both inside and outside Bundler, PDF title decoding in the built image,
   and the absence of private configuration or development files;
3. complete the Rails and browser regression tests and the image security assessment;
4. back up the existing private trial before any image or service change;
5. verify title display, opening a prepared copy after URL expiry, and the notice for an unsubscribed reader on the
   Docker host, while preserving existing rating references and original and annotated PDF copies.

Preparation does not validate public DNS, HTTPS, external SMTP, host maintenance, or production exposure.
No image identity or completed container check is recorded here until that exact candidate has been built and tested.
