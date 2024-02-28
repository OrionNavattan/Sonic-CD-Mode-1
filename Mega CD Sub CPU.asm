; ---------------------------------------------------------------------------
; Mega CD Sub CPU hardware addresses, entry points, and BIOS functions

; Many have been renamed from the "official" names from the sake of clarity
; and readability. Wherever the name has changed beyond moving away from
; all caps, the original name will be given in the description.
; ---------------------------------------------------------------------------

program_ram:		equ	0 ; Mega CD Program RAM
sp_start:			equ $6000	; start of user program in program RAM
program_ram_end:	equ	$80000	; MCD PRG-RAM end

word_ram:			equ $80000 ; Mega CD Word RAM
word_ram_2M:		equ	word_ram	; MCD Word RAM start (2M)
word_ram_2M_end:	equ	$C0000	; MCD Word RAM end (2M)

word_ram_1M:		equ	$C0000	; MCD Word RAM start (1M/1M)
word_ram_1M_end:	equ	$E0000	; MCD Word RAM end (1M/1M)

; Backup RAM
backup_ram:			equ	$FE0000	; Mega CD backup RAM (only odd bytes accessible)
backup_ram_end:		equ $FE3FFF

mcd_control_registers:		equ $FFFF8000 ; aka, the gate array
led_control:			equ	$FFFF8000 ; LED control register; BIOS use only
	red_led_bit:	equ	0 ; enable/disable red LED
	green_led_bit:	equ	1 ; enable/disable green LED
	red_led:		equ 1<<red_led_bit
	green_led:		equ 1<<green_led_bit

mcd_reset:			equ	$FFFF8001 ; reset and hardware version register
	peripheral_reset_bit:		equ 0	; set to 0 to initiate peripheral reset, reads 1 once reset is finished
	hardware_version:	equ	$F0		; hardware version bits

mcd_write_protect:	equ	$FFFF8002 ; read-only; returns write protection address set by main CPU
mcd_mem_mode:		equ $FFFF8003 ; word ram mode/swap and priority mode registers; first two bits have different meanings depending on 1M or 2M mode
	; 1M mode:
	bank_assignment_bit:	equ 0	; RET; set word RAM bank assignment; 0 = bank 0 main CPU and bank 1 sub CPU, 1 = bank 0 sub CPU and bank 1 main CPU; when read, returns 1 if swap is in progress
	bank_swap_request_bit:	equ 1	; DMNA; read-only; returns 1 while swap is in progress and 0 once it is complete
	; 2M mode:
	wordram_swapmain_bit:	equ 0	; RET; give word RAM to main CPU by setting to 1; returns 0 while swap is in progress and 1 once it is complete
	wordram_swapsub_bit:	equ 1	; DMNA; read-only, 0 = word RAM is assigned to main CPU; 1 = word RAM is assigned to sub CPU

	wordram_mode_bit:		equ 2	; MODE; 0 = 2M mode, 1 = 1M mode

	priority_underwrite_bit:	equ 3	; enables underwrite mode; data output from GFX ops will not overwrite blank pixels already in the image buffer, effectively rendering under the previous data
	priority_overwrite_bit:		equ 4	; enables overwrite mode; non-blank pixels output from GFX ops will write over existing data in image buffer, effectively rendering over the previous data
	priority_disabled:			equ 0 	; priority mode disabled; all data output from GFX ops is written
	priority_underwrite:		equ 1<<priority_underwrite_bit
	priority_overwrite:			equ 1<<priority_overwrite_bit

	program_ram_bank:			equ $C0	; bits 6 and 7

cdc_mode:		equ $FFFF8004	; CD data decoder mode and destination select register
	cdc_destination:		equ 7	; bits 0-2, destination of CD data read
		cdc_dest_main:			equ	2	; main CPU read from its instance of cdc_data_port
		cdc_dest_sub:			equ 3	; sub CPU read from cdc_data_port
		cdc_dest_pcm:			equ 4	; DMA to PCM waveram
		cdc_dest_prgram:		equ 5	; DMA to program RAM
		cdc_dest_wordram:		equ 7	; DMA to word RAM
	cdc_dataready_bit:		equ 6	; indicates data is ready to be read from cdc_data_port
	cdc_endtrans_bit:		equ 7	; indicates all data has been transferred

	;hibyte_ready_bit:	equ 5	; set when upper byte is sent from CD controller; cleared once full word is ready
	data_ready_bit:		equ 6	; set once full word of data is ready
	data_end_bit:		equ 7	; set once the data read is finished

