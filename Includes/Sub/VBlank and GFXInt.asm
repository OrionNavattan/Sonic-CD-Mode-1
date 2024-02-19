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
		beq.w	MainCrash1				; branch if not

		addq.w	#1,(v_vblank_counter).w		; increment VBlank counter
		tst.w	(FileVars+fe_opermode).l	; do we need to run a file operation? (id_FileMode_None = 0)
		beq.s	.vblank_done						; exit if not

		movem.l	d0-a6,-(sp)			; save registers
		moveq	#id_FileFunc_Operation,d0			; perform engine operation
		bsr.s	FileFunction
		movem.l	(sp)+,d0-a6			; restore registers

	.vblank_done:
		rts
