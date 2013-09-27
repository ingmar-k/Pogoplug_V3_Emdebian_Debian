#!/bin/bash
# Bash script that creates a Debian or Emdebian rootfs or even a complete USB thumb drive a Pogoplug V3 device
# Should run on current Debian or Ubuntu versions
# Author: Ingmar Klein (ingmar.klein@hs-augsburg.de)

# This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.

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
	if [ "${create_disk}" = "yes" ]
	then
		create_drive
	fi
	regular_cleanup
	
elif [ "$1" = "--clean" ]	# case of wanting to clean cache, or build directory, or even both
then
	if [ "$2" = "cache" ]
	then
		echo "Cleaning the cache directory, now!"
		if [ -d ${output_dir_base}/cache/ ]
		then
			rm -rf ${output_dir_base}/cache/*
		else
			echo "No cache directory '${output_dir_base}/cache/' found, so not cleaning it!"
		fi
	elif [ "$2" = "build" ]
	then
		echo "Cleaning the build directory/directories, now!"
		if [ -d ${output_dir_base}/build_* ]
		then
			rm -rf ${output_dir_base}/build_* 2>>${output_dir_base}/clean_errors.txt
		else
			echo "No build directory '${output_dir_base}/build_*' found, so not cleaning it!"
		fi
	elif [ "$2" = "all" ]
	then
		echo "Cleaning both cache and build directories, now!"
		echo "Cleaning the cache directory, now!"
		if [ -d ${output_dir_base}/cache/ ]
		then
			rm -rf ${output_dir_base}/cache/*
		else
			echo "No cache directory '${output_dir_base}/cache/' found, so not cleaning it!"
		fi
		echo "Cleaning the build directory/directories, now!"
		if [ -d ${output_dir_base}/build_* ]
		then
			rm -rf ${output_dir_base}/build_* 2>>${output_dir_base}/clean_errors.txt
		else
			echo "No build directory '${output_dir_base}/build_*' found, so not cleaning it!"
		fi
	else
		echo "The 'clean' parameter needs a second parameter to further specify what you want to do.
Valid parameters are 'cache', 'build' or 'all'.
For more information please call the script with the '--help' parameter."
	fi
elif [ "$1" = "--mrproper" ] # case of wanting to completely remove the build directory and all its content
then
	if [ -d ${output_dir_base} ]
	then
		echo "ATTENTION!
You are trying to completely remove the build base directory '${output_dir_base}'.
If you are absolutely sure that you want to do that, please confirm by typing in 'yes', followed by pressing the ENTER key."
		read affirmation
		if [ "${affirmation}" = "yes" ]
		then
			rm -rf ${output_dir_base}
		else
			echo "You did not confirm, so cancelling the action, NOT removing the directory."
		fi
	else
		echo "Base directory '${output_dir_base}' NOT found, so not cleaning it!"
	fi
elif [ \( "$1" = "--build" -o "$1" = "-b" \) -a -z "$2" ]  # case of just wanting to build a compressed rootfs archive
then
	#param_1="build"
	prep_output
	build_rootfs
	regular_cleanup
	
elif [ \( "$1" = "--install" -o "$1" = "-i" \) -a ! -z "$2" ] # case of wanting to install a existing rootfs-image to USB drive
then
	prep_output
	fn_log_echo "Running the script in install-only mode!
Just creating a complete, fully bootable USB drive."
	#param_1="install"
	if [ "$2" = "default" ]
	then
		fn_log_echo "Using the default rootfs-package settings defined in 'general_settings.sh'."
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
		fn_log_echo "The variable rootfs_package_name seems to point to a file that is neither a '.tar.bz2' nor a '.tar.gz' package.
Please check! Exiting now."
		exit 2
	fi
	create_drive
	regular_cleanup
	
elif [ \( "$1" = "--install" -o "$1" = "-i" \) -a -z "$2" ]
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
Parameter 1: --install 'archivename' OR -i 'archivename' (if you only want to create a bootable USB drive with an already existing rootfs-package, tar.bz2 or tar.gz compressed archive)
Parameter 1: --clean all OR --clean build OR --clean cache (The first one cleans both, build and cache directories, while the other two only clean one directory respectively)
-----------------------
Besides that you can also run '$0' without any parameters, for the full functionality, according to the settings in 'general_settings'.
Exiting now!"
	exit 4
fi


exit 0