cdc_rs0:		equ	$FFFF8005 ; CD data decoder control registers; BIOS use only
					; 	$FFFF0006 unused
cdc_rs1:		equ	$FFFF8007 ; CD data decoder control registers; BIOS use only

cdc_data_port:		equ	$FFFF8008 ; CD data out for sub CPU read
cdc_dma_dest:		equ	$FFFF800A ; CDC DMA destination address
	; bits 0-9 used for PCM waveram
	; bits 0-$D used for word RAM
	; all bits used for program RAM
mcd_stopwatch:		equ	$FFFF800C ; 12-bit timer

mcd_com_flags:		equ	$FFFF800E ; communication flags
mcd_main_flag:		equ	mcd_com_flags ; Main CPU communication flag
mcd_sub_flag:		equ	$FFFF800F ; Sub CPU communication flag

mcd_maincoms:		equ	$FFFF8010 ; communication from main CPU
mcd_maincom_0:		equ	mcd_maincoms		; $FFFF8010 ; communication command 0
mcd_maincom_0_lo:	equ	$FFFF8011 ; communication command 0
mcd_maincom_1:		equ	$FFFF8012 ; communication command 1
mcd_maincom_1_lo:	equ	$FFFF8013 ; communication command 1
mcd_maincom_2:		equ $FFFF8014 ; communication command 2
mcd_maincom_2_lo:	equ $FFFF8015 ; communication command 2
mcd_maincom_3:		equ	$FFFF8016 ; communication command 3
mcd_maincom_3_lo:	equ $FFFF8017 ; communication command 3
mcd_maincom_4:		equ	$FFFF8018 ; communication command 4
mcd_maincom_4_lo:	equ	$FFFF8019 ; communication command 4
mcd_maincom_5:		equ $FFFF801A ; communication command 5
mcd_maincom_5_lo:	equ $FFFF801B ; communication command 5
mcd_maincom_6:		equ	$FFFF801C ; communication command 6
mcd_maincom_6_lo:	equ	$FFFF801D ; communication command 6
mcd_maincom_7:		equ	$FFFF801E ; communication command 7
mcd_maincom_7_lo:	equ	$FFFF801F ; communication command 7

mcd_subcoms:		equ	$FFFF8020 ; communication to main CPU
mcd_subcom_0:		equ	mcd_subcoms	; $FFFF8020 ; communication status 0
mcd_subcom_0_lo:	equ	$FFFF8021 ; communication status 0
mcd_subcom_1:		equ	$FFFF8022 ; communication status 1
mcd_subcom_1_lo:	equ	$FFFF8023 ; communication status 1
mcd_subcom_2:		equ	$FFFF8024 ; communication status 2
mcd_subcom_2_lo:	equ $FFFF8025 ; communication status 2
mcd_subcom_3:		equ $FFFF8026 ; communication status 3
mcd_subcom_3_lo:	equ $FFFF8027 ; communication status 3
mcd_subcom_4:		equ	$FFFF8028 ; communication status 4
mcd_subcom_4_lo:	equ $FFFF8029 ; communication status 4
mcd_subcom_5:		equ $FFFF802A ; communication status 5
mcd_subcom_5_lo:	equ $FFFF802B ; communication status 5
mcd_subcom_6:		equ $FFFF802C ; communication status 6
mcd_subcom_6_lo:	equ $FFFF802D ; communication status 6
mcd_subcom_7:		equ $FFFF802E ; communication status 7
mcd_subcom_7_lo:	equ $FFFF802F ; communication status 7

mcd_timerint_interval:	equ	$FFFF8031 ; IRQ 3 timer; counts down from the 8-bit value written to this register, triggers IRQ 3 when it reaches 0; generally used for PCM driver timing

