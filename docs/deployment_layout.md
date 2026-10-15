# Server installation layout

The planned server layout separates operational software, configuration and local state. The Rails application
remains inside its verified container image; the host does not need a writable checkout of its source repository.

| Location | Purpose |
| --- | --- |
| `/opt/readersourcing/rs-server` | Operational commands and their verified helper code |
| `/etc/opt/readersourcing/rs-server` | Active Compose definition, SMTP certificates, authentication and proxy configuration |
| `/var/opt/readersourcing/rs-server` | Protected plans, inventories, locks and operational records |

This separation follows the Filesystem Hierarchy Standard for [additional software under `/opt`](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch03s13.html),
[its configuration under `/etc/opt`](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch03s07.html), and
[its variable state under `/var/opt`](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch05s12.html).
Private configuration and records remain accessible only to root. Public helper code mounted into an unprivileged
container must remain readable by that container without exposing its enclosing private directories on the host.

Database and publication data remain in their existing Docker named volumes. Their physical storage is managed by
Docker, not moved into these directories. The encrypted NAS backup remains separate from the operational state.
The internal Compose project identity is retained to preserve the existing volume and network identities; it is
not the name of the installation directory or a change to the application's public identity.

## Preparation

`deploy/private/deployment_layout_configuration.rb` generates a restricted replacement for the resolved private
configuration. It retains the exact running images, environment, ports, networks, volume definitions and runtime
restrictions. Only the five runtime bind file locations are changed. The completed setup service is excluded from
the active definition, together with its completed dependency: this migration must not run database migrations.

A host specific preparation command checks the current operational scripts and deployment, then creates a protected
plan under `/var/opt/readersourcing/rs-server/plans`. It records the source container inventory, generates the proposed
definition and checks it against Docker Compose's resolved output. Runtime file contents, ownership and permissions
are compared before and after preparation. Private values and diagnostic logs are not printed.

Preparation uses short lived local helper containers without a network, pulling or building images. It does not
stop, start or recreate the existing application services, install the active configuration, copy a live database,
or activate the new operational commands. A preparation report is not evidence of a completed migration.

The [October 15 preparation record](deployment-layout-preparation-2026-10-15.json) reports successful preparation
on Homer. It does not record an installation or service interruption. The next host acceptance command performs
only the activation preflight: it repeats the prepared configuration and container comparisons, exercises the read
only database and publication probes and checks deployment readiness. No service replacement is requested by that
command, and no active configuration or operational command is installed.

The [activation preflight record](deployment-layout-preflight-2026-10-15.json) reports that these checks passed on
Homer without service interruption or configuration installation. This is distinct from activation and from a
restore rehearsal using the new backup format.

## Activation requirements

Activation requires a separately verified procedure, a current point in time backup, and an explicit maintenance
step limited to Readersourcing. Database rows and sequences and publication contents and permissions must be compared
while the web application cannot write. The application, mail and access containers need recreation to use the new
configuration and bind paths; the database container and existing volumes must be retained. Their exact images and
security settings must be verified before the replacement containers are started.

The new commands must be checked against the installed definition and inventory. Recovery precautions and rollback
must refer to the retained old configuration, without automatically restoring a database or regenerating secrets.
The existing installation under `/srv/readersourcing/private-trial` and its protected original inputs are retained
until activation and operational checks have passed and their removal has been reviewed separately.

The proposed command is `/opt/readersourcing/rs-server/rs-server`, with `check`, `start`, `restart` and explicitly
confirmed `restore-rehearsal` operations.
Its implementation reuses the existing startup and restart functions with the new configuration and state paths;
it does not require the old generated configuration to operate. Local tests cover the new configuration files and
stopped replacement inventory, service ordering, and closing access after a failed check. The completed setup
container is retained only for historical inventory checks. The recovery adapter reuses the tested isolated restore
flow with the new definition, backup and protected state paths. Local tests check the archive format, isolation,
runtime metadata and failure handling; host execution of the new recovery entry point remains part of activation.

