

; File engine statuses
fstatus_ok:			equ	100			; OK
fstatus_getfail:	equ	-1			; File get failed
fstatus_notfound:	equ	-2			; File not found
fstatus_loadfail:	equ	-3			; File load failed
fstatus_readfail:	equ	-100			; Failed
fstatus_fmvfail:	equ	-111			; FMV load failed

; FMV data types
fmvdata_pcm:	equ	0			; PCM data type
fmvdata_gfx:	equ	1			; Graphics data type

; FMV flags
fmvflag_init:	equ	3			; Initialized flag
fmvflag_pbuf:	equ	4			; PCM buffer ID
fmvflag_readyL	equ	5			; Ready flag
fmvflag_sect:	equ	7			; Reading data section 1 flag

; File data
sizeof_filename:	equ	12			; File name length
