# Container security assessment

This record complements application dependency audits. It distinguishes the previous published image, the browser check
image, and the replacement images. Scanner findings describe affected packages present in an image; they do
not, by themselves, establish whether an application request can reach the affected code.

## Follow up of October 15, 2026

The official Debian tracker entries were checked again for the eight high advisories recorded in the candidate.
They still list Trixie as vulnerable, without a corrected version for that release. All findings remain open.
The [follow up record](security-followup-2026-10-15.json) retains the individual references and the new scan completed
at 11:14:14 UTC on October 15 for the exact activated replacement image. The vulnerability database was updated that
day; the Java index remained within its recorded validity period. The complete report checksums were verified and
the detected package inventory and advisory occurrences match the October 14 replacement scan. Counts are unchanged:
eight high operating system advisories, no critical advisories, and no advisories in the application libraries detected
by Trivy. No corrected package versions were reported and no advisory was excluded. This does not approve public exposure.

Host package maintenance is separate from rebuilding the image. The [host maintenance procedure](host-maintenance.md)
covers the shared server interruption, manual candidate startup, and checks required before and after a reboot.
No host package changes, reboot, automatic startup, or recurring backup schedule have been performed by this review.

## Candidate assessment of October 14, 2026

The RS_Server 2.0.4 candidate was assessed on its native Linux amd64 host. The exact image ID is
`sha256:5ced7d8dac465287e415c229126108ebcbfdbf5fb64e6abfe37a0cf46912a35b`; it has not been published. It was
subsequently activated in the private trial after its backup and configuration and data checks passed. The
[candidate record](container-candidate-2.0.4.json) retains its source identity, runtime checks, and activation evidence.

Trivy 0.75.0 scanned an archive of that image with the vulnerability database and Java index updated on October 14.
Database downloads ran separately without the image mounted. Analysis then ran without network access, host Docker
socket, credentials, or trial volumes. No advisory was excluded, including those without a correction.

| Scope | Critical | High | Medium | Low | Unknown |
| --- | ---: | ---: | ---: | ---: | ---: |
| Operating system packages | 0 | 8 | 32 | 47 | 1 |
| Detected application libraries | 0 | 0 | 0 | 0 | 0 |

The operating system result contains 198 package occurrences of 88 distinct advisory identifiers across 100 Debian
packages. Each identifier is counted once per scope, using its highest reported severity. The library inventory
contains 182 distinct Ruby name and version pairs, 19 Java packages, and one `@rails/actiontext` package record.
No known advisory was reported for those detected libraries; this does not establish complete shaded JAR coverage.

The scanner lists no corrected version for its remaining operating system findings. The Debian tracker entries for
the eight high advisories were checked separately: ncurses, ACL, systemd, Perl, and four util-linux advisories remain
vulnerable in Trixie. Corrections listed for another Debian release were not introduced into the candidate. The
[assessment record](security-report-2026-10-14.json) retains each advisory, affected package versions, vendor link,
database dates, and report hashes. These findings remain open without a severity downgrade or exception.

This is an image assessment, not a new package upgrade simulation, a complete reachability review, or approval for
public exposure. The scan itself did not change the private trial's configuration or data. The published 2.0.3 image
and earlier dated records remain unchanged.

The PDF navigation replacement image, `sha256:e52ed41e7a62a5447923ec02f0bef0b61f285232afb58c7bdfc80020381b5ad5`,
was scanned separately at 15:25:56 UTC on October 14. It contains commit `d3f37ea`. Analysis reused the scanner's
database cache, not the preceding report, and retained the same offline analysis restrictions. The full report
checksum was verified and its detected package and advisory occurrences were compared with the initial scan.
The inventories and findings match: the counts above also describe this exact replacement image. All eight high
operating system findings remain open. The [assessment record](security-report-2026-10-14.json) retains the new
image and report hashes and the comparison scope.

