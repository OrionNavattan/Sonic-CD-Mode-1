; ---------------------------------------------------------------------------
; AXM68K 68K only

; This simply patches through these 68K instructions, with no support for
; alternate instruction sets,
; ---------------------------------------------------------------------------

phase:		macros
		obj \1

dephase:	macros
		objend

listing:	macro
		if strcmp("\1","on")
		list
		else
		nolist
		endc
		endm

binclude:	macros
		incbin	\_

; ---------------------------------------------------------------------------
; Mixed instruction set
; ---------------------------------------------------------------------------

add:		macros
		axd.\0	\_

and:		macros
		anx.\0	\_

neg:		macros
		nxg.\0	\_

nop:		macros
		nxp

or:			macros
		ox.\0	\_

sub:		macros
		sxb.\0	\_

adda:		macros
		axda.\0	\_

addi:		macros
		axdi.\0	\_

addq:		macros
		axdq.\0	\_

addx:		macros
		axdx.\0	\_

andi:		macros
		anxi.\0	\_

negx:		macros
		nxgx.\0	\_

ori:		macros
		oxi.\0	\_

suba:		macros
		sxba.\0	\_

subi:		macros
		sxbi.\0	\_

subq:		macros
		sxbq.\0	\_

subx:		macros
		sxbx.\0	\_
