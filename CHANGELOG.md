# Changelog

This changelog keeps track of work items that have been completed and are ready to be shipped in the next release.

To learn more, we recommend reading [this document](README.md).

## History

- [Unreleased](#unreleased)
- [v2.0.2](#v202)
- [v2.0.1](#v201)
- [v2.0.0](#v200)
- [v1.0.0](#v100)

## Unreleased / under development

### New
- Refactoring of resources installations
- Path-aware definitions evaluations

### Other
- Unbundling of required dependencies to aim for a more standalone install

## v2.0.2

### Fix
- Fix cluster install bug from an wrongly expanded variable (continued)

## v2.0.1

### Fix
- Fix cluster install bug from an wrongly expanded variable

## v2.0.0

### New
- General codebase refactoring
- Refactoring of functions and install mechanisms
- General bug fixing
- Support for Docker Engine
- New interactive interface
- Added support for kubernetes cluster reapplication
- Added support for docker/podman on-demand image building

### Other
- Implementation of Strimzi
- Implementation of Mayfly

## v1.0.0

### New
- Initial implementation of `localkube` with `minikube` via `podman` on `containerd` Stack, to provision a sandboxed kubernetes cluster.