The activation implementation stages configuration before maintenance and takes a fresh protected backup while
access and the application are stopped. It creates the three selected replacements without starting them, then
compares their actual execution settings, mount contents and isolation to the retained source inspection. Only the
approved bind sources and Compose bookkeeping may differ. Database and setup identities and lifecycle must be
unchanged. Database and publication fingerprints are compared before access reopens. A failure during maintenance
keeps access and the writer stopped where possible and requires inspection; it never restores a database by itself.

Compose bookkeeping is checked against the approved definition and the services selected for recreation. In the
installed Compose 2.39.1, the [replacement label records the service name and container number](https://github.com/docker/compose/blob/v2.39.1/pkg/compose/convergence.go#L595),
while [`--no-deps` selects services before creation](https://github.com/docker/compose/blob/v2.39.1/cmd/compose/up.go#L60)
and [prunes dependencies outside that selection](https://github.com/compose-spec/compose-go/blob/v2.8.1/types/project.go#L483).
The comparison allows those exact metadata changes without relaxing environment, execution, storage or isolation checks.

Mailpit's temporary inbox is archived before recreation. The new inbox is empty; the old messages remain in the
protected point in time backup. Before replacing containers, the actual new backup is checked by generating a recovery
definition without starting recovery services. Once the installed commands pass their checks, the activation wrapper
rehearses database and publication restoration using that backup in an isolated project with new volumes, an internal
network and no published ports. It compares restored data and runs the existing synthetic application probes. The
source deployment's container identities and lifecycle must remain unchanged throughout the rehearsal. A successful
activation report requires the rehearsal to pass; a failure stops access and the writer where possible for inspection.
Recovery containers are stopped after the checks, while their isolated volumes and private diagnostics are retained.
There is no restore over the active deployment, Mailpit inbox restore or additional encrypted NAS copy. The original
NAS copy is not overwritten.

If activation stops, do not rerun the installer over the staged directories or start unchecked replacements.
`deploy/private/deployment_layout_diagnostic.py` provides a read only diagnostic for the recorded stopped attempt.
It compares the retained and current inspection inside the host, verifies backup archive checksums and reports only
fixed schema field names, states, booleans and error categories. Environment values, unknown label names, private
paths and log contents are not exported. Its Python tests cover expected relocation, redaction and source preservation.
Known top level host fields follow the [Moby HostConfig and resource schema](https://github.com/moby/moby/blob/v28.3.2/api/types/container/hostconfig.go#L342).
For differing fields, the diagnostic reports only whether a value is missing, null, empty or nonempty and its JSON
type. This does not normalize or approve the difference, and it does not relax the activation checks.

Docker may represent the default OOM setting as either `null` or `false`:
[Moby assigns `false` to an unspecified `OomKillDisable`](https://github.com/moby/moby/blob/v28.3.2/daemon/daemon_unix.go#L351).
The replacement comparison accepts only the transition from an explicit `null` source value to an explicit `false`
replacement value, with `oom_kill_disable` absent or `false` in the approved definition. It does not accept `true`,
a missing inspection field or changes to other resource and isolation settings. Retained database and setup
containers and subsequent startup inventory checks still use their exact settings.

A separately verified resume command can continue a recorded interruption after stopped replacements were created.
It checks the original package, installed helper manifest, prepared plan, runtime files and retained checkpoint.
The same replacement identities must still be in the `created` state and never started; retained containers must
have the original lifecycle. Database and publication fingerprints must match both the interrupted attempt and its
verified backup. The recovery definition is checked before any service starts. The command retains the previous
validator and manifest, updates only the public replacement validator, freezes the verified existing inventory and
performs the same readiness, data preservation and isolated recovery checks required by activation. It does not
reinstall configuration, recreate service containers or restore over the active database. A rejected checkpoint is
not automatically retried with a new baseline. Local test results do not establish that a host resume has succeeded.

This procedure does not configure automatic startup or recurring backups, update host packages, restart Docker,
reboot the host, publish an image or expose the application publicly.

The standalone deployment suite passed on October 15 with 120 tests and 1,146 assertions. It covers both the
original recovery procedure and the new layout adapter, archive validation, stopped replacement checks and failure
handling, the guarded resume checkpoint and the validator's default OOM comparison. The five read only diagnostic
tests also passed. These local results do not assert that the installation, resume or recovery rehearsal has run on Homer.
