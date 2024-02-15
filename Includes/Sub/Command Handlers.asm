MainCommandLoop:
		cmpi.b	#$FF,(mcd_main_flag).w	; is main CPU OK?
		beq.s	MainCrash2				; branch if it is
		move.w	(mcd_maincom_0).w,d0	; get command ID from main CPU
		beq.s	MainCommandLoop				; wait if not set
		cmp.w	(mcd_maincom_0).w,d0	; safeguard against spurious writes?
		bne.s	MainCommandLoop
		cmpi.w	#sizeof_SubCPUCmd_Index/2,d0	; is it a valid command?
		bhi.s	.invalid				; branch if not

		add.w	d0,d0
		move.w	SubCPUCmd_Index-2(pc,d0.w),d0	; minus 2 since IDs start at 1
		jsr	SubCPUCmd_Index(pc,d0.w)		; run the command
		bra.s	MainCommandLoop
; ===========================================================================

.invalid:
		bsr.s	CmdFinish
		bra.s	MainCommandLoop
; ===========================================================================

CmdFinish:
		move.w	(mcd_maincom_0).w,(mcd_subcom_0).w	; acknowledge command

	.wait:
		cmpi.b	#$FF,(mcd_main_flag).w	; is main CPU OK?
		beq.s	MainCrash2				; branch if it is
		tst.w	(mcd_maincom_0).w			; is the main CPU ready?
		bne.s	.wait			; if not, wait
		tst.w	(mcd_maincom_0).w
		bne.s	.wait			; if not, wait

		clr.w	(mcd_subcom_0).w			; mark as ready for another command
		rts
; ===========================================================================

MainCrash2:
		trap #0
; ===========================================================================

SubCPUCmd_Index:	index *,1

GenSubCmdIndex:	macro	name
		ptr \name
		endm

	;	SubCPUCommands	GenSubCmdIndex	; generate the index table for all commands

		arraysize	SubCPUCmd_Index
