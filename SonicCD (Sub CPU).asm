;  =========================================================================
; |					       Sonic the Hedgehog CD Mode 1						|
; |								Sub CPU Program								|
;  =========================================================================


		opt l.					; . is the local label symbol
		opt ae-					; automatic evens are disabled by default
		opt ws+					; allow statements to contain white-spaces
		opt w+					; print warnings
		opt op+					; optimize to PC relative if possible
		opt os+					; optimize backwards branches to .s if possible
		opt ow+					; optimize to absolute short if possible
		opt oz+					; optimize address register indirect with displacement to plain address register indirect if displacement = 0
		opt	oaq+				; optimize addi and adda to addq if possible
		opt osq+				; optimize subi and suba to subq if possible

		include "AXM68K 68k Only.asm"
		include "Mega CD Sub CPU.asm"
		include "includes/Debugger Macros and Common Defs.asm"
		include "Common Macros.asm"
		include "Constants (Sub CPU).asm"
		include "RAM Addresses (Sub CPU).asm"
	;	include "includes/Sub CPU Commands.asm"


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
		addq.w	#2,a1		; skip over instruction word
		move.l	(a0)+,(a1)+	; set table entry to point to exception entry point
		dbf d0,.vectorloop	; repeat for all vectors and GFX int

		move.l	(a0)+,(_TimerInt+2).w			; set timer interrupt address
		move.b	(a0)+,(mcd_timerint_interval).w	; set timer interrupt interval

	;	tst.b	(mcd_maincom_0).w
	;	bne.w	.nodisc				; branch if disc detection has been disabled by the user

		moveq	#DriveInit,d0
		jsr	(_CDBIOS).w				; initialize the drive and get TOC

	.waitinit:
		move.w	#BIOSStatus,d0
		jsr	(_CDBIOS).w				; get BIOS status
		btst	#drive_ready_bit,(a0)				; a0 = _BIOSStatus
		bne.s	.waitinit			; branch if drive init hasn't finished


		btst	#no_disc_bit,(a0)
		bne.w	.nodisc				; branch if there is no disc in the drive

.readheader:
		lea (FileVars).l,a5	; we use the file engine code to get the header sector
		move.b	#cdc_dest_sub,(cdc_mode).w				; set CDC device to sub CPU
		clr.l	fe_sector(a5)
		move.l	#1,fe_sectorcount(a5)
		move.l	#FileVars+fe_dirreadbuf,fe_readbuffer(a5)
		move.w	#30,fe_retries(a5)		; set retry counter

.startread:
		lea	fe_sector(a5),a0			; get sector information
		move.l	(a0),d0				; get sector frame (in BCD)
		divu.w	#75,d0
		swap	d0
		ext.l	d0
		divu.w	#10,d0
		move.b	d0,d1
		lsl.b	#4,d1
		swap	d0
		move	#0,ccr
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)

		move.w	#DecoderStop,d0
		jsr	(_CDBIOS).w				; stop CDC
		moveq	#ROMReadNum,d0
		jsr	(_CDBIOS).w				; read first sector of disc

.waitstatus:
		moveq	#$72-1,d0	; outer loop

	.waitinner:
		moveq_	$FF,d1		; inner loop
	.waitloopinner:
		dbf	d1,.waitloopinner
		dbf d0,.waitinner

		move.w	#DecoderStatus,d0
		jsr	(_CDBIOS).w				; is sector read done?
		bcc.s	.waitread		; branch if so
		subq.w	#1,fe_waittime(a5)
		bge.s	.waitstatus			; if we are still waiting, branch
		subq.w	#1,fe_retries(a5)		; if we waited too long, decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.w	.nodisc
; ===========================================================================

.waitread:
		move.w	#DecoderRead,d0
		jsr	(_CDBIOS).w				; prepare to read data
		bcs.s	.waitread		; branch if not ready
		move.l	d0,fe_readtime(a5)		; get time of sector read
		move.b	fe_sectorframe(a5),d0
		cmp.b	fe_readframe(a5),d0		; does the read sector match the sector we want?
		beq.s	.wait_data_set			; if so, branch

	.read_retry:
		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.s	.nodisc			; give up
; ===========================================================================

.wait_data_set:
		move.w	#$800-1,d0			; wait for data set

	.wait_loop:
		btst	#cdc_dataready_bit,(cdc_mode).w
		dbne	d0,.wait_loop		; loop until ready or until it takes too long
		bne.s	.transferdata			; if the data is ready to be transfered, branch

		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.w	.startread			; if we can still retry, do it
		bra.s	.nodisc			; give up
; ===========================================================================

.transferdata:
		move.w	#DecoderTransfer,d0			; transfer data
		movea.l	fe_readbuffer(a5),a0
		lea	fe_readtime(a5),a1
		jsr	(_CDBIOS).w
		bcs.s	.copy_retry		; if it wasn't successful, branch

		move.b	fe_sectorframe(a5),d0		; does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.checkheader			; if so, branch

	.copy_retry:
		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.w	.startread			; if we can still retry, do it
		bra.s	.nodisc			; give up
; ===========================================================================

.checkheader:
		move.w	#DecoderAck,d0
		jsr	(_CDBIOS).w			; acknowledge transfer

		movea.l fe_readbuffer(a5),a1	; name of disc in header
		lea HeaderTitle(pc),a2		; header title we're checking for
		moveq	#sizeof_HeaderTitle,d1

		bsr.w	CompareStrings	; does the title in the header match?
		beq.s	.fulldisc		; if so, branch

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

HeaderTitle:
		dc.b "SONIC CD M1 DATA DISC"
		arraysize	HeaderTitle
; ===========================================================================

Main:
		addq.w #4,sp	; throw away return address to BIOS call loop, as we will not be returning there
		moveq	#id_FileFunc_GetFiles,d0
		bsr.w	FileFunction		; initialize the filesystem

	.waitfiles:
		jsr	(_WaitForVBlank).w			; file engine only runs during VBlank

		moveq	#id_FileFunc_GetStatus,d0		; is the operation finished?
		bsr.w	FileFunction
		bcs.s	.waitfiles				; if not, wait

		moveq	#'R',d0
		move.b	d0,(mcd_subcom_0).w		; signal initialization success

	WaitReady:
		cmpi.b	#$FF,(mcd_main_flag).w	; is main CPU OK?
		beq.s	MainCrash1			; branch if so
		cmp.b	(mcd_maincom_0).w,d0		; has main CPU acknowledged?
		bne.s	WaitReady			; branch if not

		moveq	#0,d0
		move.b	d0,(mcd_subcom_0).w		; we are ready to accept commands once main CPU clears its com register

	.waitmainready:
		tst.b	(mcd_maincom_0).w	; is main CPU ready to send commands?
		bne.s	.waitmainready		; branch if not

		bra.w	MainCommandLoop		; continue to main command loop

; -------------------------------------------------------------------------
; Main CPU crash
; -------------------------------------------------------------------------

MainCrash1:
		trap #0
; ===========================================================================

		include "includes/sub/VBlank and GFXInt.asm"
		include "includes/sub/File Engine.asm"
		include "includes/sub/Mega CD Exception Handler (Sub CPU).asm"
		include "includes/sub/Command Handlers.asm"

DriverInit:
		rts

RunPCMDriver:
		rte

FileTable:

fmv_pcm_buffer:
		even

FileVars:
		dcb.b	sizeof_FileVars,$FF
		even
		end

