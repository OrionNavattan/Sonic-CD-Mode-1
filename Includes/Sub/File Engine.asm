; -------------------------------------------------------------------------
; Subroutine to get the file name for a file ID

; input:
;	d0.w - file ID

; output:
;	a0.l - pointer to file name
; -------------------------------------------------------------------------

Get_Name:
		mulu.w	#sizeof_filename+1,d0		; get file name pointer
		lea	FileTable(pc),a0
		adda.w	d0,a0
		rts

; -------------------------------------------------------------------------
; Subroutine to load a file from disc

; input:
;	a0.l - pointer to file name
;	a1.l - file read destination buffer
; -------------------------------------------------------------------------

LoadFile:
		moveq	#id_FileFunc_LoadFile,d0		; start file loading
		bsr.s	FileFunction_NonInt

	.waitload:
		jsr	(_WaitForVBlank).w			; engine operation occurs during VBlank

		moveq	#id_FileFunc_GetStatus,d0		; is the operation finished?
		bsr.s	FileFunction_NonInt
		bcs.s	.waitload				; if not, wait

		cmpi.w	#fstatus_ok,d0			; was the operation a success?
		bne.s	LoadFile		; if not, try again
		rts

; -------------------------------------------------------------------------
; File engine function

; input:
;	d0.w - file engine function ID
; -------------------------------------------------------------------------

FileFunction_NonInt:		; if we're calling this outside of VBlank, we may want return values in data registers
		pushr.l	a0-a6				; save address registers
		bsr.s	FileFunction
		popr.l	a0-a6
		rts

FileFunction:				; assumes registers have already been backed up before call or that we don't need them backed up
		lea	FileVars(pc),a5
		move.w	FileFunction_Index(pc,d0.w),d0
		jmp	FileFunction_Index(pc,d0.w)				; perform function
; ===========================================================================

FileFunction_Index:	index *,,2
		ptr	FileFunc_EngineInit	; initialize engine
		ptr	FileFunc_GetDiscHeader	; load disc's header/IP sector
		ptr	FileFunc_Operation	; perform operation
		ptr	FileFunc_GetStatus	; get status
		ptr	FileFunc_LoadFilesystem	; load filesystem
		ptr	FileFunc_LoadFile	; load file
		ptr	FileFunc_FindFile	; find file
		ptr	FileFunc_LoadFMV	; load FMV
		ptr	FileFunc_EngineReset	; reset engine
		ptr	FileFunc_LoadMuteFMV	; load mute FMV

; -------------------------------------------------------------------------
; Initialize file engine
; -------------------------------------------------------------------------

FileFunc_EngineInit:
FileFunc_EngineReset:
		move.l	#FileOperation,fe_operbookmark(a5)	; reset operation bookmark
		move.w	#id_FileMode_None,fe_opermode(a5)	; set operation mode to "none"
		rts

; -------------------------------------------------------------------------
; Get disc header
; -------------------------------------------------------------------------

FileFunc_GetDiscHeader:
		move.w	#id_FileMode_GetDiscHeader,fe_opermode(a5)	; set operation mode to "get disc header"
		rts

; -------------------------------------------------------------------------
; Get file engine status

; output:
;	d0.w  - return code
;	d1.l  - file size if file load was successful
;	        Sectors read if file load failed
;	cc/cs - inactive/busy
; -------------------------------------------------------------------------

FileFunc_GetStatus:
		cmpi.w	#id_FileMode_None,fe_opermode(a5)	; is there an operation going on?
		bne.s	.busy				; if so, branch

		move.w	fe_status(a5),d0			; get status
		cmpi.w	#fstatus_ok,d0			; is the status marked as successful?
		bne.s	.failed				; if not, branch
		move.l	fe_filesize(a5),d1		; return file size
		bra.s	.inactive

	.failed:
		cmpi.w	#fstatus_loadfail,d0		; is the status marked as a failed load?
		bne.s	.inactive			; if not, branch
		move.w	fe_sectorsread(a5),d1		; return sectors read

	.inactive:
		move.w	#0,ccr				; mark as inactive
		rts
; ===========================================================================

	.busy:
		move.w	#1,ccr				; mark as busy (sets carry bit of CCR)
		rts

; -------------------------------------------------------------------------
; Perform operation
; -------------------------------------------------------------------------

FileFunc_Operation:
		movea.l	fe_operbookmark(a5),a0		; go to operation bookmark
		jmp	(a0)

; -------------------------------------------------------------------------
; Load the disc's filesystem
; -------------------------------------------------------------------------

