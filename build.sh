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

function set_nl_vars() {
	if [[ ! -v NL_ARCH ]]; then
		echo "\$NL_ARCH must be set. choices are: i686, x86_64"
		exit 1
	fi

	NL_KARCH=$NL_ARCH
	if [[ "i686" = "$NL_KARCH" ]]; then
		NL_KARCH=x86
	fi
	
	NL_MUSL=${NL_ARCH}-buildroot-linux-musl
}

PATH=${PWD}/crosscompile/buildroot-${BUILDROOT_VERSION}/output/host/usr/bin:${PATH}
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
	set_nl_vars;
	pushd kernel/linux-${KERNEL_VERSION}
		cp ../../kernel.${NL_ARCH}.config ./.config
		time make -j ${JOBS}
		cp arch/${NL_KARCH}/boot/bzImage ../
	popd
}

build_buildroot() {
	set_nl_vars;
	pushd crosscompile/buildroot-${BUILDROOT_VERSION}
		cp ../../buildroot.${NL_ARCH}.config ./.config
		time make toolchain -j ${JOBS}
	popd
}

build_busybox() {
	set_nl_vars;
	pushd bin/busybox-${BUSYBOX_VERSION}
		make defconfig
		time make CONFIG_STATIC=y CROSS_COMPILE=${NL_MUSL}- busybox -j ${JOBS}
		cp busybox ../
	popd
}

build_bash() {
	set_nl_vars;
	pushd bin/bash-${BASH_VERSION}
		autoconf -f
		CC=${NL_MUSL}-gcc CFLAGS="-Os -static" ./configure --without-bash-malloc
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
	set_nl_vars;
	${NL_MUSL}-gcc -static sethostname.c -o bin/sethostname
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
	set_nl_vars;
	mkdir -p iso/boot/grub/
	cp kernel/bzImage iso/boot/
	cp kernel/initramfs.cpio.gz iso/boot/
	cp grub.cfg iso/boot/grub/
	grub2-mkrescue -o neofetch-linux-${NL_ARCH}.iso iso/
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

clean_kernel() {
	pushd kernel/linux-${KERNEL_VERSION}
		make clean
	popd
}

clean_buildroot() {
	pushd crosscompile/buildroot-${BUILDROOT_VERSION}
		make clean
	popd
}

clean_busybox() {
	pushd bin/busybox-${BUSYBOX_VERSION}
		make clean
	popd
	rm -r bin/busybox
}

clean_bash() {
	pushd bin/bash-${BASH_VERSION}
		make clean
	popd
	rm -r bin/bash
}

clean_iso() {
	rm -rf iso
}

clean_sethostname() {
	rm -rf bin/sethostname
}

clean_neofetch() {
	rm -rf bin/neofetch
}

clean_initramfs() {
	rm -rf kernel/initramfs
}

clean() {
	clean_kernel;
	clean_buildroot;
	clean_busybox;
	clean_bash;
	clean_iso;
	clean_neofetch;
	clean_sethostname;
	clean_initramfs;
}

clean_full() {
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
	echo "		clean_kernel clean_buildroot clean_busybox clean_bash clean_iso clean_neofetch"
	echo "		clean_sethostname clean_initramfs"
	echo "	clean_full"
	exit 1
fi

$1;
