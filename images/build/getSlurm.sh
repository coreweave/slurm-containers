#!/usr/bin/env bash

# (c) 2025 by CoreWeave, Inc.
#
# This file is part of Slurm Containers.
#
# Slurm Containers is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# Slurm Containers is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Slurm Containers; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA



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
