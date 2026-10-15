# Private host maintenance

Host maintenance and application image maintenance are separate operations. RS_Server's candidate image uses
Debian packages; updating an Ubuntu Docker host does not update those packages inside an existing image.
Neither a successful restart nor a clean application test suite is security approval for public deployment.

## Before a maintenance window

On a shared host, agree the interruption with the administrators and researchers before changing packages,
restarting Docker, or rebooting. Logged in sessions, GPU work, scheduled jobs, containers from other projects,
remote access, and NAS mounts all require review. An idle GPU at one instant is not evidence that the host is unused.

Record the operating system, kernel, Docker and Compose versions, available disk space, failed services, reboot
requirement, and pending package changes. A package simulation uses the available local package indexes; its
result must not be presented as a current security assessment when those indexes are stale. Read private system
logs on the host; do not attach their contents to a public application report.

Before approving changes:

- verify a usable console or other recovery access independent of the current SSH connection;
- retain the application's verified backup, its encrypted independent copy, and the passphrase separately;
- prepare and check the candidate's manual startup inventory while its existing containers are healthy;
- confirm that the exact candidate image, other trial images, configuration, activation plan, startup helpers,
  and inventory will survive the reboot and are not due for temporary file cleanup;
- check the trial SMTP certificate expiry; startup must fail rather than bypass TLS validation;
- review the proposed package transaction, including held packages, removals, kernel and NVIDIA driver changes,
  Docker, SSH, and networking. Do not infer permission for a distribution upgrade from a login banner.

Keep the startup inventory and effective configuration private: both can contain credentials. A directory under
`/var/tmp` normally survives a reboot but is not a permanent installation or backup policy. Relocating an existing
trial is a separate operation because its validated bind mounts and generated settings identify their paths.

## During and after maintenance

Perform only the agreed package transaction in the agreed window. Resolve package manager failures before
rebooting. Do not reset firewall, GPU, container, or SSH settings merely to make an application check pass.
If the host does not return, use the agreed recovery access rather than weakening authentication.

After boot, check the new kernel, failed services, Docker, NVIDIA workloads, storage mounts, and remote access.
Do not automatically start or modify another project's containers. For the RS_Server candidate, use its verified
manual `startup_candidate.sh check` and `startup_candidate.sh start`, not the original published trial command.
Verify the login page, a prepared PDF, and authenticated local SMTP capture afterwards. Record failures separately
from a successful container health check. Mailpit messages are temporary and are not retained through a reboot.

A rehearsal that stops and starts the four trial services tests the application's startup order and data retention.
It does not test host boot, SSH recovery, kernel or NVIDIA compatibility, or mount availability after reboot.
Record a real host reboot only after those checks have actually passed.

## Refreshing the image assessment

Scan the exact activated image ID with a recorded scanner version and fresh vulnerability database metadata.
Retain the complete report and its checksum, including findings without corrections. Compare the current report
with the previous assessment; do not reuse yesterday's counts as evidence of a new scan.

If corrections become available, build a new candidate without overwriting the retained image. Repeat runtime,
security, backup, and regression checks before replacing the private trial. Do not install packages interactively
inside the running application container or mix packages from another Debian release to suppress an advisory.
No exclusions, host reboot, image publication, automatic startup, or recurring backup schedule are implied by this
procedure.
