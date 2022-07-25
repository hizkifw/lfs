VERSION 0.6

lfs-base:
  FROM ubuntu:22.04

  # Set up dependencies
  WORKDIR /src
  RUN apt-get update && apt-get install -y \
      build-essential bash bison yacc python3 gawk texinfo wget aria2; \
      ln -sf /bin/bash /bin/sh

  COPY ./scripts/version-check.sh /src/scripts/version-check.sh
  RUN /src/scripts/version-check.sh

  ENV LFS=/mnt/lfs
  WORKDIR $LFS
  RUN mkdir -p $LFS/sources && \
      chmod a+wt $LFS/sources

  # Download packages
  COPY ./scripts/download-packages.sh /src/scripts/download-packages.sh
  RUN cd $LFS/sources && /src/scripts/download-packages.sh

  # Download patches
  COPY ./scripts/download-patches.sh /src/scripts/download-patches.sh
  RUN cd $LFS/sources && /src/scripts/download-patches.sh

  # Set up directories
  RUN set -e; \
      mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}; \
      for i in bin lib sbin; do \
        ln -sv usr/$i $LFS/$i; \
      done; \
      case $(uname -m) in \
        x86_64) \
          mkdir -pv $LFS/lib64 ;; \
      esac; \
      mkdir -pv $LFS/tools;

  # Create user
  RUN set -ex; \
      groupadd lfs; \
      useradd -s /bin/bash -g lfs -m -k /dev/null lfs; \
      echo "lfs:lfs" | chpasswd; \
      echo "lfs ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers; \
      chown -vR lfs $LFS/*;

lfs-toolchain:
  FROM +lfs-base

  # Run as the user
  USER lfs
  ENV LC_ALL=POSIX \
      LFS_TGT=$(uname -m)-lfs-linux-gnu \
      PATH=$LFS/tools/bin:$PATH \
      CONFIG_SITE=$LFS/usr/share/config.site \
      MAKEFLAGS=-j$(nproc)
  WORKDIR $LFS/sources

  # Build binutils
  RUN set -ex; \
      tar -xf binutils-*.tar.xz; \
      cd binutils-*; \
      mkdir -v build; \
      cd build; \
      ../configure \
          --prefix=$LFS/tools \
          --with-sysroot=$LFS \
          --target=$LFS_TGT \
          --disable-nls \
          --disable-werror; \
      make; \
      make install; \
      cd ..; \
      rm -rf binutils-*


# vi: ft=dockerfile
