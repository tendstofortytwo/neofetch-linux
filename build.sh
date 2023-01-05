#!/usr/bin/env bash

set -euo pipefail

KERNEL_MAJOR=6
KERNEL_MINOR=1
KERNEL_PATCH=2
KERNEL_VERSION=${KERNEL_MAJOR}.${KERNEL_MINOR}.${KERNEL_PATCH}
BUILDROOT_VERSION=2022.11
BUSYBOX_VERSION=1.36.0
BASH_VERSION=5.1.16
NEOFETCH_VERSION=7.1.0

PATH=${PWD}/crosscompile/buildroot-${BUILDROOT_VERSION}/output/host/usr/bin:${PATH}
MUSL=x86_64-buildroot-linux-musl
JOBS=$(($(nproc) - 1))

fetch_kernel() {
	mkdir -p kernel
	pushd kernel
		wget https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_VERSION}.tar.xz
		tar xf linux-${KERNEL_VERSION}.tar.xz
	popd
}

fetch_buildroot() {
	mkdir -p crosscompile
	pushd crosscompile
		wget https://buildroot.uclibc.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz
		tar xf buildroot-${BUILDROOT_VERSION}.tar.gz
	popd
}

fetch_busybox() {
	mkdir -p bin
	pushd bin
		wget https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
		tar xf busybox-${BUSYBOX_VERSION}.tar.bz2
	popd
}

fetch_bash() {
	mkdir -p bin
	pushd bin
		wget https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz
		tar xf bash-${BASH_VERSION}.tar.gz
	popd
}

fetch_neofetch() {
	mkdir -p bin
	pushd bin
		wget https://github.com/dylanaraps/neofetch/archive/refs/tags/${NEOFETCH_VERSION}.tar.gz
		tar xf ${NEOFETCH_VERSION}.tar.gz
	popd
}

fetch() {
	fetch_kernel;
	fetch_buildroot;
	fetch_busybox;
	fetch_bash;
	fetch_neofetch;
}

build_kernel() {
	pushd kernel/linux-${KERNEL_VERSION}
		cp ../../kernel.config ./.config
		time make -j ${JOBS}
		cp arch/x86_64/boot/bzImage ../
	popd
}

build_buildroot() {
	pushd crosscompile/buildroot-${BUILDROOT_VERSION}
		cp ../../buildroot.config ./.config
		time make toolchain -j ${JOBS}
	popd
}

build_busybox() {
	pushd bin/busybox-${BUSYBOX_VERSION}
		make defconfig
		time make CONFIG_STATIC=y CROSS_COMPILE=${MUSL}- busybox -j ${JOBS}
		cp busybox ../
	popd
}

build_bash() {
	pushd bin/bash-${BASH_VERSION}
		autoconf -f
		CC=${MUSL}-gcc CFLAGS="-Os -static" ./configure --without-bash-malloc
		make -j ${JOBS}
		cp bash ../
	popd
}

build_neofetch() {
	pushd bin/neofetch-${NEOFETCH_VERSION}
		cp neofetch ../
	popd
}

build_sethostname() {
	${MUSL}-gcc -static sethostname.c -o bin/sethostname
}

build_initramfs() {
	mkdir -p kernel/initramfs
	pushd kernel/initramfs
		mkdir -p {bin,dev,proc,sbin,usr/bin,usr/sbin}
		cp ../../init .
		cp ../../bin/busybox bin/
		cp ../../bin/neofetch usr/bin/
		cp ../../bin/bash usr/bin/
		cp ../../bin/sethostname usr/bin/
		find . -print0 | cpio --null --create --verbose --format=newc | gzip --best > ../initramfs.cpio.gz
	popd
}

build_iso() {
	mkdir -p iso/boot/grub/
	cp kernel/bzImage iso/boot/
	cp kernel/initramfs.cpio.gz iso/boot/
	cp grub.cfg iso/boot/grub/
	grub2-mkrescue -o neofetch-linux.iso iso/
}

build() {
	build_kernel;
	build_buildroot;
	build_busybox;
	build_bash;
	build_sethostname;
	build_neofetch;
	build_initramfs;
	build_iso;
}

clean() {
	rm -rf bin crosscompile iso kernel
}

if [[ $# -ne 1 ]]; then
	echo "usage: $0 <cmd>"
	echo "where cmd is one of:"
	echo "	fetch"
	echo "		fetch_kernel fetch_buildroot fetch_busybox fetch_bash fetch_neofetch"
	echo "	build"
	echo "		build_kernel build_buildroot build_busybox build_bash build_sethostname"
	echo "		build_neofetch build_initramfs build_iso"
	echo "	clean"
	exit 1
fi

$1;
