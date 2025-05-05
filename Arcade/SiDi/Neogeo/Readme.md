# SNK Neo Geo core for SiDi

![Neo Geo rounded logo](https://live.staticflickr.com/65535/52958482059_69a299d0a8_o.png)

This is a port of the [NeoGeo FPGA implementation](https://github.com/MiSTer-devel/NeoGeo_MiSTer) by [Furrtek](https://www.patreon.com/furrtek/posts) and [Gyurco](https://github.com/gyurco/NeoGeo_MiSTer/tree/mist/mist#sidenotes) for the SiDi FPGA platform.
The core now supports **NeoGeo AES**, **MVS** and **NeoGeo CD** (minimum firmware 230705 is required).

## Usage

Copy the *NeoGeo_SiDi_XXXXXX.rbf* file on the SD card. ROMs and ISOs should go in the 'NEOGEO' folder.

A **bios** must be loaded before cartridges or CDs, it can be created from MAME's *neogeo.zip* or the [Universe Bios](http://unibios.free.fr/download.html) with the help of the [MRA files](https://github.com/mist-devel/mist-binaries/tree/master/cores/neogeo/bios).

TerraOnion's **.neo** file format was chosen as supported cart format, as it conveniently merges all the various ROMs in one file. The following utilities can be used to create such files from MAME ROMS:

* [Original NeoBuilder tool](https://wiki.terraonion.com/index.php/Neobuilder_Guide)

* [MAME to .neo conversion tool](https://github.com/city41/neosdconv)

* [Darksoft to .neo conversion tool](https://gitlab.com/loic.petit/darksoft-to-neosd/)

**Note:** this core doesn't support encrypted ROMs, so make sure the ROM has no encrypted parts before use. MAME ROM pack includes many encrypted ROMs so it's not recommended for inexperienced users, using the MAME .neo conversion tool with a MAME ROM set will result in some ROMs still being encrypted. The .neo conversion tool for the Darksoft ROM set will give you a fully decrypted set.

NeoGeo CD ISOs must be **CUE+BIN**, with only one BIN file.

## Controls

| NeoGeo | SiDi    |
|--------|---------|
| A      | A       |
| B      | B       |
| C      | X       |
| D      | Y       |
| Start  | Start   |
| Select | Select  |
| Coin1  | L       |
| Coin2  | R       |

Mouse (trackball) support for the game "Irritating Maze" can be selected in the OSD. Middle mouse button is Start. **Note:** this game requires its own system BIOS.

## Memory Card

A 8K (8192 bytes) empty file can be used as a memory card. It can be loaded-unloaded and saved via the OSD (use a .SAV extension). Hint: rename it to **NeoGeo.vhd** and it'll be auto-mounted. One memory card can store progress and high scores for a couple of games.

## AES/MVS limitations
The original Neo Geo system has big RAM/ROM memories, which don't fit into the BRAM of the SiDi's FPGA. A new SDRAM controller was written, which can
read two 32 bit words simultaneously in just 8 cycles using bank interleaving, running at 96MHz.

The limitation of ROM sizes for SiDi (**32 MiB**) is ~6 MiB PROMS and 24 MiB CROM+VROMs (in any size combination).  
SiDi128 has no limitations.

## Resources

- [Original core and documentation by Sean Gonsalves](https://github.com/MiSTer-devel/NeoGeo_MiSTer)
- [MiST port by Gyorgy Szombathelyi](https://github.com/gyurco/NeoGeo_MiSTer/tree/mist/mist)
- [Alternative link for NeoBuilder tool (Stone Age Gamer)](https://stoneagegamer.com/neosd-downloads.html)
- [MAME to .neo conversion tool](https://github.com/city41/neosdconv)
- [Darksoft to .neo conversion tool](https://gitlab.com/loic.petit/darksoft-to-neosd/)
- [The Universe Bios by Razoola](http://unibios.free.fr/download.html)
- [MRA tool by Sebastien Delestaing / squidrpi](https://github.com/mist-devel/mra-tools-c/tree/master/release)
- [Arcade cores overview](https://github.com/ManuFerHi/SiDi-FPGA/wiki/Arcade-overview)
