This port of Sonic CD is based on the disassembly of the Mode 2 original by Ralakaimus,
and targets ASM68K/ClownASM with Z80 macros. It makes use of Clownancy's ported 
Sonic 3 Z80 sound driver, a modified version of Ralakaimus' Mega CD Mode 1 init library, 
and Vladikcomper's optimized Nemesis and Kosinski decompression routines.

Labels and naming conventions are for the most part based on Sonic 1 Hivebrain 2022, 
and documentation for routines in common with that game is derived from it; all other
documentation is copied directly from Ralakaimus' disassembly.

Due to the inherent space limitations of a cartridge, FMV data will still need
to be loaded from CD, in addition to the CD-DA audio. The build script will automatically
build both an ISO image of this disc for use with real hardware, as well as standalone
FMV binaries, OGGs and a cue sheet for use with emulators. Support for CD-DA past tracks is included,
as is switching between them and the CD-DA past tracks in the game's settings. Church of Kondo's 
remasters of the JP past tracks and King Meteor's US Past concepts are included in the repository. 
As a bonus, FM-PSG-PCM versions of the JP Present and Future tracks are included, enabling the 
game to run in a reduced functionality mode if no disc is detected.

Support is included for both the SEGA CD internal RAM and cartridge SRAM, as is transferring
saves between them, and loading saves made by the Mode 2 version. The Mega CD RAM Cart is, 
of course, not supported.

Almost all of the duplicated code and data required by the Mode 2
original as an inherent part of its structure has been eliminated,
along with a substantial amount of unused garbage leftover from Sonic 1.

The Sub CPU program and the Z80 sound driver are both Kosinski compressed. 128x128 level chunks,
uncompressed in the Mode 2 original, are now Enigma compressed. 16x16 Block mappings are still
Nemesis compressed to save space.

For the sake of documentation, this port also attempts to preserve a number of bugs and oddities 
found in the original, including WW Sonic using older code, bits of shoddy controller coding 
in the DA garden, misaligned sprite mappings, palette oddities, SMPS-PCM bugs, and more.
Fixes for all have been provided that can be toggled by setting "FixBugs" to 1.