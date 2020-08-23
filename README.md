# build an openbsd autoinstall image

## description
a small helper script to create a bootable openbsd disk image
with customized ramdisk kernel which contains:

	- a small profile hack to reinitialize disk at boot
	- an auto_install.conf file
	- a siteXX.tgz package for initial python installation

the goal of this project is to create a a small openbsd boot medium
which can be copied to a host's root disk from a rescue system to
prepare the host for an openbsd autoinstall.

please be aware that the defaults in this project are only tested with hetzner cloud's
linux64 rescue system. 

also the auto_install.conf currently contains a ssh pubkey you will probably need to change

## requirements
- openbsd host
- auto_install.conf
- site_package/

## steps

- download bsd.rd
- modify bsd.rd
  - add auto_install.conf to bsd.rd
  - add site.tgz to bsd.rd
  - modify .profile to rerun disk initialization on install

- create empty disk image
- initialize disk image
  - fdisk -iy
  - disklabel -A

- copy bsd.rd to disk image
- make disk image bootable

## usage

./create_autoinstall_image.sh VERSION ARCH
