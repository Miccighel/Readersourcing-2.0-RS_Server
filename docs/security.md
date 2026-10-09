# Container security assessment

This record complements application dependency audits. It distinguishes the previous published image, the browser check
image, and the replacement images. Scanner findings describe affected packages present in an image; they do
not, by themselves, establish whether an application request can reach the affected code.

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
browser dependencies. Dependabot checks the Bundler, npm, Docker, and GitHub Actions dependency definitions each week.

The `Container scan` GitHub workflow repeats the Docker Scout report every Monday and can also be started manually. It
requires repository secrets named `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`; without them, the workflow explains why the
scan was skipped. The report includes findings with available corrections as well as those without a corrected
version; this assessment does not exclude them from the scan.

The runtime continues to reduce the possible impact through an unprivileged user, a read only root file system, dropped Linux capabilities, a process limit, a memory limit, private publication storage, and no direct database port. These controls reduce impact but do not turn a vulnerable package into a corrected package.
