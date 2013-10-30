#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete SATA/USB drive for a Pogoplug V3 device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)
# Additional part of the main script 'build_emdebian_debian_system.sh', that contains all the general settings

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html )
# for more details.

##################
### IMPORTANT: ###
##################

# The settings that you put into this file will exactly define the output of the scripts.
# So, please take your time and look through all the settings thoroughly, before running the scripts.
# Reading the file 'README.md' is also highly recommended!


##################################################################################################
####### GETTING THE NAME OF THE LOGGED IN USER, FOR USE IN THE DEFAULT OUTPUT-DIRECTORY ##########
##################################################################################################
if logname &> /dev/null ; then 
    LOG_NAME=$( logname )
else 
    LOG_NAME=$( id | cut -d "(" -f 2 | cut -d ")" -f1 )		
fi
##################################################################################################
##################################################################################################


###################################
##### GENERAL BUILD SETTINGS: #####
###################################

### These settings MUST be checked/edited ###
build_target="emdebian" # possible settings are either 'debian' or 'emdebian'
build_target_version="wheezy" # The version of debian/emdebian that you want to build (ATM wheezy is the stable version)
target_mirror_url="http://ftp.uk.debian.org/emdebian/grip" # mirror address for debian or emdebian
target_repositories="main" # what repos to use in the sources.list (for example 'main contrib non-free' for Debian)

pogoplug_v3_version="classic" # either 'classic' or 'pro' (the pro features integrated wireless lan, the classic does NOT; if you set this to 'pro' 'additional_packages_wireless' will be included)
pogoplug_mac_address="00:00:00:00:00:00" # !!!VERY IMPORTANT!!! (YOU NEED TO EDIT THIS!) Without a valid MAC address, your device won't be accessible via LAN

host_os="Ubuntu" # Debian or Ubuntu (YOU NEED TO EDIT THIS!)

output_dir_base="/home/${LOG_NAME}/pogoplug_v3_${build_target}_build" # where the script is going to put its output files (YOU NEED TO CHECK THIS!; default is the home-directory of the currently logged in user) 
current_date=`date +%s` # current date for use on all files that should get a consistent timestamp
#################################################
########## A little necessary check #############
#################################################
echo ${output_dir_base} |grep '//' >/dev/null
if [ "$?" = "0" ]
then
	echo "ERROR! Please check the script variable 'output_dir_base' in the 'general_settings.sh' file.
It seems like there was a empty variable (LOG_NAME???), which led to a wrong path description. Exiting now."
	exit 95
fi
if [ "${output_dir_base:(-1):1}" = "/" ]
then
	output_dir="${output_dir_base}build_${current_date}" # Subdirectory for each build-run, ending with the unified Unix-Timestamp (seconds passed since Jan 01 1970)
else
	output_dir="${output_dir_base}/build_${current_date}" # Subdirectory for each build-run, ending with the unified Unix-Timestamp (seconds passed since Jan 01 1970)
fi
##################################################
##################################################

root_password="root" # password for the Debian or Emdebian root user
username="tester"  # Name of the normal user for the target system
user_password="tester" # password for the user of the target system

deb_add_packages="apt-utils,dialog,locales,emdebian-archive-keyring,debian-archive-keyring" # packages to directly include in the first debootstrap stage
additional_packages="mtd-utils udev ntp netbase module-init-tools isc-dhcp-client nano bzip2 unzip zip screen less usbutils psmisc procps ifupdown iputils-ping wget net-tools ssh hdparm" # List of packages (each seperated by a single space) that get added to the rootfs
additional_wireless_packages="wireless-tools wpasupplicant" # packages for wireless lan; mostly for the Pogoplug V3 Pro

module_load_list="gmac" # names of modules (for example wireless, leds ...) that should be automatically loaded through /etc/modules (list them, seperated by a single blank space)

interfaces_auto="lo eth0" # (IMPORTANT!!!) what network interfaces to bring up automatically on each boot; if you don't list the needed interfaces here, you will have to enable them manually, after booting
nameserver_addr="192.168.2.1" # "141.82.48.1" (YOU NEED TO CHECK THIS!!!)

rootfs_filesystem_type="ext4" # what filesystem type should the created rootfs be?
# ATTENTION: Your kernel has to support the filesystem-type that you specify here. Otherwise the Pogoplug won't boot.
# ALSO, please check the Uboot Environment Variable 'bootargs' !!!
# The part 'rootfstype=' has to reflect the filesystem that your created USB drive uses!
# AND your specified (and flashed!) kernel has to have support for that file system (compiled in, NOT as module!!!)


### These settings are for experienced users ###

std_locale="en_US.UTF-8" # initial language setting for console (alternatively for example 'en_US.UTF-8')'

locale_list="en_US.UTF-8 de_DE.UTF-8" # list of locales to enable during configuration

extra_files="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/extra_files/pogoplug_v3_arch_ledcontrol.tar.bz2" # some extra archives (list seperated by a single blank space!) that get extracted into the rootfs, when done (for example original led control program and original arch linux kernel modules)

