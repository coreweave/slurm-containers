# Slurm Containers

This repository contains files for building the SUNK Slurm container image, which is the core container image used for deploying Slurm on Kubernetes with SUNK.

## Overview

The Slurm container image is built as a multi-stage build that creates a fully functional Slurm installation along with supporting tools needed for integrating Slurm with Kubernetes. The image includes:

- Slurm workload manager (from source, with custom patches)
- NVIDIA Pyxis plugin for container execution inside Slurm jobs
- NVIDIA Enroot for unprivileged container execution
- MUNGE authentication system
- SSSD for directory service integration (LDAP/AD)
- S6 overlay for process supervision
- Various utilities and tools for cluster management

## Key Components

### Base Configuration

The default image is built from Ubuntu 22.04 with Slurm 24.11.3. The image supports multiple user IDs:

- MUNGE runs as UID/GID 400
- Slurm runs as UID/GID 401

### Custom Patches

Several patches are applied to Slurm to enhance functionality for Kubernetes integration:

- `0001-max-server-threads.patch`: Increases maximum server threads for better scalability
- `0002-agent-thread.patch`: Thread handling improvements
- `0003-revert-no-dynamic-sort.patch`: Reverts sorting changes for compatibility
- `0004-rest-get-node-default-flags.patch`: Fixes REST API node information access
- `0005-allow-persistent-none.patch`: Enables persistent storage configurations
- `0006-allow-all-topology.patch`: Improves topology handling in degraded states
- `0007-cgroup-v2.patch`: Fixes process assignment issues with cgroup v2
- `0008-job-skip-ids.patch`: Enhances job ID management
- `0009-allowgaps.patch`: Implements functionality for allowing gaps in job allocation

See the [patches/README.md](./patches/README.md) for detailed explanations of each patch.

### Key Features

- **JWT Authentication**: Built with JWT support for secure API access
- **Container Support**: Includes NVIDIA Pyxis/Enroot for running containerized workloads
- **Directory Services**: Configured for SSSD integration with LDAP/AD authentication
- **SSH Access**: Preconfigured for secure shell access to compute nodes
- **Process Management**: Uses S6 overlay for robust service supervision

## Building the Image

The image is built using Docker multi-stage builds. Key build arguments include:

- `PARENT_IMAGE`: Base image (default: ubuntu:22.04)
- `SLURM_VERSION`: Slurm version to build (default: 24.11.3)
- `S6_OVERLAY_VERSION`: S6 overlay version (default: 3.2.0.2)
- `PYXIS_VERSION`: NVIDIA Pyxis version (default: 0.20.0)
- `ENROOT_VERSION`: NVIDIA Enroot version (default: 3.5.0)
- `LIBJWT_VERSION`: JWT library version (default: 1.17.2)
- `KUBECTL_VERSION`: Kubectl version (default: 1.29.9)

### Build Command

```bash
docker buildx build -t sunk/slurm:latest .
```
