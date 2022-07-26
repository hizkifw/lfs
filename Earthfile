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

  # 6.2. M4-1.4.19
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf m4-1.4.19.tar.xz; \
      cd m4-1.4.19; \
      ./configure --prefix=/usr            \
        --host=$LFS_TGT                    \
        --build=$(build-aux/config.guess); \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf m4-1.4.19;

  # 6.3. Ncurses-6.3
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf ncurses-6.3.tar.gz; \
      cd ncurses-6.3; \
      sed -i s/mawk//g configure; \
      mkdir build; \
      pushd build; \
        ../configure; \
        make -C include; \
        make -C progs tic; \
      popd; \
      ./configure --prefix=/usr      \
        --host=$LFS_TGT              \
        --build=$(./config.guess)    \
        --mandir=/usr/share/man      \
        --with-manpage-format=normal \
        --with-shared                \
        --without-debug              \
        --without-ada                \
        --without-normal             \
        --disable-stripping          \
        --enable-widec; \
      make; \
      make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install; \
      echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so; \
      cd ..; \
      rm -rf ncurses-6.3;

  # 6.4. Bash-5.1.16
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf bash-5.1.16.tar.gz; \
      cd bash-5.1.16; \
      ./configure --prefix=/usr         \
        --build=$(support/config.guess) \
        --host=$LFS_TGT                 \
        --without-bash-malloc; \
      make; \
      make DESTDIR=$LFS install; \
      ln -sv bash $LFS/bin/sh; \
      cd ..; \
      rm -rf bash-5.1.16;

  # 6.5. Coreutils-9.0
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf coreutils-9.0.tar.xz; \
      cd coreutils-9.0; \
      ./configure --prefix=/usr           \
        --host=$LFS_TGT                   \
        --build=$(build-aux/config.guess) \
        --enable-install-program=hostname \
        --enable-no-install-program=kill,uptime; \
      make; \
      make DESTDIR=$LFS install; \
      mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin; \
      mkdir -pv $LFS/usr/share/man/man8; \
      mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8; \
      sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8; \
      cd ..; \
      rm -rf coreutils-9.0.tar.xz;

  # 6.6. Diffutils-3.8
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf diffutils-3.8.tar.xz; \
      cd diffutils-3.8; \
      ./configure --prefix=/usr --host=$LFS_TGT; \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf diffutils-3.8;

  # 6.7. File-5.41
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf file-5.41.tar.gz; \
      pushd file-5.41; \
        mkdir build; \
        pushd build; \
          ../configure \
            --disable-bzlib      \
            --disable-libseccomp \
            --disable-xzlib      \
            --disable-zlib;      \
          make; \
        popd; \
        ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess); \
        make FILE_COMPILE=$(pwd)/build/src/file; \
        make DESTDIR=$LFS install; \
      popd; \
      rm -rf file-5.41;

  # 6.8. Findutils-4.9.0
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf findutils-4.9.0.tar.xz; \
      cd findutils-4.9.0; \
      ./configure --prefix=/usr         \
        --localstatedir=/var/lib/locate \
        --host=$LFS_TGT                 \
        --build=$(build-aux/config.guess); \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf findutils-4.9.0;

  # 6.9. Gawk-5.1.1
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf gawk-5.1.1.tar.xz; \
      cd gawk-5.1.1; \
      sed -i 's/extras//' Makefile.in; \
      ./configure --prefix=/usr   \
        --host=$LFS_TGT           \
        --build=$(build-aux/config.guess); \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf gawk-5.1.1;

  # 6.10. Grep-3.7
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf grep-3.7.tar.xz; \
      cd grep-3.7; \
      ./configure --prefix=/usr --host=$LFS_TGT; \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf grep-3.7;

  # 6.11. Gzip-1.11
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf gzip-1.11.tar.xz; \
      cd gzip-1.11; \
      ./configure --prefix=/usr --host=$LFS_TGT; \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf gzip-1.11;

  # 6.12. Make-4.3
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf make-4.3.tar.gz; \
      cd make-4.3; \
      ./configure --prefix=/usr \
        --without-guile \
        --host=$LFS_TGT \
        --build=$(build-aux/config.guess); \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf make-4.3;

  # 6.13. Patch-2.7.6
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf patch-2.7.6.tar.xz; \
      cd patch-2.7.6; \
      ./configure --prefix=/usr   \
        --host=$LFS_TGT \
        --build=$(build-aux/config.guess); \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf patch-2.7.6;

  # 6.14. Sed-4.8
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf sed-4.8.tar.xz; \
      cd sed-4.8; \
      ./configure --prefix=/usr --host=$LFS_TGT; \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf sed-4.8;

  # 6.15. Tar-1.34
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf tar-1.34.tar.xz; \
      cd tar-1.34; \
      ./configure --prefix=/usr   \
        --host=$LFS_TGT \
        --build=$(build-aux/config.guess); \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf tar-1.34;

  # 6.16. Xz-5.2.5
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf xz-5.2.5.tar.xz; \
      cd xz-5.2.5; \
      ./configure --prefix=/usr           \
        --host=$LFS_TGT                   \
        --build=$(build-aux/config.guess) \
        --disable-static                  \
        --docdir=/usr/share/doc/xz-5.2.5; \
      make; \
      make DESTDIR=$LFS install; \
      cd ..; \
      rm -rf xz-5.2.5;

  # 6.17. Binutils-2.38 - Pass 2
  RUN set -ex; \
      . /src/scripts/env.sh; \
      tar -xf binutils-2.38.tar.xz; \
      cd binutils-2.38; \
      sed '6009s/$add_dir//' -i ltmain.sh; \
      mkdir -v build; \
      cd build; \
      ../configure                 \
        --prefix=/usr              \
        --build=$(../config.guess) \
        --host=$LFS_TGT            \
        --disable-nls              \
        --enable-shared            \
        --disable-werror           \
        --enable-64-bit-bfd;       \
      make; \
      make DESTDIR=$LFS install; \
      cd ../..; \
      rm -rf binutils-2.38;

  # 6.18. GCC-11.2.0 - Pass 2
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
          sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64; \
        ;; \
      esac; \
      mkdir -v build; \
      cd build; \
      mkdir -pv $LFS_TGT/libgcc; \
      ln -s ../../../libgcc/gthr-posix.h $LFS_TGT/libgcc/gthr-default.h; \
      ../configure                 \
        --build=$(../config.guess) \
        --host=$LFS_TGT            \
        --prefix=/usr              \
        CC_FOR_TARGET=$LFS_TGT-gcc \
        --with-build-sysroot=$LFS  \
        --enable-initfini-array    \
        --disable-nls              \
        --disable-multilib         \
        --disable-decimal-float    \
        --disable-libatomic        \
        --disable-libgomp          \
        --disable-libquadmath      \
        --disable-libssp           \
        --disable-libvtv           \
        --disable-libstdcxx        \
        --enable-languages=c,c++;  \
      make; \
      make DESTDIR=$LFS install; \
      ln -sv gcc $LFS/usr/bin/cc; \
      cd ../..; \
      rm -rf gcc-11.2.0;

