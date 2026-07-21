#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 CoreWeave, Inc.
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-PackageName: slurm-containers

# If script throws errors about not being a valid archive, the SLURM_VERSION is likely bad, or there
# was a download error.
echo "Getting Slurm ${SLURM_VERSION}"
if test "${SLURM_VERSION#*.}" != "$SLURM_VERSION"; then
  # Download the release tarball asset from GitHub instead of download.schedmd.com. The asset
  # name stays dotted (slurm-<version>.tar.bz2), matching the original schedmd.com tarball.
  SLURM_TAG="slurm-$(echo "$SLURM_VERSION" | tr '.' '-')"
  # Stable releases get a -1 tag revision (25.11.6 -> slurm-25-11-6-1); pre-releases like
  # 26.05.0-0rc1 already carry their own suffix, so only append -1 when there is no dash.
  if [[ "$SLURM_VERSION" != *-* ]]; then
    SLURM_TAG="$SLURM_TAG-1"
  fi
  curl -fLO https://github.com/SchedMD/slurm/releases/download/$SLURM_TAG/slurm-$SLURM_VERSION.tar.bz2 && \
  tar -jxvf slurm-$SLURM_VERSION.tar.bz2
else
  curl -OL https://github.com/SchedMD/slurm/archive/$SLURM_VERSION.tar.gz && \
  tar -xvf $SLURM_VERSION.tar.gz
fi
