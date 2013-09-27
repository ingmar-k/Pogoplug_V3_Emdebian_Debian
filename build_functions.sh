#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete USB thumb drive a Pogoplug V3 device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)


# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.


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
	exit 5
fi


mkdir ${output_dir}/tmp # subdirectory for all downloaded or local temporary files
if [ "$?" = "0" ]
then
	echo "Subfolder 'tmp' of output directory '${output_dir}' successfully created."
else
	echo "ERROR while trying to create the 'tmp' subfolder '${output_dir}/tmp'. Exiting now!"
	exit 6
fi
}

### Rootfs Creation ###
build_rootfs()
{
	check_n_install_prerequisites # see if all needed packages are installed and if the versions are sufficient

	create_n_mount_temp_image_file # create the image file that is then used for the rootfs

	do_debootstrap # run debootstrap (first and second stage)
	
	do_post_debootstrap_config # do some further system configuration

	compress_rootfs # compress the resulting rootfs
}


### USB thumb drive creation ###
create_drive()
{
	partition_n_format_disk # USB drive: make partitions and format
	finalize_disk # copy the bootloader, rootfs and kernel to the USB drive
}




#######################################
##### MAIN lower level functions: #####
#######################################

# Description: Check if the user calling the script has the necessary priviliges
check_priviliges()
{
if [[ $UID -ne 0 ]]
then
	echo "$0 must be run as root/superuser (su, sudo etc.)!
Please try again with the necessary priviliges."
	exit 10
fi
}


# Description: Function to log and echo messages in terminal at the same time
fn_log_echo()
{
	if [ -d ${output_dir} ]
	then
		echo "`date`:   ${1}" >> ${output_dir}/log.txt
		echo "${1}"
	else
		echo "Output directory '${output_dir}' doesn't exist. Exiting now!"
		exit 11
	fi
}


# Description: Function that checks if the needed internet connectivity is there.
check_connectivity()
{
fn_log_echo "Checking internet connectivity, which is mandatory for the next step."
for i in {1..3}
do
	for i in google.com kernel.org debian.org 
	do
		ping -c 3 ${i}
		if [ "$?" = "0" ]
		then 
			fn_log_echo "Pinging '${i}' worked. Internet connectivity seems fine."
			done=1
			break
		else
			fn_log_echo "ERROR! Pinging '${i}' did NOT work. Internet connectivity seems bad or you are not connected.
	Please check, if in doubt!"
			if [ "${i}" = "kernel.org" ]
			then
				fn_log_echo "ERROR! All 3 ping attempts failed! You do not appear to be connected to the internet.
	Exiting now!"
				exit 97
			else	
				continue
			fi
		fi
	done
if [ "${done}" = "1" ]
then
	break
fi
done
}