FileFunc_LoadFilesystem:
		move.w	#id_FileMode_LoadFilesystem,fe_opermode(a5)	; set operation mode to "get files"
		move.b	#1<<fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1
		clr.l	fe_fmvfailcount(a5)		; reset fail counter
		rts

; -------------------------------------------------------------------------
; Initiate loading a file

; input:
;	a0.l - file name
;	a1.l - file destination
; -------------------------------------------------------------------------

FileFunc_LoadFile:
		move.w	#id_FileMode_LoadFile,fe_opermode(a5)	; set operation mode to "load file"
		move.l	a1,fe_readbuffer(a5)		; set read buffer

		movea.l	a0,a1				; a1 = pointer to filename
		lea	fe_filename(a5),a2
		moveq	#sizeof_filename-1,d1

	.loop:
		move.b	(a1)+,(a2)+		; copy filename to variables
		dbf	d1,.loop
		rts

; -------------------------------------------------------------------------
; Find a file

; input:
;	a0.l  - file name

; output:
;	a0.l  - found file information
;	cc/cs - found/not found
; -------------------------------------------------------------------------

FileFunc_FindFile:
		pushr.l	a2			; save a2
		moveq	#0,d1				; prepare to find file
		movea.l	a0,a1
		moveq	#sizeof_filename-2,d0

	.get_name_length:
		tst.b	(a1)				; is this character a terminator?
		beq.s	.got_length			; if so, branch
		cmpi.b	#';',(a1)			; is this character a semicolon?
		beq.s	.got_length			; if so, branch
		cmpi.b	#' ',(a1)			; is this character a space?
		beq.s	.got_length			; if so, branch

		addq.w	#1,d1				; increment length
		addq.w	#1,a1				; next character
		dbf	d0,.get_name_length		; loop until finished

	.got_length:
		move.w	fe_filecount(a5),d0		; prepare to scan file list
		movea.l	a0,a1				; a1 - filename
		lea	fe_filelist(a5),a0		; return this in a0 if it is the first file

		lea	.first_file(pc),a2		; are we retrieving the first file?
		bsr.s	CompareStrings
		beq.w	.done				; if so, branch

		movea.l	a0,a2				; start scanning list
		subq.w	#1,d0

	.find_file:
		bsr.s	CompareStrings			; is this file entry the one we are looking for?
		beq.s	.found			; if so, branch
		lea	sizeof_fileentry(a2),a2		; go to next file
		dbf	d0,.find_file			; loop until file is found or until all files are scanned
		bra.s	.not_found			; file not found

	.found:
		moveq	#1,d0				; mark as found
		movea.l	a2,a0				; get file entry

	.done:
		popr.l	a2			; restore a2
		rts
; ===========================================================================

.not_found:
		move.w	#1,ccr				; mark as not found
		bra.s	.Done
; ===========================================================================

	.first_file:
		dc.b	"\          ",0
		even

; -------------------------------------------------------------------------
; Subroutine to compare two strings

; input:
;	d1.w  - number of characters to compare
;	a1.l  - pointer to string 1
;	a2.l  - pointer to string 2

; output:
;	eq/ne - same/different
; -------------------------------------------------------------------------

CompareStrings:
		pushr.l	d1/a1-a2			; save registers

	.compare:
		cmpm.b	(a1)+,(a2)+			; ccmpare characters
		bne.s	.done				; if they aren't the same, branch
		dbf	d1,.compare			; loop until all characters are scanned

		moveq	#0,d1				; mark strings as the same

	.done:
		popr.l	d1/a1-a2			; restore registers
		rts


; -------------------------------------------------------------------------
; Initiate streaming an FMV with PCM sound

; input:

;	a0.l - filename
; -------------------------------------------------------------------------

FileFunc_LoadFMV:
		move.b	#1<<fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1
		move.w	#FileMode_LoadFMV,fe_opermode(a5)	; set operation mode to "load FMV"
		move.l	#fmvflag_pbuf,fe_readbuffer(a5)	; prepare to read PCM data
		clr.w	fe_fmv_sectframe(a5)
		bset	#fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1

		movea.l	a0,a1				; a1 = pointer to filename
		lea	fe_filename(a5),a2
		move.w	#sizeof_filename-1,d1

	.loop:
		move.b	(a1)+,(a2)+		; copy filename to variables
		dbf	d1,.loop
		rts

; -------------------------------------------------------------------------
; Initiate streaming an FMV with no sound

; input:
;	a0.l - File name
; -------------------------------------------------------------------------

