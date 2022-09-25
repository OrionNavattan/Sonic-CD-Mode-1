; -------------------------------------------------------------------------
; Sega CD Mode 1 Library
; Ralakimus 2022
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; Initialize the Sub CPU
; -------------------------------------------------------------------------
; NOTES:
;	* This assumes that the Sega CD is present and that you have
;	  the Sub CPU BIOS code ready to go. Call FindMCDBIOS before this
;
;	* Sub CPU boot requires that we send it level 2 interrupt requests.
;	  After calling this, make sure you enable vertical interrupts
;	  and have your handler call SendMCDInt2. Then you can properly
;	  wait for the Sub CPU to boot and initialize.
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l - Pointer to compressed Sub CPU BIOS code
;	a1.l - Pointer to user Sub CPU program
;	d0.l - Size of user Sub CPU program
; RETURNS:
;	d0.b - Error codes
;	       Bit 0 - MCD took too long to respond
;	       Bit 1 - Failed to load user Sub CPU
; -------------------------------------------------------------------------

InitSubCPU:
		bsr.s	ResetSubCPU			; Reset the Sub CPU

		bsr.w	ReqSubCPUBus			; Request Sub CPU bus
		move.b	d2,d3
		bne.s	.returnbus			; If it failed to do that, branch

		move.b	#0,$A12002			; Disable write protect on Sub CPU memory

		movem.l	d0/d3/a1,-(sp)			; Decompress Sub CPU BIOS into PRG RAM
		lea	$420000,a1
		jsr	KosDec
		movem.l	(sp)+,d0/d3/a1

		movea.l	a1,a0				; Copy user Sub CPU program into PRG RAM
		move.l	#$6000,d1
		bsr.w	CopyPRGRAMData
		or.b	d2,d3

	.returnbus:
		move.b	#$2A,$A12002			; Enable write protect on Sub CPU memory
		bsr.w	ReturnSubCPUBus			; Return Sub CPU bus
		or.b	d2,d3				; Set error code

		move.b	d3,d0				; Get return code
		rts

; -------------------------------------------------------------------------
; Copy new user Sub CPU program into PRG RAM and reset the Sub CPU
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l - Pointer to Sub CPU program to copy
;	d0.l - Size of Sub CPU program to copy
; RETURNS:
;	d0.b - Error codes
;	       Bit 0 - MCD took too long to respond
;	       Bit 1 - Failed to load user Sub CPU
; -------------------------------------------------------------------------

CopyNewUserSP:
		bsr.s	ResetSubCPU			; Reset the Sub CPU
		move.l	#$6000,d1			; Copy to user Sub CPU program area

; -------------------------------------------------------------------------
; Copy data into PRG RAM
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l - Pointer to data to copy
;	d0.l - Size of data to copy
;	d1.l - Destination offset in PRG RAM
; RETURNS:
;	d0.b - Error codes
;	       Bit 0 - MCD took too long to respond
;	       Bit 1 - Failed to load user Sub CPU
; -------------------------------------------------------------------------

CopyToPRGRAM:
		bsr.s	ReqSubCPUBus			; Request Sub CPU bus
		move.b	d2,d3
		bne.s	.returnbus			; If it failed to do that, branch

		move.b	$A12002,d3			; Save write protect settings on Sub CPU memory
		move.b	#0,$A12002			; Disable write protect on Sub CPU memory

		bsr.w	CopyPRGRAMData			; Copy data to PRG-RAM
		or.b	d2,d3

		move.b	d3,$A12002			; Restore write protect on Sub CPU memory

	.returnbus:
		bsr.s	ReturnSubCPUBus			; Return Sub CPU bus
		or.b	d2,d3				; Set error code

		move.b	d3,d0				; Get return code
		rts

; -------------------------------------------------------------------------
; Reset the Sub CPU
; -------------------------------------------------------------------------

