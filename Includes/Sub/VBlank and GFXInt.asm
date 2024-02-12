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
		cmpi.b	#$FF,(mcd_main_flag).w	; is main CPU OK?
		beq.s	MainCrash1				; branch if not

		tst.b	(FileVars+fe_opermode).l	; do we need to run a file operation?
		beq.s	.vblank_done						; branch if not

		movem.l	d0-a6,-(sp)			; save registers
		moveq	#id_FileFunc_Operation,d0			; perform engine operation
		bsr.w	FileFunction
		movem.l	(sp)+,d0-a6			; restore registers

	.vblank_done:
		rts
