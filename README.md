Pogoplug_V3_Emdebian
====================

Scripts to create a bootable Emdebian USB-Stick for the Pogoplug V3 devices.

Based on the Gnublin_Emdebian project ATM. Preliminary version with some problems and parts that don't necessarily make sense.
This will change.

Preliminary HOWTO:
------------------

- Boot you Pogoplug V3 and install Arch Linux, like explained here:
[http://archlinuxarm.org/platforms/armv6/pogoplug-provideov3#qt-platform_tabs-ui-tabs2]

-Then get your Debian or Ubuntu Host machine ready and get the scipts via git or download them as a zip file:
- `git clone git://github.com/ingmar-k/Pogoplug_V3_Emdebian.git`
**OR**
- `https://github.com/ingmar-k/Pogoplug_V3_Emdebian/archive/master.zip`
- Make the file `build_emdebian_system.sh` executable, by running `chmod +x build_emdebian_system.sh`
- Edit the file `general_settings.sh` to represent your host system, Pogoplug-device and network environment
- Run the script **with root privileges** (su or sudo!) by typing `./build_emdebian_system.sh`
