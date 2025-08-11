#!/usr/bin/env bash

# SPDX-FileCopyrightText: © 2025 CoreWeave, Inc. <sunk@coreweave.com>


# If script throws errors about not being a valid archive, the SLURM_VERSION is likely bad, or there
# was a download error.
echo "Getting Slurm ${SLURM_VERSION}"
if test "${SLURM_VERSION#*.}" != "$SLURM_VERSION"; then
  curl -O https://download.schedmd.com/slurm/slurm-$SLURM_VERSION.tar.bz2 && \
  tar -jxvf slurm-$SLURM_VERSION.tar.bz2
else
  curl -OL https://github.com/SchedMD/slurm/archive/$SLURM_VERSION.tar.gz && \
  tar -xvf $SLURM_VERSION.tar.gz
fi
