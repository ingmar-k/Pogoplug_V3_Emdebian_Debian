#!/bin/bash
# Bash script that creates a Emdebian rootfs (and optional USB stick) for the Pogoplug V3 devices
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)


# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.trap cleanup INT

trap int_cleanup INT
source general_settings.sh # Including settings through an additional file
source build_functions.sh # functions called by this main build script

#########################
###### Main script ######
#########################


check_priviliges # check if the script was run with root priviliges

if [ -z "$1" ] # if started without parameters, just run the full program, as specified in 'general_settings.sh'
then
	prep_output
	build_rootfs
	if [ "${create_usb_stick}" = "yes" ]
	then
		create_usb_stick
	fi
	regular_cleanup
	
elif [ "$1" = "--clean" ]
then
	if [ "$2" = "cache" ]
	then
		echo "Cleaning the cache directory, now!"
		rm -rf ${output_dir_base}/cache/*
	elif [ "$2" = "build" ]
	then
		echo "Cleaning the build directory/directories, now!"
		rm -rf ${output_dir_base}/build_*
	elif [ "$2" = "all" ]
	then
		echo "Cleaning both cache and build directories, now!"
		rm -rf ${output_dir_base}/cache/*
		rm -rf ${output_dir_base}/build_*
	fi
elif [ \( "$1" = "--build" -o "$1" = "-b" \) -a -z "$2" ]  # case of just wanting to build a compressed rootfs archive
then
	param_1="build"
	prep_output
	build_rootfs
	regular_cleanup
	
elif [ \( "$1" = "--install" -o "$1" = "-i" \) -a ! -z "$2" ] # case of wanting to install a existing rootfs-image to sd-card
then
	if [ \( "$3" = "--bootloader" -o "$3" = "-bl" \) -a ! -z "$4" ] # case of additionally telling the script directly what bootloader binary to use
	then
		if [ -z "$4" ] # case of forgotten parameter for the bootloader
		then
			echo "You seem to have called the script with the '--install' AND additional '--bootloader 'parameter.
'--bootloader' requires the location of the bootloader binary file, as an additional parameter.
Please rerun the script accordingly.
For example:
sudo ./build_debian_system.sh install 'http://www.hs-augsburg.de/~ingmar_k/hackberry/rootfs_packages/debian_rootfs_hackberry.tar.bz2' --bootloader 'http://www.hs-augsburg.de/~ingmar_k/hackberry/bootloader/uboot.bin'
"
			exit 1
		else # case of using a non-default bootloader binary
			bootloader_bin_path=${4%/*}
			bootloader_bin_name=${4##*/}
		fi
	fi

	prep_output
	fn_my_echo "Running the script in install-only mode!
Just creating a complete, fully bootable sd-card."
	param_1="install"
	if [ "$2" = "default" ]
	then
		fn_my_echo "Using the default rootfs-package settings defined in 'general_settings.sh'."
		rootfs_package=${default_rootfs_package}
	else 
		rootfs_package_path=${2%/*}
		rootfs_package_name=${2##*/}
	fi
	get_n_check_file "${rootfs_package_path}/${rootfs_package_name}" "rootfs_package" "${output_dir}"
	if [ "${rootfs_package_name:(-8)}" = ".tar.bz2" ]
	then
		tar_format="bz2"
		output_filename="${rootfs_package_name%.tar.bz2}"
	elif [ "${rootfs_package_name:(-7)}" = ".tar.gz" ]
	then
		tar_format="gz"
		output_filename="${rootfs_package_name%.tar.gz}"
	else
		fn_my_echo "The variable rootfs_package_name seems to point to a file that is neither a '.tar.bz2' nor a '.tar.gz' package.
Please check! Exiting now."
		exit 2
	fi
	create_usb_stick
	regular_cleanup
	
elif [ "$1" = "--install" -o "$1" = "-i" ] -a [ -z "$2" ]
then
	echo "You seem to have called the script with the '--install' parameter.
This requires the location of the compressed rootfs archive as second parameter.
Please rerun the script accordingly.
For example:
sudo ./build_debian_system.sh --install 'http://www.hs-augsburg.de/~ingmar_k/hackberry/rootfs_packages/debian_rootfs_hackberry.tar.bz2'
"
	exit 3
else
	echo "'$0' was called with parameter '$1', which does not seem to be a correct parameter.
	
Correct parameters are:
-----------------------
Parameter 1: --build OR -b (If you only want to build a compressed rootfs archive for example for later use, according to the settings in 'general_settings.sh'.)
Parameter 1: --install 'archivename' OR -i 'archivename' (if you only want to create a bootable SD-card with an already existing rootfs-package, tar.bz2 or tar.gz compressed archive)
Parameter 1: --clean all OR --clean build OR --clean cache (The first one cleans both, build and cache directories, while the other two only clean one directory respectively)
Parameter 2: --bootloader 'binary name' OR -bl 'binary name' (if you want to specify a Bootloader binary directly. It can either be a local file or link to an online source)
-----------------------
Besides that you can also run '$0' without any parameters, for the full functionality, according to the settings in 'general_settings'.
Exiting now!"
	exit 4
fi

exit 0
