; -------------------------------------------------------------------------
; Sub CPU program constants
; -------------------------------------------------------------------------

; Standard ISO 9660 equates
; Primary volume descriptor offsets
iso9660_pvd_sector:		equ $10
iso9660_pvd_rootdir:	equ $9C		; start of root directory record in primary volume descriptor

; Directory record offsets
directory_length:	equ 0		; size of the directory record
directory_start:	equ 2		; start sector of file
directory_size:		equ $A		; size of file in bytes
directory_flags:	equ $19
directory_name_length:	equ $20		; length of file name in bytes
directory_name:		equ $21		; file name

sizeof_sector:		equ $800	; size of one sector on disc

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
fmvflag_ready:	equ	5			; Ready flag
fmvflag_sect:	equ	7			; Reading data section 1 flag

sizeof_filename:	equ	12			; File name length

; File entry structure
	rsreset
file_name:		rs.b	sizeof_filename		; file name
				rs.b	$17-__rs
file_flags:		rs.b	1			; file flags
file_sector:	rs.l	1			; file sector
file_length:	rs.l	1			; file size
sizeof_fileentry:	equ __rs			; size of structure


; Disc header
domestic_title:	equ $120