FileFunc_LoadMuteFMV:
		move.b	#1<<fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1
		move.w	#id_FileMode_LoadMuteFMV,fe_opermode(a5)	; set operation mode to "load mute FMV"
		move.l	#wordram_1M,fe_readbuffer(a5)	; prepare to read graphics data

		clr.w	fe_fmv_sectframe(a5)		; reset FMV sector frame

		movea.l	a0,a1				; a1 = pointer to filename
		lea	fe_filename(a5),a2
		move.w	#sizeof_filename-1,d1

	.loop:
		move.b	(a1)+,(a2)+		; copy filename to variables
		dbf	d1,.loop
		rts

; -------------------------------------------------------------------------
; Handle file engine operation
; -------------------------------------------------------------------------

FileOperation:
FileMode_None:
		bsr.s	FileEngine_SuspendExecution		; set bookmark

		move.w	fe_opermode(a5),d0		; perform operation
		move.w	FileOperation_Index(pc,d0.w),d0
		jmp	FileOperation_Index(pc,d0.w)
; ===========================================================================


FileOperation_Index:	index *,,2
		ptr	FileMode_None		; none
		ptr	FileMode_GetDiscHeader	; get disc header
		ptr	FileMode_LoadFilesystem	; get files
		ptr	FileMode_LoadFile	; load file
		ptr	FileMode_LoadFMV	; load FMV
		ptr	FileMode_LoadMuteFMV	; load mute FMV

; -------------------------------------------------------------------------
; Set operation bookmark
; -------------------------------------------------------------------------

FileEngine_SuspendExecution:
		popr.l	fe_operbookmark(a5)		; set bookmark
		rts

; -------------------------------------------------------------------------
; "Get disc header" operation
; -------------------------------------------------------------------------

FileMode_GetDiscHeader:
		move.b	#cdc_dest_sub,fe_cdcmode(a5)				; set CDC device to sub CPU
		clr.l	fe_sector(a5)					; read sector 0
		move.l	#1,fe_sectorcount(a5)			; 1 sector
		move.l	#FileVars+fe_dirreadbuf,fe_readbuffer(a5)	; read buffer (will be overwritten later)

		bsr.w	ReadSectors		; read header sector

		cmpi.w	#fstatus_ok,fe_status(a5)		; was the operation a success?
		beq.s	.done				; if so, branch
		move.w	#fstatus_loadfail,fe_status(a5)	; mark as failed

	.done:
		move.w	#id_FileMode_None,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation			; loop back

; -------------------------------------------------------------------------
; "Load filesystem" operation
; -------------------------------------------------------------------------

