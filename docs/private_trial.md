# Private trial

This procedure runs the published RS_Server 2.0.3 image with synthetic reader accounts and the repository's PDF fixture.
It is a private functional trial, not a public deployment or a replacement for the production host security review.
The application code, dependency declarations, and normal production Compose configuration are unchanged.
An existing trial updated to a development candidate must use its verified candidate procedure instead of the
published image's start command; see [candidate restarts](#candidate-restarts).

## Requirements

Use a Linux Docker host with Docker Engine 28 or newer, the Compose plugin, SSH access, and permission to run Docker.
The image supports `linux/amd64` and `linux/arm64`. CPU and memory availability must be confirmed on a shared host.
Docker versions before 28 have a documented limitation in [loopback port isolation](https://docs.docker.com/engine/network/port-publishing/).
Preparation requires registry access to pull the images; the running application network has no Internet access.

The trial creates a unique Compose project, its own PostgreSQL and publication volumes, and a local Mailpit service.
RS_Server is limited to one CPU and 1 GiB of memory, PostgreSQL to half a CPU and 512 MiB, and Mailpit to a quarter CPU
and 128 MiB. A small NGINX access service is limited to a quarter CPU and 64 MiB. Logs are bounded. None of these services
starts automatically after a host reboot.
The trial selects the ordinary `runc` runtime explicitly and requests no GPU devices, including on hosts with an NVIDIA
runtime configured for their research workloads.

Only `127.0.0.1:33030` for RS_Server and `127.0.0.1:33031` for Mailpit are published. PostgreSQL and SMTP have no host
ports. HTTP remains on loopback; SSH encrypts the connection between the browser's host and the Docker host. Public
origins still require HTTPS under the application's existing configuration rules. Loopback is accessible to other
users on the same host, so Mailpit requires a generated UI password and only synthetic data must be used.
The access service forwards HTTP only to the application and Mailpit. It has no application secrets or database volume.
The application, database, and Mailpit remain on a separate internal network with no external route; the access service
alone joins the bridge used to publish the loopback ports. It does not provide a general purpose proxy or SMTP relay.

Mailpit requires [STARTTLS and SMTP authentication](https://mailpit.axllent.org/docs/configuration/smtp/).
Preparation creates a certificate valid for 30 days and trusts it only inside the application containers. It does not
change the host or browser trust stores. Messages remain in Mailpit; forwarding and relaying are not configured.
Mailpit message storage is temporary and is lost when its container is recreated or the host restarts.

## Preparation

Obtain the development branch in a dedicated checkout on the Docker host. Do not reuse a directory containing another
service or private application configuration. For example:

```console
git clone --single-branch --branch codex/development https://github.com/Miccighel/Readersourcing-2.0-RS_Server.git RS_Server-private
cd RS_Server-private
trial_directory=$(mktemp -d /var/tmp/rs-server-private.XXXXXX)
sudo sh bin/private_trial prepare "$trial_directory"
```

The helper refuses a nonempty trial directory. It generates separate application, database, and Mailpit settings with
new credentials; it does not reuse the checkout's `.env` or any credentials from a previous trial. The private directory
must remain on persistent local storage for the duration of the trial. Record its path locally without publishing its
contents. Its fixture is an unchanged copy of `test/fixtures/files/Reader.pdf`.

The generated record verifies the project identity and the hashes of its configuration before subsequent operations.
Do not edit the generated configuration to change the ports, network, image, or secret values. A failed preparation may
leave partial files; preserve or inspect them and choose another empty directory rather than overwriting them.

## Starting and accessing the trial

From the same checkout and terminal on the Docker host:

```console
sudo sh bin/private_trial start "$trial_directory"
sudo sh bin/private_trial status "$trial_directory"
```

Startup uses published images without a local build, runs the migrations for this trial database, waits for readiness,
and checks the production configuration, storage, database, migration state, and authenticated SMTP connection.
A failure does not trigger a global cleanup or remove the trial data; inspect the failed project before proceeding.

On the browser's host, use the SSH alias configured for the trial host:

```console
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:33030:127.0.0.1:33030 -L 127.0.0.1:33031:127.0.0.1:33031 trial-host
```

Keep the tunnel terminal open. Visit `http://127.0.0.1:33030/login` for RS_Server and `http://127.0.0.1:33031/` for Mailpit.
The Mailpit username is `rs-trial`; read its generated password locally from `runtime/ui.auth` in the private directory.
Never paste this file or the application settings into a chat, issue, or public report. If a local tunnel port is already
in use, stop and resolve the conflict rather than forwarding a different port: generated email and PDF links use 33030.

## Functional checks

Use a synthetic email address such as `reader1@rs-trial.test` and a password that is not used for any real account.

1. register and open the confirmation email in Mailpit;
2. sign in, upload the copied PDF fixture, and check its title in the publication list;
3. open the annotated PDF, exercise its QR Code rating, and check that the confirmation notice respects the reader's email preference;
4. request password recovery and open the captured email;
5. sign out, sign in again, and reopen the prepared publication after the signed download URL's five minute lifetime;
6. delete the synthetic account and check the removal of its private publications.

The published 2.0.3 image can leave the fixture's title blank, keep an expired Open link, and show an email confirmation
notice to an unsubscribed reader. Record these interface outcomes separately from PDF preparation, rating persistence,
and actual mail delivery. Reloading the publication list obtains a fresh download link for an existing copy.

Remote publication retrieval is intentionally unavailable in this trial because its network has no Internet access.
The private address restriction remains enabled. These checks do not validate public DNS, HTTPS certificates, real SMTP
delivery, external backup storage, production capacity, or exposure to untrusted Internet clients. PDF links identify
this loopback trial and must not be distributed as public publication links.

## Stopping

```console
sudo sh bin/private_trial stop "$trial_directory"
```

This stops only the identified trial project. Its database, publication volumes, configuration, and secrets remain
available for inspection and recovery. It does not prune images, caches, or volumes, and it does not remove resources
belonging to other projects. Permanent removal requires checking the exact project resources and a separate decision.

## Candidate restarts

An updated trial retains its generated configuration and a separate verified image override. The original
`bin/private_trial start` still selects the published image and must not be used to restart that candidate.
Earlier candidate activation scripts are not restart commands either.

Use the host specific `restart_candidate.sh` wrapper prepared for the activated image and project. Retain that
wrapper, its `RESTART-SHA256SUMS` manifest and helper files, the original trial directory, and the private activation
plan. The shared implementation is in `deploy/private/candidate_restart.sh` and `deploy/private/restart_configuration.rb`.
The wrapper fixes the exact image ID, source revision, project, and activation plan; it does not select an image tag.

From its verified operations directory on the Docker host:

```console
sudo sh restart_candidate.sh check
sudo sh restart_candidate.sh restart
```

`check` compares the original and effective configurations with the activated snapshot, then verifies existing
container identities and readiness without stopping or starting a service. `restart` pauses access and restarts
only the same application and access containers. It waits for the application, runs `deployment:check`, and repeats
configuration and identity checks before reopening access. A failure during maintenance leaves access stopped for
inspection; if access cannot be stopped, the command reports that operator attention is required.

The database and Mailpit must already be running, and the setup container must have completed successfully.
The procedure does not run setup or migrations, create containers, pull or build images, restore backups, or delete
volumes. It can resume the same stopped application and access containers, but is not a full stack startup procedure
after a host reboot. Database contents are not fingerprinted by a restart check. Diagnostics can contain private
configuration and remain in a protected directory on the host; do not paste or upload them.

## Recovery rehearsal

A protected trial backup can be rehearsed without replacing or pausing the running application. The host specific
`restore_rehearsal.sh` wrapper fixes the source project, backup directory, and exact local application image. Its
`RECOVERY-SHA256SUMS` manifest verifies the shared helpers in `deploy/private` before they are used.

From the verified operations directory on the Docker host:

```console
sudo sh restore_rehearsal.sh --confirm-isolated-restore
```

The procedure checks the activated trial, backup completeness and checksums, and the archived configuration. It
rejects symbolic links and unsafe archive entries. It creates a separate Compose project with fresh PostgreSQL and
publication volumes and an internal network, without publishing ports. Existing source volumes and containers are
not recovery targets. The application uses the retained signing secret and public origin; Mailpit uses a private
copy of the archived TLS and authentication files. No images are pulled or built, and no migrations are run.

After restoring the empty target, the procedure compares every public table and sequence and the full publication
inventory with the backup fingerprints. The fixture check uses the synthetic reader and publication selected for
that host: it exercises readiness, login, original and annotated downloads, and the existing paper reference inside
the restored application through Rack. It does not follow PDF links to the running source or submit a rating.
Normal download URL issuance can renew copy leases in the isolated publication volume. Database fingerprints are
compared again after these requests. These are application checks, not a browser compatibility test.

The recovery containers are stopped after the checks, including on failure. Their volumes and protected diagnostics
are retained for inspection; removal requires checking those exact resources separately. Source container identities
and lifecycle state are compared before and after the rehearsal, but the live source database is not fingerprinted
while users can write to it. Only a successful aggregate report is made available outside the protected directory.

The rehearsal validates the selected synthetic backup on the same host. It does not provide an independent host
copy, a production recovery time, or security approval for public deployment. The backup and generated recovery
configuration contain private settings and must not be pasted into a chat, committed, or uploaded with the report.