pre-chroot:
  FROM +lfs-toolchain

  USER root
  RUN set -ex; \
      chown -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools}; \
      case $(uname -m) in \
        x86_64) chown -R root:root $LFS/lib64 ;; \
      esac;

  # 7.3. Preparing Virtual Kernel File Systems
  RUN set -ex; \
      mkdir -pv $LFS/{dev,proc,sys,run}; \
      mknod -m 600 $LFS/dev/console c 5 1; \
      mknod -m 666 $LFS/dev/null c 1 3;

  SAVE ARTIFACT /mnt/lfs

lfs-chroot:
  BUILD +pre-chroot
  FROM scratch

  # Copy the LFS files to the rootfs
  COPY +pre-chroot/lfs /
  ENV PATH=/usr/bin:/usr/sbin \
      HOME=/root
  # When usign a chroot, /dev, /proc, /sys, and /run should be bind-mounted.
  # Since we're using Docker, it's already done for us.
  RUN /bin/ls -alh /dev /proc /sys /run

  # Create the full directory structure
  RUN set -ex; \
      mkdir -pv /{boot,home,mnt,opt,srv}; \
      mkdir -pv /etc/{opt,sysconfig}; \
      mkdir -pv /lib/firmware; \
      mkdir -pv /media/{floppy,cdrom}; \
      mkdir -pv /usr/{,local/}{include,src}; \
      mkdir -pv /usr/local/{bin,lib,sbin}; \
      mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}; \
      mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}; \
      mkdir -pv /usr/{,local/}share/man/man{1..8}; \
      mkdir -pv /var/{cache,local,log,mail,opt,spool}; \
      mkdir -pv /var/lib/{color,misc,locate}; \
      ln -sfv /run /var/run; \
      ln -sfv /run/lock /var/lock; \
      ln -sfv /proc/self/mounts /etc/mtab; \
      install -dv -m 0750 /root; \
      install -dv -m 1777 /tmp /var/tmp;

  # Create essential files
  # /etc/hosts should also be made but since we're using Docker, the file is
  # read-only.
  RUN set -ex; \
      ls -alh /etc/hosts; \
      echo "root:x:0:0:root:/root:/bin/bash" >> /etc/passwd; \
      echo "bin:x:1:1:bin:/dev/null:/usr/bin/false" >> /etc/passwd; \
      echo "daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false" >> /etc/passwd; \
      echo "messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false" >> /etc/passwd; \
      echo "uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false" >> /etc/passwd; \
      echo "nobody:x:99:99:Unprivileged User:/dev/null:/usr/bin/false" >> /etc/passwd; \
      echo "root:x:0:" >> /etc/group; \
      echo "bin:x:1:daemon" >> /etc/group; \
      echo "sys:x:2:" >> /etc/group; \
      echo "kmem:x:3:" >> /etc/group; \
      echo "tape:x:4:" >> /etc/group; \
      echo "tty:x:5:" >> /etc/group; \
      echo "daemon:x:6:" >> /etc/group; \
      echo "floppy:x:7:" >> /etc/group; \
      echo "disk:x:8:" >> /etc/group; \
      echo "lp:x:9:" >> /etc/group; \
      echo "dialout:x:10:" >> /etc/group; \
      echo "audio:x:11:" >> /etc/group; \
      echo "video:x:12:" >> /etc/group; \
      echo "utmp:x:13:" >> /etc/group; \
      echo "usb:x:14:" >> /etc/group; \
      echo "cdrom:x:15:" >> /etc/group; \
      echo "adm:x:16:" >> /etc/group; \
      echo "messagebus:x:18:" >> /etc/group; \
      echo "input:x:24:" >> /etc/group; \
      echo "mail:x:34:" >> /etc/group; \
      echo "kvm:x:61:" >> /etc/group; \
      echo "uuidd:x:80:" >> /etc/group; \
      echo "wheel:x:97:" >> /etc/group; \
      echo "nogroup:x:99:" >> /etc/group; \
      echo "users:x:999:" >> /etc/group;

  # Create a regular user for testing
  RUN set -ex; \
      echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd; \
      echo "tester:x:101:" >> /etc/group; \
      install -o tester -d /home/tester;

  # Initialize log files
  RUN set -ex; \
      touch /var/log/{btmp,lastlog,faillog,wtmp}; \
      chgrp -v utmp /var/log/lastlog; \
      chmod -v 664  /var/log/lastlog; \
      chmod -v 600  /var/log/btmp;

  # 7.7. Libstdc++ from GCC-11.2.0, Pass 2
  RUN set -ex; \
      cd /sources; \
      tar -xf gcc-11.2.0.tar.xz; \
      cd gcc-11.2.0; \
      ln -s gthr-posix.h libgcc/gthr-default.h; \
      mkdir build; \
      cd build; \
      ../libstdc++-v3/configure          \
        CXXFLAGS="-g -O2 -D_GNU_SOURCE"  \
        --prefix=/usr                    \
        --disable-multilib               \
        --disable-nls                    \
        --host=$(uname -m)-lfs-linux-gnu \
        --disable-libstdcxx-pch; \
      make -j$(nproc); \
      make install; \
      cd ../..; \
      rm -rf gcc-11.2.0;

  # 7.8. Gettext-0.21
  RUN set -ex; \
      cd /sources; \
      tar -xf gettext-0.21.tar.xz; \
      cd gettext-0.21; \
      ./configure --disable-shared; \
      make -j$(nproc); \
      cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin; \
      cd ..; \
      rm -rf gettext-0.21;

  # 7.9. Bison-3.8.2
  RUN set -ex; \
      cd /sources; \
      tar -xf bison-3.8.2.tar.xz; \
      cd bison-3.8.2; \
      ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2; \
      make -j$(nproc); \
      make install; \
      cd ..; \
      rm -rf bison-3.8.2;




# vi: ft=dockerfile
