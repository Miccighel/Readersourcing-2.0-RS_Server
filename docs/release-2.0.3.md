# RS_Server 2.0.3

Version 2.0.3 is available on Docker Hub for `linux/amd64` and `linux/arm64`. The Compose configuration and scheduled
scan refer to `miccighel/rs_server:v2.0.3`. Registry digests and completed checks are retained in the
[publication record](container-release-2026-10-12.json).

## Scope

This patch release uses the locked `resolv` 0.7.2 library for Ruby commands both inside and outside Bundler. Container
preparation removes the older default implementation and its specification. The runtime retains Ruby 3.4.10 and
`json` 2.21.2, including the existing preparation of JSON for commands outside Bundler.

The changes do not introduce a new API contract, database migration, or scoring model. Reader authentication,
publication preparation, and rating references retain their existing behavior. No additional dependency override or
scanner exception is introduced.

## Images

The native `linux/arm64` and emulated `linux/amd64` candidates are the same images recorded in the
[security assessment](security-report-2026-10-12.json) and [production rehearsal](production-check-2026-10-12.json).
Preparation assigned local version tags without rebuilding their contents. The package manifest identifies the source
release; it is used during asset installation and is not copied into the final application image.

Image identities and the checks completed before publication are retained in the
[candidate record](container-candidate-2.0.3.json). The earlier assessment and publication records remain unchanged.
The operating system findings recorded in [security.md](security.md) remain open.

## Publication

The assessed platform images were published as `v2.0.3-arm64` and `v2.0.3-amd64`. The common `v2.0.3` tag contains
those two registry manifests. Each registry configuration digest matches its prepared image ID. Both platforms were
pulled from the common version tag, and runtime and application file checks passed before Compose and the scheduled
scan were updated.

The existing `v2.0.2` and `v2.0.1` manifests remain unchanged. No `latest` tag was created, no merge into `master` was
performed, and no public service was deployed.
