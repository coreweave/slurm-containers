#!/bin/bash

# SPDX-FileCopyrightText: © 2025 CoreWeave, Inc. <sunk@coreweave.com>



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
