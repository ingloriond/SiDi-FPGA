MIST Firmware
=============
Load latest firmware here https://github.com/mist-devel/mist-binaries/tree/master/firmware

SiDi "Classic" use same firmware than MIST.

These are the binary releases of the MIST firmware.

See the [wiki](https://github.com/mist-devel/mist-board/wiki) for [details how to install it](https://github.com/mist-devel/mist-board/wiki/HowToInstallTheFirmware).

Please read the txt file accompaning the firmware to check whether this update is of any benefit for your use case. In many cases updates only affect certain cores.

Important note
==============

Firmware versions up and until 230705 has a bug which might prevent a successful upgrade. After the upgrade fails, the only way is to de-brick MiST is the SAM-BA or JTAG method.
An intermediate firmware (firmware_231214-intermediate) was created, which fixes the bug, and has a higher chance for a successful upgrade from earlier versions.
So if you're upgrading from a version before 231214, then upgrade first to 231214-intermediate, then go for the latest release.

Unbricking
==========

If the update went wrong, there's several possibilities to restore the firmware to a working state:

- Via USB with the official [SAM-BA](https://github.com/mist-devel/mist-board/wiki/HowToInstallTheFirmware#updating-the-io-controller-via-sam-ba-under-windows)
- Via USB with [BOSSA](https://www.shumatech.com/web/products/bossa)
- Via [JTAG](https://github.com/mist-devel/mist-board/wiki/HowToInstallTheFirmware#updating-the-io-controller-via-jtag)
