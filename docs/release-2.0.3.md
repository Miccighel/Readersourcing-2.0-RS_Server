# RS_Server 2.0.3

Version 2.0.3 is prepared for container publication. It is not yet available on Docker Hub. The Compose configuration
and scheduled scan continue to refer to the published `miccighel/rs_server:v2.0.2` image until publication is verified.

## Scope

This patch release uses the locked `resolv` 0.7.2 library for Ruby commands both inside and outside Bundler. Container
preparation removes the older default implementation and its specification. The runtime retains Ruby 3.4.10 and
`json` 2.21.2, including the existing preparation of JSON for commands outside Bundler.

The changes do not introduce a new API contract, database migration, or scoring model. Reader authentication,
publication preparation, and rating references retain their existing behavior. No additional dependency override or
scanner exception is introduced.

## Prepared images

The native `linux/arm64` and emulated `linux/amd64` candidates are the same images recorded in the
[security assessment](security-report-2026-10-12.json) and [production rehearsal](production-check-2026-10-12.json).
Preparation assigns local version tags without rebuilding their contents. The package manifest identifies the source
release; it is used during asset installation and is not copied into the final application image.

Image identities and the additional preparation checks are retained in the
[candidate record](container-candidate-2.0.3.json). The earlier assessment and publication records remain unchanged.
The operating system findings recorded in [security.md](security.md) remain open.

## Publication

Publish the assessed platform images as `v2.0.3-arm64` and `v2.0.3-amd64`, then create `v2.0.3` from those two registry
manifests. Verify that each registry configuration digest matches the prepared image ID and pull both platforms from
the version tag before changing Compose or the scheduled scan. Record the manifest digests and runtime checks in a
separate publication record.

The existing `v2.0.2` and `v2.0.1` tags must retain their current contents. No `latest` tag, merge into `master`, or public
service deployment is part of this preparation.
