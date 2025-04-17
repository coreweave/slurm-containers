ARG PARENT_IMAGE=ubuntu:22.04
# Slurm version can be release version (ex. 22.05.7) or full git commit sha
ARG SLURM_VERSION=24.11.5
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG PYXIS_VERSION=0.20.0
ARG ENROOT_VERSION=3.5.0
ARG LIBJWT_VERSION=1.17.2
ARG KUBECTL_VERSION=1.29.9
# version 4 for Ubuntu 20.04
# version 5 for Ubuntu 22.04
ARG LIBJSON_VERSION=5
# pmix for Ubuntu 20.04
# pmix2 for Ubuntu 22.04
ARG SLURM_PMIX_VERSION=pmix2
ARG LIBNSSCACHE_VERSION=0.21
# NSSCACHE_VERSION points to a commit fixing an occasionally incorrect assumption about a
# `modifyTimestamp` field being present in responses.
ARG NSSCACHE_VERSION=v0.1.0
# This is currently only used to find the `dist-packages` location for the `nsscache` installation
# TODO (SUNK-948): Do this dynamically
ARG PYTHON_VERSION=3.10
# This needs to match the `nsscache.nsscacheConfig.default.files_dir` setting in the values
ARG NSSCACHE_FILES_DIR="/etc/nsscache"

FROM $PARENT_IMAGE AS builder

ARG LIBJSON_VERSION
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update && \
  apt-get -qq install -y --no-install-recommends \
  adcli \
  autoconf \
  automake \
  autotools-dev \
  build-essential \
  bzip2 \
  ca-certificates \
  curl \
  dialog \
  environment-modules \
  git \
  gettext-base \
  gnupg \
  gpg \
  hwloc \
  iputils-ping \
  krb5-user \
  less \
  libcurl4-gnutls-dev \
  libdb-dev \
  libdbus-1-dev \
  libgnutls28-dev \
  libhttp-parser-dev \
  libhttp-parser2.9 \
  libhwloc-dev \
  libjansson-dev \
  libjson-c${LIBJSON_VERSION} \
  libjson-c-dev \
  libldap2-dev \
  liblua5.3-dev \
  liblz4-dev \
  libmunge-dev \
  libmysqlclient-dev \
  libnss-db \
  libnss-sss \
  libnuma-dev \
  libnuma1 \
  libpam-cap \
  libpam-modules \
  libpam-modules-bin \
  libpam-runtime \
  libpam-sss \
  libpam0g \
  libpam0g-dev \
  libpci-dev \
  libpmix-dev \
  libreadline-dev \
  libsasl2-dev \
  libsecret-1-0 \
  libssl-dev \
  libsubunit0 \
  libtool \
  libyaml-0-2 \
  libyaml-dev \
  linux-headers-generic-hwe-$(cat /etc/os-release | grep -oP "(?<=VERSION_ID=\").*(?=\")") \
  lua-sec \
  lua5.3 \
  lua5.3-dev \
  munge \
  net-tools \
  numactl \
  pip \
  python3-dev \
  pkg-config \
  realmd \
  tini \
  unzip \
  xz-utils

# Build libjwt
FROM builder AS libjwt-builder
ARG LIBJWT_VERSION
WORKDIR /build
RUN cd /build && \
  curl --fail --show-error --silent --location \
  --remote-name https://github.com/benmcollins/libjwt/releases/download/v${LIBJWT_VERSION}/libjwt-${LIBJWT_VERSION}.tar.bz2 && \
  tar -xvf libjwt-${LIBJWT_VERSION}.tar.bz2 && \
  cd libjwt-${LIBJWT_VERSION} && \
  autoreconf -fi && \
  ./configure --disable-doxygen-doc --disable-dependency-tracking --without-examples --prefix=/build/libjwt-install/ && \
  make && \
  make install

FROM builder AS slurm-builder
# Slum version can be release version (ex. 22.05.7) or full git commit sha
ARG SLURM_VERSION
WORKDIR /build
COPY build/getSlurm.sh .
RUN ./getSlurm.sh

# Install libjwt
ARG LIBJWT_VERSION
COPY --from=libjwt-builder /build/libjwt-install/include/jwt.h /usr/local/include/jwt.h
# Copying entire directory to preserve symlinks.
COPY --from=libjwt-builder /build/libjwt-install/lib/ /usr/local/lib/

