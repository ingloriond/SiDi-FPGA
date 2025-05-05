# NES core for SiDi

This is a port of Luddes' NES core to SiDi (see his [FPGANES blog](http://fpganes.blogspot.de) for details).

## Resources
- [FPGANES original source code by strigeus](https://github.com/strigeus/fpganes) 
- [MiST port by gyurco](https://github.com/mist-devel/nes)

## Installation

Copy the following files to the root of your SD card:

* copy the latest rbf file (i.e. nes_SiDi_20230117.rbf) and rename it core.rbf (or load it from the Menu core)
* copy your .nes cartridge images to the SD card (preferably into a NES subdirectory) to load them via OSD menu


## 15 khz support (TV)
Create a mist.ini file with at least the following line:

```
[mist]
scandoubler_disable=1
```

## Joystick support

* Use one or two gamepads
* Buttons X and Y are Turbo A and Turbo B

## Keyboard support
* F12 - Open the OSD menu
* 1 - Switch to joystick A
* 2 - Switch to joystick B
* Up, Down, Left, Right
* Esc - Start
* Tab - Select
* Space - Fire 1
* Left Alt - Fire 2

## Powerpad emulation support

The [Powerpad / Family Trainer / Family Fun Fitness](https://en.wikipedia.org/wiki/Power_Pad) accessory is emulated through
the keyboard.

Side A:
*    O  O    -   T R
* O  O  O  O - H G F D
*    O  O    -   B V   

Side B:
* 1  2  3  4 - E R T Y
* 5  6  7  8 - D F G H
* 9 10 11 12 - C V B N 

## FDS image support

Famicom Disk System images are supported through Loopy's FDS mapper. It needs
a modified FDS BIOS from the [NES PowerPak](https://www.retrousb.com/product_info.php?products_id=34).
Get FDSBIOS.BIN from the archive, and load it using the "Load FDS BIOS" OSD option before
loading any FDS file.

If a game requires a disk swap, hold down the PgUp key for a while. If the automatic
feature determining the requested disk side doesn't work, select it using the "Disk Side" OSD option.

## NSF music files support

They're played using Loopy's NSF player. Just load the NSF file and enjoy!

## Backup RAM support / FDS image save

* Create an empty SAV file on the SD card to store the backup RAM data. The size of this file should be 8 kbytes for
ordinary cart saves, and the size of the .FDS file (usually ~128 kbytes) for disk saves.
* After loading the NES/FDS file, choose the "Mount SRAM" OSD option and select the SAV file.
* You can load/save the backup RAM contents from/to the SD card via the "Load SRAM" and the "Save SRAM" OSD items.