ResetSubCPU:
		move.w	#$FF00,$A12002		; Reset the Sub CPU
		move.b	#3,$A12001
		move.b	#2,$A12001
		move.b	#0,$A12001

		moveq	#$80-1,d2			; Wait
		dbf	d2,*
		rts

; -------------------------------------------------------------------------
; Request the Sub CPU bus
; -------------------------------------------------------------------------
; RETURNS:
;	d2.b - Return code
;	       0 - Success
;	       1 - MCD took too long to respond
; -------------------------------------------------------------------------

ReqSubCPUBus:
		move.w	#$100-1,d2			; Max time to wait for MCD response

	.resetsub:
		bclr	#0,$A12001			; Set the Sub CPU to be reset
		dbeq	d2,.resetsub			; Loop until we've waited too long or until the MCD has responded
		bne.s	.waited_too_long			; If we've waited too long, branch

		move.w	#$100-1,d2			; Max time to wait for MCD response

	.req_sub_bus:
		bset	#1,$A12001			; Request Sub CPU bus
		dbne	d2,.req_sub_bus			; Loop until we've waited too long or until the MCD has responded
		beq.s	.waited_too_long			; If we've waited too long, branch

		moveq	#0,d2				; Success
		rts

	.waited_too_long:
		moveq	#1,d2				; Waited too long
		rts

; -------------------------------------------------------------------------
; Return the Sub CPU bus
; -------------------------------------------------------------------------
; RETURNS:
;	d2.b - Return code
;	       0 - Success
;	       1 - MCD took too long to respond
; -------------------------------------------------------------------------

ReturnSubCPUBus:
		move.w	#$100-1,d2			; Max time to wait for MCD response

	.runsub:
		bset	#0,$A12001			; Set the Sub CPU to run again
		dbne	d2,.runsub			; Loop until we've waited too long or until the MCD has responded
		beq.s	.waited_too_long			; If we've waited too long, branch

		move.w	#$100-1,d2			; Max time to wait for MCD response

	.givesubbus:
		bclr	#1,$A12001			; Give back Sub CPU bus
		dbeq	d2,.givesubbus			; Loop until we've waited too long or until the MCD has responded
		bne.s	.waited_too_long			; If we've waited too long, branch

		moveq	#0,d2				; Success
		rts

	.waited_too_long:
		moveq	#1,d2				; Waited too long
		rts

; -------------------------------------------------------------------------
; Copy PRG-RAM data
; -------------------------------------------------------------------------
; NOTE: Requires that Sub CPU bus access must be granted
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l - Pointer to data to copy
;	d0.l - Size of data to copy
;	d1.l - PRG RAM offset
; RETURNS:
;	d2.b - Return code
;	       0 - Success
;	       2 - Failed to copy data
; -------------------------------------------------------------------------

CopyPRGRAMData:
		lea	$420000,a1			; Get destination address
		move.l	d1,d2
		andi.l	#$1FFFF,d2
		add.l	d2,a1
		
		move.b	$A12003,d2			; Set bank ID
		andi.b	#$3F,d2
		swap	d1
		ror.b	#3,d1
		andi.b	#$C0,d1
		or.b	d2,d1
		move.b	d1,$A12003

	.copydata:
		move.b	(a0),(a1)			; Copy byte
		cmpm.b	(a0)+,(a1)+			; Did it copy correctly?
		beq.s	.copydataloop			; If so, branch
		moveq	#2,d2				; Failed to copy data
		rts

	.copydataloop:
		subq.l	#1,d0				; Decrement size
		beq.s	.exit				; If there's no more data left copy, branch
		cmpa.l	#$43FFFF,a1			; Have we reached the end of the bank?
		bls.s	.copydata			; If not, branch

		lea	$420000,a1			; Go to top of bank
		move.b	$A12003,d1			; Increment bank ID
		addi.b	#$40,d1
		move.b	d1,$A12003
		bra.s	.copydata			; Copy more data

	.exit:
		moveq	#0,d2				; Success
		rts

; -------------------------------------------------------------------------
; Send a level 2 interrupt request to the Sub CPU
; -------------------------------------------------------------------------

