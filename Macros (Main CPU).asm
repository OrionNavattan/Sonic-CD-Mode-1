; -------------------------------------------------------------------------
; Check if the sub CPU has crashed, and enter the error handler if so
; -------------------------------------------------------------------------

chksubcrash:	macro

		cmpi.b	#$FF,(mcd_sub_flag).l	; is sub CPU OK?
		bne.s	.ok\@				; branch if not
		trap	#0					;

	.ok\@:
		endm
