#!/bin/ksh

USAGE="./build_autoinstall_image.sh VERSION SHORT_VERSION ARCH"

[[ $# != 3 ]] && echo $USAGE && exit 1


MIRROR=ftp.hostserver.de
VERSION="$1"
SHORT_VERSION="$2"
ARCH="$3"

BUILD_DIR=./build

BSD_RD=$BUILD_DIR/bsd.rd
BSD_RD_CUSTOM=$BUILD_DIR/bsd.rd.custom
BSD_RD_CUSTOM_MOUNT=$BUILD_DIR/bsd.rd.custom.mount
BSD_RD_CUSTOM_IMAGE=$BUILD_DIR/bsd.rd.custom.img
BSD_RD_URL=https://$MIRROR/pub/OpenBSD/$VERSION/$ARCH/bsd.rd

IMAGE=$BUILD_DIR/autoinstall$SHORT_VERSION.fs
IMAGE_MOUNT=$BUILD_DIR/autoinstall$SHORT_VERSION.fs.mount
IMAGE_GZ=$IMAGE.gz
IMAGE_SIZE=15M

VND=vnd0

BUILD_DIRECTORIES[0]=$BUILD_DIR
BUILD_DIRECTORIES[1]=$BSD_RD_CUSTOM_MOUNT
BUILD_DIRECTORIES[2]=$IMAGE_MOUNT

AUTO_INSTALL_CONF=./auto_install.conf
SITE_PACKAGE=$BUILD_DIR/site.tgz
SITE_PACKAGE_SRC=./site_package
PROFILE_INJECTION=./bsd_rd_profile_injection

NECESSARY_FILES[0]=$AUTO_INSTALL_CONF
NECESSARY_FILES[1]=$PROFILE_INJECTION

NECESSARY_DIRS[0]=$SITE_PACKAGE_SRC


check_environment() {
	for file in ${NECESSARY_FILES[@]}; do
		if [[ ! -f $file ]]; then
			echo "Error: $file not found"
			exit 1
		fi
	done

	for dir in ${NECESSARY_DIRS[@]}; do
		if [[ ! -d $dir ]]; then
			echo "Error: $dir not found"
			exit 1
		fi
	done

	[[ -d $BUILD_DIR ]] && rm -r $BUILD_DIR
	if vnconfig -l $VND | grep 'not in use'; then
		echo "Using $VND for image creation."
	else
		echo "Error: $VND in use."
		exit 1
	fi

}

create_directories() {
	for directory in ${BUILD_DIRECTORIES[@]}; do
		[[ ! -d $directory ]] && mkdir -p $directory
	done
}

download_bsd_rd() {
	ftp -o $BSD_RD $BSD_RD_URL
	[[ $? != 0 ]] && echo "Failed to download: $BSD_RD_URL" && exit 1
}

mount_image() {
	image=$1
	mount=$2
	vnconfig $VND $image
	mount /dev/${VND}a $mount
}

umount_image() {
	mount=$1
	umount $mount
	vnconfig -u $VND
}

build_site_package () {
	tar czf $SITE_PACKAGE -C $SITE_PACKAGE_SRC .
}

modify_bsd_rd() {
	cp $BSD_RD $BSD_RD_CUSTOM && \
	rdsetroot -x $BSD_RD_CUSTOM $BSD_RD_CUSTOM_IMAGE && \
	mount_image $BSD_RD_CUSTOM_IMAGE $BSD_RD_CUSTOM_MOUNT && \
	cp $AUTO_INSTALL_CONF $BSD_RD_CUSTOM_MOUNT/ && \
	cat $PROFILE_INJECTION $BSD_RD_CUSTOM_MOUNT/.profile > ./profile.tmp && \
	cp ./profile.tmp $BSD_RD_CUSTOM_MOUNT/.profile && \
	rm ./profile.tmp && \
	mkdir -p $BSD_RD_CUSTOM_MOUNT/$VERSION/$ARCH && \
	cp $SITE_PACKAGE $BSD_RD_CUSTOM_MOUNT/$VERSION/$ARCH/site$SHORT_VERSION.tgz && \
	touch $BSD_RD_CUSTOM_MOUNT/$VERSION/$ARCH/INSTALL.$ARCH && \
	cd $BSD_RD_CUSTOM_MOUNT/$VERSION/$ARCH/ && \
	ls -l > index.txt && \
	cd - && \
	umount_image $BSD_RD_CUSTOM_MOUNT && \
	rdsetroot $BSD_RD_CUSTOM $BSD_RD_CUSTOM_IMAGE
}

create_image() {
	[[ -f $IMAGE ]] && rm $IMAGE
	vmctl create -s $IMAGE_SIZE $IMAGE && \
	vnconfig $VND $IMAGE && \
	fdisk -iy $VND && \
	disklabel -w -A $VND && \
	newfs /dev/r${VND}a && \
	vnconfig -u $VND && \
	mount_image $IMAGE $IMAGE_MOUNT &&
	installboot -r $IMAGE_MOUNT $VND /usr/mdec/biosboot /usr/mdec/boot && \
	gzip -c9n $BSD_RD_CUSTOM > $IMAGE_MOUNT/bsd && \
	umount_image $IMAGE_MOUNT && \
	gzip -c9n $IMAGE > $IMAGE_GZ
}

check_environment 
create_directories 
download_bsd_rd 
build_site_package 
modify_bsd_rd 
create_image
