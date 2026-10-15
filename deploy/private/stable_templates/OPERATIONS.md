# Private Readersourcing operations

Run these commands on Homer in an interactive terminal. Passwords belong only in the terminal, never in chat.
The installation is accessible only to root. It does not enable automatic startup or scheduled backups.

Check configuration and existing container inventory without starting or stopping services:

```sh
sudo sh /srv/readersourcing/private-trial/operations/startup_candidate.sh check
```

Resume the existing trial containers manually, without running setup or migrations:

```sh
sudo sh /srv/readersourcing/private-trial/operations/startup_candidate.sh start
```

Restart only the web application and access, when PostgreSQL and Mailpit are already running:

```sh
sudo sh /srv/readersourcing/private-trial/operations/restart_candidate.sh restart
```

The full service rehearsal interrupts only this trial and can discard temporary Mailpit messages:

```sh
sudo sh /srv/readersourcing/private-trial/operations/startup_candidate.sh rehearse
```

Rehearse the retained backup in a fresh isolated project, without replacing the active application:

```sh
sudo sh /srv/readersourcing/private-trial/operations/restore_rehearsal.sh --confirm-isolated-restore
```

The recovery helper never restores over active volumes. Its stopped recovery containers, isolated volumes and
protected diagnostics remain for inspection. This is a manual rehearsal, not a recurring backup job.

The original active configuration paths remain unchanged because existing container bind mounts and the verified
configuration identify them. A dedicated tmpfiles rule excludes only those paths and their shared lock from age
based cleanup. It does not prevent explicit removal or changes by an administrator.

`configuration/trial`, `configuration/activation` and `configuration/backup` retain verified installation time copies.
The snapshots are not continuously synchronized. Preserve the installation and the independent encrypted NAS copy,
with its passphrase kept separately. Do not disclose or upload the installation directory or `snapshots.json`.
If an original active directory is missing, stop and inspect before manually restoring its corresponding snapshot
to the recorded original path with identical ownership and permissions. Never copy a snapshot over an existing
directory, regenerate secrets, select the published 2.0.3 image, or restore a database automatically.

This procedure does not upgrade packages, reboot Homer, change Docker restart policies, publish images, open ports,
or approve public deployment. Host maintenance requires a separate explicit decision.
