set -e

echo 'https://www.linuxfromscratch.org/patches/lfs/11.1/binutils-2.38-lto_fix-1.patch' >> patches.txt
echo '3df11b6123d5bbdb0fc83862a003827a  binutils-2.38-lto_fix-1.patch' >> patches.md5
echo 'https://www.linuxfromscratch.org/patches/lfs/11.1/bzip2-1.0.8-install_docs-1.patch' >> patches.txt
echo '6a5ac7e89b791aae556de0f745916f7f  bzip2-1.0.8-install_docs-1.patch' >> patches.md5
echo 'https://www.linuxfromscratch.org/patches/lfs/11.1/coreutils-9.0-i18n-1.patch' >> patches.txt
echo '1eeba2736dfea013509f9975365e4e32  coreutils-9.0-i18n-1.patch' >> patches.md5
echo 'https://www.linuxfromscratch.org/patches/lfs/11.1/coreutils-9.0-chmod_fix-1.patch' >> patches.txt
echo '4709df88e68279e6ef357aa819ba5b1a  coreutils-9.0-chmod_fix-1.patch' >> patches.md5
echo 'https://www.linuxfromscratch.org/patches/lfs/11.1/glibc-2.35-fhs-1.patch' >> patches.txt
echo '9a5997c3452909b1769918c759eff8a2  glibc-2.35-fhs-1.patch' >> patches.md5
echo 'https://www.linuxfromscratch.org/patches/lfs/11.1/kbd-2.4.0-backspace-1.patch' >> patches.txt
echo 'f75cca16a38da6caa7d52151f7136895  kbd-2.4.0-backspace-1.patch' >> patches.md5
echo 'https://www.linuxfromscratch.org/patches/lfs/11.1/perl-5.34.0-upstream_fixes-1.patch' >> patches.txt
echo 'fb42558b59ed95ee00eb9f1c1c9b8056  perl-5.34.0-upstream_fixes-1.patch' >> patches.md5
echo 'https://www.linuxfromscratch.org/patches/lfs/11.1/sysvinit-3.01-consolidated-1.patch' >> patches.txt
echo '4900322141d493e74020c9cf437b2cdc  sysvinit-3.01-consolidated-1.patch' >> patches.md5

aria2c --input-file patches.txt --max-concurrent-downloads 8
md5sum --check patches.md5
