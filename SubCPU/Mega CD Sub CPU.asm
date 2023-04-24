; ---------------------------------------------------------------------------
; Mega CD Mode 1 Sub CPU hardware addresses and BIOS Functions
; ---------------------------------------------------------------------------

program_ram:		equ	0 ; Mega CD Program RAM
program_ram_end:	equ	$80000	; MCD PRG-RAM end

word_ram:			equ $80000 ; Mega CD Word RAM
word_ram_2M:		equ	word_ram	; MCD Word RAM start (2M)
word_ram_2M_end:	equ	$C0000	; MCD Word RAM end (2M)

word_ram_1M:		equ	$C0000	; MCD Word RAM start (1M/1M)
word_ram_1M_end:	equ	$E0000	; MCD Word RAM end (1M/1M)

; Equates for the PCM chip are in Sound/Sound Equates (PCM).asm

; Backup RAM
backup_ram:			equ	$FE0000	; Mega CD backup RAM (only odd bytes accessible)
backup_ram_end:		equ $FE3FFF	

mcd_control_registers:		equ $FFFF8000			; Mega CD gate array
mcd_led_control:			equ	$FFFF8000 ; LED control register (BIOS control only)
	red_led_bit:	equ	0 ; enable/disable red LED
	green_led_bit:	equ	1 ; enable/disable red LED
	red_led:		equ 1<<red_led_bit
	green_led:		equ 1<<green_led_bit

mcd_reset:			equ	$FFFF8001 ; reset and hardware version register
	peripheral_reset_bit:		equ 0	; set to 0 to initiate peripheral, reset reads 1 once reset is finished
	hardware_version:	equ	$F0		; hardware version bits
	
mcd_write_protect:	equ	$FFFF8002 ; read-only; returns write protection address set by main CPU
mcd_mem_mode:		equ $FFFF8003 ; word ram mode/swap and priority mode registers; first two bits have different meanings depending on 1M or 2M mode
	; 1M mode:
	bank_assignment_bit:	equ 0	; RET; set word RAM bank assignment; 0 = bank 0 main CPU and bank 1 sub CPU, 1 = bank 0 sub CPU and bank 1 main CPU; when read, returns 1 if swap is in progress
	bank_swap_request_bit:	equ 1	; DMNA; read-only; returns 1 while swap is in progress and 0 once it is complete
	; 2M mode:	
	wordram_swaptomain_bit:	equ 0	; RET; give word RAM to main CPU by setting to 1; returns 0 while swap is in progress and 1 once it is complete
	wordram_swaptosub_bit:	equ 1	; DMNA; read-only, returns 0 while swap is in progress and 1 once it is complete
	
	wordram_mode_bit:		equ 2	; MODE; 0 = 2M mode, 1 = 1M mode
	
	priority_underwrite_bit:	equ 3	; enable underwrite mode
	priority_overwrite_bit:		equ 4	; enable overwrite mode
	priority_underwrite:		equ 1<<priority_underwrite_bit
	priority_overwrite:			equ 1<<priority_overwrite_bit			 
	
mcd_cdc_mode:		equ $FFFF8004; CD data controller mode and device destination register
	cd_destination:		equ 7	; bits 0-2, destination of CD data read
	cd_dest_main:		equ	2	; main CPU read from mcd_cdc_host
	cd_dest_sub:		equ 3	; sub CPU read from mcd_cdc_host
	cd_dest_pcm:		equ 4	; DMA to PCM sound source
	cd_dest_prgram:		equ 5	; DMA to program RAM
	cd+dest_wordram:	equ 7	; DMA to word RAM
	
	hibyte_ready_bit:	equ 5	; set when upper byte is sent from CD controller, cleared once full word is ready
	data_ready_bit:		equ 6	; set once full word of data is ready
	data_end_bit:		equ 7	; set once the data read is finished
	
mcd_cdc_rs0:		equ	$FFFF8005 ; CDC control registers, user use prohibited
; $FFFF0006 unused
mcd_cdc_rs1:		equ	$FFFF8007 ; CDC control registers, user use prohibited

mcd_cdc_host:		equ	$FFFF8008 ; CD data out for sub CPU read
mcd_cdc_dma_dest:	equ	$FFFF800A ; CDC DMA destination address
	; bits 0-9 used for PCM sound source
	; bits 0-$D used for word RAM
	; all bits used for program RAM
mcd_stopwatch:		equ	$FFFF800C ; 12-bit timer

mcd_com_flags:		equ	$FFFF800E ; Communication flags
mcd_main_flag:		equ	mcd_com_flags ; Main CPU communication flag
mcd_sub_flag:		equ	$FFFF800F ; Sub CPU communication flag

