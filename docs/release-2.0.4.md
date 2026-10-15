# RS_Server 2.0.4 candidate

Version 2.0.4 prepares the interface corrections found during the private trial. It is not yet a published
container release. Docker Hub, the normal Compose configuration, and `bin/private_trial` still select version 2.0.3.
The dedicated private trial runs the verified 2.0.4 candidate with the PDF navigation correction. Its activation
preserved the existing data and configuration. The three initial functional regression cases passed; subsequent
navigation checks passed in the integrated browser and were confirmed manually in Firefox as described below.

## Scope

The candidate contains three corrections:

- PDF title metadata encoded with PDFDocEncoding is converted to UTF-8 when imported into the publication record.
  The inspected metadata and original PDF bytes remain unchanged.
- The publication list opens an existing reader copy through an authenticated route that issues a fresh signed
  download URL. Its PDF links use a full browser navigation without Turbolinks. The source is not retrieved or
  annotated again. API download URLs retain their existing lifetime.
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

Reference archives must retain the file bytes stored in Git. Use `git -c core.autocrlf=false archive` when a local Git
configuration would otherwise convert line endings. The recorded lockfile hashes identify the committed bytes,
not a platform's working copy.

## Runtime verification of October 14, 2026

The native Linux amd64 candidate built from commit `3c26746ca0828693aca16de62b8017e5d589bba2` passed the isolated
runtime checks. Its [candidate record](container-candidate-2.0.4.json) retains the exact image ID and input hashes.
All 181 compared source files matched the commit. JSON 2.21.2 and resolv 0.7.2 passed the checks in separate
processes with and without Bundler; the application selected timeout 0.6.1 through its existing lockfile.

The PDF fixture title decoded to “Readersourcing—a manifesto” without altering its metadata or file bytes.
The compiled asset manifest and Java 21 runtime were checked, and the selected private and development paths were
absent. These containers used an unprivileged user, no network, and a read only image root. They did not start Rails
or connect to a database.

The source CI run passed 301 Rails tests and 2,374 assertions, together with its image build check. These source
checks are distinct from the security assessment and functional browser checks recorded for the image on the Docker host.

## Verification and private trial

The [security assessment of October 14](security-report-2026-10-14.json) covers this exact native Linux amd64 image.
Trivy identified no critical advisories, eight high operating system advisories, and no advisories in the application
libraries it detected. The remaining findings have no corrected Trixie version listed in the report; the Debian
tracker entries for the high advisories were checked separately. All findings remain open without exclusions.
This assessment does not approve public exposure or replace the private trial checks.

The operator completed the protected local backup on October 14. It includes the PostgreSQL dump, publication files,
and private trial configuration. Archive checks passed and the same 2.0.3 containers returned to healthy status.
No backup content is attached to this record. This original 2.0.3 backup has no recorded independent host copy or
restore rehearsal; the updated 2.0.4 backup is covered in the recovery section below.

For the trial update:

1. record the source commit, image ID, platform, lockfile hashes, and RS_PDF hash;
2. check the locked JSON and resolver libraries both inside and outside Bundler, PDF title decoding in the built image,
   and the absence of private configuration or development files;
3. complete the Rails and browser regression tests and the image security assessment;
4. back up the existing private trial before any image or service change;
5. verify title display, opening a prepared copy after URL expiry, and the notice for an unsubscribed reader on the
   Docker host, while preserving existing rating references and original and annotated PDF copies.

The original generated configuration remains subject to `PrivateTrial.validate!`. A separate candidate configuration
comparison permits only the two application image identities to change. It rejects changes to the signing key,
public origin, volumes, networks, mail service, ports, or runtime restrictions. This comparison is a preparation check,
not evidence that the candidate has been installed or that its database and browser checks have passed.

The preflight completed on October 14. It repeated the backup integrity checks, matched the backed up configuration
record to the current trial, and verified the two image overrides against the resolved Compose configuration.
No service was interrupted or candidate installed during that preflight.

The prepared activation procedure recreates only the web application, without running the setup service or migrations.
It pauses access while comparing all public table rows and sequence states, together with publication file contents,
ownership, permissions, and directory entries. Database statistics and file timestamps are not compared. Fingerprints
remain on the host, and the public report contains only aggregate hashes and counts. A failed activation attempts to
return to the retained image only when the data and original configuration still match. A mismatch leaves access
stopped for inspection; it never triggers an automatic backup restore.

