;-----------------------------------------------------------------------
; Calls the BIOS with a specified function number. Assumes that all
; preparatory and cleanup work is done externally.
;
; input:
;	command (jsr or jmp), function code

; usage:
;	cdbios jsr,DriveInit
;-----------------------------------------------------------------------

cdbios: macro command,fcode

	if \fcode<$7F
		moveq	#\fcode,d0	; optimize fcode set to moveq if a queued BIOS command
	else
		move.w	#\fcode,d0
	endc
	\command	(_CDBIOS).w
	endm