mcd_maincoms:		equ	$FFFF8010 ; Communication from main CPU
mcd_maincom_0:		equ	mcd_maincoms		; $FFFF8010 ; Communication command 0
mcd_maincom_0_lo:	equ	$FFFF8011 ; Communication command 0
mcd_maincom_1:		equ	$FFFF8012 ; Communication command 1
mcd_maincom_1_lo:	equ	$FFFF8013 ; Communication command 1
mcd_maincom_2:		equ $FFFF8014 ; Communication command 2
mcd_maincom_2_lo:	equ $FFFF8015 ; Communication command 2
mcd_maincom_3:		equ	$FFFF8016 ; Communication command 3
mcd_maincom_3_lo:	equ $FFFF8017 ; Communication command 3
mcd_maincom_4:		equ	$FFFF8018 ; Communication command 4
mcd_maincom_4_lo:	equ	$FFFF8019 ; Communication command 4
mcd_maincom_5:		equ $FFFF801A ; Communication command 5
mcd_maincom_5_lo:	equ $FFFF801B ; Communication command 5
mcd_maincom_6:		equ	$FFFF801C ; Communication command 6
mcd_maincom_6_lo:	equ	$FFFF801D ; Communication command 6
mcd_maincom_7:		equ	$FFFF801E ; Communication command 7
mcd_maincom_7_lo:	equ	$FFFF801F ; Communication command 7

mcd_subcoms:		equ	$FFFF8020 ; Communication to main CPU
mcd_subcom_0:		equ	mcd_subcoms	; $FFFF8020 ; Communication status 0
mcd_subcom_0_lo:	equ	$FFFF8021 ; Communication status 0
mcd_subcom_1:		equ	$FFFF8022 ; Communication status 1
mcd_subcom_1_lo:	equ	$FFFF8023 ; Communication status 1
mcd_subcom_2:		equ	$FFFF8024 ; Communication status 2
mcd_subcom_2_lo:	equ $FFFF8025 ; Communication status 2
mcd_subcom_3:		equ $FFFF8026 ; Communication status 3
mcd_subcom_3_lo:	equ $FFFF8027 ; Communication status 3
mcd_subcom_4:		equ	$FFFF8028 ; Communication status 4
mcd_subcom_4_lo:	equ $FFFF8029 ; Communication status 4
mcd_subcom_5:		equ $FFFF802A ; Communication status 5
mcd_subcom_5_lo:	equ $FFFF802B ; Communication status 5
mcd_subcom_6:		equ $FFFF802C ; Communication status 6
mcd_subcom_6_lo:	equ $FFFF802D ; Communication status 6
mcd_subcom_7:		equ $FFFF802E ; Communication status 7
mcd_subcom_7_lo:	equ $FFFF802F ; Communication status 7

mcd_timer_interrupt:	equ	$FFFF8031 ; IRQ 3 timer; counts down from the 8-bit value written, triggers IRQ 3 when it reaches 0

mcd_interrupt_control:	equ	$FFFF8032 	; enable/disable triggering of interrupts (NOT the same as the interrupts in the 68K status register)
	; WARNING: ONLY levels 1 and 3 are user-configurable when BIOS is in use.
	graphics_done_int:	equ 1	; triggered in 1M mode when a graphics operation is complete
	sub_vblank_int:		equ 2	; interrupt triggered by main CPU, usually on VBlank
	timer_int:			equ 3	; triggered when timer set with mcd_timer_interrupt reaches 0
	cdd_int:			equ 4	; triggered by CD drive when reception of receiving status 7 is complete
	cdc_int:			equ 5	; triggered by CD data controller when error correction is complete
	subcode_int:		equ 6	; triggered when 98 byte buffering of subcode is complete