FileMode_LoadFilesystem:
		move.b	#cdc_dest_sub,fe_cdcmode(a5)			; set CDC device to sub CPU
		move.l	#iso9660_pvd_sector,fe_sector(a5)		; read sector $10 (primary volume descriptor)
		move.l	#1,fe_sectorcount(a5)		; read 1 sector
		move.l	#FileVars+fe_dirreadbuf,fe_readbuffer(a5)	; read buffer
		bsr.w	ReadSectors			; read volume descriptor sector
		cmpi.w	#fstatus_readfail,fe_status(a5)	; was the operation a failure?
		beq.w	.failed				; if so, branch

		lea	fe_dirreadbuf(a5),a1		; primary volume descriptor buffer
		move.l	iso9660_pvd_rootdir+directory_start+4(a1),fe_sector(a5)		; get root directory start sector (which we'll read next)
		move.l	iso9660_pvd_rootdir+directory_size+4(a1),d0			; get root directory size in bytes
		divu.w	#sizeof_sector,d0			; get size in sectors
		swap	d0
		tst.w	d0				; is the size sector aligned?
		beq.s	.aligned			; if so, branch
		addi.l	#1<<16,d0			; align sector count

	.aligned:
		swap	d0				; set sector count
		move.w	d0,fe_dirsectors(a5)
		clr.w	fe_filecount(a5)			; reset file count

.get_directory:
		move.l	#1,fe_sectorcount(a5)		; read 1 sector
		move.l	#FileVars+fe_dirreadbuf,fe_readbuffer(a5)	; read buffer
		bsr.w	ReadSectors			; read sector of root directory
		cmpi.w	#fstatus_readfail,fe_status(a5)	; was the operation a failure?
		beq.w	.failed				; if so, branch

		lea	fe_filelist(a5),a0		; go to file list cursor
		move.w	fe_filecount(a5),d0		; d0 = current file count
		mulu.w	#sizeof_fileentry,d0
		adda.l	d0,a0				; jump to entry for file we're about to load info for

		lea	fe_dirreadbuf(a5),a1		; prepare to get file info
		moveq	#0,d0

.get_file:
		move.b	directory_length(a1),d0			; get file entry size
		beq.s	.no_more_files			; branch if zero (no more files left)
		move.b	directory_flags(a1),file_flags(a0)		; get file flags

		moveq	#0,d1				; prepare to get location and size

	.get_file_sector_size:
		move.b	directory_start+4(a1,d1.w),file_sector(a0,d1.w)	; get one byte of file sector
		move.b	directory_size+4(a1,d1.w),file_length(a0,d1.w)	; get one byte of file size
		addq.w	#1,d1				; next byte
		cmpi.w	#4,d1				; have we done all four bytes of sector and size?
		blt.s	.get_file_sector_size			; if not, branch

		moveq	#0,d1				; prepare to get file name

	.get_name:
		move.b	directory_name(a1,d1.w),(a0,d1.w)		; get one byte of file name
		addq.w	#1,d1
		cmp.b	directory_name_length(a1),d1			; have we copied the full name?
		blt.s	.get_name			; if not, branch

	.pad_name:
		cmpi.b	#sizeof_filename,d1			; did we reach the maximum length for the file name?
		bge.s	.next_file			; if so, branch
		move.b	#' ',(a0,d1.w)			; if not, pad out with spaces
		addq.w	#1,d1
		bra.s	.pad_name			; loop until done

	.next_file:
		addq.w	#1,fe_filecount(a5)		; increment file count
		adda.l	d0,a1					; next file in directory sector
		lea	sizeof_fileentry(a0),a0		; next file entry in file table
		bra.s	.get_file

	.no_more_files:
		subq.w	#1,fe_dirsectors(a5)		; decrement directory sector count
		bne.w	.get_directory			; branch if there are more left to do

		move.w	#fstatus_ok,fe_status(a5)		; mark operation as successful

.done:
		move.w	#id_FileMode_None,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation				; loop back
; ===========================================================================

.failed:
		move.w	#fstatus_getfail,fe_status(a5)	; mark operation as failed
		bra.s	.done

; -------------------------------------------------------------------------
; "Load file" operation
; -------------------------------------------------------------------------

FileMode_LoadFile:
		move.b	#cdc_dest_sub,fe_cdcmode(a5)			; set CDC device to "Sub CPU"
		lea	fe_filename(a5),a0
		bsr.w	FileFunc_FindFile			; find file
		bcs.w	.not_found			; branch if not found

		move.l	file_sector(a0),fe_sector(a5)	; get file sector
		move.l	file_length(a0),d1		; get file size
		move.l	d1,fe_filesize(a5)

		move.l	#1,fe_sectorcount(a5)	; 1 sector minimum

	.get_sectors:
		subi.l	#sizeof_sector,d1	; subtract size of sector
		ble.s	.read				; branch if we underflowed to negative or reached zero
		addq.l	#1,fe_sectorcount(a5)	; increment sector count
		bra.s	.get_sectors

	.read:
		bsr.s	ReadSectors			; read file from disc
		cmpi.w	#fstatus_ok,fe_status(a5)		; was the operation a success?
		beq.s	.done				; if so, branch
		move.w	#fstatus_loadfail,fe_status(a5)	; mark as failed

.done:
		move.w	#id_FileMode_None,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation			; loop back
; ===========================================================================

	.not_found:
		move.w	#fstatus_notfound,fe_status(a5)	; mark as not found
		bra.s	.done

; -------------------------------------------------------------------------
; Common routine to begin reading disc sectors
; -------------------------------------------------------------------------

BeginSectorRead:
		move.b	fe_cdcmode(a5),(cdc_mode).w	; set CDC device

		lea	fe_sector(a5),a0			; get sector information
		move.l	(a0),d0				; get sector frame (in BCD)
		divu.w	#75,d0				; divide sector count by 75
		swap	d0
		ext.l	d0					; only need remainder
		divu.w	#10,d0				; divide by 10
		move.b	d0,d1
		lsl.b	#4,d1				; divide by 16
		swap	d0
		move.w	#0,ccr
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)

		move.w	#600,fe_waittime(a5)		; set wait timer

		move.w	#DecoderStop,d0			; stop CDC
		jsr	(_CDBIOS).w
		moveq	#ROMReadNum,d0			; start reading the sectors
		jmp	(_CDBIOS).w

; -------------------------------------------------------------------------
; Subroutine to read disc sectors and copy from CDC to destination
; -------------------------------------------------------------------------

ReadSectors:
		popr.l	fe_returnaddr(a5)		; save return address
		clr.w	fe_sectorsread(a5)		; reset sectors read count
		move.w	#30,fe_retries(a5)		; set retry counter

.startread:
		bsr.s	BeginSectorRead

	.bookmark:
		bsr.w	FileEngine_SuspendExecution		; set bookmark; continue at next VBlank
; ===========================================================================

