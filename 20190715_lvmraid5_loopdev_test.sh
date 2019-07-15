#!/bin/bash
#
# LVMRAID lvl 5 test with loop devices
# Copyright (C) 2019  Robert Pilstål
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see <http://www.gnu.org/licenses/>.

# Number of settings options
NUMSETTINGS=1;
# If you require a target list, of minimum 1, otherwise NUMSETTINGS
let NUMREQUIRED=${NUMSETTINGS}+1;
# Start of list
let LISTSTART=${NUMSETTINGS}+1;

# Set default values
if [ -z ${MOUNTDIR} ]; then
  MOUNTDIR=./raid;
fi

# I/O-check and help text
if [ $# -lt ${NUMREQUIRED} ]; then
  echo "USAGE: [MOUNTDIR=${ENV1}] $0 <size> <target1> [<target2> [...]]";
  echo "";
  echo " OPTIONS:";
  echo "  size    - loopback disk size in MB";
  echo "  file(s) - testfiles to copy to raid";
  echo "";
  echo " ENVIRONMENT:";
  echo "  MOUNTDIR - directory to mount raid on";
  echo "";
  echo " EXAMPLES:";
  echo "  # Run on three files, size 300MB, with MOUNTDIR=./raid";
  echo "  MOUNTDIR=./raid $0 300 file1 file2 file3";
  echo "";
  echo "$(basename $0 .sh)  Copyright (C) 2019  Robert Pilstål;"
  echo "This program comes with ABSOLUTELY NO WARRANTY.";
  echo "This is free software, and you are welcome to redistribute it";
  echo "under certain conditions; see supplied General Public License.";
  exit 0;
fi;

# Parse settings
size=$1;
targetlist=${@:$LISTSTART};

let count=${size}*2048

sudo modprobe loop;
sudo losetup -D;
sudo modprobe dm_mod;
sudo vgscan;
sudo vgchange -ay;

for i in 1 2 3 4; do
  dd bs=512 count=${count} if=/dev/zero of=./disk$i status=progress;
  sudo losetup /dev/loop$i ./disk$i;
done

for i in 1 2 3; do sudo pvcreate /dev/loop$i; done
sudo pvdisplay

echo "[Enter] - create volume groop";
read a;

sudo vgcreate LoopVol00 /dev/loop1 /dev/loop2 /dev/loop3;
sudo vgdisplay;

echo "[Enter] - create logical volume raid5";
read a;

sudo lvcreate --type raid5 --name LoopRaid5 -l 100%FREE LoopVol00 /dev/loop1 /dev/loop2 /dev/loop3;
sudo lvdisplay;

echo "[Enter] - create filesystem and mount";
read a;

sudo mkfs.ext4 /dev/LoopVol00/LoopRaid5;
mkdir -p raid;
sudo mount /dev/LoopVol00/LoopRaid5 ${MOUNTDIR};
lsblk;

echo "[Enter] - copy files";
read a;

for target in ${targetlist}; do
  echo cp ${target} ${MOUNTDIR}/;
  sudo cp ${target} ${MOUNTDIR}/;
done;
sudo lvchange --syncaction check /dev/LoopVol00/LoopRaid5;

echo "[Enter] - check diff on files";
read a;

for target in ${targetlist}; do
  echo diff ${target} ${MOUNTDIR}/${target};
  diff ${target} ${MOUNTDIR}/${target};
done;

echo "[Enter] - simulate disk missing failure";
read a;

sudo umount ${MOUNTDIR};
sudo lvchange -a n LoopVol00;
sudo losetup -d /dev/loop1;
sudo lvchange -a y LoopVol00;
sudo lvchange --syncaction check /dev/LoopVol00/LoopRaid5;
sudo vgdisplay;
sudo pvdisplay;

echo "[Enter] - Add simulated repair disk";
read a;

sudo pvcreate /dev/loop4;
sudo vgextend LoopVol00 /dev/loop4;
sudo pvdisplay;

echo "[Enter] - Repair";
read a;

sudo lvconvert --repair /dev/LoopVol00/LoopRaid5 /dev/loop4;
sudo vgreduce --removemissing LoopVol00;
sudo lvchange --syncaction check /dev/LoopVol00/LoopRaid5;

echo "[Enter] - mount";
read a;

sudo mount /dev/LoopVol00/LoopRaid5 ${MOUNTDIR}

echo "[Enter] - check diff on files";
read a;

for target in ${targetlist}; do
  echo diff ${target} ${MOUNTDIR}/${target};
  diff ${target} ${MOUNTDIR}/${target};
done;

echo "[Enter] - cleanup";
read a;

sudo umount ${MOUNTDIR};
sudo lvremove /dev/LoopVol00/LoopRaid5;
sudo vgreduce --removemissing LoopVol00;
sudo vgremove LoopVol00;
for i in 1 2 3 4; do sudo pvremove /dev/loop$i; done
sudo losetup -D;
for i in 1 2 3 4; do rm ./disk$i; done
