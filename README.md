**This program (including documentation) is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied**
**warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License version 3 (GPLv3; http://www.gnu.org/licenses/gpl-3.0.html ) for more details.**

**If you don't know what you are doing, think twice before using this guide.**
**I take absolutely no responsibility for any damage(s) that you might cause to your hard- and/or software-environment by following the descriptions below!**


<h1>Pogoplug_V3_Emdebian_Debian</h1>


Scripts to create a bootable Emdebian or Debian USB-Stick for the Pogoplug V3 devices.
Emdebian is (mostly) binary compatible to the same Debian versions. However Emdebian is size optimized, by removing documentation etc. . 
<br><b>Hint: Emdebian is far better suited for a NAND install!</b>

<br>
<h2>ATTENTION:</h2>
<ol>
<li><b>The original ARCH Linux kernel 2.6.31.6, that is flashed to NAND per default, is too old to run Debian/Emdebian Wheezy or anything newer!<br>

<li>If you want to run Wheezy, or anything newer, you will have to update the kernel FIRST! Otherwise the system won't boot!</b><br>

<li>A <b>SERIAL CONNECTION</b> to the Pogoplug is <b>HIGHLY RECOMMENDED</b> for this procedure.<br><i><b>Debugging is more or less impossible without it!</b></i></li><br>

<li><b>Most of the descriptions below assume that you are able to connect to the Pogoplug via serial connection!!!</b></li><br>

<li>A <b>working INTERNET CONNECTION</b> is <b>mandatory</b> and <b>must be available RIGHT AWAY</b> when running the script! So please make sure to be connected <b>before starting the script.</b></li>
</b><br>Otherwise you will simply get an error message right away, stating the lack of a connection.</ol>
<br>

HOWTO: Emdebian or Debian on the Pogoplug V3 (Classic and/or Pro)
------------------

Step-by-step description on how to get Emdebian runnning on your Pogogplug V3:

1. Boot your Pogoplug V3 and install Arch Linux, like explained here: <http://archlinuxarm.org/platforms/armv6/pogoplug-provideov3>
2. Then get your Debian or Ubuntu Host machine ready and get the scipts via git or download them as a zip file: **`'git clone git://github.com/ingmar-k/Pogoplug_V3_Emdebian_Debian.git'`** **_OR_** <https://github.com/ingmar-k/Pogoplug_V3_Emdebian_Debian/archive/master.zip>
3. Make the file _**build_emdebian_debian_system.sh**_ executable, by running **`'chmod +x build_emdebian_debian_system.sh'`**
4. **VERY IMPORTANT:** Edit the file _**general_settings.sh**_ to exactly represent your host system, Pogoplug-device and network environment.
5. Run the script **with root privileges (su or sudo!)** by typing **`'./build_emdebian_system.sh'`**
6. When the script is done, boot your Pogoplug Classic/Pro with the newly created USB-drive attached.
7. If everything went well, the Plug should boot fine and be accessible via SSH (if you installed the package and the network settings are correct --> _**general_settings.sh**_ ).

DEBUGGING:
----------

There are several log files that get created while running the script.
The main one, <b><i>log.txt</b></i> can be found under <b><i>${output_dir}/log.txt</b></i>, where <b><i>${output_dir}</b></i> is a variable that you set in the file <b><i>general_settings.sh</b></i>.
<p>
Several other log and error-log files get created in the root directory of the target-rootfs (the root filesystem that the script creates). If you need to find an error, have a look there, too.
If the script comes that far, you can find the files in the output-archive (hint: <b><i>${output_dir}/${output_filename}</b></i>, as set in <b><i>general_settings.sh</b></i> ) that the script creates.
<br>If the error occurs before the creation of the output-archive, you might want to set the option <b><i>clean_tmp_files</b></i> in the <b><i>general_settings.sh</b></i> to <b><i>no</b></i>. This will cause the script to KEEP the temporary image file that is used for the rootfs creation. In order to debug you can then mount that very image file via loop, after the script failed. 
<br><br>

Running the script with call parameters (special functions)
--------------------------------------------------------------

The script at the moment accepts three main call parameters.
These are **"build"**, **"install".** and **"clean"**.

Descriptions:

**build** : This only runs the script's functions to build a new rootfs including kernel, but does not create a bootable USB drive (USB-stick). It is meant for those creating rootfs-archives for others to use, with known-to-work configurations.

**install** : Opposite of "build"!
It will just download/copy/link a prebuilt rootfs-archive + bootloader and will create a bootable USB drive using these files. This is meant for people not familiar with the build specifics who just want to create a SD-card with known-to-work rootfs configurations.
The "install" parameter, however **REQUIRES** a valid second parameter, to work properly.
You need to pass the complete path+filename of a compressed (.tar.gz or .tar.bz2) rootfs-archive of your choice on to the script. The archive can be located online (for example 'http://www.tester.com/rootfs.tar.bz2' ) or on your local storage (for example '/home/tester/rootfs.tar.bz2' ). The script should be able to handle both cases just fine.

**clean** : Cleanup the build directory
This option is used to delete either the files located in the **cache** or **build** directories, or even in both.
As the script knows caching of apt-packages, it might sometimes be necessary to delete the old cache files before starting a new build. That's what **--clean cache** would be for. Respectively, **--clean build** would only delete the files and folders in the build directory and **--clean all** would do both.


**Usage examples:**

**`sudo ./build_emdebian_system.sh --build`**  will run only the scripts build funtions to create a rootfs-archive according to your settings (NO USB drive creation!).

**`sudo ./build_emdebian_system.sh --install http://www.tester.com/rootfs.tar.bz2`** will download the named rootfs-archive and create a bootable USB drive with it.

**`sudo ./build_emdebian_system.sh --install /local/path/to/rootfs.tar.bz2`** will create a bootable USB drive, using the local rootfs-archive that you set.

**`sudo ./build_emdebian_system.sh --build`**  will run only the scripts build funtions to create a rootfs-archive according to your settings.

**`sudo ./build_emdebian_system.sh --clean all`**  will delete both the files in the build and cache directories.

**`sudo ./build_emdebian_system.sh --clean cache`**  will only delete the files in the cache directory.

**`sudo ./build_emdebian_system.sh --clean build`**  will only delete the files in the build directory.


**Any wrong parameter leads to an error message and a short help text, explaining the valid usage options.**


<br><br>
Flashing and testing a new kernel
-----------------

If you want to use a new/newer kernel, you need to replace the original (Arch Linux-)Kernel in NAND.

Here is how to do that:

1. Boot your pogoplug and get (through USB, wget etc. ) the new uImage and kernel modules.
2. Make sure to place the new kernels modules directory into **/lib/modules** !
3. Then run **`'/usr/sbin/flash_erase /dev/mtd1 0xB00000 24'`** to delete the backup image in flash.
4. By running **`'/usr/sbin/nandwrite -p -s 0xB00000 /dev/mtd1 /path/to/new/uImage'`** you write the newer uImage to flash.
5. Reboot the Pogoplug and interrupt the boot process at the Uboot prompt( _**CE>>**_ ).
6. In order to boot the backup kernel image directly, instead of the main image, run <b>`'run load_custom_nand2 boot'`</b> (as found in the second half of the <b>boot_custom</b> command, shown by running <b>`'printenv'`</b> ) 
7. This will boot the backup kernel image **for one time only**. At the next reboot, the default command will be run again.
8. **Extensively (!!!)** test the kernel before thinking about making it your default kernel!
9. To make this new kernel the default, repeat steps 3. and 4. with the hex adress **0x500000**, INSTEAD OF **0xB00000**.
10. The Pogoplug will then boot to the new kernel by default.


<br>
Root-filesystem in NAND
-----------------

Now that the Pogoplug boots Emdebian (Debian will probably be way too big for NAND) from USB, the next possible (but optional) step is putting the rootfs into NAND.

1. First, shut down your Pogoplug, remove the USB drive and attach it to your desktop system that was used to create the Emdebian rootfs.
2. Create a new directory on the USB drive (for example named _**nand_rootfs**_).
3. Extract the created rootfs archive (by default _emdebian_rootfs_pogoplug_v3.tar.bz2_ file) into the newly created directory.
4. Open the filesystem-table used for mounting the Rootfs ( _**../nand_rootfs/etc/fstab**_ ) with an editor (for example **nano**).
5. Remove the 2 lines **'/dev/root	/	ext4	defaults,noatime	0	1'** and **'/dev/sda2	none	swap	defaults	0	0'**, **replace** them with **'/dev/root	/	ubifs	defaults,noatime	0	0'** and save the file.
6. Make absolutely sure that the _**nand_rootfs**_-directory includes the needed kernel modules in _**/lib/modules**_ !
7. To delete the contents of the old rootfs in nand, run the command <b>`'flash_eraseall /dev/mtd2'`</b> ( with mtd2 being the rootfs partition according to <b>`'cat /proc/mtd'`</b> ).
8. Change into a different directory, that is not part of the _**nand_rootfs**_ dir !!!
9. Create a file called _**ubinize.cfg**_, with the following content:

    <b> [ubifs]
    <br> mode=ubi
    <br> image=ubifs.img
    <br> vol_id=0
    <br> vol_size=100MiB
    <br> vol_type=dynamic
    <br> vol_name=rootfs
    <br> vol_alignment=1
    <br> vol_flags=autoresize</b>

10. Check your boot log (or via dmesg) for the UBI entry called **UBI: available PEBs:** and memorize or write down the number ( should be something like '897' ).
11. Run **`'mkfs.ubifs -r /nand_rootfs -m 2048 -e 129024 -c 897 -x zlib -o ubifs.img'`** with the parameters **fitting your system (very important, the number after '-c' is the one you memorized). Check the other parameters, too, to be sure.**
12. Then run **`'ubinize -o ubi.img -m 2048 -p 128KiB -s 512 ubinize.cfg'`** to create the final image, ready to flash.
13. To flash that image to NAND, you first need to detach second the partition (<b>mtd2</b>) from UBI, by running **`'ubidetach /dev/ubi_ctrl -m 2'`** .
14. Finally flash the created image to NAND by running **`'ubiformat /dev/mtd2 -f ubi.img'`** .
15. Reboot the Pogoplug and again **interrupt the boot process at the Uboot prompt**.
16. To boot the system from NAND, run the commmand <b>`'setenv bootargs $bootargs_stock'`</b> , followed by <b>`'run boot_custom'`</b>.
17. This change again is only temporary until the next reboot.
18. To make the Pogoplug boot from NAND by default, run <b>`'setenv bootargs $bootargs_stock'`</b> at the Uboot prompt again, followed followed by running <b>`'saveenv'`</b> .
19. Now the Pogoplug should boot to NAND by default.