.checkready:
		move.w	#DecoderStatus,d0			; is data ready to read?
		jsr	(_CDBIOS).w
		bcc.s	.read				; if so, branch
		subq.w	#1,fe_waittime(a5)		; decrement wait time
		bge.s	.bookmark			; if we are still waiting, branch
		subq.w	#1,fe_retries(a5)		; if we waited too long, decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.read:
		move.w	#DecoderRead,d0			; prepare to read data
		jsr	(_CDBIOS).w
		bcs.s	.read_retry				; branch if data is not present
		move.l	d0,fe_readtime(a5)		; get time of sector read
		move.b	fe_sectorframe(a5),d0
		cmp.b	fe_readframe(a5),d0		; does the read sector match the sector we want?
		beq.s	.wait_data_set			; if so, branch

	.read_retry:
		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.wait_data_set:
		move.w	#$800-1,d0			; wait for data set

	.wait_loop:
		btst	#cdc_dataready_bit,(cdc_mode).w
		dbne	d0,.wait_loop		; loop until ready or until it takes too long
		bne.s	.transferdata			; if the data is ready to be transfered, branch

		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.s	.read_failed			; give up
; ===========================================================================

.transferdata:
		move.w	#DecoderTransfer,d0			; copy data to destination
		movea.l	fe_readbuffer(a5),a0
		lea	fe_readtime(a5),a1
		jsr	(_CDBIOS).w
		bcs.s	.copy_retry			; if it wasn't successful, branch

		move.b	fe_sectorframe(a5),d0		; does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.incsectorframe			; if so, branch

	.copy_retry:
		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.s	.read_failed			; give up
; ===========================================================================

.incsectorframe:
		move.w	#0,ccr				; next sector frame
		moveq	#1,d1
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)
		cmpi.b	#$75,fe_sectorframe(a5)		; should we wrap it?
		bcs.s	.finish_sector_read		; if not, branch
		clr.b	fe_sectorframe(a5)		; if so, wrap it

	.finish_sector_read:
		move.w	#DecoderAck,d0			; let decoder know read is finished
		jsr	(_CDBIOS).w

		move.w	#6,fe_waittime(a5)		; set new wait time
		move.w	#30,fe_retries(a5)		; set new retry counter
		addi.l	#$800,fe_readbuffer(a5)		; advance read buffer
		addq.w	#1,fe_sectorsread(a5)		; increment sectors read counter
		addq.l	#1,fe_sector(a5)			; next sector
		subq.l	#1,fe_sectorcount(a5)		; decrement sectors to read
		bgt.w	.checkready			; if there are still sectors to read, branch
		move.w	#fstatus_ok,fe_status(a5)		; mark as successful

	.done:
		move.b	fe_cdcmode(a5),(cdc_mode).w	; set CDC device
		movea.l	fe_returnaddr(a5),a0		; go to saved return address
		jmp	(a0)
; ===========================================================================

.read_failed:
		move.w	#fstatus_readfail,fe_status(a5)	; mark as failed
		bra.s	.done

; -------------------------------------------------------------------------
; "Load FMV" operation
; -------------------------------------------------------------------------

FileMode_LoadFMV:
		move.b	#cdc_dest_sub,fe_cdcmode(a5)			; set CDC device to "Sub CPU"
		lea	fe_filename(a5),a0		; find file
		bsr.w	FileFunc_FindFile
		bcs.w	.not_found			; if it wasn't found, branch

		move.l	file_sector(a0),fe_sector(a5)	; get file sector
		move.l	file_length(a0),d1		; get file size
		move.l	d1,fe_filesize(a5)

		move.l	#1,fe_sectorcount(a5)		; get file size in sectors

	.get_sectors:
		subi.l	#sizeof_sector,d1
		ble.s	.read
		addq.l	#1,fe_sectorcount(a5)
		bra.s	.get_sectors

	.read:
		bsr.s	ReadFMVSectors			; read FMV file data
		cmpi.w	#fstatus_ok,fe_status(a5)		; was the operation a success?
		beq.s	.done				; if so, branch
		move.w	#fstatus_loadfail,fe_status(a5)	; mark as failed

	.done:
		move.w	#id_FileMode_None,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation			; loop back
; ===========================================================================

	.not_found:
		move.w	#fstatus_notfound,fe_status(a5)	; mark as not found
		bra.s	.done

; -------------------------------------------------------------------------
; Read sound FMV file data from CD
; -------------------------------------------------------------------------

ReadFMVSectors:
		popr.l	fe_returnaddr(a5)		; save return address
		clr.w	fe_sectorsread(a5)		; reset sectors read count
		move.w	#10,fe_retries(a5)		; set retry counter