; CD Drive control registers
; USER ACCESS PROHIBITED!
mcd_cdd_fader:	equ	$FFFF8034 	; CD drive fader control/spindle speed register
mcd_cdd_type:	equ	$FFFF8036 	; CD drive data type
mcd_cdd_ctrl:	equ	$FFFF8037 	; CD drive control register
mcd_cdd_communication:	equ	$FFFF8038 	; CD drive communication registers
mcd_cdd_status_0:	equ	mcd_cdd_status_0 	; CDD receive status 0
mcd_cdd_status_1:	equ	$FFFF8039 	; CDD receive status 1
mcd_cdd_status_2:	equ	$FFFF803A 	; CDD receive status 2
mcd_cdd_status_3:	equ	$FFFF803B 	; CDD receive status 3
mcd_cdd_status_4:	equ	$FFFF803C 	; CDD receive status 4
mcd_cdd_status_5:	equ	$FFFF3803D 	; CDD receive status 5
mcd_cdd_status_6:	equ	$FFFF803E 	; CDD receive status 6
mcd_cdd_status_7:	equ	$FFFF803F 	; CDD receive status 7
mcd_cdd_status_8:	equ	$FFFF8040 	; CDD receive status 8
mcd_cdd_status_9:	equ	$FFFF8041 	; CDD receive status 9
mcd_cdd_cmd_0:	equ	$FFFF8042 	; CDD transfer command 0
mcd_cdd_cmd_1:	equ	$FFFF8043 	; CDD transfer command 1
mcd_cdd_cmd_2:	equ	$FFFF8044 	; CDD transfer command 2
mcd_cdd_cmd_3:	equ	$FFFF8045 	; CDD transfer command 3
mcd_cdd_cmd_4:	equ	$FFFF8046 	; CDD transfer command 4
mcd_cdd_cmd_5:	equ	$FFFF8047 	; CDD transfer command 5
mcd_cdd_cmd_6:	equ	$FFFF8048 	; CDD transfer command 6
mcd_cdd_cmd_7:	equ	$FFFF8049 	; CDD transfer command 7
mcd_cdd_cmd_8:	equ	$FFFF804A 	; CDD transfer command 8
mcd_cdd_cmd_9:	equ	$FFFF804B 	; CDD transfer command 9

; Font generator registers
gfx_fontgen_color:	equ	$FFFF804C ; font color (only low byte is used, so could be written with byte operation at $FF840D)
	; bits 0-3 are color for bits set to 0 in the font bit register;
	; bits 4-7 are color for bits set to 1

gfx_fontgen_in:		equ	$FFFF804E 	; font source bitmap input
gfx_fontgen_out:	equ	$FFFF8050 	; finished font data, 8 bytes

; Graphics transformation control registers
gfx_stampsize:	equ	$FFFF8058 	; stamp size/Map size
	stampmap_repeat_bit:	equ 0 ; 0 = repeat when end of map is reached, 1 = 0 data beyond map size is set to 0
	stamp_size_bit:			equ 1 ; 0 = 16x16 pixels, 1 = 32x32 pixels
	stampmap_size_bit:		equ 2 ; 0 = 1x1 screen (256x256 pixels), 1 = 16x16 screen (4096x4096 pixels) 

	stampmap_repeat:			equ 1<<stampmap_repeat_bit
	stamp_size_16x16:			equ 0
	stamp_size_32x32:			equ 1<<stamp_size_bit
	stampmap_size_256x256:		equ 0
	stampmap_size_4096x4096:	equ 1<<stampmap_size_bit
	
gfx_stampmap:	equ	$FFFF805A 	; base address of stamp map, expressed as offset relative to start of 2M word RAM
	; todo; what are the limitations on starting offsets?
	
gfx_bufheight:	equ	$FFFF805C 	; image buffer height in tiles, 0-32

gfx_imgstart:	equ	$FFFF805E 	; image buffer start address
gfx_imgoffset:	equ	$FFFF8060 	; image buffer offset
gfx_img_hsize:	equ	$FFFF8062 	; image buffer width in pixels
gfx_img_vsize: 	equ	$FFFF8064 	; image buffer height in pixels

gfx_tracetbl:	equ	$FFFF8066 	; trace vector base address

; Subcode registers
; User access prohibited.
mcd_subcode_addr:	equ	$FFFF8068 						; subcode top address
mcd_subcode:		equ	$FFFF8100 		; 64 word subcode buffer
mcd_subcode_mirror:	equ	equ	$FFFF8108  	; mirror of subcode buffer

; -------------------------------------------------------------------------
; BIOS function calls
; -------------------------------------------------------------------------

;		rsset 2

MSCSTOP		equ	$02
MSCPAUSEON	equ	$03
MSCPAUSEOFF	equ	$04
MSCSCANFF	equ	$05
MSCSCANFR	equ	$06
MSCSCANOFF	equ	$07

ROMPAUSEON	equ	$08
ROMPAUSEOFF	equ	$09

DRVOPEN		equ	$0A	; open the disc tray on Mega CD Model 1s and Pioneer LaserActive; wait for user to open drive door on all other devices
DRVINIT		equ	$10

MSCPLAY		equ	$11
MSCPLAY1	equ	$12
MSCPLAYR	equ	$13
MSCPLAYT	equ	$14
MSCSEEK		equ	$15
MSCSEEKT	equ	$16

ROMREAD		equ	$17
ROMSEEK		equ	$18

