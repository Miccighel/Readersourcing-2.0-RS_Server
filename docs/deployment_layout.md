# Server installation layout

The server layout separates operational software, configuration and local state. The Rails application
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

## Operational commands

Installation completed on Homer on October 16, 2026. Run these commands on that host, not on the workstation
which carries the SSH tunnel:

```console
sudo sh /opt/readersourcing/rs-server/rs-server check
sudo sh /opt/readersourcing/rs-server/rs-server start
sudo sh /opt/readersourcing/rs-server/rs-server restart
sudo sh /opt/readersourcing/rs-server/rs-server restore-rehearsal --confirm-isolated-restore
```

`check` verifies configuration, the recorded container inventory and readiness without starting or stopping services.
`start` resumes existing containers in dependency order when needed. `restart` restarts only the application and its
access proxy. The completed setup container remains stopped. None of these operations creates service containers,
runs migrations, pulls or builds images, changes host packages, reboots Homer or enables automatic startup.

`restore-rehearsal` uses the recorded migration backup in a new isolated project with separate volumes and no
published ports. It never restores over the active deployment. Recovery services are stopped after the checks;
their protected diagnostics and volumes remain available for inspection. This operation is manual and explicit,
not a recurring backup or an export to the NAS.

Use these installed commands for the current deployment. Do not use `bin/private_trial start`, earlier candidate
wrappers or the snapshot commands under `/srv/readersourcing/private-trial`: their retained configuration and
container inventories describe earlier installations. Do not rerun the migration or its completion over the
installed directories. Old inputs and backups remain retained; their removal requires a separate review.

The [completion record](deployment-layout-completion-2026-10-16.json) reports that the frozen inventory and
configuration were preserved, data fingerprints matched, and the installed command check and isolated restoration
from the new backup passed. It records the operator's aggregate report, not access to protected diagnostics.
The [encrypted export of that backup](backup-layout-nas-2026-10-16.json) was verified on the separate university NAS
on the same date. The earlier NAS copy remains retained. No new live backup or recurring schedule was created.

The [browser checks of October 16](browser-regression-2026-10-16.json) cover login, publication listing and search,
opening the prepared PDF in Firefox without reloading, and following its rating reference. The synthetic reader
had already rated that publication, so the server showed the existing rating notice; no new rating was submitted.
The integrated browser received a PDF document but displayed a blank viewer. A subsequent check confirmed an empty
PDF document body without an embedded viewer. The PDF itself opens in Firefox; this does not establish a server
generation failure or complete compatibility with other viewers. No PDF generation or response security policy
was changed to accommodate that browser.

Two older synthetic publication rows also had empty titles. The publication model permits missing metadata and the
list originally rendered such titles as an empty cell. The development source now displays `Title not available`
for a missing, empty or whitespace only title, without writing a replacement to the database, changing API metadata
or preparing the PDF again. Tests check preservation of metadata, retained opening links and HTML escaping. This
display correction has not been installed on Homer; it does not repair or establish the original cause of historical
missing metadata.

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

The installed command is `/opt/readersourcing/rs-server/rs-server`, with `check`, `start`, `restart` and explicitly
confirmed `restore-rehearsal` operations.
Its implementation reuses the existing startup and restart functions with the new configuration and state paths;
it does not require the old generated configuration to operate. Local tests cover the new configuration files and
stopped replacement inventory, service ordering, and closing access after a failed check. The completed setup
container is retained only for historical inventory checks. The recovery adapter reuses the tested isolated restore
flow with the new definition, backup and protected state paths. Local tests check the archive format, isolation,
runtime metadata and failure handling. Host execution of the new recovery entry point passed during completion.

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
containers still use their exact settings.

At runtime, [Moby may clear the OOM flag when the kernel does not support that option](https://github.com/moby/moby/blob/v28.3.2/daemon/daemon_unix.go#L441).
The final operational commands therefore use `deployment_startup_inventory.rb`, a restricted adapter over the
original inventory checker. For the three replacement services only, it compares an explicit `false` or `null` as
the same default, provided the checked definition leaves `oom_kill_disable` absent or `false`. It rejects `true`,
missing fields and other JSON types in both the frozen and current inventories. All other settings and the retained
database and setup inventories remain exact. The original checker and the stored inventory are not rewritten.

A separately verified resume command can continue a recorded interruption after stopped replacements were created.
It checks the original package, installed helper manifest, prepared plan, runtime files and retained checkpoint.
The same replacement identities must still be in the `created` state and never started; retained containers must
have the original lifecycle. Database and publication fingerprints must match both the interrupted attempt and its
verified backup. The recovery definition is checked before any service starts. The command retains the previous
validator and manifest, updates only the public replacement validator, freezes the verified existing inventory and
performs the same readiness, data preservation and isolated recovery checks required by activation. It does not
reinstall configuration, recreate service containers or restore over the active database. A rejected checkpoint is
not automatically retried with a new baseline. Local test results do not establish that a host resume has succeeded.

If a resumed activation stops at the installed command check, `deploy/private/deployment_operation_diagnostic.py`
provides a separate read only diagnosis of that recorded attempt. It checks public helper hashes, context and
configuration records, expected path permissions, backup archive integrity and the frozen container inventory.
Only fixed field names, value shapes, comparison results and predefined error categories are reported. It does not
approve inventory differences, change the frozen baseline, execute the installed operational commands or start
services. Its nine dedicated tests cover redaction, exact boolean handling, path selection and helper integrity.

A guarded completion procedure handles the recorded interruption after the replacements have already started.
It checks the installed software against the verified resume package and its retained manifest, proves that the
frozen inventory is still the one prepared before the first start, and validates the current containers with the
restricted runtime adapter. Access and the application must remain stopped, while the database and mail service
must remain running. Recorded data fingerprints must agree before and after the interrupted attempt and with fresh
read only probes and the verified backup. Only the operational adapter, its new inventory helper and the public
helper manifest are installed. Configuration, secrets, images and the frozen inventory remain unchanged.
The continuation checks application readiness and data preservation before reopening access, then runs the
installed command check and isolated recovery rehearsal. It preserves database, completed setup and Mailpit
identities and lifecycle. A failure does not automatically restore data or refresh the acceptance baseline.

This procedure does not configure automatic startup or recurring backups, update host packages, restart Docker,
reboot the host, publish an image or expose the application publicly.

The standalone deployment suite passed on October 16 with 133 tests and 1,261 assertions. It covers both the
original recovery procedure and the new layout adapter, archive validation, stopped replacement checks and failure
handling, the guarded resume and completion checkpoints and the validator's default OOM comparison. The fourteen
read only diagnostic tests also passed. These local results are separate from the operator's successful installation,
completion and recovery report linked above. They do not establish public deployment approval.
