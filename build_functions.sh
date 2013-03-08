#!/bin/bash
# Bash script that creates a Emdebian rootfs (and optional USB stick) for the Pogoplug V3 devices
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)


# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.

# THIS SCRIPT IS ONLY INTENDED FOR THE POGOPLUG V3! CHECK IF YOU REALLY HAVE A MODEL OF THE 3RD SERIES BEFORE USING THIS SCRIPT!

#####################################
##### MAIN Highlevel Functions: #####
#####################################


### Preparation ###

prep_output()
{
	
if [ ! -d ${output_dir_base}/cache ]
then
	mkdir -p ${output_dir_base}/cache
fi

mkdir -p ${output_dir} # main directory for the build process
if [ "$?" = "0" ]
then
	echo "Output directory '${output_dir}' successfully created."
else
	echo "ERROR while trying to create the output directory '${output_dir}'. Exiting now!"
	exit 10
fi


mkdir ${output_dir}/tmp # subdirectory for all downloaded or local temporary files
if [ "$?" = "0" ]
then
	echo "Subfolder 'tmp' of output directory '${output_dir}' successfully created."
else
	echo "ERROR while trying to create the 'tmp' subfolder '${output_dir}/tmp'. Exiting now!"
	exit 11
fi
}

### Rootfs Creation ###
build_rootfs()
{
	check_n_install_prerequisites # see if all needed packages are installed and if the versions are sufficient

	create_n_mount_temp_image_file # create the image file that is then used for the rootfs

	do_debootstrap # run debootstrap (first and second stage)
	
	do_post_debootstrap_config # do some further system configuration

	# disable_mnt_tmpfs # disable all entries in /etc/init.d trying to mount temporary filesystems (tmpfs), in order to save precious RAM	
	
	change_udev_tmpfs_size

	compress_debian_rootfs # compress the resulting rootfs
}


### SD-Card Creation ###
create_usb_stick()
{
	partition_n_format_disk # SD-card: make partitions and format
	finalize_disk # copy the bootloader, rootfs and kernel to the SD-card
}


#######################################
##### MAIN lower level functions: #####
#######################################


# Description: Check if the user calling the script has the necessary priviliges
check_priviliges()
{
if [[ $UID -ne 0 ]]
then
	echo "$0 must be run as root/superuser (sudo etc.)!
Please try again with the necessary priviliges."
	exit 12
fi
}


# Description: Function to log and echo messages in terminal at the same time
fn_my_echo()
{
	if [ -d ${output_dir} ]
	then
		echo "`date`:   ${1}" >> ${output_dir}/log.txt
		echo "${1}"
	else
		echo "Output directory '${output_dir}' doesn't exist. Exiting now!"
		exit 13
	fi
}