.startread:
		bsr.w	BeginSectorRead

	.bookmark:
		bsr.w	FileEngine_SuspendExecution		; set bookmark; continue at next VBlank
; ===========================================================================

.checkready:
		move.w	#DecoderStatus,d0			; is data ready to read?
		jsr	(_CDBIOS).w
		bcc.s	.read				; if so, branch
		subq.w	#1,fe_waittime(a5)		; decrement wait time
		bge.s	.bookmark			; if we are still waiting, branch
		subq.w	#1,fe_retries(a5)		; if we waited too long, decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.read:
		move.w	#DecoderRead,d0			; prepare to read data
		jsr	(_CDBIOS).w
		bcs.s	.read_retry				; branch if data is not present
		move.l	d0,fe_readtime(a5)		; get time of sector read
		move.b	fe_sectorframe(a5),d0
		cmp.b	fe_readframe(a5),d0		; does the read sector match the sector we want?
		beq.s	.wait_data_set			; if so, branch

.read_retry:
		addq.l	#1,fe_fmvfailcount(a5)		; increment fail counter
		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.wait_data_set:
		move.w	#$800-1,d0			; wait for data set

	.wait_loop:
		btst	#cdc_dataready_bit,(cdc_mode).w
		dbne	d0,.wait_loop		; loop until ready or until it takes too long
		bne.s	.transferdata			; if the data is ready to be transfered, branch

		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.transferdata:
		move.w	#DecoderTransfer,d0				; copy data to destination
		movea.l	fe_readbuffer(a5),a0
		lea	fe_readtime(a5),a1
		jsr	(_CDBIOS).w
		bcs.s	.copy_retry			; if it wasn't successful, branch

		move.b	fe_sectorframe(a5),d0		; does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.incsectorframe			; if so, branch

	.copy_retry:
		addq.l	#1,fe_fmvfailcount(a5)		; increment fail counter
		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.w	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.incsectorframe:
		move.w	#0,ccr				; next sector frame
		moveq	#1,d1
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)
		cmpi.b	#$75,fe_sectorframe(a5)		; should we wrap it?
		bcs.s	.finish_sector_read		; if not, branch
		clr.b	fe_sectorframe(a5)		; if so, wrap it

	.finish_sector_read:
		move.w	#DecoderAck,d0			; finish data read
		jsr	(_CDBIOS).w

		move.w	#6,fe_waittime(a5)		; set new wait time
		move.w	#10,fe_retries(a5)		; set new retry counter

		move.w	fe_fmv_sectframe(a5),d0		; get current sector frame
		cmpi.w	#15,d0				; is it time to load graphics data now?
		beq.s	.pcm_done			; if so, branch
		cmpi.w	#74,d0				; are we done loading graphics data?
		beq.s	.gfx_done			; if so, branch
		addi.l	#$800,fe_readbuffer(a5)		; advance read buffer
		bra.s	.advance
; ===========================================================================

.pcm_done:
		move.b	#fmvdata_gfx,fe_fmv_datatype(a5)	; set graphics data type
		bclr	#fmvflag_sect,fe_fmv(a5)		; mark as reading data section 2
		move.l	#wordram_1M,fe_readbuffer(a5)	; set read buffer for graphics data
		bra.w	.advance
; ===========================================================================

.gfx_done:
		bset	#0,(mcd_sub_flag).w			; sync with main CPU
		bset	#fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1
		bset	#fmvflag_ready,fe_fmv(a5)		; mark as ready

	.waitmainCPU:
		cmpi.b	#$FF,(mcd_main_flag).w	; is main CPU OK?
		beq.w	MainCrash1			; branch if not
		btst	#0,(mcd_main_flag).w			; wait for main CPU
		beq.s	.waitmainCPU
		bclr	#0,(mcd_sub_flag).w

		bchg	#bank_assignment_bit,(mcd_mem_mode).w			; swap word RAM banks

	.waitwordRAM:
		btst	#bank_swap_request_bit,(mcd_mem_mode).w
		bne.s	.waitwordRAM

		move.b	#fmvdata_pcm,fe_fmv_datatype(a5)	; set PCM data type
		move.l	#fmv_pcm_buffer,fe_readbuffer(a5)	; set read buffer for PCM data
		bset	#fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1

.advance:
		addq.w	#1,fe_sectorsread(a5)		; increment sectors read counter
		addq.l	#1,fe_sector(a5)			; next sector
		addq.w	#1,fe_fmv_sectframe(a5)		; increment FMV sector frame
		cmpi.w	#75,fe_fmv_sectframe(a5)		; should we wrap it?
		bcs.s	.checksectorsleft		; if not, branch
		clr.w	fe_fmv_sectframe(a5)		; if so, wrap it

	.checksectorsleft:
		subq.l	#1,fe_sectorcount(a5)		; decrement sectors to read
		bgt.w	.checkready			; if there are still sectors to read, branch
		move.w	#fstatus_ok,fe_status(a5)		; mark as successful

