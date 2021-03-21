#!/bin/ksh

AUTOINSTALL_PROFILE=./autoinstall_profile
. $AUTOINSTALL_PROFILE

BUILD_DIR=./build

MIRROR=$OPENBSD_MIRROR
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
NECESSARY_FILES[2]=$AUTOINSTALL_PROFILE

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

check_arguments() {
	if [[ $# != 1 ]]; then
		echo "./$(basename $0) HOSTNAME"
		exit 1
	fi
}

template_auto_install_conf() {
	target_file=$BSD_RD_CUSTOM_MOUNT/auto_install.conf
	if [[ ! -f $target_file ]]; then
		echo "$target file does not exist"
		exit 1
	fi

	sed -i "s/{{ HOSTNAME }}/$HOSTNAME/g" $target_file
	sed -i "s/{{ OPENBSD_MIRROR }}/$OPENBSD_MIRROR/g" $target_file
	sed -i "s/{{ ARCH }}/$ARCH/g" $target_file
	sed -i "s/{{ VERSION }}/$VERSION/g" $target_file
	sed -i "s/{{ SHORT_VERSION }}/$SHORT_VERSION/g" $target_file
	sed -i "s/{{ DHCP_INTERFACE }}/$DHCP_INTERFACE/g" $target_file
	sed -i "s/{{ INSTALL_PACKAGES }}/$INSTALL_PACKAGES/g" $target_file
	sed -i "s/{{ ENC_DISK }}/$ENC_DISK/g" $target_file
	sed -i "s/{{ ROOT_DISK }}/$ROOT_DISK/g" $target_file
	sed -i "s|{{ SSH_PUBLIC_KEY }}|$SSH_PUBLIC_KEY|g" $target_file

	cp $target_file $BUILD_DIR/

}

create_directories() {
	for directory in ${BUILD_DIRECTORIES[@]}; do
		[[ ! -d $directory ]] && mkdir -p $directory
	done
}

download_bsd_rd() {
	ftp -o $BSD_RD.gz $BSD_RD_URL
	gunzip $BSD_RD.gz -o $BSD_RD
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
	cp $AUTOINSTALL_PROFILE $SITE_PACKAGE_SRC/
	tar czf $SITE_PACKAGE -C $SITE_PACKAGE_SRC .
}

modify_bsd_rd() {
	cp $BSD_RD $BSD_RD_CUSTOM && \
	rdsetroot -x $BSD_RD_CUSTOM $BSD_RD_CUSTOM_IMAGE && \
	mount_image $BSD_RD_CUSTOM_IMAGE $BSD_RD_CUSTOM_MOUNT && \
	cp $AUTOINSTALL_PROFILE $BSD_RD_CUSTOM_MOUNT/ && \
	cp $AUTO_INSTALL_CONF $BSD_RD_CUSTOM_MOUNT/ && \
	template_auto_install_conf && \
	cat $PROFILE_INJECTION $BSD_RD_CUSTOM_MOUNT/.profile > ./profile.tmp && \
	cp ./profile.tmp $BSD_RD_CUSTOM_MOUNT/.profile && \
	echo "$PASSPHRASE" > $BSD_RD_CUSTOM_MOUNT/passphrase && \
	echo "$DATA_PART_PASSPHRASE" > $BSD_RD_CUSTOM_MOUNT/data_part_passphrase && \
	chown root $BSD_RD_CUSTOM_MOUNT/passphrase && \
	chown root $BSD_RD_CUSTOM_MOUNT/data_part_passphrase && \
	chmod 0600 $BSD_RD_CUSTOM_MOUNT/passphrase && \
	chmod 0600 $BSD_RD_CUSTOM_MOUNT/data_part_passphrase && \
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

check_arguments $@
HOSTNAME="$1"
check_environment 
create_directories 
download_bsd_rd 
build_site_package 
modify_bsd_rd 
create_image