# Apply any patches
COPY patches/ patches/
RUN find /build/patches -type f -name *.patch -print0 | \
  sort -z | \
  xargs -t -0 -r -n 1 patch -p1 -d slurm-$SLURM_VERSION -i
# Build Slurm
ARG SLURM_PMIX_VERSION
WORKDIR /build/slurm-$SLURM_VERSION
RUN arch=$(uname -m) && \
  ./configure --prefix=/usr --libdir=/usr/lib/${arch}-linux-gnu --sysconfdir=/etc/slurm \
  --enable-pam --with-pam_dir=/usr/lib/${arch}-linux-gnu/security \
  --without-hdf5 --disable-glibtest --disable-gtktest \
  --with-pmix=/usr/lib/${arch}-linux-gnu/$SLURM_PMIX_VERSION \
  --with-json=yes --with-yaml=yes --with-http-parser=yes --with-jwt=/usr/local/ --with-bpf=yes
COPY build/Makefile.docs doc/Makefile

RUN mkdir /build/slurm-$SLURM_VERSION/INSTALLDIR && \
  make -j $(nproc) && \
  make -j $(nproc) contrib && \
  make install DESTDIR=/build/slurm-$SLURM_VERSION/INSTALLDIR && \
  make install-contrib DESTDIR=/build/slurm-$SLURM_VERSION/INSTALLDIR

## Install pyxis
## Requires enroot version 3.1.0
## Requires spank.h from deployed slurm version
FROM builder AS pyxis-builder
ARG PYXIS_VERSION
ARG SLURM_VERSION
COPY --from=slurm-builder /build/slurm-$SLURM_VERSION/INSTALLDIR/usr/include/slurm /usr/include/slurm
WORKDIR /build
RUN cd /build && \
  curl --fail --show-error --silent --location --remote-header-name \
  --remote-name https://github.com/NVIDIA/pyxis/archive/refs/tags/v${PYXIS_VERSION}.tar.gz && \
  tar -xf pyxis-${PYXIS_VERSION}.tar.gz && \
  mkdir -p /build/pyxis-${PYXIS_VERSION}/INSTALLDIR && \
  cd /build/pyxis-${PYXIS_VERSION} && \
  make -j $(nproc) install DESTDIR=/build/pyxis-${PYXIS_VERSION}/INSTALLDIR

FROM builder AS libnvidia
# Stage libnvidia-container repo for enroot dependencies (e.g. nvidia-container-cli)
RUN curl --fail --show-error --silent --location https://nvidia.github.io/libnvidia-container/gpgkey | \
  gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
  curl --fail --show-error --silent --location https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Stage enroot
FROM builder AS enroot
ARG ENROOT_VERSION
WORKDIR /build
RUN arch=$(dpkg --print-architecture) && \
  curl --fail --show-error --silent --location \
  --remote-name https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot-hardened_${ENROOT_VERSION}-1_${arch}.deb \
  --remote-name https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot-hardened+caps_${ENROOT_VERSION}-1_${arch}.deb

# Stage s6-overlay
FROM builder AS s6-overlay
ARG S6_OVERLAY_VERSION
WORKDIR /build
RUN arch=$(uname -m) && \
  cd /tmp && \
  curl --fail --show-error --silent --location \
  --remote-name https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz  \
  --remote-name https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${arch}.tar.xz && \
  tar -C /build -xpf /tmp/s6-overlay-noarch.tar.xz && \
  tar -C /build -xpf /tmp/s6-overlay-${arch}.tar.xz

FROM builder as libnss-cache
ARG LIBNSSCACHE_VERSION
WORKDIR /build
RUN cd /build && \
  git clone https://github.com/google/libnss-cache.git && \
  cd libnss-cache && \
  git checkout version/${LIBNSSCACHE_VERSION} && \
  make install

FROM builder as nsscache
ARG NSSCACHE_VERSION
WORKDIR /build
# Patch default shell from empty string to configurable value in `ldap_default_shell` in nsscahe.conf
RUN cd /build && \
  git clone https://github.com/coreweave/nsscache.git && \
  cd nsscache/ && \
  git checkout ${NSSCACHE_VERSION} && \
  pip install --upgrade pip && \
  pip install -r requirements.txt && \
  pip install .

# Actual container artifact
FROM $PARENT_IMAGE AS controller

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update && \
  apt-get -qq install -y --no-install-recommends \
  ca-certificates

