#!/bin/bash
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)
# Additional part of the main script 'build_debian_system.sh', that contains all the general settings

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.


#############################
##### GENERAL SETTINGS: #####
#############################

host_os="Debian" # Debian or Ubuntu (YOU NEED TO EDIT THIS!)

debian_mirror_url="http://ftp.uk.debian.org/emdebian/grip" # mirror for debian

debian_target_version="squeeze" # The version of debian that you want to build (ATM, 'squeeze', 'wheezy' and 'sid' are supported)

qemu_kernel_pkg_path="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/kernels/" # where to get the qemu kernel

std_kernel_pkg_path="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/kernels/" # where to get the standard kernel

qemu_kernel_pkg_name="zImage-qemu.tar.bz2" # qemu kernel file name

std_kernel_pkg_name="pogoplug_v3_arch_kernel_modules.tar.bz2" # standard kernel file name

tar_format="bz2" # bz2(=bzip2) or gz(=gzip)

output_dir_base="/home/${USERNAME}/pogoplug_v3_emdebian_build" # where to put the files in general (YOU NEED TO EDIT THIS!)

output_dir="${output_dir_base}/build_`date +%s`" # Subdirectory for each build-run, ending with the unified Unix-Timestamp (seconds passed since Jan 01 1970)

work_image_size_MB=512 # size of the temporary image file, in which the installation process is carried out

output_filename="emdebian_rootfs_pogoplug_v3" # base name of the output file (compressed rootfs)

apt_prerequisites_debian="debootstrap binfmt-support qemu-user-static qemu qemu-kvm qemu-system parted" # packages needed for the build process on debian

apt_prerequisites_ubuntu="debootstrap binfmt-support qemu qemu-system qemu-kvm qemu-kvm-extras-static parted" # packages needed for the build process on ubuntu

clean_tmp_files="yes" # delete the temporary files, when the build process is done?

create_usb_stick="yes" # create a bootable USB-stick after building the rootfs?



###################################
##### CONFIGURATION SETTINGS: #####
###################################

nameserver_addr="192.168.2.1" # "141.82.48.1" (YOU NEED TO EDIT THIS!)

pogoplug_mac_address="00:00:00:00:00:00" # (YOU NEED TO EDIT THIS!)

use_ramzswap="no" # set if you want to use a compressed SWAP space in RAM (can potentionally improve performance)

ramzswap_size_kb="3072" # size of the ramzswap device in KB

ramzswap_kernel_module_name="ramzswap" # name of the ramzswap kernel module (could have a different name on newer kernel versions)

vm_swappiness="100" # Setting for general kernel RAM swappiness: With RAMzswap and low RAM, a high number (like 100) could be good. Default in Linux mostly is 60.

additional_packages="emdebian-archive-keyring mtd-utils udev ntp netbase module-init-tools nano bzip2 unzip zip screen less usbutils psmisc procps dhcp3-client ifupdown iputils-ping wget net-tools ssh"

extra_files="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/extra_files/pogoplug_v3_arch_ledcontrol.tar.bz2"