qemu_kernel_pkg="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/kernels/2.6.32.61-ppv3-qemu-1.2.tar.bz2" # qemu kernel file name

std_kernel_pkg="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/kernels/2.6.32-ppv3-classic-zram-1.1_ARMv6k.tar.bz2" # std kernel file name

tar_format="bz2" # bz2(=bzip2) or gz(=gzip)

qemu_mnt_dir="${output_dir}/mnt_debootstrap" # directory where the qemu filesystem will be mounted

work_image_size_MB="1024" # size of the temporary image file, in which the installation process is carried out

base_sys_cache_tarball="${build_target}_${build_target_version}_minbase.tgz" # cache file created by debootstrap, if caching is enabled

output_filename="${build_target}_rootfs_pogoplug_v3_${pogoplug_v3_version}_${current_date}" # base name of the output file (compressed rootfs)

### Check these very carefully, if you experience errors while running 'check_n_install_prerequisites'
apt_prerequisites_debian="emdebian-archive-keyring debootstrap binfmt-support qemu-user-static qemu-kvm qemu-system-arm parted e2fsprogs" # packages needed for the build process on debian
apt_prerequisites_ubuntu="debian-archive-keyring emdebian-archive-keyring debootstrap binfmt-support qemu-user-static qemu-system-arm qemu-kvm parted e2fsprogs" # packages needed for the build process on ubuntu


###################################
##### NETWORK BUILD SETTINGS: #####
###################################

### GENERAL NETWORK SETTINGS ###

pogo_hostname="pogoplug-v3-${build_target}" # Name that the Emdebian system uses to identify itself on the network


### ETHERNET ###

ip_type="dhcp" # set this either to 'dhcp' (default) or to 'static'

static_ip="192.168.2.100" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

netmask="255.255.255.0" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

gateway_ip="192.168.2.1" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'


### WIRELESS ###

ip_type_wireless="dhcp" # set this either to 'dhcp' (default) or to 'static'

wireless_ssid="MySSID" # set this to your wireless SSID

wireless_password="Password_Swordfish" # set this to your wireless password

wireless_static_ip="192.168.2.100" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

wireless_netmask="255.255.255.0" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

wireless_gateway_ip="192.168.2.1" # you only need to set this, if ip-type is NOT set to 'dhcp', but to 'static'

Country_Region="1" # wireless region setting for rt3090

Country_Region_A_Band="1" # wireless region band setting for rt3090

Country_Code="DE" # wireless country code setting for rt3090

Wireless_Mode="5" # wireless mode setting for rt3090


####################################
##### SPECIFIC BUILD SETTINGS: #####
####################################

clean_tmp_files="yes" # delete the temporary files, when the build process is done?

create_disk="yes" # create a bootable USB thumb drive after building the rootfs?
# set the following option to 'yes', if you want to create a rootfs on a sata drive, in order to boot it directly, using the Pogoplug V3's onboard SATA connector!!!
boot_directly_via_sata="no" 
# However, if you want to boot from a USB drive, be sure to set the option ABOVE to 'no' !!!

use_cache="yes" # use or don't use caching for the apt and debootstrap processes (caching can speed things up, but it can also lead to problems)


### Settings for compressed SWAP space in RAM ### 

use_compressed_swapspace="yes" # Do you want to use a compressed SWAP space in RAM (can potentionally improve performance)?
compressed_swapspace_module_name="zram" # name of the kernel module for compressed swapspace in RAM (could either be called 'ramzswap' or 'zram', depending on your kernel)
compressed_swapspace_size_MB="32" # size of the ramzswap/zram device in MegaByte (MB !!!), per CPU-core (so per default 2 swap devices will be created)
vm_swappiness="" # (empty string makes the script ignore this setting and uses the debian default). Setting for general kernel RAM swappiness: Default in Linux mostly is 60. Higher number makes the kernel swap faster.


### Partition setting ###
# Comment: size of the rooot partition doesn't get set directly, but is computed through the following formula:
# root partition = size_of_usb_drive - (size_boot_partition + size_swap_partition + size_wear_leveling_spare)
size_swap_partition="512"   # size of the swap partition, in MB (MegaByte)
size_wear_leveling_spare="" ## size of spare space to leave for advanced usb thumb drive flash wear leveling, in MB (MegaByte); leave empty for normal hdds
size_alignment="1" ## size of spare space before the root partitionto starts (in MegaByte); also leave empty for normal hdds


######################################
##### DIRECT SATA BOOT SETTINGS: #####
######################################

sata_boot_stage1="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/sata_boot/stage1/stage1.wrapped700" # stage1 bootloader, needed for direct sata boot
sata_uboot="http://www.hs-augsburg.de/~ingmar_k/Pogoplug_V3/sata_boot/u-boot/u-boot.wrapped" # uboot (stage2) file for direct sata boot


####################################
##### "INSTALL ONLY" SETTINGS: #####
####################################

default_rootfs_package="" # filename of the default rootfs-archive for the '--install' call parameter
