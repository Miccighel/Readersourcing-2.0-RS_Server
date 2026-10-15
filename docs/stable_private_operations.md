# Stable private operations

The private trial can retain its verified containers while its operational tools and installation time configuration
copies are installed under `/srv/readersourcing/private-trial`. This is a private operational installation, not a
public deployment, host upgrade, or automatic startup service. Installation requires interactive root permission.

The shared installer is `deploy/private/stable_installation.rb`; its shell wrappers and operations guide are in
`deploy/private/stable_templates`. A host specific installer fixes the trial, activation plan, exact local image,
retained backup and shared lock. Its checksum manifest verifies all public inputs before execution.

## Layout

| Location inside the installation | Purpose |
| --- | --- |
| `operations` | Verified startup, restart and isolated recovery helpers |
| `configuration/trial` | Installation time copy of the generated configuration and synthetic fixture |
| `configuration/activation` | Retained activation plan and prepared container inventory |
| `configuration/backup` | Verified copy of the existing protected backup, not a new live backup |
| `OPERATIONS.md` | Commands and recovery precautions for the operator |
| `snapshots.json` | Private contents and permissions inventory of the retained copies |

The installation and its parent directory are owned by root with mode `0700`. Wrappers and their context have mode
`0600`. Public helper code has mode `0644` because selected scripts are mounted into containers running as the
existing unprivileged users. The protected parent directory still prevents other host users from accessing them.
Configuration copies preserve source ownership and permissions inside the protected installation. These files can
contain credentials and reader data: never paste, commit, or upload the installation or its inventories.

## Installation and checks

The installer first checks the existing trial and acquires its current shared lock. It refuses an existing destination
or cleanup rule. A fresh staging directory receives copies of the trial, activation plan, and retained backup. The
backup's complete marker, project, image identity and seven checksums are checked before copying. Each copied tree
is compared with its source for file contents, hidden entries, ownership and permissions; source inventories are
repeated to detect changes during copying. Symbolic links and special files are rejected. No database is dumped or
restored, and no source file is deleted or rewritten.

The staged operational scripts are syntax and checksum checked before the directory is installed. The stable startup
and restart commands then run their nonmutating checks. The installer compares all five trial container identities,
images, running state, start timestamps and restart counts before and after installation. A successful aggregate
report is printed; protected diagnostics remain on the host. A failure preserves the sources and any partial staging
directory for inspection rather than removing data or retrying destructively.

If installation has already published its destination but stopped at the command checks, do not rerun the installer
or remove that directory. A reviewed completion procedure must verify the exact installed code and failure category,
retain the existing snapshots, and repeat the command and container checks. Public helper read permissions inside
containers are distinct from private host directory access; changing helper permissions must not relax access to
configuration, credentials, or snapshot inventories.

After installation, run the commands documented in the protected `OPERATIONS.md`, for example:

```sh
sudo sh /srv/readersourcing/private-trial/operations/startup_candidate.sh check
sudo sh /srv/readersourcing/private-trial/operations/restart_candidate.sh check
```

The retained backup can be rehearsed manually through `operations/restore_rehearsal.sh --confirm-isolated-restore`.
This uses a fresh isolated project, never the active volumes. Installation does not itself execute that recovery or
claim it has been retested from the stable location. No backup timer or synchronization job is installed.

## Active configuration paths

The running containers retain their original bind mount paths under `/var/tmp`, and configuration validation retains
the original activation snapshot. Moving those active paths would be a separate migration requiring container and
configuration checks. The stable installation does not recreate containers or silently replace the prepared baseline.

One dedicated file, `/etc/tmpfiles.d/readersourcing-private-trial.conf`, excludes the exact active trial and activation
directories from age based cleanup. It also preserves the shared lock and its parent directory, but does not exempt
the parent's other contents, such as the scanner cache. It does not disable the host cleanup service or apply cleanup
to another project. No cleanup command is run during installation.

The rule uses systemd's `x` entries for directory contents and the lock, and an `X` entry for the lock's parent alone.
These exclusions do not prevent explicit administrator removal or an explicit `r` or `R` rule. See the
[systemd tmpfiles specification](https://github.com/systemd/systemd/blob/v249/man/tmpfiles.d.xml).

The stable copies are snapshots, not continuously updated replicas. If a required original directory is missing, stop
and inspect before explicitly restoring its corresponding snapshot to the recorded original path. Preserve identical
ownership, permissions and contents, and never overwrite an existing directory. Do not regenerate signing secrets,
run the original published trial start command, or automatically restore a database.

## Scope

No host package is installed or upgraded, no host or Docker service is restarted, no container restart policy changes,
and no port is opened. The exact activated image, original configuration, active database, publication volumes and
independent encrypted NAS copy remain unchanged. Existing backups and temporary operational directories are retained;
cleanup of those exact resources requires a separate review. Host maintenance and public deployment are outside this
procedure.
