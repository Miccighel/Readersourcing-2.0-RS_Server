# RS_Server operations

The application runs inside the recorded local container image. Operational software is installed under
`/opt/readersourcing/rs-server`, active configuration under `/etc/opt/readersourcing/rs-server`, and protected
state under `/var/opt/readersourcing/rs-server`. PostgreSQL and publication files retain their Docker volumes.

These commands require root on the Docker host:

```sh
sudo sh /opt/readersourcing/rs-server/rs-server check
sudo sh /opt/readersourcing/rs-server/rs-server start
sudo sh /opt/readersourcing/rs-server/rs-server restart
sudo sh /opt/readersourcing/rs-server/rs-server restore-rehearsal --confirm-isolated-restore
```

`check` validates the active configuration, runtime file contents and permissions, exact container inventory and
health. It does not change service lifecycle. `start` resumes the existing containers, in dependency order, when
necessary. `restart` restarts only the application and its access proxy. None of these three commands creates service
containers, pulls or builds images, runs migrations, configures automatic startup or restarts the Docker daemon.

The completed setup container remains stopped and is checked as a historical record. It is not part of the active
Compose definition and is never started. The internal project identity is retained to preserve volume and network
identities. Do not rename Docker volumes or regenerate application signing secrets to change a directory name.

An error before maintenance does not interrupt the running services. An error during startup or restart keeps access
closed where possible. Inspect the protected diagnostics on the host before reopening it. Never paste or upload
configuration, inspection snapshots, database dumps, messages, or diagnostic logs. Success reports contain only
aggregate checks and public installation identities.

## Backups and recovery

The layout migration records a fresh protected backup under the state directory while access and application are
stopped. It retains the database dump, original and new configuration, publications, their fingerprints, and a snapshot
of Mailpit's temporary mailbox. Archive integrity is checked before replacing any service. The migration then checks
the installed commands and rehearses database and publication restoration in a separate isolated project. A success
report requires both checks to pass. This is not a new NAS copy or a restoration of Mailpit's temporary inbox.
Recreated Mailpit starts with a new temporary inbox; the previous messages remain in that protected backup.

The earlier verified backups and encrypted NAS copy remain retained separately. Keep the NAS passphrase in the
password manager, not in the installation or chat. No backup schedule or automatic retention policy is installed.

`restore-rehearsal --confirm-isolated-restore` checks the current deployment and the recorded migration backup, then
creates a separate project with new volumes and no published ports. Only the backup is read: active database and
publication volumes are never mounted into the rehearsal. It compares restored rows, sequences and publication
files and checks the restored application and synthetic PDF references. The recovery containers are stopped after
checks; their isolated volumes and protected diagnostics are retained. The aggregate report is stored under the
protected active state, not in the public software directory. No host update, public exposure or recurring backup
is configured by this command.

There is no automatic restore over active data or generic destructive cleanup command. The old installation
and its original inputs are retained for inspection and rollback preparation; after service recreation their frozen
container inventories no longer describe the active deployment. Do not use the old startup, restart or recovery
wrappers as shortcuts. A failed migration or rehearsal requires inspection before access is reopened; it does not
trigger an automatic rollback or database restore.

Public deployment, host updates and a host reboot are outside these operations.
