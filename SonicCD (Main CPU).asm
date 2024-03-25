;  =========================================================================
; |					       Sonic the Hedgehog CD Mode 1						|
; |								Main CPU Program							|
;  =========================================================================

; 	Based on the partial disassembly of the Mode 2 original by Devon.

;  =========================================================================


		opt	l.					; . is the local label symbol
		opt	ae-					; automatic evens are disabled by default
		opt	ws+					; allow statements to contain white-spaces
		opt	an+					; allow use of -h for hexadecimal (used in Z80 code)
		opt	w+					; print warnings
		opt	m+					; do not expand macros - if enabled, this can break assembling

Main:	group word,org(0) ; we have to use the long form of group declaration to avoid triggering an overlay warning during assembly
		section MainProgram,Main


MainCPU: equ 1 ; enable some debugging features for Main CPU only

		include "Macros - More CPUs.asm"	; Z80 support macros
		cpu 68000


		include "Mega CD Main CPU (Mode 1).asm"		; Mega CD Mode 1 main CPU hardware addresses and function macros
		include "includes/Debugger Macros and Common Defs.asm"	; error handler definitions common to both CPUs
		include "Common Macros.asm"					; macros common to both main and sub CPU programs
		include "Macros (Main CPU).asm"
	;	include "File List.asm"
		include "Constants (Main CPU).asm"
		include "RAM Addresses (Main CPU).asm"
	;	include "VRAM Addresses.asm"
	;	include "Sub CPU Commands.asm"

	;	include "sound/Main CPU Sound Equates.asm"
	;	include "sound/Main CPU Frequency, Note, Envelope, & Sample Definitions.asm" ; definitions used in both the Z80 sound driver and SMPS2ASM
	;	include "sound/Sound Language.asm" ; SMPS2ASM macros and conversion functionality
	;	include "sound/FM and PSG Sounds.asm"
	;	include "sound/PCM Sounds.asm"

ROM_Start:
	if offset(*) <> 0
		inform 3,"ROM_Start was $%h but it should be 0.",ROM_Start
	endc

Vectors:
		dc.l v_stack_pointer	; Initial stack pointer value
		dc.l EntryPoint					; Start of program
		dc.l BusError					; Bus error
		dc.l AddressError				; Address error
		dc.l IllegalInstr				; Illegal instruction
		dc.l ZeroDivide					; Division by zero
		dc.l ChkInstr					; CHK exception
		dc.l TrapvInstr					; TRAPV exception
		dc.l PrivilegeViol				; Privilege violation
		dc.l Trace						; TRACE exception
		dc.l Line1010Emu				; Line-A emulator
		dc.l Line1111Emu				; Line-F emulator
		dcb.l 2,ErrorExcept				; Unused (reserved)
		dc.l ErrorExcept				; Format error
		dc.l ErrorExcept				; Uninitialized interrupt
		dcb.l 8,ErrorExcept				; Unused (reserved)
		dc.l ErrorExcept				; Spurious exception
		dc.l ErrorExcept					; IRQ level 1
		dc.l ErrorExcept					; IRQ level 2
		dc.l ErrorExcept					; IRQ level 3
		dc.l HBlank						; IRQ level 4 (horizontal interrupt)
		dc.l ErrorExcept					; IRQ level 5
		dc.l VBlank						; IRQ level 6 (vertical interrupt)
		dc.l ErrorExcept					; IRQ level 7
		dc.l SubCPUError
		dc.l DMAQueueOverflow
		dcb.l 14,ErrorExcept				; TRAP #00..#15 exceptions
		dcb.l 16,ErrorExcept			; Unused (reserved)


Header:
;	if region=japan
;		dc.b	"SEGA DISC SYSTEM"	; Hardware ID
;		dc.b	"(C)SEGA 1993.AUG"	; Release date
;	elseif region=usa
		dc.b	"SEGA DISC SYSTEM"	; Hardware ID
		dc.b	"(C)SEGA 1993.OCT"	; Release date
;	else
;		dc.b	"SEGA DISC SYSTEM"	; Hardware ID
;		dc.b	"(C)SEGA 1993.AUG"	; Release date
;	endc
		dc.b 'SONIC THE HEDGEHOG-CD                           ' ; Domestic name
		dc.b 'SONIC THE HEDGEHOG-CD                           ' ; International name