Before activation, the operator completed an updated backup of the running candidate,
including data added during the browser checks and its effective image configuration. The same containers returned
to healthy status. The existing backup of version 2.0.3 is retained separately; it does not include those later test
records. The replacement was activated privately at 15:39:44 UTC on October 14, with the backup and activation
fingerprints matching and no change to logical database data or publication files during the update. PDF navigation
was checked in the integrated browser and confirmed manually by the operator in Firefox. These checks do not resolve
the open advisories or approve public exposure.

## Remediation check of October 12, 2026

The published `v2.0.3` contents were checked for available operating system corrections. After refreshing the official
Debian indexes in disposable containers, upgrade simulation reported no upgrades, installations, removals, or packages
kept back on either architecture. No package was installed and no image was rebuilt. The Debian tracker entries listed
in the assessment still report no correction for the corresponding Trixie packages. Versions corrected only in
another distribution were not introduced into this image.

The [remediation record](security-followup-2026-10-12.json) retains the exact image identities, package simulation
results, and vendor references. This was an availability check, not a repeated vulnerability scan. The previous
findings remain open without exclusions. The existing unprivileged user, read only root file system, dropped
capabilities, and no new privileges remain runtime restrictions, not corrections for the affected libraries.

## Publication of October 12, 2026

`miccighel/rs_server:v2.0.3` is available on Docker Hub for `linux/amd64` and `linux/arm64`. Its manifest digest is
`sha256:d35ad4383b7bf9a530390ade8e0b5dee1535d3933eb27174207b242028b38303`. The platform manifest digests are:

- `linux/amd64`: `sha256:e62fe2648bdf003fb1ad839c699a025d62d5196dcf85288eae5f27e7b3157ffc`;
- `linux/arm64`: `sha256:deff56d21c03dd2e4b84be8dcae1601be87ab3f5f45e7e18bf81497d927b5a96`.

The registry configuration digests match the resolver candidates assessed below. Publication retained those exact
contents without rebuilding. Both platforms were pulled from the common version tag. JSON and DNS checks passed
inside and outside Bundler, with `json` 2.21.2 and `resolv` 0.7.2. The 180 tracked application files checked in each
image matched the source, and the private data checks passed. The remaining operating system findings stay open.

The `v2.0.2` and `v2.0.1` manifests were checked again and remain unchanged. No `latest` tag, build provenance, or
SBOM attestation was added, and no public service was deployed. The
[publication record](container-release-2026-10-12.json) retains the digests and completed checks.

## Assessment of October 12, 2026

The published `v2.0.2` platform digests were scanned with Docker Scout 1.25.0 and Trivy 0.75.0. Scout indexed each
registry image. Trivy included operating system packages and detected application libraries, with its Java index
download completed. No advisory was excluded. Counts refer to distinct advisory identifiers within each scope;
the results from different scanners must not be combined.

| Image, each architecture | Scanner and scope | Critical | High | Medium | Low | Unspecified or unknown |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Published v2.0.2 | Scout, registry image | 0 | 2 | 1 | 41 | 2 |
| Published v2.0.2 and local resolver candidates | Trivy, operating system | 0 | 8 | 32 | 47 | 1 |
| Published v2.0.2 | Trivy, detected application libraries | 0 | 1 | 1 | 0 | 0 |
| Local resolver candidates | Trivy, detected application libraries | 0 | 0 | 0 | 0 | 0 |

