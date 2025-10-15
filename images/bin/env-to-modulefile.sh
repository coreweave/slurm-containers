#!/bin/bash

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




cat >/usr/share/modules/modulefiles/image-defaults <<EOL
#%Module1.0#####################################################################
##
## $PARENT_IMAGE modulefile
##
proc ModulesHelp { } {
        global version

        puts stderr "\tSets up environment for $PARENT_IMAGE\n"
}

module-whatis   "sets up environment from included environment variables in $PARENT_IMAGE"

append-path     PATH                   "${PATH}"
append-path     LIBRARY_PATH           "${LIBRARY_PATH}"
append-path     LD_LIBRARY_PATH        "${LD_LIBRARY_PATH}"
append-path     PKG_CONFIG_PATH        "${PKG_CONFIG_PATH}"
append-path     CPATH                  "${CPATH}"
append-path     CUDA_HOME              "${CUDA_HOME}"
append-path     PYTHONPATH             "${PYTHONPATH}"

append-path     NVM_BIN                "${NVM_BIN}"
append-path     NVM_INC                "${NVM_INC}"

setenv          PYTORCH_HOME           "${PYTORCH_HOME}"
setenv          PYTORCH_VERSION        "${PYTORCH_VERSION}"
setenv          NCCL_VERSION           "${NCCL_VERSION}"
setenv          CUDA_VERSION           "${CUDA_VERSION}"
setenv          NV_CUDA_LIB_VERSION    "${NV_CUDA_LIB_VERSION}"
setenv          NVARCH                 "${NVARCH}"
setenv          NV_CUDA_COMPAT_PACKAGE "${NV_CUDA_COMPAT_PACKAGE}"
setenv          NV_NVPROF_VERSION      "${NV_NVPROF_VERSION}"
setenv          OPENMPI_VERSION        "${OPENMPI_VERSION}"
setenv          OPAL_PREFIX            "${OPAL_PREFIX}"

conflict cuda
EOL
