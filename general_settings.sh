#!/bin/bash
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)
# Additional part of the main script 'build_debian_system.sh', that contains all the general settings

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.

# THIS SCRIPT IS ONLY INTENDED FOR THE POGOPLUG V3! CHECK IF YOU REALLY HAVE A MODEL OF THE 3RD SERIES BEFORE USING THIS SCRIPT!

###########################################
##### SETTINGS THAT YOU NEED TO EDIT: #####
###########################################

pogoplug_v3_version="classic" # either 'classic' or 'pro' (the pro features integrated wireless lan, the classic does NOT)

pogoplug_mac_address="00:00:00:00:00:00" # !!!VERY IMPORTANT!!! (YOU NEED TO EDIT THIS!) Without a valid MAC address, your device won't be accessible via LAN

host_os="Ubuntu" # Debian or Ubuntu (YOU NEED TO EDIT THIS!)

output_dir_base="/home/`logname`/pogoplug_v3_emdebian_build" # this is a arbitrary local directory on the development machine, running Ubuntu or Debian, where the script's output files will be placed (YOU NEED TO EDIT THIS!)

root_password="root" # root users password

username="tester"  # Name of the standard (non-root) user for creation on the target emdebian system
user_password="tester" # the users password on the emdebian system

nameserver_addr="192.168.2.1" # "141.82.48.1" (YOU NEED TO EDIT THIS!) Needed for the qemu-environment to work properly.

ip_type="dhcp" # set this either to 'dhcp' (default) or to 'static'

static_ip="192.168.2.100" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

netmask="255.255.255.0" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

gateway_ip="192.168.2.1" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

pogo_hostname="pogoplug-emdebian" # Name that the Emdebian system uses to identify itself on the network

additional_packages="emdebian-archive-keyring samba samba-common mtd-utils udev ntp netbase module-init-tools nano bzip2 unzip zip screen less usbutils psmisc procps dhcp3-client ifupdown iputils-ping wget net-tools ssh hdparm" # List of packages (each seperated by a single space) that get added to the rootfs

module_load_list="mii gmac" # add names of modules (for example wireless, leds ...) here that should be loaded by /etc/modules (list them, seperated by a single blank space)


#############################
##### GENERAL SETTINGS: #####
#############################


if [ "${output_dir_base:(-1):1}" = "/" ]
then
	output_dir="${output_dir_base}build_`date +%s`" # Subdirectory for each build-run, ending with the unified Unix-Timestamp (seconds passed since Jan 01 1970)
else
	output_dir="${output_dir_base}/build_`date +%s`" # Subdirectory for each build-run, ending with the unified Unix-Timestamp (seconds passed since Jan 01 1970)
fi

output_filename="emdebian_rootfs_pogoplug_v3" # base name of the output file (compressed rootfs)

extra_files="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/extra_files/pogoplug_v3_arch_ledcontrol.tar.bz2 http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/extra_files/pogoplug_v3_arch_kernel_modules.tar.bz2" # some extra archives (list seperated by a single blank space!) that get extracted into the rootfs, when done (for example original led control program and original arch linux kernel modules)

debian_mirror_url="http://ftp.uk.debian.org/emdebian/grip" # mirror for debian

debian_target_version="stable-grip" # The version of debian that you want to build (ATM only 'squeeze'/'stable' is supported)

debian_target_repos="main java"  # select which repository parts to enable for apt; ATM possible parts are: 'main debug dev doc java'

qemu_kernel_pkg_path="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/kernels/" # where to get the qemu kernel (local path or web adress)

std_kernel_pkg_path="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/kernels" # where to get the standard kernel (local path or web adress)

qemu_kernel_pkg_name="zImage-qemu.tar.bz2" # qemu kernel file name

std_kernel_pkg_name="3.1.10-pogoplug_v3-nonpro-1.9_1362751903.tar.bz2" # standard kernel file name

tar_format="bz2" # bz2(=bzip2) or gz(=gzip) format for the rootfs-archive, this script creates

work_image_size_MB=512 # size of the temporary image file, in which the installation process is carried out (512MB should be plenty)

apt_prerequisites_debian="debootstrap binfmt-support qemu-user-static qemu qemu-kvm qemu-system parted emdebian-archive-keyring" # packages that need to be installed on a debian system in order to create a emdebian rootfs for the pogoplug

apt_prerequisites_ubuntu="debootstrap binfmt-support qemu qemu-system qemu-kvm qemu-user-static parted emdebian-archive-keyring" # packages that need to be installed on a ubuntu system in order to create a emdebian rootfs for the pogoplug

clean_tmp_files="yes" # delete the temporary files, when the build process is done? yes or no

create_usb_stick="yes" # create a bootable USB-stick after building the rootfs? yes or no

udev_tmpfs_size="3M" # Value for changing the UDEV-daemon's default tmpfs size (default=10M); 3M should be plenty enough for such a small system



#####################################################
##### SETTINGS FOR COMPRESSED SWAPSAPCE IN RAM: #####
#####################################################

# You can use one (and only ONE) of the settings below to potentionally increase performance of you pogoplug under heavy memory load, IF your kernel supports and includes the neaded module!

use_ramzswap="no" # for Kernels 2.6xx only !!! set if you want to use a compressed SWAP space in RAM (can potentionally improve performance)

ramzswap_size_kb="32768" # size of each (there are 2) the ramzswap device in KB(<-- !!!)

ramzswap_kernel_module_name="ramzswap" # name of the ramzswap kernel module (could have a different name on newer kernel versions)


use_zram="no" # for Kernels 3.xx only !!! set if you want to use a compressed SWAP space in RAM (can potentionally improve performance)

zram_size_byte="33554432" # size of each (there are 2) the zram device in Bytes(<-- !!!)

zram_kernel_module_name="zram" # name of the ramzswap kernel module (could have a different name on newer kernel versions)


vm_swappiness="75" # Setting for general kernel RAM swappiness: With RAMzswap and low RAM, a high number (like 100) could be good. Default in Linux mostly is 60.



#########################
##### LED SETTINGS: #####
#########################

## PLEASE COMMENT OR UNCOMMENT THE SETTINGS FITTING YOUR KERNEL !!!

## LED settings for newer, patched kernels (mostly kernel versions 2.6.31-14 or even 3.1.10 or newer)
#led_boot_green="echo default-on>/sys/class/leds/status\:health\:green/trigger;"
#led_reboot_amber="echo default-on>\/sys\/class\/leds\/status\\\:fault\\\:orange\/trigger;" # needs to have escaped slahes and backslashes for the neccessary sed operations
#led_halt_orange="echo none>\/sys\/class\/leds\/status\\\:health\\\:green\/trigger;echo default-on>\/sys\/class\/leds\/status\\\:fault\\\:orange\/trigger;" # needs to have escaped slahes and backslashes for the neccessary sed operations

## LED settings for old original kernels (mostly kernel version 2.6.31-6)
led_boot_green="/sbin/proled unlock;/sbin/proled green"
led_reboot_amber="\/sbin\/proled off;\/sbin\/proled amber" # needs to have escaped slahes and backslashes for the neccessary sed operations
led_halt_orange="\/sbin\/proled off;\/sbin\/proled orange" # needs to have escaped slahes and backslashes for the neccessary sed operations