mcd_interrupt_control:	equ	$FFFF8033 	; enable/disable triggering of interrupts (NOT the same as the interrupts in the 68K status register)
	; WARNING: when BIOS is in use, ONLY gfx_int and timer_int are user-configurable.
	; The BIOS requires sub_vblank_int and cdd_int to ALWAYS be enabled, and will malfunction
	; if they are disabled. cdc_int and subcode_int are enabled/disabled as needed when BIOS calls
	; that require them are executed.

	gfx_int_bit:			equ 1	; triggered when a graphics operation completes (only while wordram is in 2M mode)
	sub_vblank_int_bit:		equ 2	; interrupt triggered by main CPU, generally on VBlank
	timer_int_bit:			equ 3	; triggered when timer set in mcd_timerint_interval reaches 0
	cdd_int_bit:			equ 4	; triggered by CD drive when reception of receiving status 7 is complete; used to manage processing of CD drive commands
	cdc_int_bit:			equ 5	; triggered by CD data controller when decoding a frame is complete
	subcode_int_bit:		equ 6	; triggered when 98 byte buffering of subcode is complete

	gfx_int:			equ 1<<gfx_int_bit
	sub_vblank_int:		equ 1<<sub_vblank_int_bit
	timer_int:			equ 1<<timer_int_bit
	cdd_int:			equ 1<<cdd_int_bit
	cdc_int:			equ 1<<cdc_int_bit
	subcode_int:		equ 1<<subcode_int_bit

; CD Drive control registers; BIOS use only
cdd_fader:	equ	$FFFF8034 	; CD drive fader control/spindle speed register
cdd_type:	equ	$FFFF8036 	; CD drive data type
cdd_ctrl:	equ	$FFFF8037 	; CD drive control register
cdd_communication:	equ	$FFFF8038 	; CD drive communication registers
cdd_status_0:	equ	cdd_status_0 	; CDD receive status 0
cdd_status_1:	equ	$FFFF8039 	; CDD receive status 1
cdd_status_2:	equ	$FFFF803A 	; CDD receive status 2
cdd_status_3:	equ	$FFFF803B 	; CDD receive status 3
cdd_status_4:	equ	$FFFF803C 	; CDD receive status 4
cdd_status_5:	equ	$FFFF3803D 	; CDD receive status 5
cdd_status_6:	equ	$FFFF803E 	; CDD receive status 6
cdd_status_7:	equ	$FFFF803F 	; CDD receive status 7
cdd_status_8:	equ	$FFFF8040 	; CDD receive status 8
cdd_status_9:	equ	$FFFF8041 	; CDD receive status 9
cdd_cmd_0:	equ	$FFFF8042 	; CDD transfer command 0
cdd_cmd_1:	equ	$FFFF8043 	; CDD transfer command 1
cdd_cmd_2:	equ	$FFFF8044 	; CDD transfer command 2
cdd_cmd_3:	equ	$FFFF8045 	; CDD transfer command 3
cdd_cmd_4:	equ	$FFFF8046 	; CDD transfer command 4
cdd_cmd_5:	equ	$FFFF8047 	; CDD transfer command 5
cdd_cmd_6:	equ	$FFFF8048 	; CDD transfer command 6
cdd_cmd_7:	equ	$FFFF8049 	; CDD transfer command 7
cdd_cmd_8:	equ	$FFFF804A 	; CDD transfer command 8
cdd_cmd_9:	equ	$FFFF804B 	; CDD transfer command 9

; Font generator registers
gfx_fontgen_color:	equ	$FFFF804C ; font color (only low byte is used, so could be written with byte operation at $FF840D)
	; bits 0-3 are color for bits set to 0 in the font bit register;
	; bits 4-7 are color for bits set to 1

gfx_fontgen_in:		equ	$FFFF804E 	; font source bitmap input
gfx_fontgen_out:	equ	$FFFF8050 	; finished font data, 8 bytes

; Graphics operation control registers
gfx_op_flag:	equ $FFFF8058
	gfx_op_bit:	equ 7	; set if a gfx op is in progress
	gfx_op:		equ 1<<gfx_op_bit