SendMCDInt2:
		bset	#0,$A12000			; Send interrupt request
		rts

; -------------------------------------------------------------------------
; Check if there's a known MCD BIOS available
; -------------------------------------------------------------------------
; RETURNS:
;	cc/cs - Found, not found 
;	a0.l  - Pointer to Sub CPU BIOS
; -------------------------------------------------------------------------

FindMCDBIOS:
		cmpi.l	#"SEGA",$400100			; Is the "SEGA" signature present?
		bne.s	.notfound			; If not, branch
		cmpi.w	#"BR",$400180			; Is the "Boot ROM" software type present?
		bne.s	.notfound			; If not, branch

		lea	MCDBIOSList(pc),a2		; Get list of known BIOSes
		moveq	#(MCDBIOSListEnd-MCDBIOSList)/2-1,d0

	.findloop:
		lea	MCDBIOSList(pc),a1		; Get pointer to BIOS data
		adda.w	(a2)+,a1

		movea.l	(a1)+,a0			; Get Sub CPU BIOS address
		lea	$400120,a3			; Get BIOS name

	.checkname:
		move.b	(a1)+,d1			; Get character
		beq.s	.namematch			; If we are done checking, branch
		cmp.b	(a3)+,d1			; Does the BIOS name match so far?
		bne.s	.nextBIOS			; If not, go check the next BIOS
		bra.s	.checkname			; Loop until name is fully checked

	.namematch:
		move.b	(a1)+,d1			; Is this Sub CPU BIOS address region specific?
		beq.s	.found				; If not, branch
		cmp.b	$4001F0,d1			; Does the BIOS region match?
		bne.s	.nextBIOS			; If not, branch

	.found:
		andi	#$FE,ccr			; BIOS found
		rts

	.nextBIOS:
		dbf	d0,.findloop			; Loop until all BIOSes are checked

	.notfound:
		ori	#1,ccr				; BIOS not found
		rts

; -------------------------------------------------------------------------
; MCD BIOSes to find
; -------------------------------------------------------------------------

MCDBIOSList:
		dc.w	MCDBIOS_JP1-MCDBIOSList
		dc.w	MCDBIOS_US1-MCDBIOSList
		dc.w	MCDBIOS_EU1-MCDBIOSList
		dc.w	MCDBIOS_CD2-MCDBIOSList
		dc.w	MCDBIOS_CDX-MCDBIOSList
		dc.w	MCDBIOS_LaserActive-MCDBIOSList
		dc.w	MCDBIOS_Wondermega1-MCDBIOSList
		dc.w	MCDBIOS_Wondermega2-MCDBIOSList
MCDBIOSListEnd:

MCDBIOS_JP1:
		dc.l	$416000
		dc.b	"MEGA-CD BOOT ROM", 0
		dc.b	"J"
		even

MCDBIOS_US1:
		dc.l	$415800
		dc.b	"SEGA-CD BOOT ROM", 0
		dc.b	0
		even

MCDBIOS_EU1:
		dc.l	$415800
		dc.b	"MEGA-CD BOOT ROM", 0
		dc.b	"E"
		even

MCDBIOS_CD2:
		dc.l	$416000
		dc.b	"CD2 BOOT ROM    ", 0
		dc.b	0
		even

MCDBIOS_CDX:
		dc.l	$416000
		dc.b	"CDX BOOT ROM    ", 0
		dc.b	0
		even

MCDBIOS_LaserActive:
		dc.l	$41AD00
		dc.b	"MEGA-LD BOOT ROM", 0
		dc.b	0
		even

MCDBIOS_Wondermega1:
		dc.l	$416000
		dc.b	"WONDER-MEGA BOOTROM", 0
		dc.b	0
		even

MCDBIOS_Wondermega2:
		dc.l	$416000
		dc.b	"WONDERMEGA2 BOOTROM", 0
		dc.b	0
		even

; -------------------------------------------------------------------------