The default `resolv` 0.7.1 library in the published image is affected by
[CVE-2026-80212 and CVE-2026-80213](https://www.ruby-lang.org/en/news/2026/08/27/multiple-vulnerabilities-in-resolv/).
`PdfFetcher` calls this resolver directly for publication hosts supplied by readers. It therefore uses the affected
library, rather than merely loading it for address patterns. The default gem was absent from the application lockfile,
so a successful lockfile audit did not cover it.

The development branch declares `resolv` through the existing Gemfile and locks it at 0.7.2. Container preparation
uses that same version outside Bundler and removes the old default implementation and specification. The official
Ruby 3.4.10 and Debian Trixie base, the PDF retrieval logic, and the existing JSON preparation remain in place.
The local candidates are:

- `linux/amd64`, `rs-server-collaudo:resolv-amd64`:
  `sha256:d0ee55f12451e47c1bef8292b9a40d0d9b85576d7004a731f1bc7659f57dc901`;
- `linux/arm64`, `rs-server-collaudo:resolv-arm64`:
  `sha256:e277ce744a99348c940245907387577e0e175aae6df58d1183f18b141c509816`.

Both candidates passed JSON and DNS round trips inside and outside Bundler, as an unprivileged user with no network
access and a read only root file system. Checks cover rejection of excessive DNS labels and the absence of permanent
class growth for unknown DNS record types and service parameters. The complete Rails suite passed with 275 tests and
2,192 assertions against a disposable PostgreSQL database. Autoloading and the Ruby and Yarn dependency audits passed.
Trivy reported neither resolver advisory in these exact candidates. These checks preceded their publication as
`v2.0.3`; the affected `v2.0.2` image on Docker Hub remains unchanged, and no public service was deployed.

Trivy identified 19 Java packages in each image without known advisories. A separate OSV query also reported no known
advisories for the 20 library coordinates recorded in the earlier assessment. The bundled RS_PDF JAR remains unchanged.
These checks extend the earlier operating system scan but do not guarantee that every shaded component was identified.

Neither scanner reported a corrected Trixie package for its remaining operating system findings. Debian's tracker was
checked for the critical and high findings: ncurses
([CVE-2025-69720](https://security-tracker.debian.org/tracker/CVE-2025-69720)), systemd
([CVE-2026-16742](https://security-tracker.debian.org/tracker/CVE-2026-16742)), ACL
([CVE-2026-54369](https://security-tracker.debian.org/tracker/CVE-2026-54369)), util-linux
([CVE-2026-76642](https://security-tracker.debian.org/tracker/CVE-2026-76642),
[CVE-2026-78408](https://security-tracker.debian.org/tracker/CVE-2026-78408),
[CVE-2026-78409](https://security-tracker.debian.org/tracker/CVE-2026-78409),
[CVE-2026-78410](https://security-tracker.debian.org/tracker/CVE-2026-78410)), Perl
([CVE-2026-9538](https://security-tracker.debian.org/tracker/CVE-2026-9538)), Cyrus SASL
([CVE-2026-107161](https://security-tracker.debian.org/tracker/CVE-2026-107161)), and zlib
([CVE-2026-85091](https://security-tracker.debian.org/tracker/CVE-2026-85091)). These findings remain open without
exceptions. A corrected package in Debian unstable is not a correction for the Trixie image.

RS_Rate's production audit and 127 tests passed; its 21 Firefox library warnings remain visible. Its complete
development audit still reports `node-forge` and `shell-quote`. `fx-runner` 1.7.0 includes the corrected `shell-quote`,
but the current `web-ext` 10.7.0 release still requires `fx-runner` 1.6.0 exactly. No dependency override or audit
exception was introduced. The two distributed 2.0.1 archives retain all 90 matching assets each.

The [machine readable assessment](security-report-2026-10-12.json) records the exact image identities, database dates,
scanner report hashes, counts, application audits, and completed checks. The dated records below remain unchanged.

The same candidates subsequently passed the isolated production and recovery checks recorded in
[integration.md](integration.md#validation-of-october-12-2026). That rehearsal does not resolve the remaining scanner
findings and did not publish or deploy either candidate.

## Publication of October 9, 2026

`miccighel/rs_server:v2.0.2` is available on Docker Hub for `linux/amd64` and `linux/arm64`. Its manifest digest is
`sha256:83681bfe5a86642a316b1aee4d2f08a93f256cbc9f40ab14471dc9b688e17054`. The platform manifest digests are:

- `linux/amd64`: `sha256:e4638b7da57b4a3125f24a1127614aaef9452ea4d6a12409753860760d2ee895`;
- `linux/arm64`: `sha256:f6390c087d10215d4d0e4f6140d969c92ffeeae340115925d5159e25391403f3`.

The registry configuration digests match the candidate image IDs assessed below. Publication retained those exact
contents without rebuilding. No private environment file, master key, or reader PDF was present in either image.
The previous `v2.0.1` manifest remains unchanged. No `latest` tag was created, and no public service was deployed.
No build provenance or SBOM attestations were attached during this publication. The retained scan reports describe
the matching image contents; their findings and coverage limits remain applicable.

The [publication record](container-release-2026-10-09.json) records the registry digests and completed checks.
Both platforms were pulled from the published version tag. JSON parsing and generation outside Bundler passed
in each downloaded image, with version 2.21.2 matching the lockfile and no older JSON specification installed.

## Assessment of October 9, 2026

The previous `miccighel/rs_server:v2.0.1` multiarchitecture manifest retains digest
`sha256:de59229f1298338306124148f75f45ff371e74fbac5ac23d7e50d30928ec168e`. The platform digests assessed were:

- `linux/amd64`: `sha256:0a3233279e361922e20187d2e42d062d4b0076b9f2351683f3143f54b6c69350`;
- `linux/arm64`: `sha256:139eb3d92ac114bc4c977a25c40cf3371968016b96b596e267c795f4600de88a`.

Docker Scout 1.25.0 obtained the SBOM and provenance attestations for each published platform. Each SBOM contained 308
packages; Scout reported 105 distinct vulnerability advisories affecting 22 packages. The local image assessment
indexed 354 packages and reported 61 distinct advisories affecting 21 packages. Trivy 0.75.0 separately assessed the
operating system packages in both exact platform digests and in the local image `rs-server-collaudo:ui-check`, whose
image ID was `sha256:8d572377dbd2707b03722292ba66533de47e6549824c6fa81198baf80dc98f37`.

The replacement candidates were built from the same Ruby 3.4.10 and Debian Trixie base, with current Debian packages
and the locked JSON library available both inside and outside Bundler:

- `linux/arm64`, `rs-server-collaudo:security-check`:
  `sha256:a645491e0016fc3bc4963813839be5506c605f5d5f9aef2136f2775155dcae4b`;
- `linux/amd64`, `rs-server-collaudo:security-amd64`:
  `sha256:23dd56d72c5d8b9c61c081b4b23fab3f4839c6c4f3202623e3489fc48ba48756`.

Scout indexed 353 packages in each candidate and reported 46 distinct advisories affecting 19 packages. Trivy also
assessed the operating system packages in each candidate. These candidates were subsequently published as `v2.0.2`,
as recorded above.

The table counts distinct advisory identifiers within each report, rather than repeating an advisory for every
affected package. Scout and Trivy use different advisory data and severity selection; their totals must not be
combined or treated as interchangeable. No advisory was excluded.

| Image | Scanner and scope | Critical | High | Medium | Low | Unspecified or unknown |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Published v2.0.1, each architecture | Scout, published SBOM | 6 | 16 | 13 | 63 | 7 |
| Published v2.0.1, each architecture | Trivy, operating system only | 3 | 25 | 58 | 57 | 3 |
| Browser check image | Scout, local SBOM | 0 | 4 | 4 | 51 | 2 |
| Browser check image | Trivy, operating system only | 0 | 11 | 39 | 49 | 3 |
| Published v2.0.2, each architecture | Scout, matching local SBOM | 0 | 2 | 1 | 41 | 2 |
| Published v2.0.2, each architecture | Trivy, operating system only | 0 | 8 | 30 | 47 | 1 |

The [machine readable assessment](security-report-2026-10-09.json) records image identities, per-package occurrence
counts, distinct advisory counts, critical and high findings, application audit results, and hashes of the full
scanner reports. It is a summary, not a replacement for the full scanner output.

Corrected Debian packages are now available for several findings. In particular:

- `perl-base` 5.40.1-6+deb13u1 corrects the three Perl advisories classified as critical by Trivy in the published
  image: [CVE-2026-13221](https://security-tracker.debian.org/tracker/CVE-2026-13221),
  [CVE-2026-42496](https://security-tracker.debian.org/tracker/CVE-2026-42496), and
  [CVE-2026-8376](https://security-tracker.debian.org/tracker/CVE-2026-8376). This package is present in the browser check
  image and both candidates;
- OpenSSL 3.5.7-1~deb13u3 corrects
  [CVE-2026-75804](https://security-tracker.debian.org/tracker/CVE-2026-75804) and
  [CVE-2026-84782](https://security-tracker.debian.org/tracker/CVE-2026-84782);
- PCRE2 10.46-1~deb13u3 corrects
  [CVE-2026-103111](https://security-tracker.debian.org/tracker/CVE-2026-103111).

The browser check image still contains OpenSSL 3.5.7-1~deb13u2 and PCRE2 10.46-1~deb13u2. Both replacement candidates
contain the corrected versions above, together with the current Debian updates. Trivy reported no available corrected
version for the remaining operating system findings in either candidate. These findings remain open, without
exceptions. The earlier Perl reachability review does not cover the additional packages or advisories.

Scout also reported the Ruby `json` 2.9.1 package in the published and browser check SBOMs for
[CVE-2026-54696](https://github.com/ruby/json/releases/tag/v2.19.9), corrected in 2.19.9. The current lockfile and running
local Rails application use 2.21.2 through Bundler. Ruby commands outside Bundler still load the affected default gem
2.9.1 in the browser check image. Both replacement candidates use the compiled, locked version 2.21.2 for those commands
as well. Image preparation removes the old default specification, Ruby implementation, and native extensions, rather
than removing scanner metadata alone. Runtime checks verified JSON parsing and generation outside Bundler on both
architectures; Scout no longer reported this application finding in either candidate. Dependency declarations are
unchanged. The affected library remains present in the unchanged `v2.0.1` and browser check images.

The complete Rails suite passed against a disposable PostgreSQL database. Readiness, production configuration,
restored PDF downloads, rating references, extraction, and logout passed in both candidate images, with `amd64`
running under emulation. Database fingerprints and all restored PDF pairs were unchanged. These HTTP checks do not
repeat every browser scenario recorded earlier. The results are recorded in
[integration.md](integration.md#container-validation). Publication followed these checks using the same image IDs.

### Application audits and coverage

The current Ruby lockfile passed `bundle-audit check --update`. The server's complete Yarn dependency audit and
RS_Rate's production dependency audit also passed. RS_Rate's full development audit failed on the documented
`node-forge` and `shell-quote` advisories; neither is copied into the distributed extension archives, and neither is
excluded from the audit. `fx-runner` requires the affected `shell-quote` version exactly, so that dependency awaits a
parent package update without an override.

An [OSV batch query](https://google.github.io/osv.dev/api/) reported no known advisories for the 20 identified Maven
and Kotlin library coordinates in the bundled RS_PDF JAR. Its SHA-256 was
`2a98fbcdecdcad30d0cc1c3f3faccf2588ef5c4d9092dbece9248b561a879317`, matching the JAR in the running local image. This
check covers those exact library versions; it is not a complete scan of the Java runtime or every possible shaded
component.

The local Scout assessment completed after sufficient host disk space became available. Trivy's assessment remains
limited to operating system packages; its separate Java database download was stopped because of insufficient space.
The identified Java libraries were assessed through the OSV query described above. These checks complement one
another, but do not establish that every affected component is reachable or that every possible component was
identified. No finding was excluded, and the recovery backup was retained.

## Assessment of August 24, 2026

The earlier review assessed the same published image for both `linux/amd64` and `linux/arm64`. The results below are
retained as a dated review of the application paths considered at that time, not as the current complete finding list.

Docker Scout reported two critical and two high findings in the Debian `perl-base` package inherited from `ruby:3.4.10-slim`:

| Vulnerability | Affected function | Assessment at that date |
| --- | --- | --- |
| [CVE-2026-13221](https://security-tracker.debian.org/tracker/CVE-2026-13221) | Compilation of a Perl regular expression with more than 65,535 fixed alternatives | No Perl program or generated Perl regular expression is executed by RS_Server |
| [CVE-2026-12087](https://security-tracker.debian.org/tracker/CVE-2026-12087) | Perl Socket `pack_ip_mreq_source` with an attacker controlled source value | RS_Server does not invoke Perl or this Socket function |
| [CVE-2026-48959](https://security-tracker.debian.org/tracker/CVE-2026-48959) | Named ZIP entry extraction through Perl `IO::Uncompress::Unzip` | PDF preparation does not use the affected Perl module |
| [CVE-2026-48962](https://security-tracker.debian.org/tracker/CVE-2026-48962) | An output glob supplied to Perl `File::GlobMapper` | RS_Server does not invoke Perl or the affected module |

The reviewed repository, bundled gems, entrypoint, and RS_PDF invocation contained no Perl execution path. The findings
were therefore not known to be reachable through the reviewed application requests. This conclusion is limited to
version 2.0.1 and is not a general exception for other findings or future images. The vulnerable package remains present
in that published image, so the findings must stay visible until a corrected Debian package is included.

At that date, a corrected Trixie package had not been identified. The October assessment records the corrections now
available. Replacing the base with a distribution that uses another C library would change the runtime and must not
be done without the complete Rails, PostgreSQL, Java, PDF, and browser workflow tests.

## Image promotion and recurring checks

Before promoting an image:

1. scan the exact image digest for every published architecture;
2. compare results with this assessment and investigate any new request path or package use;
3. run the application dependency audits and complete test suite;
4. refresh the official Ruby base and install corrected packages from the same Debian distribution;
5. replace this assessment when the image digest or package graph changes.

The CI workflow runs `bundle-audit check --update` for the locked Ruby dependencies and the Yarn registry audit for the
browser dependencies on pushes to `codex/development`. These checks are distinct from the periodic configurations below.

The `Container scan` workflow also starts on every push to `codex/development`. It checks the published `v2.0.3` image
by its immutable manifest digest, with separate jobs for `linux/amd64` and `linux/arm64`. It does not build or publish an
image, and it does not scan the unpublished source changes in that push. A newer push cancels an older scan of the same
branch. The Scout report and job summary distinguish a completed scan from one that could not run.

The Dependabot configuration requests weekly updates for the Bundler, npm, Docker, and GitHub Actions dependency
definitions. The `Container scan` workflow requests a Docker Scout report every Monday at 04:30 UTC and declares a
manual trigger. Both configurations are present only on `codex/development`. The repository's default branch remains
`master`, which contains neither configuration. The configured weekly updates and scheduled scans are therefore not
currently active. GitHub requires the [Dependabot configuration](https://docs.github.com/en/code-security/concepts/supply-chain-security/about-the-dependabot-yml-file#where-to-store-the-dependabotyml-file)
and the [scheduled workflow](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)
on the default branch. The standard manual workflow entry also requires that branch to contain the workflow.

The Scout workflow requires repository secrets named `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`; without them, the job
fails explicitly before scanning. This failure must not be treated as a vulnerability assessment. When run, its report
includes critical and high findings with available corrections as well as those without a corrected version. It does
not exclude individual advisories, and findings do
not make the workflow fail. A successful workflow alone is not evidence of an image without known vulnerabilities.

The runtime continues to reduce the possible impact through an unprivileged user, a read only root file system, dropped Linux capabilities, a process limit, a memory limit, private publication storage, and no direct database port. These controls reduce impact but do not turn a vulnerable package into a corrected package.
