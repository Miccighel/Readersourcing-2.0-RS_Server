# Container security assessment

This record complements application dependency audits. It documents the review of the published `miccighel/rs_server:v2.0.0` image performed on August 21, 2026 for both `linux/amd64` and `linux/arm64`.

Docker Scout reported two critical and two high findings in the Debian `perl-base` package inherited from `ruby:3.4.10-slim`:

| Vulnerability | Affected function | Current assessment |
| --- | --- | --- |
| [CVE-2026-13221](https://security-tracker.debian.org/tracker/CVE-2026-13221) | Compilation of a Perl regular expression with more than 65,535 fixed alternatives | No Perl program or generated Perl regular expression is executed by RS_Server |
| [CVE-2026-12087](https://security-tracker.debian.org/tracker/CVE-2026-12087) | Perl Socket `pack_ip_mreq_source` with an attacker controlled source value | RS_Server does not invoke Perl or this Socket function |
| [CVE-2026-48959](https://security-tracker.debian.org/tracker/CVE-2026-48959) | Named ZIP entry extraction through Perl `IO::Uncompress::Unzip` | PDF preparation does not use the affected Perl module |
| [CVE-2026-48962](https://security-tracker.debian.org/tracker/CVE-2026-48962) | An output glob supplied to Perl `File::GlobMapper` | RS_Server does not invoke Perl or the affected module |

The repository, bundled gems, entrypoint, and RS_PDF invocation contain no Perl execution path. The findings are therefore not known to be reachable through the current application requests. This conclusion is limited to version 2.0.0 and is not a general exception for future images. The vulnerable package remains present, so the findings must stay visible until a corrected Debian package is included.

Debian currently marks the Trixie package used by the image as vulnerable. Rebuilding from the same base does not remove these findings. Replacing the base with a distribution that uses another C library would change the runtime and must not be done without the complete Rails, PostgreSQL, Java, PDF, and browser workflow tests.

Before promoting an image:

1. scan the exact image digest for every published architecture;
2. compare results with this assessment and investigate any new request path or package use;
3. run the application dependency audits and complete test suite;
4. rebuild as soon as the official Ruby base incorporates corrected Debian packages;
5. replace this assessment when the image digest or package graph changes.

The CI workflow runs `bundle-audit check --update` for the locked Ruby dependencies and the Yarn registry audit for the
browser dependencies. Dependabot checks the Bundler, npm, Docker, and GitHub Actions dependency definitions each week.

The `Container scan` GitHub workflow repeats the Docker Scout report every Monday and can also be started manually. It
requires repository secrets named `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`; without them, the workflow explains why the
scan was skipped. The report remains visible even while the documented Debian findings have no stable correction.

The runtime continues to reduce the possible impact through an unprivileged user, a read only root file system, dropped Linux capabilities, a process limit, a memory limit, private publication storage, and no direct database port. These controls reduce impact but do not turn a vulnerable package into a corrected package.
