#!/bin/bash -e
install -m 755 files/flash_dyson_v10.sh "${ROOTFS_DIR}/home/pi/"
install -m 755 files/openocd "${ROOTFS_DIR}/home/pi/"

install -m 644 files/at91samdXX.cfg  "${ROOTFS_DIR}/home/pi/"
install -m 644 files/swj-dp.tcl  "${ROOTFS_DIR}/home/pi/"

install -m 644 files/V10_BMS.elf "${ROOTFS_DIR}/boot/"

install -m 750 files/rc.local "${ROOTFS_DIR}/etc/"
