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

This procedure does not configure automatic startup or recurring backups, update host packages, restart Docker,
reboot the host, publish an image or expose the application publicly.
