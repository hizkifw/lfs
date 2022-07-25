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
      chown -vR lfs $LFS/* /src/scripts;

lfs-toolchain:
  FROM +lfs-base

  # Run as the user
  USER lfs
  WORKDIR $LFS/sources
  COPY ./scripts/env.sh /src/scripts/env.sh

  # 5.2. Binutils-2.38 - Pass 1
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf binutils-2.38.tar.xz; \
      cd binutils-2.38; \
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
      cd ../..; \
      rm -rf binutils-2.38

  # 5.3. GCC-11.2.0 - Pass 1
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf gcc-11.2.0.tar.xz; \
      cd gcc-11.2.0; \
      \
      tar -xf ../mpfr-4.1.0.tar.xz; \
      mv -v mpfr-4.1.0 mpfr; \
      tar -xf ../gmp-6.2.1.tar.xz; \
      mv -v gmp-6.2.1 gmp; \
      tar -xf ../mpc-1.2.1.tar.gz; \
      mv -v mpc-1.2.1 mpc; \
      \
      case $(uname -m) in \
        x86_64) \
          sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;; \
      esac; \
      \
      mkdir -v build; \
      cd build; \
      ../configure                \
        --target=$LFS_TGT         \
        --prefix=$LFS/tools       \
        --with-glibc-version=2.35 \
        --with-sysroot=$LFS       \
        --with-newlib             \
        --without-headers         \
        --enable-initfini-array   \
        --disable-nls             \
        --disable-shared          \
        --disable-multilib        \
        --disable-decimal-float   \
        --disable-threads         \
        --disable-libatomic       \
        --disable-libgomp         \
        --disable-libquadmath     \
        --disable-libssp          \
        --disable-libvtv          \
        --disable-libstdcxx       \
        --enable-languages=c,c++; \
      make; \
      make install; \
      cd ..; \
      cat gcc/limitx.h gcc/glimits.h gcc/limity.h \
        > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h; \
      cd ..; \
      rm -rf gcc-11.2.0;

  # 5.4. Linux-5.16.9 API Headers
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf linux-5.16.9.tar.xz; \
      cd linux-5.16.9; \
      make mrproper; \
      make headers; \
      find usr/include -name '.*' -delete; \
      rm usr/include/Makefile; \
      cp -rv usr/include $LFS/usr; \
      cd ..; \
      rm -rf linux-5.16.9;

  # 5.5. Glibc-2.35
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf glibc-2.35.tar.xz; \
      cd glibc-2.35; \
      case $(uname -m) in \
          i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3; \
          ;; \
          x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64; \
                  ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3; \
          ;; \
      esac; \
      patch -Np1 -i ../glibc-2.35-fhs-1.patch; \
      mkdir -v build; \
      cd build; \
      echo "rootsbindir=/usr/sbin" > configparms; \
      ../configure                         \
        --prefix=/usr                      \
        --host=$LFS_TGT                    \
        --build=$(../scripts/config.guess) \
        --enable-kernel=3.2                \
        --with-headers=$LFS/usr/include    \
        libc_cv_slibdir=/usr/lib; \
      make; \
      make DESTDIR=$LFS install; \
      sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd; \
      \
      echo 'int main(){}' > dummy.c; \
      $LFS_TGT-gcc dummy.c; \
      readelf -l a.out | grep -q '/ld-linux' || exit 1; \
      rm -v dummy.c a.out; \
      \
      $LFS/tools/libexec/gcc/$LFS_TGT/11.2.0/install-tools/mkheaders; \
      cd ../..; \
      rm -rf glibc-2.35;

  # 5.6. Libstdc++ from GCC-11.2.0, Pass 1
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf gcc-11.2.0.tar.xz; \
      cd gcc-11.2.0; \
      mkdir -v build; \
      cd build; \
      ../libstdc++-v3/configure         \
        --host=$LFS_TGT                 \
        --build=$(../config.guess)      \
        --prefix=/usr                   \
        --disable-multilib              \
        --disable-nls                   \
        --disable-libstdcxx-pch         \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/11.2.0; \
      make; \
      make DESTDIR=$LFS install; \
      cd ../..; \
      rm -rf gcc-11.2.0;


# vi: ft=dockerfile