MSCSEEK1	equ	$19
TESTENTRY	equ	$1E
TESTENTRYLOOP	equ	$1F

ROMREADN	equ	$20
ROMREADE	equ	$21

CDBCHK		equ	$80
CDBSTAT		equ	$81
CDBTOCWRITE	equ	$82
CDBTOCREAD	equ	$83
CDBPAUSE	equ	$84

FDRSET		equ	$85
FDRCHG		equ	$86

CDCSTART	equ	$87
CDCSTARTP	equ	$88
CDCSTOP		equ	$89
CDCSTAT		equ	$8A
CDCREAD		equ	$8B
CDCTRN		equ	$8C
CDCACK		equ	$8D

SCDINIT		equ	$8E
SCDSTART	equ	$8F
SCDSTOP		equ	$90
SCDSTAT		equ	$91
SCDREAD		equ	$92
SCDPQ		equ	$93
SCDPQL		equ	$94

LEDSET		equ	$95

CDCSETMODE	equ	$96

WONDERREQ	equ	$97
WONDERCHK	equ	$98

CBTINIT		equ	$00
CBTINT		equ	$01
CBTOPENDISC	equ	$02
CBTOPENSTAT	equ	$03
CBTCHKDISC	equ	$04
CBTCHKSTAT	equ	$05
CBTIPDISC	equ	$06
CBTIPSTAT	equ	$07
CBTSPDISC	equ	$08
CBTSPSTAT	equ	$09

BRMINIT		equ	$00
BRMSTAT		equ	$01
BRMSERCH	equ	$02
BRMREAD		equ	$03
BRMWRITE	equ	$04
BRMDEL		equ	$05
BRMFORMAT	equ	$06
BRMDIR		equ	$07
BRMVERIFY	equ	$08

; -------------------------------------------------------------------------
; BIOS entry points
; -------------------------------------------------------------------------

_AddressError:	equ	$005F40	; _ADRERR; address error exception
_BootStatus:	equ	$005EA0	; boot status
_BackupRAM:		equ	$005F16	; backup RAM function entry
_CDBIOS:		equ	$005F22	; CD BIOS function entry
_CDBoot:		equ	$005F1C	; CD boot system
_CDStatus:		equ	$005E80	; CD status
_ChkExcp:		equ	$005F52	; _CHKERR; CHK exception		
_IllegalIns:	equ	$005F46	; _CODERR; illegal instruction exception
_DivByZero:		equ	$005F4C	; _DEVERR; divide by zero exception

_GFXInt:		equ	$005F76	; _LEVEL1; graphics operation complete
_MDInt:			equ	$005F7C	; _LEVEL2; main CPU interrupt
_TimerInt:		equ	$005F82	; _LEVEL3; timer interrupt
_CDDInt:		equ	$005F88	; _LEVEL4; CD data interrupt
_CDCInt:		equ	$005F8E	; _LEVEL5: CD controller interrupt
_SubcodeInt:	equ	$005F94	; _LEVEL6; subcode interrupt
_Level7:		equ	$005F9A	; unused
_ALine:			equ	$005F6A	; _NOCOD0; unimplemented A-line trap exception
_FLine:			equ	$005F70	; _NOCOD1; unimplemented F-line trap exception
_SetJmpTbl:		equ	$005F0A	; set up a module
_PrivViol:		equ	$005F5E	; _SPVERR; privilege violation exception
_Trace:			equ	$005F64	; trace exception
_Trap00:		equ	$005FA0	; user trap exceptions 0-15
_Trap01:		equ	$005FA6
_Trap02:		equ	$005FAC
_Trap03:		equ	$005FB2
_Trap04:		equ	$005FB8
_Trap05:		equ	$005FBE
_Trap06:		equ	$005FC4
_Trap07:		equ	$005FCA
_Trap08:		equ	$005FD0
_Trap09:		equ	$005FD6
_Trap10:		equ	$005FDC
_Trap11:		equ	$005FE2
_Trap12:		equ	$005FE8
_Trap13:		equ	$005FEE
_Trap14:		equ	$005FF4
_Trap15:		equ	$005FFA
_TrapV:			equ	$005F58	; _TRPERR; trap overflow exception

_UserInit:		equ	$005F28	; _USERCALL0; user initialization code
_UserMain:		equ	$005F2E	; _USERCALL1; user program main entry point	
_UserVBlank:	equ	$005F34	; _USERCALL2; user VBlank routine
_UserCall3:		equ	$005F3A	; user-defined call, not used by BIOS, can be set to point to anything
_userMode:		equ	$005EA6	; system program return code
_WaitForVBlank:	equ	$005F10	; _WAITVSYNC