; ---------------------------------------------------------------------------
; RAM Addresses - Variables (v) and Flags (f)
; ---------------------------------------------------------------------------

		pusho						; save options
		opt	ae+					; enable auto evens


		rsset	$FFFF8000

v_stack_pointer:	equ __rs
v_vblank_primary_routine:	rs.l 1

		rsset 	$FFFFFFFE
v_console_region:	rs.b 1		; $FFFFFFFE
v_bios_id:			rs.b 1		; $FFFFFFFF

