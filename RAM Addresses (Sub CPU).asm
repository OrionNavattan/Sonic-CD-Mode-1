; -------------------------------------------------------------------------
; Global sub CPU variables

; These variables either persist across game modes or are used by more than
; one mode.
; -------------------------------------------------------------------------

include_SubCPUGlobalVars:	macro
SubCPUGlobalVars:

v_disc_status:	ds.b 1		; 0 - no disc, 1 - CDDA only, 2 - CDDA and FMV
v_pcm_module:	ds.b 1			; current PCM music module
f_rundriver:	ds.b 1
v_ss_flags:		ds.b 1			; special stage flags copy
f_gfx_op:			ds.b 1		; flag indicating a GFX operation is in progress
v_vblank_counter:	ds.b 1		; byte that increments every VBlank
v_joypad_hold:		rs.w 1				; joypad input - held, actual
v_joypad_press:		equ __rs-1			; joypad input - pressed, actual

		arraysize	SubCPUGlobalVars
		endm

; -------------------------------------------------------------------------
; File engine variables
; -------------------------------------------------------------------------

		rsreset
fe_operbookmark:	rs.l	1			; operation bookmark
fe_sector:	rs.l	1			; sector to read from
fe_sectorcount:	rs.l	1			; number of sectors to read
fe_returnaddr:	rs.l	1			; return address for CD read functions
fe_readbuffer:	rs.l	1			; read buffer address
fe_readtime:	rs.b	0			; time of read sector
fe_readmin:	rs.b	1			; read sector minute
fe_readsec:	rs.b	1			; read sector second
fe_readframe:	rs.b	1			; read sector frame
		rs.b	1
fe_dirsectors:	rs.b	0			; directory size in sectors
fe_filesize:	rs.l	1			; file size buffer
fe_opermode:	rs.w	1			; operation mode
fe_status:	rs.w	1			; status code
fe_filecount:	rs.w	1			; file count
fe_waittime:	rs.w	1			; wait timer
fe_retries:	rs.w	1			; retry counter
fe_sectorsread:	rs.w	1			; number of sectors read
fe_cdcmode:		rs.b	1			; CDC mode
fe_sectorframe:	rs.b	1			; sector frame
fe_filename:	rs.b	sizeof_filename		; file name buffer
		rs.b	$100-__rs
fe_filelist:	rs.b	$2000			; file list	(can be shrunk)
fe_dirreadbuf:	rs.b	$900			; directory read buffer
fe_fmv_sectframe:	rs.w	1			; FMV sector frame
fe_fmv_datatype:	rs.b	1			; FMV read data type
fe_fmv:		rs.b	1			; FMV flags
fe_fmvfailcount:	rs.b	1			; FMV fail counter

sizeof_FileVars:		equ __rs		; size of structure


; -------------------------------------------------------------------------
; Mode-specific variables
; -------------------------------------------------------------------------

; Requirements for each sub CPU program mode:

; Title screen: - $62
; Special stage: - $1C96
; DA Garden: - $60
