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

the current default setup creates a ready to install openbsd image which will
do an autoinstall on boot. the root device will be encrypted either by passphrase or keydisk.

## requirements
- openbsd host
- auto_install.conf
- site_package/
- autoinstall_profile

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

1. edit ``autoinstall_profile`` according to your needs

2. run ``./create_autoinstall_image.sh`` as ``root``