The activation completed on October 14 after these checks passed. Only the web application container was recreated;
PostgreSQL, Mailpit, and the setup service were retained. The comparison matched all six public tables, four sequences,
and twelve publication files in fifteen directories. The deployment check passed for production settings, migrations,
publication storage, database access, and authenticated SMTP. No migrations or backup restore were run. The
[candidate record](container-candidate-2.0.4.json) retains the aggregate fingerprints and the activation timestamp.
The three functional browser cases passed on the running image with a newly registered synthetic reader. The imported
fixture title appeared as “Readersourcing—a manifesto”. A publication list left open beyond the original download
reference's expiry issued a new reference for the same copy generation; the expired reference returned 404. A separate
HTTP check returned the same prepared copy as a valid PDF with status 200 and content type `application/pdf`.
The rating reference was extracted from a downloaded prepared PDF and used to submit the paper form. Its confirmation
stated that the rating was saved and email notifications were disabled, without promising a confirmation email.

These checks added a synthetic reader, two publications, and their ratings after the activation data comparison.
They did not reset earlier readers or rewrite the titles of existing publication records.

## Startup preparation of October 15, 2026

The development branch adds a separate manual procedure for resuming all four existing trial services after Docker
becomes available. It records a protected container inventory while the trial is healthy, retains the exact activated
image and completed setup container, and checks configuration before reopening access. Its optional rehearsal compares
logical database and publication fingerprints while the application is stopped. It does not enable automatic startup
or recurring backups. The [private trial procedure](private_trial.md#complete-candidate-startup) documents its scope.

The combined startup, inventory, restart and configuration tests passed locally: 26 tests and 233 assertions.
The wider standalone deployment suite also passed, with 63 tests and 536 assertions; the Rails dependent recovery
probe was not rerun as part of that standalone suite.
These synthetic safety tests are separate from the live rehearsal and are not proof of a real host reboot. The verified
helpers were installed separately on Homer and the operator completed `prepare`: configuration and inventory checks
passed for the exact activated image without creating containers or running migrations. No host packages were changed
and no host reboot was performed.
The first rehearsal stopped before maintenance because Docker returned identical mount entries in a different order
for the setup and application containers. The operator's read only diagnostic confirmed that configuration matched,
no container had an unstable state, and only mount ordering differed. The inventory comparison now orders complete
mount entries by destination on both sides without rewriting the retained inventory. Seven inventory tests passed
with 29 assertions, including rejection of changed sources, permissions, volume names, and missing or duplicate mounts.
The standalone deployment suite then passed with 66 tests and 549 assertions.

The operator then completed the live rehearsal with the corrected helpers from commit `25f637d`. The four trial
services stopped and started using the existing containers and exact activated image. Configuration and inventory
checks passed, and logical database and publication fingerprints matched across the stop and start. No migrations
ran and no containers were created. The application readiness and deployment checks passed before access reopened.
Independent HTTP requests on Homer subsequently returned 200 for the login page and 401 for unauthenticated Mailpit
access. The helper manifest was checked again; private diagnostics and inventory contents were not read or downloaded.
This verifies the trial service startup, not a reboot of Homer, a new browser regression, or public deployment approval.
Automatic startup and recurring backups remain unconfigured.

The [stable private operations procedure](stable_private_operations.md) prepares a protected installation outside the
temporary operations directories, with verified configuration and backup copies. Existing bind mount paths are
retained and receive narrowly scoped age based cleanup exclusions. Installation does not restart the host or trial
services. Installation completed on Homer without host maintenance or a reboot.
The standalone deployment suite passed with 72 tests and 625 assertions, including six installation tests with
76 assertions for verified copies, source preservation, wrapper generation, cleanup scope, and refusal of unsafe inputs.

The operator's first installation reached the final stable command check and stopped there without starting or
stopping trial services. The cleanup rule was subsequently checked independently and the login page still returned
200. The installer permission policy has been corrected so public helper code remains readable by the existing
unprivileged container users, while its host directories and private configuration stay protected. A separate guarded
completion confirmed that permission failure and changed only public helper permissions, wrapper context and its
checksum manifest. The retained configuration copies were verified against their recorded inventories and original
sources before and after completion, without being recopied. The original installer must not be rerun over the
existing destination.
The corrected standalone deployment suite passed with 75 tests and 649 assertions, including nine installation tests
with 100 assertions. These cover explicit helper permissions under a restrictive process umask and verification of
retained snapshots without changing their sources.

The operator's aggregate completion report confirmed that the stable startup and restart checks passed with the same
trial containers, images and lifecycle state as before installation. Configuration paths and private permissions were
unchanged. Independent HTTP checks returned 200 for login and 401 for unauthenticated Mailpit access. The protected
installation parent, narrow cleanup rule and public completion package checksums were also checked independently.
The [installation record](stable-installation-2026-10-15.json) distinguishes those checks from the operator's protected
snapshot comparisons. No host package changes, reboot, automatic startup or recurring backups were performed.
Isolated recovery has not been repeated from the stable path; the earlier successful recovery rehearsal remains
separate evidence. Active bind mount paths remain in place with cleanup exclusions, rather than being relocated.
The [maintenance procedure](host-maintenance.md) requires a coordinated interruption on the shared server.
The [October 15 assessment](security-followup-2026-10-15.json) includes a new scan with an updated vulnerability
database. Its verified complete report retains the same detected package inventory and advisory occurrences as the
October 14 replacement scan. All eight previously recorded high image advisories remain open.

## PDF navigation

The publication list's Open link was also checked in an isolated Firefox profile. The click displayed the PDF bytes
as HTML, as it had in the integrated browser. Reloading the same signed URL opened Firefox's PDF viewer correctly.
The server returned a valid PDF with content type `application/pdf`; Turbolinks intercepted the extensionless opening
route and treated the redirected response as page content.

The source now marks this link with `data-turbolinks="false"`, so the browser performs a complete navigation to the
PDF. Other application links continue to use Turbolinks. The preparation controls already use `window.open` and
require no change. Authentication, reference expiry, copy ownership, and PDF generation remain unchanged.
This correction and its regression test are retained in commit `d3f37eabfd0ddcb55ccd049af55be80eda8c5a8b` on
`codex/development`.

The list regression test failed before the attribute was added and passed afterwards. The local suite passed
311 tests and 2,406 assertions using Ruby 3.4.10 and a dedicated PostgreSQL 11.22 test database. This local check
does not replace CI's PostgreSQL 17 coverage. In a separate local Rails test instance with repository fixtures,
clicking Open produced an `application/pdf` document rather than inserting PDF bytes into the HTML page.
The [source CI](https://github.com/Miccighel/Readersourcing-2.0-RS_Server/actions/runs/38587593435) passed
301 tests and 2,375 assertions on PostgreSQL 17, together with the image build and private trial jobs.
The corrected source was built on Homer as `rs-server-candidate:v2.0.4-pdf-d3f37ea-amd64`. The replacement image,
`sha256:e52ed41e7a62a5447923ec02f0bef0b61f285232afb58c7bdfc80020381b5ad5`, passed the isolated runtime checks on
October 14 at 15:20:55 UTC. All 181 compared source files matched commit `d3f37ea`, including the PDF opening link.
The lockfiles, bundled RS_PDF JAR, and PDF fixture retained their expected hashes. JSON and resolver checks passed
both inside and outside Bundler. No Rails process or database was started for those checks.

Its separate security scan completed at 15:25:56 UTC on October 14.
The full report checksum was verified, and the detected package inventory and all 198 advisory occurrences match
the earlier candidate's report. The same eight high operating system advisories remain open. The scanner reused
its vulnerability database cache, not its findings, and retained a separate report for the replacement image.
The operator completed an updated backup of the running candidate. It includes the database, publication files,
and effective image configuration, with checksums and database and publication fingerprints recorded while the
application was stopped. The same application and access containers returned to healthy status. The earlier
2.0.3 backup is retained separately; it predates the browser test records. The updated backup's recovery rehearsal
is recorded below. Its encrypted NAS copy is recorded separately from the earlier 2.0.3 backup.

The prepared replacement procedure repeats configuration and backup checks, requires the current data to match
the updated backup, and recreates only the web application. It compares logical database and publication fingerprints
again while the application is stopped. Recovery selects the retained 2.0.4 image, not the published 2.0.3 image,
and never restores a data backup automatically. Eighteen synthetic safety tests passed with 139 assertions, including
rejection of a stale backup and closed access when database or publication contents change.

The replacement was activated on Homer at 15:39:44 UTC on October 14. The activation matched the updated backup's
fingerprints and preserved all six public tables, four sequences, and 24 publication files in 24 directories.
Only the web application was recreated; no migrations ran and the original configuration files were unchanged.
The public activation report was checked independently. These checks compare logical database contents and
publication contents, ownership, and permissions, not PostgreSQL physical files or timestamps.

After activation, the integrated browser's publication list supplied both retained copy links with Turbolinks disabled.
Clicking Open returned an `application/pdf` document without inserting PDF bytes into the HTML page. The operator
also confirmed that the PDF displayed on the first click in the temporary Firefox profile, without reloading.
This Firefox result is a manual confirmation, not an automated visual check or a complete browser compatibility
assessment.

The generated trial configuration continues to identify version 2.0.3. The candidate uses a separate verified
configuration, and the original `bin/private_trial start` command would select 2.0.3 again. Do not use that command to
restart the candidate. Earlier candidate procedures select the retained image rather than the PDF navigation
replacement. The dedicated `restart_candidate.sh` wrapper uses the exact activated image and existing container IDs.
Its `check` mode verifies configuration, identities, and readiness without interrupting services; `restart` pauses
access, restarts the same application container, checks deployment readiness, and reopens the same access container.
It does not create containers or run setup, migrations, image pulls, or builds. The database and mail service must
already be running. The [private trial procedure](private_trial.md#candidate-restarts) describes its scope and failure
behavior. Fourteen synthetic restart and configuration tests passed with 114 assertions. The wrapper and input hashes
were checked on Homer. The operator ran `check` successfully on October 14: the pinned image, configuration snapshot,
and existing container readiness matched without stopping or starting services. This check did not fingerprint database
contents. The operator also completed `restart` successfully on the same date. The same image and existing containers
were retained, configuration matched activation, and health checks passed. No migrations, image pulls or builds, or
database or Mailpit restarts occurred. An independent HTTP request through the SSH tunnel returned status 200 for
the login page afterwards. These restart checks did not compare logical database fingerprints; the earlier data
integrity comparison remains evidence for the image activation, not a repeated measurement during restart.

## Backup recovery of October 15, 2026

The updated 2.0.4 backup was restored on Homer into a separate Compose project with new PostgreSQL and publication
volumes. The recovery used the verified PDF navigation image, preserved the archived signing secret and public
origin, and published no ports. No migrations ran, and no images were pulled or built. The active trial was not
stopped or replaced; its container identities and lifecycle state matched before and after the rehearsal.

All six public tables and four sequence states matched the backup fingerprints. The publication inventory also
matched: 24 files in 24 directories, with their contents, ownership, and permissions checked before application
probes. The restored application passed readiness and deployment checks. Original and annotated downloads returned
HTTP 200 with matching file hashes, and the existing paper reference resolved with the retained signing key.
Anonymous access to that reference required login. No authentication token was issued and no rating was submitted.
All database fingerprints still matched after these requests. Download URL issuance can renew copy leases in the
isolated publication volume; its complete inventory comparison preceded those requests.

The successful rehearsal took 17 seconds and completed at 09:32:35 UTC. This measures the small synthetic backup
on the same host, not a production recovery objective or an independent host recovery. The requests ran through
Rack inside the restored application, not a browser or the active service. Recovery containers were stopped after
the checks; their separate volumes and protected configuration were retained. No backup contents were transferred
from Homer during that rehearsal. The [aggregate report](recovery-2026-10-15.json) was read independently and its
checksum verified. The subsequent encrypted copy is recorded below. The security findings and public deployment
limitations are unchanged.

## Encrypted NAS copy

The updated 2.0.4 backup was copied to a separate university NFS server on October 15 at 10:03:36 UTC. The archive
includes the verified database and publication backup and its private recovery configuration. GnuPG encrypted it
with OpenPGP AES256 and a passphrase entered only in the operator's terminal. Decryption was verified locally
before transfer, and the encrypted bytes were checked again on the NAS. The original backup remained intact;
no application service was stopped or replaced. The temporary plaintext archive was removed, and neither it nor
the passphrase was written to the NAS.

The encrypted file contains 2,990,163 bytes. Its checksum, size, and permissions were checked independently on the
NAS without downloading or decrypting it: the file mode is 0600 and its dedicated directory mode is 0700. The
[aggregate report](backup-nas-2026-10-15.json) was also read independently and its checksum verified. The passphrase
must remain available separately from the NAS. This confirms an encrypted copy outside Homer, not an additional
full application restore from that copy, immutable storage, or a guarantee of NAS availability. Future backup
frequency and retention still require configuration.

## Source validation

The complete local suite of October 14, including the shared configuration, publication fingerprint, and restart
helpers, passed 325 tests and 2,519 assertions with no failures, errors, or skipped tests. This check used Ruby 3.4.10
and a dedicated temporary PostgreSQL 11.22 database. The configured application autoload paths also passed `zeitwerk:check`.
The application image on Homer remains the verified `d3f37ea` build; consolidating the host helpers and these records
does not rebuild, restart, or publish it. The source CI checks on PostgreSQL 17 are separate from this local run.

The recovery configuration and orchestration checks passed 15 synthetic tests and 173 assertions on October 15,
including unsupported Compose options, transfer into a read only container, and failures that stop only the isolated
recovery project. A separate Rails fixture test exercised the application probe with the real PDF fixture and
confirmed unchanged reader, publication, rating, and authentication records. These helper tests are distinct from
the successful backup restore recorded above.

The complete local suite including the recovery helpers passed 341 tests and 2,701 assertions on October 15,
with no failures, errors, or skipped tests. This run used Ruby 3.4.10 and a separate temporary PostgreSQL 11.22
database; configured application autoload paths also passed. No private trial data was used for these tests.

Preparation does not validate public DNS, HTTPS, external SMTP, host maintenance, or production exposure.
The private trial activation does not publish the candidate or approve production use. The Docker Hub release remains
at version 2.0.3, and the recorded operating system advisories remain open.