COPY --from=libnvidia /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
COPY --from=libnvidia /etc/apt/sources.list.d/nvidia-container-toolkit.list /etc/apt/sources.list.d/nvidia-container-toolkit.list

ARG MUNGE_USER=400
ARG SLURM_USER=401

RUN addgroup --gid $MUNGE_USER munge && \
  useradd munge -u $MUNGE_USER -g $MUNGE_USER -s /usr/sbin/nologin && \
  addgroup --gid $SLURM_USER slurm && \
  useradd slurm -u $SLURM_USER -g $SLURM_USER -s /usr/sbin/nologin

# Runtime deps
# /build/slurm-23.02.7/MYINSTALLDIR/usr# find bin sbin -type f -exec ldd {} \; | awk '/=>/ { print $1 }' | sort | uniq | xargs -I% -n1 dpkg-query --search  % | awk 'NF == 2 { split($1, a, ":"); print a[1]}'  | sort | uniq
# dpkg-query: no path found matching pattern *libslurmfull.so*
# libaudit1
# libc6
# libcap-ng0
# libhttp-parser2.9
# libhwloc15
# libltdl7
# liblua5.3-0
# liblz4-1
# libnuma1
# libpam0g
# libreadline8
# libtinfo6
# libudev1

# Install runtime dependencies and libnvidia-container for enroot dependencies (e.g. nvidia-container-cli)
ARG LIBJSON_VERSION
RUN apt-get -qq update && \
  apt-get -qq install -y --no-install-recommends \
  libaudit1 \
  libcap-ng0 \
  libhttp-parser2.9 \
  libhwloc15 \
  libltdl7 \
  liblua5.3-0 \
  liblz4-1 \
  libnuma1 \
  libpam-cap \
  libpam-modules \
  libpam-modules-bin \
  libpam-runtime \
  libpam0g \
  libreadline8 \
  libtinfo6 \
  libudev1 \
  # Missed with above command
  libjson-c${LIBJSON_VERSION} \
  libmysqlclient-dev \
  libpmix-dev \
  libyaml-0-2 \
  munge \
  environment-modules \
  # Needed for init.sh script
  gettext-base \
  openssh-server \
  # libnvidia-container
  nvidia-container-toolkit=1.17.6-1 \
  nvidia-container-toolkit-base=1.17.6-1 \
  libnvidia-container-tools=1.17.6-1 \
  libnvidia-container1=1.17.6-1 \
  # Enroot
  bash \
  curl \
  jq  \
  parallel \
  squashfs-tools \
  zstd \
  bsdmainutils \
  pigz \
  # Enroot caps
  libcap2-bin \
  # SSSD
  adcli \
  krb5-user \
  libnss-sss \
  libpam-krb5 \
  libpam-sss \
  realmd \
  sssd-ad \
  sssd-ldap \
  sssd-tools \
  # Misc
  bash-completion \
  binutils \
  gdb \
  htop \
  inetutils-ping \
  inetutils-traceroute \
  net-tools \
  numactl \
  sudo \
  wget && \
  apt-get -qq clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install libjwt
COPY --from=libjwt-builder /build/libjwt-install/lib/ /usr/local/lib/

RUN arch=$(uname -m) && \
  ln -s /usr/lib/${arch}-linux-gnu/libnvidia-ml.so.1 /usr/lib/${arch}-linux-gnu/libnvidia-ml.so

# SSH Configuration
RUN echo "HostKey /opt/sunk/etc/ssh/ssh_host_rsa_key" >> /etc/ssh/sshd_config && \
  echo "HostKey /opt/sunk/etc/ssh/ssh_host_ed25519_key" >> /etc/ssh/sshd_config && \
  echo "HostKey /opt/sunk/etc/ssh/ssh_host_dsa_key" >> /etc/ssh/sshd_config && \
  echo "HostKey /opt/sunk/etc/ssh/ssh_host_ecdsa_key" >> /etc/ssh/sshd_config && \
  sed -i 's/#\(StrictModes \).*/\1no/g' /etc/ssh/sshd_config && \
  echo "AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys" >> /etc/ssh/sshd_config && \
  echo "AuthorizedKeysCommandUser root" >> /etc/ssh/sshd_config && \
  echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config && \
  echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config && \
  echo "StreamLocalBindUnlink yes" >> /etc/ssh/sshd_config && \
  sed -i 's/[ #]\(.*StrictHostKeyChecking \).*/ \1no/g' /etc/ssh/ssh_config && \
  echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config && \
  mkdir -p /var/run/sshd