gfx_stampsize:	equ	$FFFF8059 	; stamp size/Map size
	stampmap_repeat_bit:	equ 0 ; 0 = repeat when end of map is reached, 1 = 0 data beyond map size is rendered as blank pixels
	stamp_size_bit:			equ 1 ; 0 = 16x16 pixels, 1 = 32x32 pixels
	stampmap_size_bit:		equ 2 ; 0 = 1x1 screen (256x256 pixels), 1 = 16x16 screen (4096x4096 pixels)

	stampmap_repeat:			equ 1<<stampmap_repeat_bit
	stamp_size_16x16:			equ 0
	stamp_size_32x32:			equ 1<<stamp_size_bit
	stampmap_size_256x256:		equ 0
	stampmap_size_4096x4096:	equ 1<<stampmap_size_bit

gfx_stampmap:	equ	$FFFF805A 	; start address of stamp map, expressed as offset relative to start of 2M word RAM divided by 4
	; Start offsets are limited to certain addresses as follows:
	; stamp_size_16x16|stampmap_size_256x256 = multiples of $200
	; stamp_size_32x32|stampmap_size_256x256 = multiples of $80
	; stamp_size_16x16|stampmap_size_4096x4096 = multiples of $20000
	; stamp_size_32x32|stampmap_size_4096x4096 = multiples of $8000

gfx_bufheight:	equ	$FFFF805C 	; image buffer height in tiles - 1 , maximum height is 32 tiles
gfx_imgstart:	equ	$FFFF805E 	; image buffer start address; same restrictions on location apply as with stampmaps
gfx_imgoffset:	equ	$FFFF8060 	; specifies an optional offset of up to 7 pixels on each axis, bits 0-2 horizontal, bits 3-5 vertical
gfx_img_hsize:	equ	$FFFF8062 	; image buffer width in pixels, maximum 511 pixels
gfx_img_vsize: 	equ	$FFFF8064 	; image buffer height in pixels, maximum 255 pixels
gfx_tracetbl:	equ	$FFFF8066 	; start address of trace vector table;  same restrictions on location apply as with stampmaps (writing this also triggers the start of a graphics operation)

; Subcode registers; BIOS use only
subcode_addr:	equ	$FFFF8068 	; subcode top address
mcd_subcode:		equ	$FFFF8100 	; 64 word subcode buffer
subcode_mirror:	equ	$FFFF8108  	; mirror of subcode buffer

; -------------------------------------------------------------------------
; BIOS status flags and jump table
; -------------------------------------------------------------------------

_SubCPUStack:	equ $5E80 ; sub CPU initial stack pointer

; BIOS status table and flags
; _BIOSStatus, _LEDStatus, and _CDStatus are updated by calling the BIOSStatus function
_BIOSStatus:	equ	$5E80	; _CDSTAT; CD BIOS status
_DriveInitStatus:	equ _BIOSStatus ; high nybble
	drive_ready_bit:	equ 7	; 0 = drive ready; 1 = drive busy
	tray_open_bit:	equ 6	; 1 = tray/door open
	toc_read_bit:	equ 5	; 1 = drive is reading disc TOC
	no_disc_bit:	equ 4	; 1 = no disc in drive
	drive_ready:	equ 1<<drive_ready_bit
	tray_open:		equ 1<<tray_open_bit
	toc_read:		equ 1<<toc_read_bit
	no_disc:		equ 1<<no_disc_bit
	toc_done:		equ 0
	drive_init_nybble:	equ no_disc|toc_read|tray_open|drive_ready

_CDDAStatus:	equ _BIOSStatus ; low nybble
	cdda_seek_bit:	equ 3	; 1 = drive is set to play CDDA in seek mode (i.e., set to stop at a specific track)
	cdda_pause_bit:	equ 2	; 1 = CDDA is paused
	cdda_scan_bit:	equ 1	; 1 = CDDA is scanning (i.e., fast forwarding or rewinding)
	disc_read_bit:	equ 0	; 1 = drive is reading disc (both playing red book CDDA and yellow book CD-ROM data)
	cdda_seek:		equ 1<<cdda_seek_bit
	cdda_pause:		equ 1<<cdda_pause_bit
	cdda_scan:		equ 1<<cdda_scan_bit
	disc_read:		equ 1<<disc_read_bit

