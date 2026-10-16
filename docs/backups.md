# Backup and recovery

RS_Server persists two resources: the PostgreSQL database and the private publication volume. A usable backup must contain both resources from the same maintenance period.

## Creating a backup

The generic Compose commands in this section do not operate the installed private candidate on Homer. For that
deployment, use the [installed operational commands](deployment_layout.md#operational-commands) and the recorded
migration backup described below. Do not run an older trial wrapper or the generic restore over its active volumes.

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

## Encrypted private trial copy

On October 15, the verified 2.0.4 private trial backup, including its recovery configuration, was copied to a separate
university NFS server. GnuPG encrypted the archive with OpenPGP AES256. The operator entered the passphrase only in
the terminal; it was not stored by the script or sent to the NAS. Decryption was checked before transfer, and the
NAS ciphertext checksum matched afterwards. The original backup was retained and the temporary plaintext archive
removed. The [validation record](backup-nas-2026-10-15.json) contains only aggregate results, not private settings
or archive contents.

Keep the passphrase in a password manager independent from the backup destination. A lost passphrase makes the
encrypted copy unusable. The NAS copy does not provide immutable storage or establish a backup schedule and
retention policy; configure these separately before relying on it for a public service. A full application restore
from the NAS copy has not been rehearsed. The separate restore of the source backup and the encrypted copy checks
are described in [the candidate validation](release-2.0.4.md#encrypted-nas-copy).

## Installed layout backup

The completed layout migration retained a separate protected backup under `/var/opt/readersourcing/rs-server/backups`.
It includes the database, publications, original and new configuration, runtime file metadata, data fingerprints and
a snapshot of the former temporary Mailpit inbox. The installed `restore-rehearsal` operation restored its database
and publications in an isolated project and checked the application without replacing the source deployment.
The [completion record](deployment-layout-completion-2026-10-16.json) reports that these checks passed.

This backup records the migration maintenance period. Exporting it later does not capture subsequent registrations,
ratings, publications or configuration changes. The October 15 encrypted NAS copy predates this layout backup and
remains retained separately.

`deploy/private/deployment_backup_export.sh` and `deployment_backup_export.py` provide a manual encrypted export of
the recorded layout backup. A host specific wrapper fixes the project, exact image and revision, installed state
directory, NAS mount and destination user. The validator checks the complete marker, exact checksum file set and
payloads, recorded backup pointer and identities, and the successful isolated recovery report and fingerprints.
It prints no configuration, dump or diagnostic contents. The export uses the deployment lock but does not stop,
start or replace any service and does not create a new live backup.

Run the verified wrapper with Bash and `--confirm-encrypted-copy` from an interactive terminal on Homer. Enter the
encryption passphrase only in that terminal and keep it separately in the password manager. GnuPG decrypts the
archive locally for an independent checksum comparison before transfer. Only encrypted bytes are copied to a fresh
NAS directory; the ciphertext checksum is checked again there. Earlier NAS copies and the original backup are not
overwritten. The temporary plaintext archive is removed on success or failure. An interrupted export may retain
an incomplete encrypted destination for inspection; it is not reported as a verified backup.

Preparation and local tests are not evidence that this new NAS export has run. Until the operator returns a successful
aggregate export report, the layout backup has no recorded independent host copy. Decryption and ciphertext checks
are not a full application restore from the NAS copy. No backup schedule or automatic retention is configured.

The October 16 export validation passed sixteen synthetic tests covering backup identity and integrity, matching
recovery evidence, passphrase verification failures, incomplete transfers and temporary plaintext cleanup. Encryption
and NFS are simulated in the orchestration tests; actual decryption and NAS verification belong to the operator's
interactive execution. Together with the existing diagnostics, thirty Python tests passed. The unchanged standalone
deployment suite also passed with 133 tests and 1,261 assertions.
