; ---------------------------------------------------------------------------
; Due to the sheer amount of variation in Sonic CD's VBlank routines, the
; global VBlank routine is minimal. Nearly everything is done in the
; mode-specific code, including the lag handlers.
; ---------------------------------------------------------------------------

VBlank:
		chksubcrash		; check if sub CPU has crashed
		move.b	#mcd_int,(mcd_md_interrupt).l	; trigger VBlank on the sub CPU
		tst.w	(v_vblank_primary_routine).w
		beq.s	.exit					; branch if no routine is set (hardware initialization)
		pushr.l	d0-a6
		movea.l	(v_vblank_primary_routine).w,a0
		jsr	(a0)						; run the relevant VBlank routine

		popr.l	d0-a6					; restore registers

	.exit:
		rte

HBlank:
		rte
