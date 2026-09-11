# enroot Patches

This file explains the patches in this directory, why they exist.

As noted in the top-level slurm-containers README, the patches are
released under the same terms as the parent source files of `enroot`, and the
specific licenses of each of those files should be consulted by users who
require validation.

## Table of Contents

- [enroot Patches](#enroot-patches)
  - [Table of Contents](#table-of-contents)
  - [0001-fix-pid](#0001-fix-pid)
  - [0002-cwcr-lota](#0002-cwcr-lota)

## 0001-fix-pid

This is a patch for the enroot runtime script to correctly identify the PID of a running container
by handling cases where the path prefix differs. This involves modifying the `runtime::list`
function in `runtime.sh` to strip the expected prefix and match against known container names as
suffixes. This patch aims to resolve issues with the `--container-name:exec` flag and the
`enroot list -f` command, which currently break due to incorrect PID identification.

## 0002-cwcr-lota

This patch adds the `X-Storage-Upstream: Lota` request header when Enroot imports images from
`cwcr.io` registries. It also permits HTTP for those requests so Enroot can follow CWCR's
presigned redirects to CWLOTA while keeping the initial registry request on HTTPS. Other
registries and Enroot authentication requests retain the upstream protocol restrictions.