;	if region=japan				; Game version
;		dc.b	"GM G-6021  -00"
;	elseif region=usa
		dc.b	"GM MK-4407 -00"
;	else
;		dc.b	"GM MK-4407-00 "
;    endc
Checksum:
		dc.w $0000			; Checksum
		dc.b 'JC              ' ; I/O Support : joypad and CD-ROM
ROMStartLoc:
		dc.l Rom_Start			; ROM Start
ROMEndLoc:
		dc.l $FFFFF
					; ROM End
RAMStartLoc:
		dc.l $FF0000		; RAM Start
RAMEndLoc:
		dc.l $FFFFFF		; RAM End
	;	dc.b "RA", $A0+(BackupSRAM<<6)+(AddressSRAM<<3),$20
		dc.b "   "
		dc.l $200000					; SRAM start
		dc.l $200FFF					; SRAM end
		dc.b '                                                          ' ; Notes
		dc.b '      '
		dc.b 'JUE             ' ; Country
EndOfHeader:
; ===========================================================================

		include "includes/main/Mega CD Initialization.asm"	; EntryPoint
; ===========================================================================

SubCrash1:
		trap #0
; ===========================================================================

WaitSubInit:
	;	bset	#wordram_swapsub_bit,(mcd_mem_mode).l ; give wordram to the sub CPU

		moveq	#'R',d0		; flag for initialization success
		lea	mcd_subcom_0-mcd_mem_mode(a3),a3

WaitReady:
		cmpi.b	#$FF,mcd_sub_flag-mcd_subcom_0(a3)	; is sub CPU OK?
		beq.s	SubCrash1				; branch if not
		cmp.b	(a3),d0		; is sub CPU done initializing?
		bne.s	WaitReady				; branch if not

		move.b	mcd_subcom_1-mcd_subcom_0(a3),(v_disc_status).w	; get disc status from sub CPU
		move.b	d0,mcd_maincom_0-mcd_subcom_0(a3)	; acknowledge

	.waitack:
		tst.b	(a3)	; is sub CPU ready?
		bne.s	.waitack						; branch if not

		clr.b	mcd_maincom_0-mcd_subcom_0(a3)	; we are ready to send commands

		vdp_comm.l	move,0,cram,write,(vdp_control_port).l

		moveq	#cRed,d0		; red no disc
		moveq	#0,d1

		move.b	(v_disc_status).w,d1	; get disc status
		tst.b	d1
		beq.s	.setcolor	; branch if no disc

		move.w	#cGreen,d0	; green if disc match
		cmpi.b	#2,d1
		beq.s	.setcolor

		move.w	#cBlue,d0	; blue if disc present but no match

	.setcolor:
		move.w	d0,(vdp_data_port).l	; set color

MainLoop:
		cmpi.b	#$FF,mcd_sub_flag-mcd_subcom_0(a3)	; is sub CPU OK?
		beq.s	SubCrash1
		bra.s 	MainLoop							; stay here forever
; ===========================================================================

gmptr:		macro
		id_\1:	equ offset(*)-GameModeArray
		if narg=1
		bra.w	GM_\1
		else
		bra.w	GM_\2
		endc
		endm


GameModeArray:

	;	gmptr	Sega			; 0
	;	gmptr	Title			; 4
	;	gmptr	Demo,Level		; 8
	;	gmptr	Level			; $C
	;	gmptr 	TimeWarp		; $10
	;	gmptr	SpecialStage	; $14
	;	gmptr	BURAM_SRAMManager	; $18
	;	gmptr	DAGarden		; $1C
	;	gmptr	FMV				; $20
	;	gmptr 	SoundTest		; $24
	;	gmptr	EasterEgg		; $28
	;	gmptr 	StageSelect		; $2C
	;	gmptr	BestStaffTimes	; $30
; ===========================================================================

		include "includes/main/KosM to PrgRAM.asm"
		include "includes/main/Kosinski Decompression.asm"

		include "includes/main/VBlank.asm"

; ===========================================================================

SubCPU_Program:
		incbin	"SonicCD (Sub CPU).kosm"
		even
; ===========================================================================

		include "includes/main/Mega CD Exception Handler (Main CPU).asm"

ROM_End:
		end