.done:
		move.b	fe_cdcmode(a5),(cdc_mode).w	; set CDC device
		movea.l	fe_returnaddr(a5),a0		; go to saved return address
		jmp	(a0)
; ===========================================================================

.read_failed:
		move.w	fe_fmv_sectframe(a5),d0		; get current sector frame
		cmpi.w	#15,d0				; is it time to load graphics data now?
		beq.s	.pcm_done2			; if so, branch
		cmpi.w	#74,d0				; are we done loading graphics data?
		beq.s	.gfx_done2			; if so, branch
		addi.l	#$800,fe_readbuffer(a5)		; advance read buffer
		bra.s	.advance2
; ===========================================================================

.pcm_done2:
		move.b	#fmvdata_gfx,fe_fmv_datatype(a5)	; set graphics data type
		bclr	#fmvflag_sect,fe_fmv(a5)		; mark as reading data section 2
		move.l	#wordram_1M,fe_readbuffer(a5)	; set read buffer for graphics data
		bra.s	.advance2
; ===========================================================================

.gfx_done2:
		bset	#0,(mcd_sub_flag).w			; sync with main CPU
		bset	#fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1
		bset	#fmvflag_ready,fe_fmv(a5)		; mark as ready

	.waitmainCPU2:
		cmpi.b	#$FF,(mcd_main_flag).w	; is main CPU OK?
		beq.w	MainCrash1			; branch if not
		btst	#0,(mcd_main_flag).w			; wait for main CPU
		beq.s	.waitmainCPU2
		bclr	#0,(mcd_sub_flag).w

		bchg	#bank_assignment_bit,(mcd_mem_mode).w			; swap Word RAM banks

	.waitwordram2:
		btst	#bank_swap_request_bit,(mcd_mem_mode).w
		bne.s	.waitwordram2

		move.b	#fmvdata_pcm,fe_fmv_datatype(a5)	; set PCM data type
		move.l	#fmv_pcm_buffer,fe_readbuffer(a5)	; set read buffer for PCM data
		bset	#fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1

.advance2:
		addq.w	#1,fe_sectorsread(a5)		; increment sectors read counter
		addq.l	#1,fe_sector(a5)			; next sector
		addq.w	#1,fe_fmv_sectframe(a5)		; increment FMV sector frame
		cmpi.w	#75,fe_fmv_sectframe(a5)		; should we wrap it?
		bcs.s	.checksectorsleft2		; if not, branch
		clr.w	fe_fmv_sectframe(a5)		; if so, wrap it

	.checksectorsleft2:
		subq.l	#1,fe_sectorcount(a5)		; decrement sectors to read
		bgt.w	.startread			; if there are still sectors to read, branch
		move.w	#fstatus_fmvfail,fe_status(a5)	; mark as failed
		bra.w	.done

; -------------------------------------------------------------------------
; "Load mute FMV" operation
; -------------------------------------------------------------------------

FileMode_LoadMuteFMV:
		move.b	#cdc_dest_sub,fe_cdcmode(a5)			; set CDC device to "Sub CPU"
		lea	fe_filename(a5),a0		; find file
		bsr.w	FileFunc_FindFile
		bcs.s	.not_found			; if it wasn't found, branch

		move.l	file_sector(a0),fe_sector(a5)	; get file sector
		move.l	file_length(a0),d1		; get file size
		move.l	d1,fe_filesize(a5)

		clr.l	fe_sectorcount(a5)		; get file size in sectors

	.get_sectors:
		subi.l	#sizeof_sector,d1
		ble.s	.read
		addq.l	#1,fe_sectorcount(a5)
		bra.s	.get_sectors

	.read:
		bsr.s	ReadMuteFMVSectors		; read FMV file data
		cmpi.w	#fstatus_ok,fe_status(a5)		; was the operation a success?
		beq.s	.done				; if so, branch
		move.w	#fstatus_loadfail,fe_status(a5)	; mark as failed

	.done:
		move.w	#id_FileMode_None,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation			; loop back
; ===========================================================================

.not_found:
		move.w	#fstatus_notfound,fe_status(a5)	; mark as not found
		bra.s	.done

; -------------------------------------------------------------------------
; Read mute FMV file data from CD
; -------------------------------------------------------------------------

ReadMuteFMVSectors:
		popr.l	fe_returnaddr(a5)		; save return address
		clr.w	fe_sectorsread(a5)		; reset sectors read count
		move.w	#10,fe_retries(a5)		; set retry counter

