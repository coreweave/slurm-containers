# enroot Patches

This file explains the patches in this directory, why they exist.

## Table of Contents

- [enroot Patches](#enroot-patches)
  - [Table of Contents](#table-of-contents)
  - [0001-fix-pid](#0001-fix-pid)

## 0001-fix-pid

This is a patch for the enroot runtime script to correctly identify the PID of a running container
by handling cases where the path prefix differs. This involves modifying the `runtime::list`
function in `runtime.sh` to strip the expected prefix and match against known container names as
suffixes. This patch aims to resolve issues with the `--container-name:exec` flag and the
`enroot list -f` command, which currently break due to incorrect PID identification.