# Install enroot
ARG ENROOT_VERSION
COPY --from=enroot /build/ /tmp/enroot/
RUN arch=$(dpkg --print-architecture) && \
  apt-get install -y \
  /tmp/enroot/enroot-hardened_${ENROOT_VERSION}-1_${arch}.deb \
  /tmp/enroot/enroot-hardened+caps_${ENROOT_VERSION}-1_${arch}.deb && \
  sed -i 's/"--ldconfig=@$(command -v ldconfig.real || command -v ldconfig)"//' /etc/enroot/hooks.d/98-nvidia.sh && \
  rm -rf /tmp/enroot

# Install s6-overlay
COPY --from=s6-overlay /build/ /

# Install Pyxis
## Note, we dont need to link the plugstack.conf since it is managed
## by the helm chart ( compute.pyxis.enabled )
ARG PYXIS_VERSION
COPY --from=pyxis-builder /build/pyxis-${PYXIS_VERSION}/INSTALLDIR/ /

# Install Slurm
ARG SLURM_VERSION
COPY --from=slurm-builder /build/slurm-$SLURM_VERSION/INSTALLDIR/ /
RUN ldconfig

# Add slurm bash completion
COPY --chown=root:root --chmod=644 --from=slurm-builder /build/slurm-$SLURM_VERSION/contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh

# Install kubectl
ARG KUBECTL_VERSION
RUN cd /tmp && \
  arch=$(dpkg --print-architecture) && \
  curl --fail --show-error --silent --location \
  --remote-name "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" && \
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install libnss-cache
COPY --from=libnss-cache /usr/lib/libnss_cache* /usr/lib

RUN rm /lib/libnss_cache.so.2 && \
  ln -sf /lib/libnss_cache.so.2.0 /lib/libnss_cache.so.2

# Install nsscache
ARG PYTHON_VERSION
COPY --from=nsscache /usr/local/bin/nsscache /usr/local/bin/nsscache
COPY --from=nsscache /usr/local/lib/python${PYTHON_VERSION}/dist-packages /usr/local/lib/python${PYTHON_VERSION}/dist-packages

# Add symlinks for /etc/*.cache -> ${NSSCACHE_FILES_DIR}/*.cache
ARG NSSCACHE_FILES_DIR
RUN for f in passwd group shadow sshkey; do ln -s ${NSSCACHE_FILES_DIR}/$f.cache /etc/$f.cache; done

RUN mkdir -p \
  /run/munge \
  /var/spool \
  /etc/munge \
  /var/lib/munge \
  /var/log/munge && \
  chown -R munge:munge \
  /etc/munge \
  /var/lib/munge \
  /var/log/munge \
  /run/munge && \
  rm /etc/munge/munge.key

COPY ./bin /usr/share/sunk/bin

RUN echo "/usr/share/sunk/bin/reboot.sh" > /usr/bin/reboot && \
  chmod +x /usr/bin/reboot

RUN echo "/usr/share/sunk/bin/reboot.sh" > /usr/sbin/reboot && \
  chmod +x /usr/sbin/reboot

RUN /usr/share/sunk/bin/env-to-modulefile.sh

# Add sudoer groups to nopasswd
RUN sed -i -e 's/%admin ALL=(ALL) ALL/%admin ALL=NOPASSWD:ALL/g' /etc/sudoers && \
  sed -i -e 's/%sudo ALL=(ALL:ALL) ALL/%sudo ALL=NOPASSWD:ALL/g' /etc/sudoers

# Set umask to read/write for user and group but noone else
RUN echo "umask u=rwx,g=rwx,o=" > /etc/profile.d/set-umask-for-all-users.sh

ADD bashrc /tmp/bashrc
RUN cat /tmp/bashrc >> /etc/bash.bashrc && rm /tmp/bashrc

# Enable automatic homedir creation for LDAP auth
RUN pam-auth-update --enable mkhomedir

# When going through s6's init as the entrypoint, container environment variables
# are not passed through to what is run, like the `slurmd` process. Setting this
# makes it so the environment variables are not cleared preventing you from
# having to use /command/with-contenv in your s6 scripts.
ENV S6_KEEP_ENV=1

ENTRYPOINT ["/init"]