# Description: See if the needed packages are installed and if the versions are sufficient
check_n_install_prerequisites()
{
	
check_connectivity

fn_log_echo "Installing some packages, if needed."
if [ "${host_os}" = "Debian" ]
then
	apt_prerequisites=${apt_prerequisites_debian}
elif [ "${host_os}" = "Ubuntu" ]
then
	apt_prerequisites=${apt_prerequisites_ubuntu}
else
	fn_log_echo "OS-Type '${host_os}' not correct.
Please run 'build_debian_system.sh --help' for more information"
	exit 12
fi

set -- ${apt_prerequisites}

while [ $# -gt 0 ]
do
	dpkg -l |grep "ii  ${1}" >/dev/null
	if [ "$?" = "0" ]
	then
		fn_log_echo "Package '${1}' is already installed. Nothing to be done."
	else
		fn_log_echo "Package '${1}' is not installed yet.
Trying to install it now!"
		if [ ! "${apt_get_update_done}" = "true" ]
		then
			fn_log_echo "Running 'apt-get update' to get the latest package dependencies."
			apt-get update
			if [ "$?" = "0" ]
			then
				fn_log_echo "'apt-get update' ran successfully! Continuing..."
				apt_get_update_done="true"
			else
				fn_log_echo "ERROR while trying to run 'apt-get update'. Exiting now."
				exit 13
			fi
		fi
		apt-get install -y ${1}
		if [ "$?" = "0" ]
		then
			fn_log_echo "'${1}' installed successfully!"
		else
			fn_log_echo "ERROR while trying to install '${1}'."
			if [ "${host_os}" = "Ubuntu" ] && [ "${1}" = "qemu-system" ]
			then
				fn_log_echo "Assuming that you are running this on Ubuntu 10.XX, where the package 'qemu-system' doesn't exist.
If your host system is not Ubuntu 10.XX based, this could lead to errors. Please check!"
			else
				fn_log_echo "Exiting now!"
				exit 14
			fi
		fi
	fi

	if [ $1 = "qemu-user-static" ]
	then
		sh -c "dpkg -l|grep \"qemu-user-static\"|grep \"1.\"" >/dev/null
		if [ $? = "0" ]
		then
			fn_log_echo "Sufficient version of package '${1}' found. Continueing..."
		else
			fn_log_echo "The installed version of package '${1}' is too old.
You need to install a package with a version of at least 1.0.
For example from the debian-testing ('http://packages.debian.org/search?keywords=qemu&searchon=names&suite=testing&section=all')
respectively the Ubuntu precise ('http://packages.ubuntu.com/search?keywords=qemu&searchon=names&suite=precise&section=all') repositiories.
Exiting now!"
			exit 15
		fi
	fi
	shift
done

fn_log_echo "Function 'check_n_install_prerequisites' DONE."
}


# Description: Create a image file as root-device for the installation process
create_n_mount_temp_image_file()
{
fn_log_echo "Creating the temporary image file for the debootstrap process."
dd if=/dev/zero of=${output_dir}/${output_filename}.img bs=1M count=${work_image_size_MB}
if [ "$?" = "0" ]
then
	fn_log_echo "File '${output_dir}/${output_filename}.img' successfully created with a size of ${work_image_size_MB}MB."
else
	fn_log_echo "ERROR while trying to create the file '${output_dir}/${output_filename}.img'. Exiting now!"
	exit 16
fi

fn_log_echo "Formatting the image file with the ext4 filesystem."
mkfs.ext4 -F ${output_dir}/${output_filename}.img
if [ "$?" = "0" ]
then
	fn_log_echo "ext4 filesystem successfully created on '${output_dir}/${output_filename}.img'."
else
	fn_log_echo "ERROR while trying to create the ext4 filesystem on  '${output_dir}/${output_filename}.img'. Exiting now!"
	exit 17
fi

fn_log_echo "Creating the directory to mount the temporary filesystem."
mkdir -p ${qemu_mnt_dir}
if [ "$?" = "0" ]
then
	fn_log_echo "Directory '${qemu_mnt_dir}' successfully created."
else
	fn_log_echo "ERROR while trying to create the directory '${qemu_mnt_dir}'. Exiting now!"
	exit 18
fi

fn_log_echo "Now mounting the temporary filesystem."
mount ${output_dir}/${output_filename}.img ${qemu_mnt_dir} -o loop
if [ "$?" = "0" ]
then
	fn_log_echo "Filesystem correctly mounted on '${qemu_mnt_dir}'."
else
	fn_log_echo "ERROR while trying to mount the filesystem on '${qemu_mnt_dir}'. Exiting now!"
	exit 19
fi

fn_log_echo "Function 'create_n_mount_temp_image_file' DONE."
}


# Description: Run the debootstrap steps, like initial download, extraction plus configuration and setup
do_debootstrap()
{
	
check_connectivity

if [ ! -e /usr/share/debootstrap/scripts/${build_target_version} ]
then
	fn_log_echo "Creating a symlink now, in order to make debootstrap work."
	ln -s /usr/share/debootstrap/scripts/${build_target_version%-grip} /usr/share/debootstrap/scripts/${build_target_version}
	if [ "$?" = "0" ]
	then
		fn_log_echo "Debootstrap script symlink successfully created!"
	fi
fi
	
fn_log_echo "Running first stage of debootstrap now."

if [ "${build_target}" = "emdebian" ]
then
	build_target_version="${build_target_version}-grip"
	if [ ! -f /usr/share/debootstrap/scripts/${build_target_version} ]
	then
		fn_my_echo "Creating a symlink now, in order to make debootstrap work."
		ln -s /usr/share/debootstrap/scripts/${build_target_version%-grip} /usr/share/debootstrap/scripts/${build_target_version}
		if [ "$?" = "0" ]
		then
			fn_my_echo "Debootstrap script symlink successfully created!"
		fi
	fi
fi

if [ "${use_cache}" = "yes" ]
then
	if [ -d "${output_dir_base}/cache/" ]
	then
		if [ -e "${output_dir_base}/cache/${base_sys_cache_tarball}" ]
		then
			fn_log_echo "Using debian debootstrap tarball '${output_dir_base}/cache/${base_sys_cache_tarball}' from cache."
			debootstrap --foreign --keyring=/usr/share/keyrings/${build_target}-archive-keyring.gpg --unpack-tarball="${output_dir_base}/cache/${base_sys_cache_tarball}" --include=${deb_add_packages} --verbose --arch=armel --variant=minbase "${build_target_version}" "${qemu_mnt_dir}/" "${target_mirror_url}"
		else
			fn_log_echo "No debian debootstrap tarball found in cache. Creating one now!"
			debootstrap --foreign --keyring=/usr/share/keyrings/${build_target}-archive-keyring.gpg --make-tarball="${output_dir_base}/cache/${base_sys_cache_tarball}" --include=${deb_add_packages} --verbose --arch=armel --variant=minbase "${build_target_version}" "${output_dir_base}/cache/tmp/" "${target_mirror_url}"
			sleep 3
			debootstrap --foreign --keyring=/usr/share/keyrings/${build_target}-archive-keyring.gpg --unpack-tarball="${output_dir_base}/cache/${base_sys_cache_tarball}" --include=${deb_add_packages} --verbose --arch=armel --variant=minbase "${build_target_version}" "${qemu_mnt_dir}/" "${target_mirror_url}"
		fi
	fi
else
	fn_log_echo "Not using cache, according to the settings. Thus running debootstrap without creating a tarball."
	debootstrap --keyring=/usr/share/keyrings/${build_target}-archive-keyring.gpg --include=${deb_add_packages} --verbose --arch armel --variant=minbase --foreign "${build_target_version}" "${qemu_mnt_dir}" "${target_mirror_url}"
fi

if [ "$?" = "0" ]
then
	fn_log_echo "Debootstrap's first stage ran successfully!"
else
	fn_log_echo "Errors while trying to run the first part of the debootstrap operations.
Exiting now!"
	regular_cleanup
	exit 98
fi


fn_log_echo "Starting the second stage of debootstrap now."
echo "#!/bin/bash
/debootstrap/debootstrap --second-stage 2>>/debootstrap_stg2_errors.txt
cd /root 2>>/debootstrap_stg2_errors.txt

cat <<END > /etc/apt/sources.list 2>>/debootstrap_stg2_errors.txt
deb ${target_mirror_url} ${build_target_version} ${target_repositories}
deb-src ${target_mirror_url} ${build_target_version} ${target_repositories}
END

apt-get update

mknod /dev/ttyS0 c 4 64	# for the serial console 2>>/debootstrap_stg2_errors.txt

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

echo ${pogo_hostname} > /etc/hostname 2>>/debootstrap_stg2_errors.txt

echo \"127.0.0.1 ${pogo_hostname}\" >> /etc/hosts 2>>/debootstrap_stg2_errors.txt
echo \"nameserver ${nameserver_addr}\" > /etc/resolv.conf 2>>/debootstrap_stg2_errors.txt

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

if [ -e /compressed_swapspace_setup.sh ]
then
	/compressed_swapspace_setup.sh 2>/compressed_swapspace_setup_log.txt
	rm /compressed_swapspace_setup.sh
fi

/setup.sh 2>/setup_log.txt && rm /setup.sh

exit 0
END

rm /debootstrap_pt1.sh
exit 0" > ${qemu_mnt_dir}/debootstrap_pt1.sh
chmod +x ${qemu_mnt_dir}/debootstrap_pt1.sh

modprobe binfmt_misc

cp /usr/bin/qemu-arm-static ${qemu_mnt_dir}/usr/bin

mkdir -p ${qemu_mnt_dir}/dev/pts

fn_log_echo "Mounting both /dev/pts and /proc on the temporary filesystem."
mount devpts ${qemu_mnt_dir}/dev/pts -t devpts
mount -t proc proc ${qemu_mnt_dir}/proc

fn_log_echo "Entering chroot environment NOW!"
/usr/sbin/chroot ${qemu_mnt_dir} /bin/bash /debootstrap_pt1.sh 2>${output_dir}/debootstrap_pt1_errors.txt
if [ "$?" = "0" ]
then
	fn_log_echo "First part of chroot operations done successfully!"
else
	fn_log_echo "Errors while trying to run the first part of the chroot operations."
fi

if [ "${use_cache}" = "yes" ]
then
	if [ -e ${output_dir_base}/cache/additional_packages.tar.bz2 ]
	then
		fn_log_echo "Extracting the additional packages 'additional_packages.tar.gz' from cache. now."
		tar_all extract "${output_dir_base}/cache/additional_packages.tar.gz" "${qemu_mnt_dir}/var/cache/apt/" 
	elif [ ! -e "${output_dir}/cache/additional_packages.tar.bz2" ]
	then
		fn_log_echo "No compressed additional_packages archive found in cache directory.
Creating it now!"
		add_pack_create="yes"
	fi
fi


echo "#!/bin/bash
export LANG=C 2>>/debootstrap_stg2_errors.txt

apt-get -d -y --force-yes install ${additional_packages} 2>>/deboostrap_stg2_errors.txt
if [ \"${pogoplug_v3_version}\" = \"pro\" ]
then
	apt-get -d -y --force-yes install firmware-ralink 2>>/deboostrap_stg2_errors.txt
fi
if [ -f /etc/locale.gen ]
then
	for k in ${locale_list}; do sed -i 's/# '\${k}'/'\${k}'/g' /etc/locale.gen; done;
	locale-gen 2>>/debootstrap_stg2_errors.txt
else
	echo 'ERROR! /etc/locale.gen not found!'
fi

export LANG=${std_locale} 2>>/debootstrap_stg2_errors.txt	# language settings
export LC_ALL=${std_locale} 2>>/debootstrap_stg2_errors.txt
export LANGUAGE=${std_locale} 2>>/debootstrap_stg2_errors.txt

cat <<END > /etc/fstab 2>>/debootstrap_stg2_errors.txt
# /etc/fstab: static file system information.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/root/	ext4	defaults,noatime	0	1
/dev/sda2	swap	swap	defaults,pri=0	0	0
tmpfs		/tmp	tmpfs	defaults	0	0
tmpfs		/var/spool	tmpfs	defaults,noatime,mode=1777	0	0
tmpfs		/var/tmp	tmpfs	defaults	0	0
tmpfs		/var/log	tmpfs	defaults,noatime,mode=0755	0	0
END

sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' /etc/inittab 2>>/deboostrap_stg2_errors.txt
echo '#T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt102' >> /etc/inittab 2>>/deboostrap_stg2_errors.txt	# insert (temporarily commented!) entry for serial console

rm /debootstrap_pt2.sh
exit 0" > ${qemu_mnt_dir}/debootstrap_pt2.sh
chmod +x ${qemu_mnt_dir}/debootstrap_pt2.sh

fn_log_echo "Mounting both /dev/pts and /proc on the temporary filesystem."
mount devpts ${qemu_mnt_dir}/dev/pts -t devpts
mount -t proc proc ${qemu_mnt_dir}/proc

fn_log_echo "Entering chroot environment NOW!"
/usr/sbin/chroot ${qemu_mnt_dir} /bin/bash /debootstrap_pt2.sh 2>${output_dir}/debootstrap_pt2_errors.txt

if [ "$?" = "0" ]
then
	fn_log_echo "Second part of chroot operations done successfully!"
else
	fn_log_echo "Errors while trying to run the second part of the chroot operations."
fi

if [ "${add_pack_create}" = "yes" ]
then
	fn_log_echo "Compressing additional packages, in order to save in the cache directory."
	cd ${qemu_mnt_dir}/var/cache/apt/
	tar_all compress "${output_dir_base}/cache/additional_packages.tar.bz2" .
	fn_log_echo "Successfully created compressed cache archive of additional packages."
	cd ${output_dir}
fi

sleep 5
umount_img sys
fn_log_echo "Just exited chroot environment."
fn_log_echo "Base debootstrap steps 1&2 are DONE!"
}


# Description: Do some further configuration of the system, after debootstrap has finished
do_post_debootstrap_config()
{

fn_log_echo "Now starting the post-debootstrap configuration steps."
mkdir -p ${output_dir}/qemu-kernel

get_n_check_file "${std_kernel_pkg}" "standard_kernel" "${output_dir}/tmp"

get_n_check_file "${qemu_kernel_pkg}" "qemu_kernel" "${output_dir}/tmp"

tar_all extract "${output_dir}/tmp/${qemu_kernel_pkg##*/}" "${output_dir}/qemu-kernel"
sleep 1
tar_all extract "${output_dir}/tmp/${std_kernel_pkg##*/}" "${qemu_mnt_dir}"
sleep 1
if [ -d ${output_dir}/qemu-kernel/lib/ ]
then
	cp -ar ${output_dir}/qemu-kernel/lib/ ${qemu_mnt_dir}  # copy the qemu kernel modules intot the rootfs
fi
sync
chown root:root ${output_dir}/mnt_debootstrap/lib/modules/ -R
if [ -e ${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware ]
then
	fn_log_echo "Moving gmac-firmware file to the right position ('/lib/firmware')."
	mkdir -p ${output_dir}/mnt_debootstrap/lib/firmware/
	mv ${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware ${output_dir}/mnt_debootstrap/lib/firmware/ 2>>${output_dir}/log.txt
else
	fn_log_echo "Could not find '${output_dir}/mnt_debootstrap/lib/modules/gmac_copro_firmware'. So, not moving it."
fi

if [ ! -z "${module_load_list}" ]
then
set -- "${module_load_list}"
while [ $# -gt 0 ]
do
	echo ${1} >> ${output_dir}/mnt_debootstrap/etc/modules 2>>/deboostrap_stg2_errors.txt
	shift
done
fi

if [ "${use_compressed_swapspace}" = "yes" ]
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
# By default this script does nothing." > ${output_dir}/mnt_debootstrap/compressed_swapspace_setup.sh
	if [ "${compressed_swapspace_module_name}" = "ramzswap" ]
	then
		echo "modprobe ${compressed_swapspace_module_name} num_devices=2 disksize_kb=`expr ${compressed_swapspace_size_MB} \* 1024`
sleep 1 
swapon -p 100 /dev/ramzswap0
swapon -p 100 /dev/ramzswap1
mkswap /dev/ramzswap0
mkswap /dev/ramzswap1
${led_boot_green}
exit 0
END

exit 0" >> ${output_dir}/mnt_debootstrap/compressed_swapspace_setup.sh
	elif [ "${compressed_swapspace_module_name}" = "zram" ]
	then
		echo "modprobe ${zram_kernel_module_name} num_devices=2
sleep 1
echo `expr ${compressed_swapspace_size_MB} \* 1024 \* 1024` > /sys/block/zram0/disksize
echo `expr ${compressed_swapspace_size_MB} \* 1024 \* 1024` > /sys/block/zram1/disksize
mkswap /dev/zram0
mkswap /dev/zram1
swapon -p 100 /dev/zram0
swapon -p 100 /dev/zram1
${led_boot_green}
exit 0
END

exit 0" >> ${output_dir}/mnt_debootstrap/compressed_swapspace_setup.sh
	fi
fi
chmod +x ${output_dir}/mnt_debootstrap/compressed_swapspace_setup.sh

#date_cur=`date` # needed further down as a very important part to circumvent the PAM Day0 change password problem

echo "#!/bin/bash

date -s \"${current_date}\" 2>>/post_debootstrap_errors.txt	# set the system date to prevent PAM from exhibiting its nasty DAY0 forced password change
apt-get -y --force-yes install ${additional_packages} 2>>/post_debootstrap_errors.txt
if [ \"${pogoplug_v3_version}\" = \"pro\" ]
then
	apt-get -y --force-yes install firmware-ralink 2>>/deboostrap_stg2_errors.txt
fi
apt-get clean	# installed the already downloaded packages

if [ "${use_compressed_swapspace}" = "yes" ]
then
	if [ ! -z "${vm_swappiness}" ]
	then
		echo vm.swappiness=${vm_swappiness} >> /etc/sysctl.conf
	fi
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

cat <<END > /etc/default/rcS 2>>/debootstrap_stg2_errors.txt
#
# /etc/default/rcS
#
# Default settings for the scripts in /etc/rcS.d/
#
# For information about these variables see the rcS(5) manual page.
#
# This file belongs to the \"initscripts\" package.

# delete files in /tmp during boot older than x days.
# '0' means always, -1 or 'infinite' disables the feature
#TMPTIME=0

# spawn sulogin during boot, continue normal boot if not used in 30 seconds
#SULOGIN=no

# do not allow users to log in until the boot has completed
#DELAYLOGIN=no

# be more verbose during the boot process
#VERBOSE=no

# automatically repair filesystems with inconsistencies during boot
#FSCKFIX=noTMPTIME=0
SULOGIN=no
DELAYLOGIN=no
VERBOSE=no
FSCKFIX=yes

END

cat <<END > /etc/default/tmpfs 2>>/debootstrap_stg2_errors.txt
# Configuration for tmpfs filesystems mounted in early boot, before
# filesystems from /etc/fstab are mounted.  For information about
# these variables see the tmpfs(5) manual page.

# /run is always mounted as a tmpfs on systems which support tmpfs
# mounts.

# mount /run/lock as a tmpfs (separately from /run).  Defaults to yes;
# set to no to disable (/run/lock will then be part of the /run tmpfs,
# if available).
#RAMLOCK=yes

# mount /run/shm as a tmpfs (separately from /run).  Defaults to yes;
# set to no to disable (/run/shm will then be part of the /run tmpfs,
# if available).
#RAMSHM=yes

# mount /tmp as a tmpfs.  Defaults to no; set to yes to enable (/tmp
# will be part of the root filesystem if disabled).  /tmp may also be
# configured to be a separate mount in /etc/fstab.
#RAMTMP=no

# Size limits.  Please see tmpfs(5) for details on how to configure
# tmpfs size limits.
#TMPFS_SIZE=20%VM
#RUN_SIZE=10%
#LOCK_SIZE=5242880 # 5MiB
#SHM_SIZE=
#TMP_SIZE=

# Mount tmpfs on /tmp if there is less than the limit size (in kiB) on
# the root filesystem (overriding RAMTMP).
#TMP_OVERFLOW_LIMIT=1024

RAMTMP=yes
END

ldconfig



echo -e \"${root_password}\n${root_password}\n\" | passwd root 2>>/post_debootstrap_errors.txt
passwd -u root 2>>/post_debootstrap_errors.txt
passwd -x -1 root 2>>/post_debootstrap_errors.txt
passwd -w -1 root 2>>/post_debootstrap_errors.txt

echo -e \"${user_password}\n${user_password}\n\n\n\n\n\n\n\" | adduser ${username} 2>>/post_debootstrap_errors.txt

if [ ! \"${build_target_version}\" = \"squeeze\" ] && [ ! \"${build_target_version}\" = \"squeeze-grip\" ] && [ ! \"${build_target_version}\" = \"oldstable\" ] && [ ! \"${build_target_version}\" = \"oldstable-grip\" ]
then
	sed -i 's<CONCURRENCY=makefile<CONCURRENCY=\"none\"<g' /etc/init.d/rc
fi

sed -i 's<#T0:2345:respawn:/sbin/getty<T0:2345:respawn:/sbin/getty<g' /etc/inittab
dpkg -l >/installed_packages.txt
df -ah > /disk_usage.txt
reboot 2>>/post_debootstrap_errors.txt
exit 0" > ${output_dir}/mnt_debootstrap/setup.sh
chmod +x ${output_dir}/mnt_debootstrap/setup.sh

sleep 1

if [ ! -z "${extra_files}" ]
then
	set -- ${extra_files}
	while [ $# -gt 0 ]
	do
		extra_files_name=${1##*/}
		get_n_check_file "${1}" "${extra_files_name}" "${output_dir}/tmp"
		tar_all extract "${output_dir}/tmp/${extra_files_name}" "${output_dir}/mnt_debootstrap"
		if [ "$?" = "0" ]
		then
			fn_log_echo "Successfully extracted '${extra_files_name}' into the created rootfs."
		else
			fn_log_echo "ERROR while trying to extract '${extra_files_name}' into the created rootfs!"
		fi
		shift
	done
else
	fn_log_echo "Variable 'extra_files' appears to be empty. No additional files extracted into the completed rootfs."
fi

umount_img all
if [ "$?" = "0" ]
then
	fn_log_echo "Filesystem image file successfully unmounted. Ready to continue."
else
	fn_log_echo "Error while trying to unmount the filesystem image. Exiting now!"
	exit 50
fi

sleep 5

mount |grep "${output_dir}/mnt_debootstrap" > /dev/null
if [ ! "$?" = "0" ]
then
	fn_log_echo "Starting the qemu environment now!"
	qemu-system-arm -M versatilepb -cpu arm926 -no-reboot -kernel ${output_dir}/qemu-kernel/zImage -hda ${output_dir}/${output_filename}.img -m 256 -append "root=/dev/sda rootfstype=ext4 mem=256M rw" 2>qemu_error_log.txt
else
	fn_log_echo "ERROR! Filesystem is still mounted. Can't run qemu!"
	exit 51
fi

fn_log_echo "Additional chroot system configuration successfully finished!"

}


# Description: Compress the resulting rootfs
compress_rootfs()
{
fn_log_echo "Compressing the rootfs now!"

mount |grep ${output_dir}/${output_filename}.img 2>/dev/null
if [ ! "$?" = "0" ]
then 
	fsck.ext4 -fy ${output_dir}/${output_filename}.img
	if [ "$?" = "0" ]
	then
		fn_log_echo "Temporary filesystem checked out, OK!"
	else
		fn_log_echo "ERROR: State of Temporary filesystem is NOT OK! Exiting now."
		regular_cleanup
		exit 24
	fi
else
	fn_log_echo "ERROR: Image file still mounted. Exiting now!"
	regular_cleanup
	exit 25
fi

mount ${output_dir}/${output_filename}.img ${qemu_mnt_dir} -o loop
if [ "$?" = "0" ]
then
	cd ${qemu_mnt_dir}
	if [ "${tar_format}" = "bz2" ]
	then
		tar_all compress "${output_dir}/${output_filename}.tar.${tar_format}" .
	elif [ "${tar_format}" = "gz" ]
	then
		tar_all compress "${output_dir}/${output_filename}.tar.${tar_format}" .
	else
		fn_log_echo "Incorrect setting '${tar_format}' for the variable 'tar_format' in the general_settings.sh.
Please check! Only valid entries are 'bz2' or 'gz'. Could not compress the Rootfs!"
	fi

	cd ${output_dir}
	sleep 5
else
	fn_log_echo "ERROR: Image file could not be remounted correctly. Exiting now!"
	regular_cleanup
	exit 26
fi

umount ${qemu_mnt_dir}
sleep 10
mount | grep ${qemu_mnt_dir} > /dev/null
if [ ! "$?" = "0" ] && [ "${clean_tmp_files}" = "yes" ]
then
	rm -r ${qemu_mnt_dir}
	rm -r ${output_dir}/qemu-kernel
	rm ${output_dir}/${output_filename}.img
elif [ "$?" = "0" ] && [ "${clean_tmp_files}" = "yes" ]
then
	fn_log_echo "Directory '${qemu_mnt_dir}' is still mounted, so it can't be removed. Exiting now!"
	regular_cleanup
	exit 27
elif [ "$?" = "0" ] && [ "${clean_tmp_files}" = "no" ]
then
	fn_log_echo "Directory '${qemu_mnt_dir}' is still mounted, please check. Exiting now!"
	regular_cleanup
	exit 28
fi

fn_log_echo "Rootfs successfully DONE!"
}


# Description: Get the USB drive device and than create the partitions and format them
partition_n_format_disk()
{
device=""
echo "Now listing all available devices:
"

while [ -z "${device}" ]
do
parted -l

echo "
Please enter the name of the USB drive device (eg. /dev/sdb) OR press ENTER to refresh the device list:"

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
			if [ ! -z "${size_swap_partition}" ]
			then
				fn_log_echo "USB drive device set to '${device}', according to user input."
				parted -s ${device} mklabel msdos
				if [ ! -z "${size_wear_leveling_spare}" ]
				then
					# first partition = boot (raw, size = ${size_boot_partition} )
					parted -s --align=opt -- ${device} unit MiB mkpart primary ext4 ${size_alignment} -`expr ${size_swap_partition} + ${size_wear_leveling_spare}`
					# last partition = swap (swap, size = ${size_swap_partition} )
					parted -s --align=opt -- ${device} unit MiB mkpart primary linux-swap -`expr ${size_swap_partition} + ${size_wear_leveling_spare}` -${size_wear_leveling_spare} 
				else
					# first partition = boot (raw, size = ${size_boot_partition} )
					parted -s --align=opt -- ${device} unit MiB mkpart primary ext4 ${size_alignment} -${size_swap_partition}
					# last partition = swap (swap, size = ${size_swap_partition} )
					parted -s --align=opt -- ${device} unit MiB mkpart primary linux-swap -${size_swap_partition} -0
				fi
				echo ">>> ${device} Partition table is now:"
				parted -s ${device} unit MiB print
			else
				fn_log_echo "ERROR! The setting for 'size_swap_partition' seems to be empty.
Exiting now!"
				regular_cleanup
				exit 29
			fi
		else
			fn_log_echo "Action canceled by user. Exiting now!"
			regular_cleanup
			exit 29
		fi
	else
		fn_log_echo "ERROR! Some partition on device '${device}' is still mounted. Exiting now!"
		regular_cleanup
		exit 30
	fi
else
	if [ ! -z "${device}" ] # in case of a refresh we don't want to see the error message ;-)
	then 
		fn_log_echo "ERROR! Device '${device}' doesn't seem to be a valid device!"
	fi
	device=""
fi

done

if [ -e ${device}1 ] && [ -e ${device}2 ]
then
	mkfs.ext4 ${device}1 # ext4 on root partition
	mkswap ${device}2 # swap
else
	fn_log_echo "ERROR: There should be 3 partitions on '${device}', but one or more seem to be missing.
Exiting now!"
	regular_cleanup
	exit 31
fi

sleep 1
partprobe
}



# Description: Copy rootfs and kernel-modules to the USB-stick and then unmount it
finalize_disk()
{
if [ -e ${device} ] &&  [ "${device:0:5}" = "/dev/" ]
then
	umount ${device}*
	sleep 3
	mount |grep ${device}
	if [ ! "$?" = "0" ]
	then
		# unpack the filesystem and kernel to the root partition
		fn_log_echo "Now unpacking the rootfs to the USB-stick's root partition!"

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
					fn_log_echo "ERROR: File '${output_dir}/${output_filename}.tar.${tar_format}' doesn't seem to exist. Exiting now!"
					regular_cleanup
					exit 80
				fi
				sleep 1
			else
				fn_log_echo "ERROR while trying to mount '${device}1' to '${output_dir}/usb-stick'. Exiting now!"
				regular_cleanup
				exit 81
			fi
		else
			fn_log_echo "ERROR while trying to create the temporary directory '${output_dir}/usb-stick'. Exiting now!"
			regular_cleanup
			exit 82
		fi
		
		sleep 3
		fn_log_echo "Nearly done! Now trying to unmount the usb-stick."
		umount ${output_dir}/usb-stick

		sleep 3
		fn_log_echo "Now doing a final filesystem check."
		fsck -fy ${device}1 # final check

		if [ "$?" = "0" ]
		then
			fn_log_echo "USB-Stick successfully created!
You can remove the usb-stick now
and try it with your pogoplug-V3.
ALL DONE!"
		else
			fn_log_echo "ERROR! Filesystem check on your card returned an error status. Maybe your card is going bad, or something else went wrong."
		fi

		rm -r ${output_dir}/tmp
		rm -r ${output_dir}/usb-stick
	else
		fn_log_echo "ERROR! Some partition on device '${device}' is still mounted. Exiting now!"
	fi
else
	fn_log_echo "ERROR! Device '${device}' doesn't seem to exist!
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
		if [ "${2:(-8)}" = ".tar.bz2" ] || [ "${2:(-5)}" = ".tbz2" ]
		then
			tar -cpjf "${2}" "${3}"
		elif [ "${2:(-7)}" = ".tar.gz" ] || [ "${2:(-4)}" = ".tgz" ]
		then
			tar -cpzf "${2}" "${3}"
		else
			fn_log_echo "ERROR! Created files can only be of type '.tar.gz', '.tgz', '.tbz2', or '.tar.bz2'! Exiting now!"
			regular_cleanup
			exit 37
		fi
	else
		fn_log_echo "ERROR! Illegal arguments '$2' and/or '$3'. Exiting now!"
		regular_cleanup
		exit 38
	fi
elif [ "$1" = "extract" ]
then
	if [ -e "${2}"  ] && [ -d "${3}" ]
	then
		if [ "${2:(-8)}" = ".tar.bz2" ] || [ "${2:(-5)}" = ".tbz2" ]
		then
			tar -xpjf "${2}" -C "${3}"
		elif [ "${2:(-7)}" = ".tar.gz" ] || [ "${2:(-4)}" = ".tgz" ]
		then
			tar -xpzf "${2}" -C "${3}"
		else
			fn_log_echo "ERROR! Can only extract files of type '.tar.gz', or '.tar.bz2'!
'${2}' doesn't seem to fit that requirement. Exiting now!"
			regular_cleanup
			exit 39
		fi
	else
		fn_log_echo "ERROR! Illegal arguments '$2' and/or '$3'. Exiting now!"
		regular_cleanup
		exit 40
	fi
else
	fn_log_echo "ERROR! The first parameter needs to be either 'compress' or 'extract', and not '$1'. Exiting now!"
	regular_cleanup
	exit 41
fi
}


# Description: Helper function to completely or partially unmount the image file when and where needed
umount_img()
{
cd ${output_dir}
if [ "${1}" = "sys" ]
then
	mount | grep "${output_dir}" > /dev/null
	if [ "$?" = "0"  ]
	then
		fn_log_echo "Virtual Image still mounted. Trying to umount now!"
		umount ${qemu_mnt_dir}/proc > /dev/null
		sleep 3
		umount ${qemu_mnt_dir}/dev/pts > /dev/null
		sleep 3
		umount ${qemu_mnt_dir}/dev/ > /dev/null
		sleep 3
		umount ${qemu_mnt_dir}/sys > /dev/null
		sleep 3
	fi

	mount | egrep '(${qemu_mnt_dir}/sys|${qemu_mnt_dir}/proc|${qemu_mnt_dir}/dev/pts)' > /dev/null
	if [ "$?" = "0"  ]
	then
		fn_log_echo "ERROR! Something went wrong. All subdirectories of '${output_dir}' should have been unmounted, but are not."
	else
		fn_log_echo "Virtual image successfully unmounted."
	fi
elif [ "${1}" = "all" ]
then
	mount | grep "${output_dir}" > /dev/null
	if [ "$?" = "0"  ]
	then
		fn_log_echo "Virtual Image still mounted. Trying to umount now!"
		umount ${qemu_mnt_dir}/proc > /dev/null
		sleep 3
		umount ${qemu_mnt_dir}/dev/pts > /dev/null
		sleep 3
		umount ${qemu_mnt_dir}/dev/ > /dev/null
		sleep 3
		umount ${qemu_mnt_dir}/sys > /dev/null
		sleep 3
		umount ${qemu_mnt_dir}/ > /dev/null
		sleep 3
	fi

	mount | grep "${output_dir}" > /dev/null
	if [ "$?" = "0"  ]
	then
		fn_log_echo "ERROR! Something went wrong. '${output_dir}' should have been unmounted, but isn't."
	else
		fn_log_echo "Virtual image successfully unmounted."
	fi
else
	fn_log_echo "ERROR! Wrong parameter. Only 'sys' and 'all' allowed when calling 'umount_img'."
fi
cd ${output_dir}
}


# Description: Helper function to search and replace strings (also works on strings containing special characters!) in files
sed_search_n_replace()
{
if [ ! -z "${1}" ] && [ ! -z "${3}" ] && [ -e "${3}" ]
then
	original=${1}
	replacement=${2}
	file=${3}

	escaped_original=$(printf %s "${original}" | sed -e 's![.\[^$*/]!\\&!g')

	escaped_replacement=$(printf %s "${replacement}" | sed -e 's![\&]!\\&!g')

	sed -i -e "s~${escaped_original}~${escaped_replacement}~g" ${file}
else
	fn_log_echo "ERROR! Trying to call the function 'sed_search_n_replace' with (a) wrong parameter(s). The following was used:
'Param1='${1}'
Param2='${2}'
Param3='${3}'"
fi
sleep 1
grep -F "${replacement}" "${file}" > /dev/null

if [ "$?" = "0" ]
then
	fn_log_echo "String '${original}' was successfully replaced in file '${file}'."
else
	fn_log_echo "ERROR! String '${original}' could not be replaced in file '${file}'!"
fi

}


# Description: Helper function to get (download via wget or git, or link locally) and check any file needed for the build process
get_n_check_file()
{
file_path=${1%/*}
file_name=${1##*/}
short_description=${2}
output_path=${3}

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
	fn_log_echo "ERROR: Function get_n_check_file needs 3 parameters.
Parameter 1 is file_path/file_name, parameter 2 is short_description and parameter 3 is output-path.
Faulty parameters passed were '${1}', '${2}' and '${3}'.
One or more of these appear to be empty. Exiting now!" 
	regular_cleanup
	exit 42
fi

if [ "${file_path:0:7}" = "http://" ] || [ "${file_path:0:8}" = "https://" ] || [ "${file_path:0:6}" = "ftp://" ] || [ "${file_path:0:6}" = "git://" ] || [ "${file_path:0:3}" = "-b " ] 
then
	check_connectivity
	if [ -d ${output_path} ]
	then
		cd ${output_path}
		if [ "${1:(-4):4}" = ".git" ]
		then
			fn_log_echo "Trying to clone repository ${short_description} from address '${1}', now."
			success=0
			for i in {1..10}
			do
				if [ "$i" = "1" ]
				then
					git clone ${1}
				else
					if [ -d ./${file_name%.git} ]
					then
						rm -rf ./${file_name%.git}
					fi
					git clone ${1}
				fi
				if [ "$?" = "0" ]
				then
					success=1
					break
				fi
			done
			if [ "$success" = "1" ]
			then
				fn_log_echo "'${short_description}' repository successfully cloned from address '${1}'."
			else
				fn_log_echo "ERROR: Repository '${1}' could not be cloned.
Exiting now!"
				regular_cleanup
				exit 42
			fi
		else
			fn_log_echo "Trying to download ${short_description} from address '${file_path}/${file_name}', now."
			wget -q --spider ${file_path}/${file_name}
			if [ "$?" = "0" ]
			then
				wget -t 3 ${file_path}/${file_name}
				if [ "$?" = "0" ]
				then
					fn_log_echo "'${short_description}' successfully downloaded from address '${file_path}/${file_name}'."
				else
					fn_log_echo "ERROR: File '${file_path}/${file_name}' could not be downloaded.
Exiting now!"
					regular_cleanup
					exit 43
				fi
			else
				fn_log_echo "ERROR: '${file_path}/${file_name}' does not seem to be a valid internet address. Please check!
Exiting now!"
				regular_cleanup
				exit 44
			fi
		fi
	else
		fn_log_echo "ERROR: Output directory '${output_path}' does not seem to exist. Please check!
	Exiting now!"
			regular_cleanup
			exit 45
	fi
else
	fn_log_echo "Looking for the ${short_description} locally (offline)."	
	if [ -d ${file_path} ]
	then
		if [ -e ${file_path}/${file_name} ]
		then
			fn_log_echo "File is a local file '${file_path}/${file_name}', so it stays where it is."
			ln -s ${file_path}/${file_name} ${output_path}/${file_name}
		else
			fn_log_echo "ERROR: File '${file_name}' does not seem to be a valid file in existing directory '${file_path}'.Exiting now!"
			regular_cleanup
			exit 47
		fi
	else
		fn_log_echo "ERROR: Folder '${file_path}' does not seem to exist as a local directory. Exiting now!"
		regular_cleanup
		exit 48
	fi
fi
cd ${output_dir}
}


# Description: Helper function to clean up in case of an interrupt
int_cleanup() # special treatment for script abort through interrupt ('ctrl-c'  keypress, etc.)
{
	fn_log_echo "Build process interrupted. Now trying to clean up!"
	umount_img all 2>/dev/null
	rm -r ${qemu_mnt_dir} 2>/dev/null
	rm -r ${output_dir}/tmp 2>/dev/null
	rm -r ${output_dir}/usb-stick 2>/dev/null
	rm -r ${output_dir}/qemu-kernel 2>/dev/null
	exit 99
}

# Description: Helper function to clean up in case of an error
regular_cleanup() # cleanup for all other error situations
{
	umount_img all 2>/dev/null
	rm -r ${qemu_mnt_dir} 2>/dev/null
	rm -r ${output_dir}/tmp 2>/dev/null
	rm -r ${output_dir}/usb-stick 2>/dev/null
	rm -r ${output_dir}/qemu-kernel 2>/dev/null
}