.startread:
		bsr.w	BeginSectorRead

	.bookmark:
		bsr.w	FileEngine_SuspendExecution		; set bookmark; continue at next VBlank
; ===========================================================================

.checkready:
		move.w	#DecoderStatus,d0			; is data ready to read?
		jsr	(_CDBIOS).w
		bcc.s	.read				; if so, branch
		subq.w	#1,fe_waittime(a5)		; decrement wait time
		bge.s	.bookmark			; if we are still waiting, branch
		subq.w	#1,fe_retries(a5)		; if we waited too long, decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.read:
		move.w	#DecoderRead,d0			; prepare to read data
		jsr	(_CDBIOS).w
		bcs.s	.read_retry				; branch if data is not present
		move.l	d0,fe_readtime(a5)		; get time of sector read
		move.b	fe_sectorframe(a5),d0
		cmp.b	fe_readframe(a5),d0		; does the read sector match the sector we want?
		beq.s	.wait_data_set			; if so, branch

.read_retry:
		addq.l	#1,fe_fmvfailcount(a5)		; increment fail counter
		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.s	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.wait_data_set:
		move.w	#$800-1,d0			; wait for data set

	.wait_loop:
		btst	#cdc_dataready_bit,(cdc_mode).w
		dbne	d0,.wait_loop		; loop until ready or until it takes too long
		bne.s	.transferdata			; if the data is ready to be transfered, branch

		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.w	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.transferdata:
		move.w	#DecoderTransfer,d0			; copy data to destination
		movea.l	fe_readbuffer(a5),a0
		lea	fe_readtime(a5),a1
		jsr	(_CDBIOS).w
		bcs.s	.copy_retry				; if it wasn't successful, branch

		move.b	fe_sectorframe(a5),d0		; does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.incsectorframe			; if so, branch

	.copy_retry:
		addq.l	#1,fe_fmvfailcount(a5)		; increment fail counter
		subq.w	#1,fe_retries(a5)		; decrement retry counter
		bge.w	.startread			; if we can still retry, do it
		bra.w	.read_failed			; give up
; ===========================================================================

.incsectorframe:
		move.w	#0,ccr				; next sector frame
		moveq	#1,d1
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)
		cmpi.b	#$75,fe_sectorframe(a5)		; should we wrap it?
		bcs.s	.finish_sector_read		; if not, branch
		clr.b	fe_sectorframe(a5)		; if so, wrap it

	.finish_sector_read:
		move.w	#DecoderAck,d0			; finish data read
		jsr	(_CDBIOS).w

		move.w	#6,fe_waittime(a5)		; set new wait time
		move.w	#10,fe_retries(a5)		; set new retry counter
		addq.w	#1,fe_sectorsread(a5)		; increment sectors read counter
		addq.l	#1,fe_sector(a5)			; next sector
		addq.w	#1,fe_fmv_sectframe(a5)		; increment FMV sector frame

		move.w	fe_fmv_sectframe(a5),d0		; get current sector frame
		cmpi.w	#5,d0				; are we done loading graphics data?
		beq.s	.gfx_done			; if so, branch
		addi.l	#$800,fe_readbuffer(a5)		; advance read buffer
		bra.s	.advance
; ===========================================================================

.gfx_done:
		bset	#0,(mcd_sub_flag).w			; sync with main CPU

	.waitmainCPU:
		cmpi.b	#$FF,(mcd_main_flag).w	; is main CPU OK?
		beq.w	MainCrash1				; branch if not
		btst	#0,(mcd_main_flag).w			; wait for main CPU
		beq.s	.waitmainCPU

		bclr	#0,(mcd_sub_flag).w
		bchg	#bank_assignment_bit,(mcd_mem_mode).w			; swap word RAM banks

	.waitwordRAM:
		btst	#bank_swap_request_bit,(mcd_mem_mode).w
		bne.s	.waitwordRAM

		move.l	#wordram_1M,fe_readbuffer(a5)	; set read buffer for graphics data
		clr.w	fe_fmv_sectframe(a5)		; reset FMV sector frame

.advance:
		subq.l	#1,fe_sectorcount(a5)		; decrement sectors to read
		bgt.w	.checkready			; if there are still sectors to read, branch
		move.w	#fstatus_ok,fe_status(a5)		; mark as successful

.done:
		move.b	fe_cdcmode(a5),(cdc_mode).w	; set CDC device
		movea.l	fe_returnaddr(a5),a0		; go to saved return address
		jmp	(a0)
; ===========================================================================

.read_failed:
		move.w	#fstatus_fmvfail,fe_status(a5)	; mark as failed
		bra.s	.done
