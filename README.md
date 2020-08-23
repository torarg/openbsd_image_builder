# build an openbsd autoinstall image

## requirements
- openbsd host
- auto_install.conf
- site.tgz

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
