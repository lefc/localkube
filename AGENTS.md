# Agent Instructions for localkube

## Git

- Before any discovery or change, update `main`. On `main`, run `git pull
  --ff-only origin main`. On another branch, run `git fetch origin
  main:main`. If the update fails, stop and tell the owner.
- Never push to `main`. Make every change on a branch, and merge it into
  `main` through a merge request. No exception applies, not even for a
  one-line change.
- Do not merge a merge request yourself. The owner merges it.