_CDDataStatus:		equ _BIOSStatus+1	; $5E81
	data_seek_bit:	equ 3	; 1 = drive is set to read beginning at a specific logical sector
	data_pause_bit:	equ 2	; 1 = data read is paused
	data_read_bit:	equ 0	; 1 = drive is reading yellow book CD-ROM data
	data_seek:		equ 1<<data_seek_bit
	data_pause:		equ 1<<data_pause_bit
	data_read:		equ 1<<data_read_bit

_LEDStatus:		equ $5E82	; LED; indicates current status of front panel LEDs
	power_led_bit:	equ 9	; 1 = power LED (green; Model 1 only) is on
	access_led_bit:	equ 8	; 1 = access LED (green on WonderMega/X'Eye, red on all other devices) is on
	led_mode:		equ	$FF	; indicates current LED blink mode
		; Following values are also used to temporarily override system LED control using the LEDSet BIOS call
		led_ready:	equ 0	; power on, access flashing; CD ready and no disc
		led_discin:	equ 1	; power on, access off; CD ready and disc OK
		led_access:	equ 2	; both on; CD access
		led_standby:equ 3	; power flashing, access off; standby mode
		led_error:	equ 4	; both flashing
		led_mode5:	equ 5	; power flashing, access on
		led_mode6:	equ 6	; power off, access flashing
		led_mode7:	equ 7 	; power off, access on
		led_system:	equ $FFFFFFFF	; return LEDs to system control

_CDDStatus:			equ	$5E84 	; $20 bytes, contains information on the CD drive, the current disc, and CDDA playback status
	CDD_Status_Code:	equ 0
	CDD_Report_Code:	equ 1
	CDD_Disc_Control:	equ 2
	CDD_CurrentTrack:	equ 3 ; current CDDA track
	CDD_Abs_Time:		equ 4 ; 4 bytes, absolute time of disc in BCD
	CDD_Rel_Time:		equ 8 ; 4 bytes, relative time of disc in BCD
	CDD_FirstTrack:		equ $C	; first CDDA track number
	CDD_LastTrack:		equ $D ; last CDDA track number
	CDD_DriveVersion:	equ $E
	CDD_StatusFlags:	equ $F
		cdd_data_bit:		equ 2 ; 1 = reading yellow book data, 0 = reading CDDA
		cdd_emphasis_bit:	equ 1 ; 1 = emphasis 1
		cdd_mute_bit:		equ 0 ; 1 = mute on
		cdd_data:		equ 1<<cdd_data_bit
		cdd_emphasis:	equ 1<<cdd_emphasis_bit
		cdd_mute:		equ 1<<cdd_mute_bit
	CDD_StartTime:		equ $10	; 4 bytes, start time of read out area

_CDVolume:		equ $5E98
	cd_mastervol:	equ $FFFF0000	; bits 16-31; master volume
	cd_vol:			equ $FFF0	; bits 4-15
	cd_volemph:		equ $F	; emphasis enable flag

_CDFrameHeader:		equ $5E9C	; time written in frame which preceeds current data

_BootStatus:	equ	$5EA0	; boot system status
_UserMode:		equ	$5EA6	; system program return code

; BIOS call entry points
_SetJmpTbl:		equ	$5F0A	; set up the jump table for a new sub CPU user program
_WaitForVBlank:	equ	$5F10	; _WAITVSYNC; wait for next MDInt
_BackupRAM:		equ	$5F16	; _BURAM: backup RAM function entry
_CDBoot:		equ	$5F1C	; CD boot function entry
_CDBIOS:		equ	$5F22	; CD BIOS function entry

; User program entry points
_UserInit:		equ	$5F28	; _USERCALL0; user initialization code
_UserMain:		equ	$5F2E	; _USERCALL1; user program main entry point
_UserVBlank:	equ	$5F34	; _USERCALL2; user VBlank routine
_UserCall3:		equ	$5F3A	; _USERCALL3; user-defined call, not used by BIOS

; Exception vectors
_AddressError:	equ	$5F40	; _ADRERR; address error exception
_IllegalIns:	equ	$5F46	; _CODERR; illegal instruction exception
_DivZero:		equ	$5F4C	; _DEVERR; divide by zero exception
_ChkExcp:		equ	$5F52	; _CHKERR; CHK exception
_TrapV:			equ	$5F58	; _TRPERR; trap overflow exception
_PrivViol:		equ	$5F5E	; _SPVERR; privilege violation exception
_Trace:			equ	$5F64	; trace exception
_ALine:			equ	$5F6A	; _NOCOD0; A-line trap exception
_FLine:			equ	$5F70	; _NOCOD1; F-line trap exception

; Interrupt handler vectors
_GFXInt:		equ	$5F76	; _LEVEL1; graphics operation complete
_MDInt:			equ	$5F7C	; _LEVEL2; main CPU interrupt
_TimerInt:		equ	$5F82	; _LEVEL3; timer interrupt
_CDDInt:		equ	$5F88	; _LEVEL4; CD data interrupt
_CDCInt:		equ	$5F8E	; _LEVEL5: CD controller interrupt
_SubcodeInt:	equ	$5F94	; _LEVEL6; subcode interrupt
_Level7:		equ	$5F9A	; unused

; User trap vectors
_Trap0:			equ	$5FA0	; user trap exceptions 0-15
_Trap1:			equ	$5FA6
_Trap2:			equ	$5FAC
_Trap3:			equ	$5FB2
_Trap4:			equ	$5FB8
_Trap5:			equ	$5FBE
_Trap6:			equ	$5FC4
_Trap7:			equ	$5FCA
_Trap8:			equ	$5FD0
_Trap9:			equ	$5FD6
_Trap10:		equ	$5FDC
_Trap11:		equ	$5FE2
_Trap12:		equ	$5FE8
_Trap13:		equ	$5FEE
_Trap14:		equ	$5FF4
_Trap15:		equ	$5FFA

; -------------------------------------------------------------------------
; BIOS function calls

; Except for the boot and BURAM commands, these are used with the _CDBIOS
; entry point. Command IDs above $80 are executed in full on the spot;
; command IDs below $80 are queued and executed during CDD, CDC, and
; subcode interrupts.

; The descriptions are intended as an at-a-glace summary. See the MEGA CD
; BIOS manual for more complete explanations of each function and their
; usage. A copy can be obtained here:
; https://segaretro.org/images/archive/4/44/20190509114241%21MCDBios.pdf
; -------------------------------------------------------------------------

; CD boot commands
; Used with _CDBoot entry point; for debugging use only
BootInit:		equ	0 ; CBTINIT; initialize the boot system
BootInt:		equ	1 ; CBTINT; call the interrupt manager (should be done as part of the user VBlank routine while CD Boot system is active)
BootDiscOpen:	equ	2 ; CBTOPENDISC; same function as DriveOpen
BootOpenStat:	equ	3 ; CBTOPENSTAT; check whether a call to BootDiscOpen has completed
BootChkDisc:	equ	4 ; CBTCHKDISC; check whether a boot can be done or not
BootChkStatus:	equ	5 ; CBTCHKSTAT; check for boot completion and return the type of disc inserted

; BURAM commands
; Used with _BackupRAM entry point
BURAMInit:		equ	0 ; BRMINIT; prepare a BURAM read or write
BURAMStatus:	equ	1 ; BRMSTAT; return how much of the BURAM is used
BURAMSearch:	equ	2 ; BRMSERCH; search for a file in BURAM by name
BURAMRead:		equ	3 ; BRMREAD; read a file from BURAM
BURAMWrite:		equ	4 ; BRMWRITE; write a file to BURAM
BURAMDelete:	equ	5 ; BRMDEL;	delete a file from BURAM
BURAMFormat:	equ	6 ; BRMFORMAT; initialize and format a directory
BURAMReadDir:	equ	7 ; BRMDIR; read a directory in BURAM
BURAMVerify:	equ	8 ; BRMVERIFY; check data written to BURAM

; CD audio control commands
MusicStop:			equ	2	; MSCSTOP; stop playing CD audio
MusicPauseOn:		equ	3	; MSCPAUSEON; pause CD audio
MusicPauseOff:		equ	4	; MSCPAUSEOFF:	resume CD audio
MusicScanForward:	equ	5	; MSCSCANFF: fast forward CD audio
MusicScanBackward:	equ	6	; MSCSCANFR: rewind CD audio
MusicScanOff:		equ	7	; MSCSCANOFF: cancel fast forward or rewind and return to normal playback
MusicPlay:			equ	$11	; MSCPLAY; play CD audio starting from a designated track and continuing through entire disc
MusicPlayOnce:		equ	$12	; MSCPLAY1; play a CD track once
MusicPlayRepeat:	equ	$13	; MSCPLAYR:	play a CD track on loop
MusicPlayAtTime:	equ	$14	; MSCPLAYT;	queue a CD track and play it at a designated time
MusicSeek:			equ	$15	; MSCSEEK; stop CD playback upon reaching a specific track
MusicSeekTime:		equ	$16 ; MSCSEEKT; stop CD playback at a specific time
MusicSeekPlayOnce:	equ	$19	; MSCSEEK1; stop CD playback after reaching a specific track
FaderSet:			equ	$85 ; FDRSET; set CD audio volume
FaderChg:			equ	$86 ; FDRGHG; change CD audio volume at a specified speed

; Drive control commands
DriveOpen:	equ	$A	; DRVOPEN; open the disc tray if an MCD Model 1 or Pioneer LaserActive (Mega LD), otherwise wait for user to open drive door
DriveInit:	equ	$10	; DRVINIT; close the disc tray if an MCD Model 1 or Pioneer LaserActive, and check for disc; if found, get TOC data and optionally start playing music automatically

; CD data read/decoder commands
ROMPauseOn:		equ	8	; ROMPAUSEON; pause a CD data read
ROMPauseOff:	equ	9	; ROMPAUSEOFF; resume CD data read
ROMRead:		equ	$17 ; ROMREAD; begin CD data read from a specific logical sector
ROMSeek:		equ	$18	; ROMSEEK; stop CD data read at a specific logical sector
ROMReadNum:		equ	$20 ; ROMREADN; begin CD data read at a specific logical sector and read a specific number of sectors
ROMReadBetween:	equ	$21	; ROMREADE; perform CD data read between two designated logical sectors
DecoderStart:		equ	$87	; CDCSTART: begin data readout from current logical sector
DecoderStartP:		equ	$88 ; CDCSTARTP
DecoderStop:		equ	$89	; CDCSTOP; terminate read and discard current sector
DecoderStatus:		equ	$8A	; CDCSTAT; check if data is ready
DecoderRead:		equ	$8B ; CDCREAD; if data is ready, prepare to read one frame
DecoderTransfer:	equ	$8C ; CDCTRN; transfer data from cdc_data_port to a location in the Sub CPU's address space
DecoderAck:			equ	$8D	; CDCACK; let the decoder know we are done reading a frame

; Subcode commands
SubcodeInit:		equ	$8E	; SCDINIT; initialize the subcode system
SubcodeStart:		equ	$8F ; SCDSTART; begin reading subcode
SubcodeStop:		equ	$90 ; SCDSTOP; stop subcode read
SubcodeStatus:		equ	$91 ; SCDSTAT; get error status of subcode system
SubcodeReadRW:		equ	$92 ; SCDREAD; read R and W codes from subcode
SubcodeReadPQ:		equ	$93 ; SCDPQ; retrive P and Q codes from subcode (WARNING: THIS FUNCTION IS BROKEN IN ALL NORTH AMERICAN MODELS!)
SubcodeLastPQ:		equ	$94 ; SCDPQL; get the last P and Q codes

; Misc BIOS commands
ChkBIOS:		equ	$80 ; CDBCHK; check if CD drive control, data read, or CD audio operations have finished
BIOSStatus:		equ	$81	; CDBSTAT; get status of the BIOS and CD drive and write to _BIOSStatus
TOCWrite:		equ	$82	; CDBTOCWRITE; modify the TOC table
TOCRead:		equ	$83	; CDBTOCREAD; read the TOC table
StandbyWait:	equ	$84	; CDBPAUSE; set time to wait while paused before entering standby mode
LEDSet:			equ	$95	; LEDSET; set mode of front LEDs; intended for debugging use only
