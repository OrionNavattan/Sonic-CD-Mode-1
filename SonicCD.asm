;  =========================================================================
; |					       Sonic the Hedgehog CD Mode 1						|
;  =========================================================================

; Based on the disassembly of the Mode 2 original by Ralakaimus.
; Includes Clownancy's ported Sonic 3 Z80 sound driver,
; Ralakaimus' Mega CD Mode 1 init library,
; and Vladikcomper's optimized Nemdec and Kosdec routines.

;  =========================================================================


		opt	l.					; . is the local label symbol
		opt	ae-					; automatic evens are disabled by default
		opt	ws+					; allow statements to contain white-spaces
		opt	w+					; print warnings
		opt	m+					; do not expand macros - if enabled, this can break assembling
		
Main	section org(0)

FixBugs = 0		; Leave at 0 to preserve a handful of bugs and oddities in the original game.
				; Set to 1 to fix them.
				
				; Region setting is done in the build script.


		include "Macros - More CPUs.asm"	; Z80 support macros
		cpu 68000
		
		include "Main CPU Hardware.asm" 			; Main CPU hardware addresses, including CD gate array, and hardware function macros
		include "Common Macros.asm"					; Macros common to both main and sub CPU programs
		include "Main CPU Macros.asm"				; Main CPU program macros
		include "Main CPU Constants.asm"			; Main CPU program constants
		include "Main CPU RAM Addresses.asm"		; Main CPU variables
		
		include "SpritePiece.asm"					; Sprite mapping macros
		include "SMPS2ASM.asm"						; SMPS2ASM
		
ROM_Start:
   if * <> 0
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
		dc.l Trace					; TRACE exception
		dc.l Line1010Emu				; Line-A emulator
		dc.l Line1111Emu				; Line-F emulator
		dcb.l 2,ErrorExcept				; Unused (reserved)
		dc.l ErrorExcept				; Format error
		dc.l ErrorExcept				; Uninitialized interrupt
		dcb.l 8,ErrorExcept				; Unused (reserved)
		dc.l ErrorExcept				; Spurious exception
		dc.l ErrorTrap					; IRQ level 1
		dc.l ErrorTrap					; IRQ level 2
		dc.l ErrorTrap					; IRQ level 3
		dc.l HBlank					; IRQ level 4 (horizontal retrace interrupt)
		dc.l ErrorTrap					; IRQ level 5
		dc.l VBlank					; IRQ level 6 (vertical retrace interrupt)
		dc.l ErrorTrap					; IRQ level 7
		dcb.l 16,ErrorTrap				; TRAP #00..#15 exceptions
		dcb.l 16,ErrorTrap			; Unused (reserved)

	
Header:		
	if region=japan
		dc.b	"SEGA MEGA DRIVE "	; Hardware ID
		dc.b	"(C)SEGA 1993.AUG"	; Release date
	elseif region=usa
		dc.b	"SEGA GENESIS    "	; Hardware ID
		dc.b	"(C)SEGA 1993.OCT"	; Release date
	else
		dc.b	"SEGA MEGA DRIVE "	; Hardware ID
		dc.b	"(C)SEGA 1993.AUG"	; Release date
	endif	
		dc.b 'SONIC THE HEDGEHOG-CD                           ' ; Domestic name
		dc.b 'SONIC THE HEDGEHOG-CD                           ' ; International name
	
	if region=japan				; Game version
		dc.b	"GM G-6021  -00  "
	elseif region=usa
		dc.b	"GM MK-4407 -00  "
	else
		dc.b	"GM MK-4407-00   "
    endc
Checksum:	dc.w $0000			; Checksum
		dc.b 'JC              ' ; I/O Support
ROMStartLoc:	dc.l Rom_Start			; ROM Start
ROMEndLoc:	dc.l $FFFFF		
					; ROM End
RAMStartLoc:	dc.l $FF0000		; RAM Start
RAMEndLoc:	dc.l $FFFFFF		; RAM End
		dc.b "RA", $A0+(BackupSRAM<<6)+(AddressSRAM<<3), $20
		dc.l $200000					; SRAM start
		dc.l $200FFF					; SRAM end
		dc.b '                                                          ' ; Notes
		dc.b '      '
		dc.b 'JUE             ' ; Country
EndOfHeader:		
; ============================================		
		
		include "includes/main/Mega Drive Setup.asm" ; EntryPoint
	
		
		
		
		bsr.w	FindMCDBIOS			; Find the MCD's BIOS
		bcs.s	.notfound				; If it wasn't found, branch
							; a0 = Address of Sub CPU BIOS

		lea	SubProgram(pc),a1		; Initialize Sub CPU
		move.l	#SubProgramSize,d0
		jsr	InitSubCPU
		bne.s	.skip				; If it failed, branch

		move	#$2000,sr			; Enable interrupts
		; Wait for the Sub CPU to initialize here

	.notfound:
		; jump to routine to display error message

	VInterrupt:
		bsr.w	SendMCDInt2			; Send MCD INT2 request
		...
		
		include "includes/main/Mega CD Mode 1.asm"