# Description: See if the needed packages are installed and if the versions are sufficient
check_n_install_prerequisites()
{
fn_my_echo "Installing some packages, if needed."
if [ "${host_os}" = "Debian" ]
then
	apt_prerequisites=${apt_prerequisites_debian}
elif [ "${host_os}" = "Ubuntu" ]
then
	apt_prerequisites=${apt_prerequisites_ubuntu}
else
	fn_my_echo "OS-Type '${host_os}' not correct.
Please run 'build_debian_system.sh --help' for more information"
	exit 20
fi

fn_my_echo "Running 'apt-get update' to get the latest package dependencies."

set -- ${apt_prerequisites}

while [ $# -gt 0 ]
do
	dpkg -l |grep "ii  ${1}" >/dev/null
	if [ "$?" = "0" ]
	then
		fn_my_echo "Package '${1}' is already installed. Nothing to be done."
	else
		if [ ! "${apt_get_update_done}" = "yes" ]
		then
			apt-get update
			if [ "$?" = "0" ]
			then
				fn_my_echo "'apt-get update' ran successfully! Continuing..."
				apt_get_update_done="yes"
			else
				fn_my_echo "ERROR while trying to run 'apt-get update'. Exiting now."
				exit 21
			fi
		fi
		fn_my_echo "Package '${1}' is not installed yet.
Trying to install it now!"
		apt-get install -y --force-yes ${1}
		if [ "$?" = "0" ]
		then
			fn_my_echo "'${1}' installed sueccessfully!"
		else
			fn_my_echo "ERROR while trying to install '${1}'."
			if [ "${host_os}" = "Ubuntu" ] && [ "${1}" = "qemu-system" ]
			then
				fn_my_echo "Assuming that you are running this on Ubuntu 10.XX, where the package 'qemu-system' doesn't exist.
If your host system is not Ubuntu 10.XX based, this could lead to errors. Please check!"
			else
				fn_my_echo "Exiting now!"
				exit 22
			fi
		fi
	fi

	if [ $1 = "qemu-user-static" ] && [ "${host_os}" = "Debian" ]
	then
		sh -c "dpkg -l|grep "qemu-user-static"|grep "1."" >/dev/null
		if [ $? = "0" ]
		then
			fn_my_echo "Sufficient version of package '${1}' found. Continueing..."
		else
			fn_my_echo "The installed version of package '${1}' is too old.
You need to install a package with a version of at least 1.0.
For example from the debian-testing repositiories.
Link: 'http://packages.debian.org/search?keywords=qemu&searchon=names&suite=testing&section=all'
Exiting now!"
			exit 23
		fi
	fi
	shift
done

fn_my_echo "Function 'check_n_install_prerequisites' DONE."
}


# Description: Create a image file as root-device for the installation process
create_n_mount_temp_image_file()
{
fn_my_echo "Creating the temporary image file for the debootstrap process."
dd if=/dev/zero of=${output_dir}/${output_filename}.img bs=1M count=${work_image_size_MB}
if [ "$?" = "0" ]
then
	fn_my_echo "File '${output_dir}/${output_filename}.img' successfully created with a size of ${work_image_size_MB}MB."
else
	fn_my_echo "ERROR while trying to create the file '${output_dir}/${output_filename}.img'. Exiting now!"
	exit 30
fi

fn_my_echo "Formatting the image file with the ext3 filesystem."
mkfs.ext3 -F ${output_dir}/${output_filename}.img
if [ "$?" = "0" ]
then
	fn_my_echo "Ext3 filesystem successfully created on '${output_dir}/${output_filename}.img'."
else
	fn_my_echo "ERROR while trying to create the ext3 filesystem on  '${output_dir}/${output_filename}.img'. Exiting now!"
	exit 31
fi

fn_my_echo "Creating the directory to mount the temporary filesystem."
mkdir -p ${output_dir}/mnt_debootstrap
if [ "$?" = "0" ]
then
	fn_my_echo "Directory '${output_dir}/mnt_debootstrap' successfully created."
else
	fn_my_echo "ERROR while trying to create the directory '${output_dir}/mnt_debootstrap'. Exiting now!"
	exit 33
fi

fn_my_echo "Now mounting the temporary filesystem."
mount ${output_dir}/${output_filename}.img ${output_dir}/mnt_debootstrap -o loop
if [ "$?" = "0" ]
then
	fn_my_echo "Filesystem correctly mounted on '${output_dir}/mnt_debootstrap'."
else
	fn_my_echo "ERROR while trying to mount the filesystem on '${output_dir}/mnt_debootstrap'. Exiting now!"
	exit 34
fi

fn_my_echo "Function 'create_n_mount_temp_image_file' DONE."
}


# Description: Run the debootstrap steps, like initial download, extraction plus configuration and setup
do_debootstrap()
{
fn_my_echo "Running first stage of debootstrap now."
debootstrap --verbose --no-check-gpg --arch armel --variant=minbase --foreign ${debian_target_version} ${output_dir}/mnt_debootstrap ${debian_mirror_url}
if [ "$?" = "0" ]
then
	fn_my_echo "Debootstrap 1st stage finished successfully."
else
	fn_my_echo "ERROR while trying to run the first stage of debootstrap. Exiting now!"
	regular_cleanup
	exit 40
fi

modprobe binfmt_misc

cp /usr/bin/qemu-arm-static ${output_dir}/mnt_debootstrap/usr/bin

mkdir -p ${output_dir}/mnt_debootstrap/dev/pts

fn_my_echo "Mounting both /dev/pts and /proc on the temporary filesystem."
mount devpts ${output_dir}/mnt_debootstrap/dev/pts -t devpts
mount -t proc proc ${output_dir}/mnt_debootstrap/proc

fn_my_echo "Entering chroot environment NOW!"

fn_my_echo "Starting the second stage of debootstrap now."
/usr/sbin/chroot ${output_dir}/mnt_debootstrap /bin/bash -c "
mkdir -p /usr/share/man/man1/
/debootstrap/debootstrap --second-stage 2>>/deboostrap_stg2_errors.txt
cd /root 2>>/deboostrap_stg2_errors.txt

cat <<END > /etc/apt/sources.list 2>>/deboostrap_stg2_errors.txt
deb ${debian_mirror_url} ${debian_target_version} ${debian_target_repos}
deb ${debian_mirror_url} ${debian_target_version}-proposed-updates ${debian_target_repos}
END

apt-get update

if [ \"${ip_type}\" = \"dhcp\" ]
then
	cat <<END > /etc/network/interfaces
auto lo eth0
iface lo inet loopback
iface eth0 inet dhcp
hwaddress ether ${pogoplug_mac_address}
END
elif [ \"${ip_type}\" = \"static\" ]
then
	cat <<END > /etc/network/interfaces
auto lo eth0
iface lo inet loopback
iface eth0 inet static
address ${static_ip}
netmask ${netmask}
gateway ${gateway_ip}
hwaddress ether ${pogoplug_mac_address}
END
fi

echo ${pogo_hostname} > /etc/hostname 2>>/deboostrap_stg2_errors.txt

echo \"127.0.0.1 localhost\" >> /etc/hosts 2>>/deboostrap_stg2_errors.txt
echo \"127.0.0.1 ${pogo_hostname}\" >> /etc/hosts 2>>/deboostrap_stg2_errors.txt
echo \"nameserver ${nameserver_addr}\" > /etc/resolv.conf 2>>/deboostrap_stg2_errors.txt

cat <<END > /etc/rc.local 2>>/deboostrap_stg2_errors.txt
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will exit 0 on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

if [ -e /ramzswap_setup.sh ]
then
	/ramzswap_setup.sh 2>/ramzswap_setup_log.txt
	rm /ramzswap_setup.sh
fi
if [ -e /zram_setup.sh ]
then
	/zram_setup.sh 2>/zram_setup_log.txt
	rm /zram_setup.sh
fi
/setup.sh 2>/setup_log.txt
rm /setup.sh


exit 0
END
exit" 2>${output_dir}/chroot_1_log.txt

if [ "$?" = "0" ]
then
	fn_my_echo "First part of chroot operations done successfully!"
else
	fn_my_echo "Errors while trying to run the first part of the chroot operations."
fi

mount devpts ${output_dir}/mnt_debootstrap/dev/pts -t devpts
mount -t proc proc ${output_dir}/mnt_debootstrap/proc


/usr/sbin/chroot ${output_dir}/mnt_debootstrap /bin/bash -c "
export LANG=C 2>>/deboostrap_stg2_errors.txt
apt-get -y --force-yes  install apt-utils dialog locales 2>>/deboostrap_stg2_errors.txt

cat <<END > /etc/apt/apt.conf 2>>/deboostrap_stg2_errors.txt
APT::Install-Recommends \"0\";
APT::Install-Suggests \"0\";
END

apt-get -d -y --force-yes install ${additional_packages} 2>>/deboostrap_stg2_errors.txt
if [ \"pogoplug_v3_version\" = \"pro\" ]
then
	apt-get -d -y --force-yes install firmware-ralink 2>>/deboostrap_stg2_errors.txt
fi

sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen 2>>/deboostrap_stg2_errors.txt	# enable locale
locale-gen 2>>/deboostrap_stg2_errors.txt

export LANG=en_US.UTF-8 2>>/deboostrap_stg2_errors.txt	# language settings
export LC_ALL=en_US.UTF-8 2>>/deboostrap_stg2_errors.txt
export LANGUAGE=en_US.UTF-8 2>>/deboostrap_stg2_errors.txt

cat <<END > /etc/fstab 2>>/deboostrap_stg2_errors.txt
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/root	/	ext3	defaults,noatime	0	1
/dev/sda2	none	swap	defaults	0	0
END

update-rc.d -f mountoverflowtmp remove 2>>/deboostrap_stg2_errors.txt
echo 'T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt102' >> /etc/inittab 2>>/deboostrap_stg2_errors.txt	# disable virtual consoles
sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' /etc/inittab 2>>/deboostrap_stg2_errors.txt

exit
" 2>${output_dir}/chroot_2_log.txt

if [ "$?" = "0" ]
then
	fn_my_echo "Second part of chroot operations done successfully!"
else
	fn_my_echo "Errors while trying to run the second part of the chroot operations."
fi

sleep 5
umount_img sys
fn_my_echo "Just exited chroot environment."
fn_my_echo "Base debootstrap steps 1&2 are DONE!"
}



# Description: Do some further configuration of the system, after debootstrap has finished
do_post_debootstrap_config()
{

fn_my_echo "Now starting the post-debootstrap configuration steps."

mkdir -p ${output_dir}/qemu-kernel

get_n_check_file "${std_kernel_pkg_path}" "${std_kernel_pkg_name}" "standard_kernel"

get_n_check_file "${qemu_kernel_pkg_path}" "${qemu_kernel_pkg_name}" "qemu_kernel"

tar_all extract "${output_dir}/tmp/${qemu_kernel_pkg_name}" "${output_dir}/qemu-kernel"
sleep 3
tar_all extract "${output_dir}/tmp/${std_kernel_pkg_name}" "${output_dir}/mnt_debootstrap"
sleep 1
sync
chown root:root ${output_dir}/mnt_debootstrap/lib/modules/ -R
if [ -e ${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware ]
then
	fn_my_echo "Moving gmac-firmware file to the right position ('/lib/firmware')."
	mkdir -p ${output_dir}/mnt_debootstrap/lib/firmware/
	mv ${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware ${output_dir}/mnt_debootstrap/lib/firmware/ 2>>${output_dir}/log.txt
else
	fn_my_echo "Could not find '${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware'. So, not moving it."
fi

if [ ! -z ${module_load_list} ]
then
set -- ${module_load_list}
while [ $# -gt 0 ]
do
	echo ${1} >> ${output_dir}/mnt_debootstrap/etc/modules 2>>/deboostrap_stg2_errors.txt
	shift
done
fi


if [ "${use_ramzswap}" = "yes" ]
then
	echo "#!/bin/sh
cat <<END > /etc/rc.local 2>>/ramzswap_setup_errors.txt
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will exit 0 on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

modprobe ${ramzswap_kernel_module_name} num_devices=2 disksize_kb=${ramzswap_size_kb}
swapon -p 100 /dev/ramzswap0
swapon -p 100 /dev/ramzswap1
mkswap /dev/ramzswap0
mkswap /dev/ramzswap1
${led_boot_green}
exit 0
END

exit 0" > ${output_dir}/mnt_debootstrap/ramzswap_setup.sh
chmod +x ${output_dir}/mnt_debootstrap/ramzswap_setup.sh
elif [ "${use_zram}" = "yes" ]
then
echo "#!/bin/sh
cat <<END > /etc/rc.local 2>>/zram_setup_errors.txt
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will exit 0 on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

modprobe ${zram_kernel_module_name} num_devices=2
sleep 1
echo ${zram_size_byte} > /sys/block/zram0/disksize
echo ${zram_size_byte} > /sys/block/zram1/disksize
mkswap /dev/zram0
mkswap /dev/zram1
swapon -p 100 /dev/zram0
swapon -p 100 /dev/zram1
${led_boot_green}
exit 0
END

exit 0" > ${output_dir}/mnt_debootstrap/zram_setup.sh
chmod +x ${output_dir}/mnt_debootstrap/zram_setup.sh
fi


date_cur=`date` # needed further down as a very important part to circumvent the PAM Day0 change password problem

echo "#!/bin/bash

date -s \"${date_cur}\" 2>>/post_debootstrap_errors.txt	# set the system date to prevent PAM from exhibiting its nasty DAY0 forced password change
apt-get -y --force-yes install ${additional_packages} 2>>/post_debootstrap_errors.txt
if [ \"pogoplug_v3_version\" = \"pro\" ]
then
	apt-get -y --force-yes install firmware-ralink 2>>/deboostrap_stg2_errors.txt
fi
apt-get clean	# install the already downloaded packages

if [ "${use_ramzswap}" = "yes" -o "${use_zram}" = "yes" ]
then
	echo vm.swappiness=${vm_swappiness} >> /etc/sysctl.conf
fi

if [ ! -z `grep setup.sh /etc/rc.local` ] # write a clean 'rc.local for the qemu-process'
then
	cat <<END > /etc/rc.local 2>>/post_debootstrap_errors.txt
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will exit 0 on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0
END
fi

sh -c \"echo '${root_password}
${root_password}
' | passwd root\" 2>>/post_debootstrap_errors.txt
passwd -u root 2>>/post_debootstrap_errors.txt
passwd -x -1 root 2>>/post_debootstrap_errors.txt
passwd -w -1 root 2>>/post_debootstrap_errors.txt

sh -c \"echo '${user_password}
${user_password}





' | adduser ${username}\" 2>>/post_debootstrap_errors.txt

passwd -u ${username} 2>>/post_debootstrap_errors.txt
passwd -x -1 ${username} 2>>/post_debootstrap_errors.txt
passwd -w -1 ${username} 2>>/post_debootstrap_errors.txt

ldconfig

dpkg -l >/installed_packages.txt
reboot 2>>/post_debootstrap_errors.txt
exit 0" > ${output_dir}/mnt_debootstrap/setup.sh

chmod +x ${output_dir}/mnt_debootstrap/setup.sh

sed_search_n_replace "mkdir /lib/init/rw/sendsigs.omit.d/" "if [ ! -d  /lib/init/rw/sendsigs.omit.d/ ]; then mkdir /lib/init/rw/sendsigs.omit.d/; fi;" "${output_dir}/mnt_debootstrap/etc/init.d/mountkernfs.sh"

sleep 1

if [ ! -z "${extra_files}" ]
then
	number=0
	set -- ${extra_files}
	while [ $# -gt 0 ]
	do
		extra_files_path=${1%/*}
		extra_files_name=${1##*/}
		get_n_check_file "${extra_files_path}" "${extra_files_name}" "extra_file"
		tar_all extract "${output_dir}/tmp/${extra_files_name}" "${output_dir}/mnt_debootstrap"
		if [ "$?" = "0" ]
		then
			fn_my_echo "Successfully extracted '${extra_files_name}' into the created rootfs."
		else
			fn_my_echo "ERROR while trying to extract '${extra_files_name}' into the created rootfs!"
		fi
		shift
	done
else
	fn_my_echo "Variable 'extra_files' appears to be empty. No additional files extracted into the completed rootfs."
fi

umount_img all
if [ "$?" = "0" ]
then
	fn_my_echo "Filesystem image file successfully unmounted. Ready to continue."
else
	fn_my_echo "Error while trying to unmount the filesystem image. Exiting now!"
	exit 50
fi

sleep 5

mount |grep "${output_dir}/mnt_debootstrap" > /dev/null
if [ ! "$?" = "0" ]
then
	fn_my_echo "Starting the qemu environment now!"
	qemu-system-arm -M versatilepb -cpu arm11mpcore -no-reboot -kernel ${output_dir}/qemu-kernel/zImage-qemu -hda ${output_dir}/${output_filename}.img -m 256 -append "root=/dev/sda rootfstype=ext3 mem=256M devtmpfs.mount=0 rw" 2>qemu_error_log.txt
else
	fn_my_echo "ERROR! Filesystem is still mounted. Can't run qemu!"
	exit 51
fi

fn_my_echo "Additional chroot system configuration successfully finished!"

}


# Description: Compress the resulting rootfs
compress_debian_rootfs()
{
fn_my_echo "Compressing the rootfs now!"

mount |grep ${output_dir}/${output_filename}.img >/dev/null
if [ ! "$?" = "0" ]
then 
	fsck.ext3 -fy ${output_dir}/${output_filename}.img
	if [ "$?" = "0" ]
	then
		fn_my_echo "Temporary filesystem checked out, OK!"
	else
		fn_my_echo "ERROR: State of Temporary filesystem is NOT OK! Exiting now."
		regular_cleanup
		exit 60
	fi
else
	fn_my_echo "ERROR: Image file still mounted. Exiting now!"
	regular_cleanup
	exit 61
fi

mount ${output_dir}/${output_filename}.img ${output_dir}/mnt_debootstrap -o loop
if [ "$?" = "0" ]
then
	fn_my_echo "Trying to edit the reboot and halt scripts now, to add LED indicators."
	sed -i "s/log_action_msg \"Will now halt\"/\\${led_halt_orange}\n\t&/g" ${output_dir}/mnt_debootstrap/etc/init.d/halt  # making the pogoplug's led turn orange on poweroff/shutdown/halt
	sed -i "s/log_action_msg \"Will now restart\"/\\${led_reboot_amber}\n\t&/g" ${output_dir}/mnt_debootstrap/etc/init.d/reboot # making the pogoplug's led turn amber on reboot
	
			
	fn_my_echo "Removing the 'qemu-arm-static' binary from the rootfs."
	if [ -e ${output_dir}/mnt_debootstrap/usr/bin/qemu-arm-static ]
	then
		rm ${output_dir}/mnt_debootstrap/usr/bin/qemu-arm-static
	fi
	
	fn_my_echo "Removing unneccessary file(s) from the rootfs '/tmp' directory."
	rm -rf ${output_dir}/mnt_debootstrap/tmp/*
		
	cd ${output_dir}/mnt_debootstrap
	
	if [ "${tar_format}" = "bz2" ]
	then
		tar_all compress "${output_dir}/${output_filename}.tar.${tar_format}" .
	elif [ "${tar_format}" = "gz" ]
	then
		tar_all compress "${output_dir}/${output_filename}.tar.${tar_format}" .
	else
		fn_my_echo "Incorrect setting '${tar_format}' for the variable 'tar_format' in the general_settings.sh.
Please check! Only valid entries are 'bz2' or 'gz'. Could not compress the Rootfs!"
	fi

	cd ${output_dir}
	sleep 3
else
	fn_my_echo "ERROR: Image file could not be remounted correctly. Exiting now!"
	regular_cleanup
	exit 62
fi

umount ${output_dir}/mnt_debootstrap
sleep 3
mount | grep ${output_dir}/mnt_debootstrap > /dev/null
if [ ! "$?" = "0" ] && [ "${clean_tmp_files}" = "yes" ]
then
	rm -r ${output_dir}/mnt_debootstrap
	rm -r ${output_dir}/qemu-kernel
	rm ${output_dir}/${output_filename}.img
elif [ "$?" = "0" ] && [ "${clean_tmp_files}" = "yes" ]
then
	fn_my_echo "Directory '${output_dir}/mnt_debootstrap' is still mounted, so it can't be removed. Exiting now!"
	regular_cleanup
	exit 63
elif [ "$?" = "0" ] && [ "${clean_tmp_files}" = "no" ]
then
	fn_my_echo "Directory '${output_dir}/mnt_debootstrap' is still mounted, please check. Exiting now!"
	regular_cleanup
	exit 64
fi

fn_my_echo "Rootfs successfully DONE!"
}


# Description: Get the USB-stick device and then create a partition and format it
partition_n_format_disk()
{
device=""
echo "Now listing all available devices:
"

while [ -z "${device}" ]
do
parted -l

echo "
Please enter the name of the USB-stick device (eg. /dev/sdb) OR press ENTER to refresh the device list:"

read device
if [ -e ${device} ] &&  [ "${device:0:5}" = "/dev/" ]
then
	umount ${device}*
	mount |grep ${device}
	if [ ! "$?" = "0" ]
	then
		echo "${device} partition table:"
		parted -s ${device} unit MB print
		echo "If you are sure that you want to repartition device '${device}', then type 'yes'.
Type anything else and/or hit Enter to cancel!"
		read affirmation
		if [ "${affirmation}" = "yes" ]
		then
			fn_my_echo "Now partitioning device '${device}'."
			parted -s ${device} mklabel msdos
			# first partition = root (rest of the drive size)
			parted --align=opt -- ${device} unit MB mkpart primary ext3 1 -256
			# last partition = swap (128MB)
			parted -s --align=opt -- ${device} unit MB mkpart primary linux-swap -256 -0
			echo ">>> ${device} Partition table is now:"
			parted -s ${device} unit MB print
		else
			fn_my_echo "Action canceled by user. Exiting now!"
			regular_cleanup
			exit 70
		fi
	else
		fn_my_echo "ERROR! Some partition on device '${device}' is still mounted. Exiting now!"
		regular_cleanup
		exit 71
	fi
else
	if [ ! -z "${device}" ] # in case of a refresh we don't want to see the error message ;-)
	then 
		fn_my_echo "ERROR! Device '${device}' doesn't seem to be a valid device!"
	fi
	device=""
fi

done

if [ -e ${device}1 ]
then
	mkfs.ext3 ${device}1 # ext3 on root partition
	mkswap ${device}2 # swap
else
	fn_my_echo "ERROR: There should be 1 partition on '${device}', but it seems to be missing.
Exiting now!"
	regular_cleanup
	exit 72
fi

sleep 1
sync
partprobe
sleep 1
}



# Description: Copy rootfs and kernel-modules to the USB-stick and then unmount it
finalize_disk()
{
if [ -e ${device} ] &&  [ "${device:0:5}" = "/dev/" ]
then
	umount ${device}*
	mount |grep ${device}
	if [ ! "$?" = "0" ]
	then
		# unpack the filesystem and kernel to the root partition
		fn_my_echo "Now unpacking the rootfs to the USB-stick's root partition!"

		mkdir ${output_dir}/usb-stick

		if [ "$?" = "0" ]
		then
			fsck -fy ${device}1 # just to be sure
			
			mount ${device}1 ${output_dir}/usb-stick
			if [ "$?" = "0" ]
			then
				if [ -e ${output_dir}/${output_filename}.tar.${tar_format} ]
				then 
					tar_all extract "${output_dir}/${output_filename}.tar.${tar_format}" "${output_dir}/usb-stick"
				else
					fn_my_echo "ERROR: File '${output_dir}/${output_filename}.tar.${tar_format}' doesn't seem to exist. Exiting now!"
					regular_cleanup
					exit 80
				fi
				sleep 1
			else
				fn_my_echo "ERROR while trying to mount '${device}1' to '${output_dir}/usb-stick'. Exiting now!"
				regular_cleanup
				exit 81
			fi
		else
			fn_my_echo "ERROR while trying to create the temporary directory '${output_dir}/usb-stick'. Exiting now!"
			regular_cleanup
			exit 82
		fi
		
		sleep 3
		fn_my_echo "Nearly done! Now trying to unmount the usb-stick."
		umount ${output_dir}/usb-stick

		sleep 3
		fn_my_echo "Now doing a final filesystem check."
		fsck -fy ${device}1 # final check

		if [ "$?" = "0" ]
		then
			fn_my_echo "USB-Stick successfully created!
You can remove the usb-stick now
and try it with your pogoplug-V3.
ALL DONE!"
		else
			fn_my_echo "ERROR! Filesystem check on your card returned an error status. Maybe your card is going bad, or something else went wrong."
		fi

		rm -r ${output_dir}/tmp
		rm -r ${output_dir}/usb-stick
	else
		fn_my_echo "ERROR! Some partition on device '${device}' is still mounted. Exiting now!"
	fi
else
	fn_my_echo "ERROR! Device '${device}' doesn't seem to exist!
	Exiting now"
	regular_cleanup
	exit 83
fi
}



#############################
##### HELPER Functions: #####
#############################


# Description: Helper funtion for all tar-related tasks
tar_all()
{
if [ "$1" = "compress" ]
then
	if [ -d "${2%/*}"  ] && [ -e "${3}" ]
	then
		if [ "${2:(-8)}" = ".tar.bz2" ]
		then
			tar -cpjvf "${2}" "${3}"
		elif [ "${2:(-7)}" = ".tar.gz" ]
		then
			tar -cpzvf "${2}" "${3}"
		else
			fn_my_echo "ERROR! Created files can only be of type '.tar.gz', or '.tar.bz2'! Exiting now!"
			regular_cleanup
			exit 90
		fi
	else
		fn_my_echo "ERROR! Illegal arguments '$2' and/or '$3'. Exiting now!"
		regular_cleanup
		exit 91
	fi
elif [ "$1" = "extract" ]
then
	if [ -e "${2}"  ] && [ -d "${3}" ]
	then
		if [ "${2:(-8)}" = ".tar.bz2" ]
		then
			tar -xpjvf "${2}" -C "${3}"
		elif [ "${2:(-7)}" = ".tar.gz"  ]
		then
			tar -xpzvf "${2}" -C "${3}"
		else
			fn_my_echo "ERROR! Can only extract files of type '.tar.gz', or '.tar.bz2'!
'${2}' doesn't seem to fit that requirement. Exiting now!"
			regular_cleanup
			exit 92
		fi
	else
		fn_my_echo "ERROR! Illegal arguments '$2' and/or '$3'. Exiting now!"
		regular_cleanup
		exit 93
	fi
else
	fn_my_echo "ERROR! The first parameter needs to be either 'compress' or 'extract', and not '$1'. Exiting now!"
	regular_cleanup
	exit 94
fi
}


# Description: Helper function to completely or partially unmount the image file when and where needed
umount_img()
{
if [ "${1}" = "sys" ]
then
	mount | grep "${output_dir}" > /dev/null
	if [ "$?" = "0"  ]
	then
		fn_my_echo "Virtual Image still mounted. Trying to umount now!"
		umount ${output_dir}/mnt_debootstrap/sys > /dev/null
		umount ${output_dir}/mnt_debootstrap/dev/pts > /dev/null
		umount ${output_dir}/mnt_debootstrap/proc > /dev/null
	fi

	mount | egrep '(${output_dir}/mnt_debootstrap/sys|${output_dir}/mnt_debootstrap/proc|${output_dir}/mnt_debootstrap/dev/pts)' > /dev/null
	if [ "$?" = "0"  ]
	then
		fn_my_echo "ERROR! Something went wrong. All subdirectories of '${output_dir}' should have been unmounted, but are not."
	else
		fn_my_echo "Virtual image successfully unmounted."
	fi
elif [ "${1}" = "all" ]
then
	mount | grep "${output_dir}" > /dev/null
	if [ "$?" = "0"  ]
	then
		fn_my_echo "Virtual Image still mounted. Trying to umount now!"
		umount ${output_dir}/mnt_debootstrap/sys > /dev/null
		umount ${output_dir}/mnt_debootstrap/dev/pts > /dev/null
		umount ${output_dir}/mnt_debootstrap/proc > /dev/null
		umount ${output_dir}/mnt_debootstrap/ > /dev/null
	fi

	mount | grep "${output_dir}" > /dev/null
	if [ "$?" = "0"  ]
	then
		fn_my_echo "ERROR! Something went wrong. '${output_dir}' should have been unmounted, but isn't."
	else
		fn_my_echo "Virtual image successfully unmounted."
	fi
else
	fn_my_echo "ERROR! Wrong parameter. Only 'sys' and 'all' allowed when calling 'umount_img'."
fi
}


# Description: Helper function to search and replace strings (also those containing special characters!) in files
sed_search_n_replace()
{
if [ ! -z "${1}" ] && [ -e ${3} ] #&& [ ! -z "${2}" ] replacement might be empty!?!
then
	original=${1}
	replacement=${2}
	file=${3}

	escaped_original=$(printf %s "${original}" | sed -e 's![.\[^$*/]!\\&!g')

	escaped_replacement=$(printf %s "${replacement}" | sed -e 's![\&]!\\&!g')

	sed -i -e "s~${escaped_original}~${escaped_replacement}~g" ${file}
else
	fn_my_echo "ERROR! Trying to call the function 'sed_search_n_replace' with (a) wrong parameter(s). The following was used:
'Param1='${1}'
Param2='${2}'
Param3='${3}'"
	if [ -z "${1}" ]
	then
		fn_my_echo "ERROR: Param1 ('${1}') seems to be empty."
	fi
	if [ ! -e ${3} ]
	then
		fn_my_echo "ERROR: File Param3 ('${3}') does NOT seem to exist."
		ls -alh ${3%/*} >>${output_dir}/log.txt
	fi
fi
sleep 1
grep -F "${replacement}" "${file}" > /dev/null

if [ "$?" = "0" ]
then
	fn_my_echo "String '${original}' was successfully replaced in file '${file}'."
else
	fn_my_echo "ERROR! String '${original}' could not be replaced in file '${file}'!"
fi

}


# Some special treatment for udev
change_udev_tmpfs_size()
{
mount ${output_dir}/${output_filename}.img ${output_dir}/mnt_debootstrap -o loop

if [ -e ${output_dir}/mnt_debootstrap/etc/init.d/udev ] && [ -e ${output_dir}/mnt_debootstrap/etc/init.d/udev-mtab ]
then
	fn_my_echo "udev files do exist!"
	fn_my_echo "Changing UDEV tmpfs_size from 10M to '${udev_tmpfs_size}' , in order to save RAM."
	for l in udev udev-mtab
	do
	grep 'tmpfs_size="10M"' "${output_dir}/mnt_debootstrap/etc/init.d/${l}"
	if [ "$?" = "0" ]
	then
		sed_search_n_replace "tmpfs_size=\"10M\"" "tmpfs_size=\"${udev_tmpfs_size}\"" "${output_dir}/mnt_debootstrap/etc/init.d/${l}" # Change tmpfs size to different value, other than the default 10M. Should be fine for this little system with not much hardware attached and saves RAM!
	else
		fn_my_echo "Not editing '${output_dir}/mnt_debootstrap/etc/init.d/${l}'.
This Udev file does not contain a 'tmpfs_size' setting."
	fi
	done
else
	fn_my_echo "No udev files found. Maybe udev is not installed?"
fi 	
umount_img all
}


# Description: Function to disable all /etc/init.d startup entries that try to mount something as tmpfs
disable_mnt_tmpfs()
{

if [ -e "${output_dir}/mnt_debootstrap/etc/init.d/mountoverflowtmp" ]
then
	rm ${output_dir}/mnt_debootstrap/etc/init.d/mountoverflowtmp
	if [ "$?" = "0" ]
	then
		fn_my_echo "File '${output_dir}/mnt_debootstrap/etc/init.d/mountoverflowtmp' successfully removed."
	else
		fn_my_echo "ERROR while trying to remove file '${output_dir}/mnt_debootstrap/etc/init.d/mountoverflowtmp'."
	fi
fi

grep_results=`grep -rn domount ${output_dir}/mnt_debootstrap/etc/init.d/ |grep tmpfs`

if [ ! -z "${grep_results}" ]
then
cat <<END > ${output_dir}/tmpfs_grep_results.txt
$grep_results
END

	while read LINE
	do
		set -- $LINE
		dest_filename="${1%%:*[0-9]:}"
		search="${LINE#${1}}"
		replace="sleep 1 # ${search}"
		echo "${dest_filename}" |grep -i "udev"
		if [ "$?" = "0" ]
		then
			fn_my_echo "UDEV seems to be installed. As udev needs a tmpfs to work properly, file won't be touched."
		else
			sed_search_n_replace "${search}" "${replace}" "${dest_filename}"
		fi
	done < ${output_dir}/tmpfs_grep_results.txt
else
	fn_my_echo "No entries found that match both the keywords 'domount' and 'tmpfs'."
fi
}


get_n_check_file()
{

file_path=${1}
file_name=${2}
short_description=${3}

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
	fn_my_echo "ERROR: Function get_n_check_file needs 3 parameters.
Parameter 1 is file_path, parameter 2 is file_name and parameter 3 is short_description.
Faulty parameters passed were '${1}', '${2}' and '${3}'.
One or more of these appear to be empty. Exiting now!" 
	regular_cleanup
	exit 100
fi

if [ "${file_path:0:4}" = "http" ] || [ "${file_path:0:5}" = "https" ] || [ "${file_path:0:3}" = "ftp" ]
then
	fn_my_echo "Downloading ${short_description} from address '${file_path}/${file_name}', now."
	cd ${output_dir}/tmp
	wget -t 5 ${file_path}/${file_name}
	if [ "$?" = "0" ]
	then
		fn_my_echo "'${short_description}' successfully downloaded from address '${file_path}/${file_name}'."
	else
		fn_my_echo "ERROR: File '${file_path}/${file_name}' could not be downloaded.
Exiting now!"
	regular_cleanup
	exit 101
	fi
else
	fn_my_echo "Looking for the ${short_description} locally (offline)."	
	if [ -d ${file_path} ]
	then
		if [ -e ${file_path}/${file_name} ]
		then
			fn_my_echo "Now linking local file '${file_path}/${file_name}' to '${output_dir}/tmp/${file_name}'."
			ln -s ${file_path}/${file_name} ${output_dir}/tmp/${file_name}
			if [ "$?" = "0" ]
			then
				fn_my_echo "File successfully linked."
			else
				fn_my_echo "ERROR while trying to link the file! Exiting now."
				regular_cleanup
				exit 102
			fi
		else
			fn_my_echo "ERROR: File '${file_name}' does not seem to be a valid file in existing directory '${file_path}'.Exiting now!"
			regular_cleanup
			exit 103
		fi
	else
		fn_my_echo "ERROR: Folder '${file_path}' does not seem to exist as a local directory. Exiting now!"
		regular_cleanup
		exit 104
	fi
fi

}


# Description: Helper function to clean up in certain cases, without exiting the script run
regular_cleanup()
{
	umount_img all 2>/dev/null
	rm -r ${output_dir}/mnt_debootstrap 2>/dev/null
	rm -r ${output_dir}/tmp 2>/dev/null
	rm -r ${output_dir}/usb-stick 2>/dev/null
}


# Description: Helper function to clean up in case of an interrupt
int_cleanup() # special treatment for script abort through interrupt ('ctrl-c'  keypress, etc.)
{
	fn_my_echo "Build process interrrupted. Now trying to clean up!"
	umount_img all 2>/dev/null
	rm -r ${output_dir}/mnt_debootstrap 2>/dev/null
	rm -r ${output_dir}/tmp 2>/dev/null
	rm -r ${output_dir}/usb-stick 2>/dev/null
	exit 110
}
