;  =========================================================================
; |					       Sonic the Hedgehog CD Mode 1						|
; |								Sub CPU Program								|
;  =========================================================================


		opt l.					; . is the local label symbol
		opt ae-					; automatic evens are disabled by default
		opt ws+					; allow statements to contain white-spaces
		opt w+					; print warnings
		opt m+					; do not expand macros - if enabled, this can break assembling

		include "Debugger Macros and Common Defs.asm"
		include "Mega CD Sub CPU.asm"
		include "Common Macros.asm"


		org	sp_start

SubPrgHeader:	index.l *
		dc.b	'MAIN       ',0				; module name (always MAIN), flag (always 0)
		dc.w	0,0							; version, type
		dc.l	0							; pointer to next module
		dc.l	0			; size of program
		ptr		UserCallTable	; pointer to usercall table
		dc.l	0							; workram size

UserCallTable:	index *
		ptr	Init		; Call 0; initialization
		ptr	Main		; Call 1; main
		ptr	VBlank		; Call 2; user VBlank
		dc.w	0		; Call 3; unused

		org	sp_start

SubPrgHeader:	index.l *
		dc.b	'MAIN       ',0				; module name (always MAIN), flag (always 0)
		dc.w	0,0							; version, type
		dc.l	0							; pointer to next module
		dc.l	0			; size of program
		ptr		UserCallTable	; pointer to usercall table
		dc.l	0							; workram size
; ===========================================================================

		include_SubCPUGlobalVars
; ===========================================================================

UserCallTable:	index *
		ptr	Init		; Call 0; initialization
		ptr	Main		; Call 1; main
		ptr	VBlank		; Call 2; user VBlank
		dc.w	0		; Call 3; unused
; ===========================================================================

Init:
		lea SetupValues(pc),a0 ; pointers to exception entry points
		lea (_AddressError).w,a1	; first error vector in jump table
		moveq	#10-1,d0			; 9 vectors + GFX int

		.vectorloop:
		addq.l	#2,a1		; skip over instruction word
		move.l	(a0)+,(a1)+	; set table entry to point to exception entry point
		dbf d0,.vectorloop	; repeat for all vectors and GFX int

		move.l	(a0)+,(_TimerInt+2).w			; set timer interrupt address
		move.b	(a0)+,(mcd_timer_interrupt).w	; set timer interrupt interval

		tst.b	(mcd_maincom_0).w
		bne.s	.nodisc				; branch if disc detection has been disabled by the user

		moveq	#DriveInit,d0
		jsr	(_CDBIOS).w				; initialize the drive and get TOC

	.waitinit:
		move.w	#BIOSStatus,d0
		jsr	(_CDBIOS).w				; get BIOS status
		btst	#drive_ready_bit,(a0)				; a0 = _BIOSStatus
		bne.s	.waitinit			; branch if drive init hasn't finished

		;moveq	#30,d7			; number of attempts to read header
	.readheader:
		btst	#no_disc_bit,(a0)
		bne.s	.nodisc				; branch if there is no disc in the drive

		move.w	#DecoderStop,d0
		jsr	(_CDBIOS).w				; stop CDC

		lea FirstSectorData(pc),a0
		moveq	#ROMReadNum,d0
		jsr	(_CDBIOS).w				; read first sector of disc

	.waitstatus:
		move.w	#DecoderStatus,d0
		jsr	(_CDBIOS).w				; is sector read done?
		bcs.s	.waitstatus		; branch if not

	.waitread:
		move.w	#DecoderRead,d0
		jsr	(_CDBIOS).w				; prepare to read data
		bcc.s	.waitread		; branch if not ready

		lea	FirstSectorHeader(pc),a1	; sector header
		move.l	d0,(a1)			; set header buffer in RAM for transfer call
		lea SectorBuffer(pc),a0		; destination buffer
		move.w	#DecoderTransfer,d0
		jsr	(_CDBIOS).w				; transfer to RAM buffer
		bcs.w	TransferFailure		; branch if it failed

		move.w	#DecoderAck,d0
		jsr	(_CDBIOS).w			; acknowledge transfer

		lea SectorBuffer+DiscName(pc),a0	; name of disc in header
		lea HeaderTitle(pc),a1
		moveq	#sizeof_HeaderTitle,d0

	.checkloop:
		cmpm.b	(a0)+,(a1)+	; check header characters
		dbne	d0,.checkloop	; exit if they don't match. loop if they do
		beq.s	.fulldisc	; branch if comparison was successful

		cmpi.b	#17,(_CDDStatus+CDD_LastTrack).w		; does this disc have at least 17 tracks?
		bcc.s	.audiocd			; if so, we can play music from this CD
		bra.s	.nodisc				; otherwise, we can't use it

	.fulldisc:
		moveq	#id_FileFunc_EngineInit,d0
		bsr.w	FileFunction		; initialize the file engine
		addq.b	#1,(v_disc_status).w	; 2 = full CD audio and FMV support

	.audiocd:
		addq.b	#1,(v_disc_status).w	; 1 = CD audio only

	.nodisc:
		jmp	(DriverInit).l	; initialize the PCM driver
; ===========================================================================

SetupValues:
		dc.l AddressError
		dc.l IllegalInstr
		dc.l ZeroDivide
		dc.l ChkInstr
		dc.l TrapvInstr
		dc.l PrivilegeViol
		dc.l Trace
		dc.l Line1010Emu
		dc.l Line1111Emu
		dc.l GFXInt			; GFX int address
		dc.l RunPCMDriver	; timer int address
		dc.b 255			; timer interrupt interval
		; ga_cdc_device value
		dc.b 1,	$FF			; drive init parameters

FirstSectorData:
		dc.l 0,1		; sector 0, one sector (to get SEGA CD disc header)

FirstSectorHeader:
		dc.l 0		; buffer used for sector header during init

HeaderTitle:
		dc.b "SONIC CD M1 DATA DISC"
		arraysize	HeaderTitle
; ===========================================================================

Main:
		addq.w #4,sp	; throw away return address to BIOS call loop, as we will not be returning there
		moveq	#FileFunction_GetFiles,d0
		bsr.w	FileFunction		; initialize the filesystem

	.waitfiles:
		jsr	(_WaitForVBlank).w			; file engine only runs during VBlank

		move.w	#id_FileFunction_Status,d0		; is the operation finished?
		bsr.w	FileFunction
		bcs.s	.wait				; If not, wait

		moveq	#'R',d0

		move.b d0,(mcd_subcom_0).w	; we are ready

	.waitmainCPU:
		cmp.b	(mcd_maincom_0).w,d0	; is main CPU ready?
		bne.s	.waitmainCPU

		clr.b	(mcd_subcom_0).w

		; proceed to main command loop


; -------------------------------------------------------------------------
; GFX interrupt
; -------------------------------------------------------------------------

GFXInt:
		clr.b	(f_gfx_op).w	; clear GFX operation flag
		rte

; -------------------------------------------------------------------------
; VBlank
; -------------------------------------------------------------------------

VBlank:
		; check main CPU state
		; exit if no disc
		; check file engine routine
		; exit if nothing to so

		tst.b	(FileVars+fe_opermode).l	; do we need to run a file operation?
		beq.s	.nop						; branch if not

		movem.l	d0-a6,-(sp)			; save registers
		move.w	#FFUNC_OPER,d0			; perform engine operation
		bsr.w	FileFunction
		movem.l	(sp)+,d0-a6			; restore registers

	.nop:
		rts

		include "includes/Sub/File Engine.asm"

		ds.b	sizeof_FileVars
