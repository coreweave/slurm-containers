# Slurm Containers

This repository contains files for building the SUNK Slurm container image, which is the core container image used for deploying Slurm on Kubernetes with SUNK.

## Overview

The Slurm container image builds in multiple stages, and creates a fully functional Slurm installation along with supporting tools needed for integrating Slurm with Kubernetes. The image includes:

- Slurm workload manager (from source, with custom patches)
- NVIDIA Pyxis plugin for container execution inside Slurm jobs
- NVIDIA Enroot for unprivileged container execution
- MUNGE authentication system
- SSSD for directory service integration (LDAP/AD)
- S6 overlay for process supervision
- Various utilities and tools for cluster management

## Key Components

### Base Configuration

The default image is built from Ubuntu 22.04 with Slurm 25.05.3. The image supports multiple user IDs:

- MUNGE runs as UID/GID 400
- Slurm runs as UID/GID 401

### Custom Patches

Several patches are applied to Slurm to enhance functionality for Kubernetes integration.
See the [images/patches/slurm/README.md](./images/patches/slurm/README.md) for the full list and detailed explanations of each patch.

Additionally, there are other custom patches in the [images/patches](./images/patches) directory.
There are enroot patches at [images/patches/enroot/README.md](./images/patches/enroot/README.md)

### Key Features

- **JWT Authentication**: Built with JWT support for secure API access
- **Container Support**: Includes NVIDIA Pyxis/Enroot for running containerized workloads
- **Directory Services**: Configured for SSSD integration with LDAP/AD authentication
- **SSH Access**: Preconfigured for secure shell access to compute nodes
- **Process Management**: Uses S6 overlay for robust service supervision

## Building the Image

The image is built using Docker multi-stage builds. Key build arguments include:

- `PARENT_IMAGE`: Base image (default: ubuntu:22.04)
- `SLURM_VERSION`: Slurm version to build (default: 25.05.3)
- `S6_OVERLAY_VERSION`: S6 overlay version (default: 3.2.0.2)
- `PYXIS_VERSION`: NVIDIA Pyxis version (default: 0.20.0)
- `ENROOT_VERSION`: NVIDIA Enroot version (default: 3.5.0)
- `LIBJWT_VERSION`: JWT library version (default: 1.17.2)
- `KUBECTL_VERSION`: Kubectl version (default: 1.29.9)

### Build Command

```bash
docker buildx build -t sunk/slurm:latest images
```

### Licensing

Slurm Containers (including its source code and any other data and materials)
is distributed subject to GPL-2.0 as noted in [LICENSE](./LICENSE) contained in
this repository. For questions about use or licensing please contact us via
GitHub issues.

Slurm Containers and the artifacts generated are also distributed with certain
third-party code. That code is from the projects and subject to the respective
licenses listed below.

#### [github.com/SchedMD/slurm](https://github.com/SchedMD/slurm)

- **Copyright**: 2002-2025 [Lawrence Livermore National Laboratory & others](https://github.com/SchedMD/slurm/commits/master/DISCLAIMER)
- **License**: GPL-2.0-or-later and other licenses for specific files
- **License File**: [https://github.com/SchedMD/slurm/blob/master/COPYING](https://github.com/SchedMD/slurm/blob/master/COPYING)

#### [github.com/NVIDIA/enroot](https://github.com/NVIDIA/enroot)

- **Copyright**: 2018-2025 NVIDIA
- **License**: Apache-2.0 with DCO (previously relicensed from BSD-3)
- **License File**: [https://github.com/NVIDIA/enroot/blob/main/LICENSE](https://github.com/NVIDIA/enroot/blob/main/LICENSE)
