# Backup and recovery

RS_Server persists two resources: the PostgreSQL database and the private publication volume. A usable backup must contain both resources from the same maintenance period.

## Creating a backup

Keep the database and application containers running, but prevent users from writing data for the duration of the backup. Put the reverse proxy in maintenance mode, wait for active requests to finish, then choose a directory outside the repository and run:

```console
bin/backup /path/to/rs_server_backups
```

The command creates a dated directory with:

- `database.dump`, a PostgreSQL archive without ownership information;
- `publications.tar.gz`, the private publication files;
- `SHA256SUMS`, integrity values for both archives;
- `manifest.txt`, the creation time and configured application image.

The files are created with access limited by the current user's file permissions. Copy the completed directory to encrypted storage that is independent from the application host. A named Docker volume protects data when a container is recreated, but it is not a backup.

These archives do not include application configuration or secrets. Keep a separate protected recovery copy of the
production settings, particularly `SECRET_PROD_KEY` and `PUBLIC_BASE_URL`. Restore the same signing secret and public
origin when existing paper rating references must remain usable. A different secret prevents those references from
being verified; a different public origin does not change links already printed or embedded in prepared PDFs. Never
store secrets in the repository or attach them to a public recovery report.

Remove maintenance mode only after both archives and `SHA256SUMS` have been written. This gives the database and publication archive a common, well defined maintenance period.

Schedule backups according to the acceptable recovery point for the service. Remove copies that have exceeded `PRIVACY_BACKUP_RETENTION_DAYS`, unless an applicable legal obligation requires a documented exception. The application validates the declared period but cannot control the retention policy of an external backup provider.

## Verifying and restoring a backup

Always rehearse recovery on an isolated Compose project before relying on a new hosting arrangement. A restore replaces the current database and every prepared publication, so create a fresh backup first and put the service in maintenance mode.

Start the target database, then run the restore only after checking the selected directory:

```console
bin/restore_backup --confirm /path/to/rs_server_backups/rs_server_YYYYMMDDTHHMMSSZ
```

The command verifies `SHA256SUMS` and rejects unsafe archive paths. It stops the web service, restores PostgreSQL, replaces the publication volume contents, and starts the web service again. The explicit `--confirm` argument prevents an accidental invocation.

After recovery:

1. wait for `GET /ready` to return `200`;
2. run `docker compose exec rs_server_webapp bin/rails deployment:check`;
3. compare reader, publication, and rating counts with the source instance;
4. download an original and annotated PDF;
5. verify that a QR Code rating reaches the restored application origin;
6. record the recovery time and any manual action.

The backup must be restored only into a trusted environment. Database archives and PDFs can contain personal or confidential material and must never be attached to a public issue.

The isolated recovery checks of October 9 and October 12, 2026 are recorded in
[integration.md](integration.md#backup-and-recovery) and the
[latest container validation](integration.md#validation-of-october-12-2026). They verify the scripts and
the restored application with synthetic data, not the availability or recovery time of a future production host or
external backup provider.

The [private candidate recovery of October 15, 2026](release-2.0.4.md#backup-recovery-of-october-15-2026) restored
the protected 2.0.4 trial backup on Homer into fresh volumes without interrupting the source application. Database,
sequence, publication inventory, download, and existing paper reference checks passed. The 17 second rehearsal
used synthetic data on the same host; it does not replace a protected backup copy outside that host. Its separate
procedure is described in [the private trial instructions](private_trial.md#recovery-rehearsal).
