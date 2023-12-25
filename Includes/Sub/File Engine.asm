; -------------------------------------------------------------------------
; Load file

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
		bne.w	LoadFile			; i not, try again
		rts

; -------------------------------------------------------------------------
; get file name

; input:
;	d0.w - file ID

; output:
;	a0.l - pointer to file name
; -------------------------------------------------------------------------

GetFileName:
		mulu.w	#sizeof_filename+1,d0		; get file name pointer
		lea	FileTable(pc),a0
		adda.w	d0,a0
		rts

; -------------------------------------------------------------------------
; File engine function

; input:
;	d0.w - file engine function ID
; -------------------------------------------------------------------------

FileFunction_NonInt:	; if we're calling this outside of VBlank, we want return values in data registers
		pushr.l	a0-a6				; save registers
		bsr.s	FileFunction
		popr.l	a0-a6
		rts

FileFunction:				; assumes registers have already been backed up
		lea	FileVars(pc),a5			; perform function
		add.w	d0,d0
		move.w	FileFunction_Index(pc,d0.w),d0
		jmp	FileFunction_Index(pc,d0.w)

; -------------------------------------------------------------------------

FileFunction_Index:	index *
		ptr	FileFunc_EngineInit	; initialize engine
		ptr	FileFunc_Operation	; perform operation
		ptr	FileFunc_GetStatus	; get status
		ptr	FileFunc_GetFiles	; get files
		ptr	FileFunc_LoadFile	; load file
		ptr	FileFunc_FindFile	; find file
		ptr	FileFunc_LoadFMV	; load FMV
		ptr	FileFunc_EngineReset	; reset engine
		ptr	FileFunc_LoadMuteFMV	; load mute FMV

; -------------------------------------------------------------------------
; get files
; -------------------------------------------------------------------------

FileFunc_GetFiles:
		move.w	#id_FileMode_GetFiles,fe_opermode(a5)	; set operation mode to "get files"
		move.b	#1<<fmvflag_sect,fe_fmv(a5)		; mark as reading data section 1
		clr.l	fe_fmvfailcount(a5)		; reset fail counter
		rts

; -------------------------------------------------------------------------
; initialize file engine
; -------------------------------------------------------------------------

FileFunc_EngineInit:
		move.l	#FileOperation,fe_operbookmark(a5)	; reset operation bookmark
		move.w	#id_FileMode_None,fe_opermode(a5)	; set operation mode to "none"
		rts

; -------------------------------------------------------------------------
; Perform operation
; -------------------------------------------------------------------------

FileFunc_Operation:
		movea.l	fe_operbookmark(a5),a0		; go to operation bookmark
		jmp	(a0)

; -------------------------------------------------------------------------
; Handle file engine operation
; -------------------------------------------------------------------------

FileOperation:
FileMode_None:
		bsr.s	FileMode_SetOperMark		; set bookmark

		move.w	fe_opermode(a5),d0		; perform operation
		add.w	d0,d0
		move.w	FileOperation_Index(pc,d0.w),d0
		jmp	FileOperation_Index(pc,d0.w)

; -------------------------------------------------------------------------

FileOperation_Index:	index *
		ptr	FileMode_None		; none
		ptr	FileMode_GetFiles	; get files
		ptr	FileMode_LoadFile	; load file
		ptr	FileMode_LoadFMV	; load FMV
		ptr	FileMode_LoadMuteFMV	; load mute FMV

; -------------------------------------------------------------------------
; set operation bookmark
; -------------------------------------------------------------------------

FileMode_SetOperMark:
		popr.l	fe_operbookmark(a5)
		rts

; -------------------------------------------------------------------------
; "Get files" operation
; -------------------------------------------------------------------------

FileMode_GetFiles:
		move.b	#cdd_dest_sub,fe_cdcmode(a5)			; set CDC device to sub CPU
		move.l	#$10,fe_sector(a5)		; read from sector $10 (primary volume descriptor)
		move.l	#1,fe_sectorcount(a5)		; read 1 sector
		lea	fe_dirreadbuf(a5),a0		; get read buffer
		move.l	a0,fe_readbuffer(a5)
		;move.l	#FileVars+fe_dirreadbuf,fe_readbuffer(a5)
		bsr.w	ReadSectors			; read volume descriptor sector
		cmpi.w	#fstatus_readfail,fe_status(a5)	; was the operation a failure?
		beq.w	.Failed				; if so, branch

		lea	fe_dirreadbuf(a5),a1		; primary volume descriptor buffer
		move.l	$A2(a1),fe_sector(a5)		; get root directory sector
		move.l	$AA(a1),d0			; get root directory size
		divu.w	#sizeof_sector,d0			; get size in sectors
		swap	d0
		tst.w	d0				; is the size sector aligned?
		beq.s	.Aligned			; if so, branch
		addi.l	#1<<16,d0			; align sector count

	.Aligned:
		swap	d0				; set sector count
		move.w	d0,fe_dirsectors(a5)
		clr.w	fe_filecount(a5)			; reset file count

.GetDirectory:
		move.l	#1,fe_sectorcount(a5)		; read 1 sector
		lea	fe_dirreadbuf(a5),a1		; get read buffer
		move.l	a1,fe_readbuffer(a5)
		bsr.w	ReadSectors			; read sector of root directory
		cmpi.w	#FSTAT_READFAIL,fe_status(a5)	; Was the operation a failure?
		beq.w	.Failed				; if so, branch

		lea	fe_filelist(a5),a0		; go to file list cursor
		move.w	fe_filecount(a5),d0
		mulu.w	#FILEENTRYSZ,d0
		adda.l	d0,a0

		lea	fe_dirreadbuf(a5),a1		; Prepare to get file info
		moveq	#0,d0

.GetFileInfo:
		move.b	0(a1),d0			; get file entry size
		beq.s	.NoMoreFiles			; if there are no more files left, branch
		move.b	$19(a1),fileFlags(a0)		; get file flags

		moveq	#0,d1				; Prepare to get location and size

.GetFileLocSize:
		move.b	6(a1,d1.w),fileSector(a0,d1.w)	; get file sector
		move.b	$E(a1,d1.w),fileLength(a0,d1.w)	; get file size
		addq.w	#1,d1
		cmpi.w	#4,d1				; Are we done?
		blt.s	.GetFileLocSize			; if not, branch

		moveq	#0,d1				; Prepare to get file name

.GetFileName:
		move.b	$21(a1,d1.w),(a0,d1.w)		; get file name
		addq.w	#1,d1
		cmp.b	$20(a1),d1			; Are we done?
		blt.s	.GetFileName			; if not, branch

.PadFileName:
		cmpi.b	#FILENAMESZ,d1			; Are we at the end of the file name?
		bge.s	.NextFile			; if so, branch
		move.b	#' ',(a0,d1.w)			; if not, pad out with spaces
		addq.w	#1,d1
		bra.s	.PadFileName			; Loop until done

.NextFile:
		addq.w	#1,fe_filecount(a5)		; increment fle count
		adda.l	d0,a1				; Prepare next file
		adda.l	#FILEENTRYSZ,a0
		bra.s	.GetFileInfo

.NoMoreFiles:
		subq.w	#1,fe_dirsectors(a5)		; Decrement directory sector count
		bne.w	.GetDirectory			; if there are sectors left, branch

		move.w	#fstatus_ok,fe_status(a5)		; Mark operation as successful

	.Done:
		move.w	#FMODE_NONE,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation			; Loop back

	.Failed:
		move.w	#fstatus_getfail,fe_status(a5)	; Mark operation as successful
		bra.s	.Done

; -------------------------------------------------------------------------
; "Load file" operation
; -------------------------------------------------------------------------

FileMode_LoadFile:
		move.b	#3,fe_cdcmode(a5)			; set CDC device to "Sub CPU"
		lea	fe_filename(a5),a0		; Find file
		bsr.w	FileFunc_FindFile
		bcs.w	.FileNotFound			; if it wasn't found, branch

		move.l	fileSector(a0),fe_sector(a5)	; get file sector
		move.l	fileLength(a0),d1		; get file size
		move.l	d1,fe_filesize(a5)

		move.l	#1,fe_sectorcount(a5)		; get file size in sectors

.GetSectors:
		subi.l	#$800,d1
		ble.s	.ReadFile
		addq.l	#1,fe_sectorcount(a5)
		bra.s	.GetSectors

.ReadFile:
		bsr.w	ReadSectors			; read file
		cmp.w	#FSTAT_OK,fe_status(a5)		; Was the operation a success?
		beq.s	.Done				; if so, branch
		move.w	#FSTAT_LOADFAIL,fe_status(a5)	; Mark as failed

.Done:
		move.w	#FMODE_NONE,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation			; Loop back

.FileNotFound:
		move.w	#FSTAT_NOTFOUND,fe_status(a5)	; Mark as not found
		bra.s	.Done

; -------------------------------------------------------------------------
; get file engine status
; -------------------------------------------------------------------------
; rETURNS:
;	d0.w  - Return code
;	d1.l  - File size if file load was successful
;	        Sectors read if file load failed
;	cc/cs - Inactive/Busy
; -------------------------------------------------------------------------

FileFunc_GetStatus:
		cmpi.w	#FMODE_NONE,fe_opermode(a5)	; is there an operation going on?
		bne.s	.Busy				; if so, branch

		move.w	fe_status(a5),d0			; get status
		cmpi.w	#FSTAT_OK,d0			; is the status marked as successful?
		bne.s	.Failed				; if not, branch
		move.l	fe_filesize(a5),d1		; return file size
		bra.s	.Inactive

.Failed:
		cmpi.w	#FSTAT_LOADFAIL,d0		; is the status marked as a failed load?
		bne.s	.Inactive			; if not, branch
		move.w	fe_sectorsread(a5),d1		; return sectors read

.Inactive:
		move	#0,ccr				; Mark as inactive
		rts

.Busy:
		move	#1,ccr				; Mark as busy
		rts

; -------------------------------------------------------------------------
; Load a file
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l - File name
;	a1.l - File read destination buffer
; -------------------------------------------------------------------------

FileFunc_LoadFile:
		move.w	#FMODE_LOADFILE,fe_opermode(a5)	; set operation mode to "load file"
		move.l	a1,fe_readbuffer(a5)		; set read buffer

		movea.l	a0,a1				; Copy file name
		lea	fe_filename(a5),a2
		move.w	#FILENAMESZ-1,d1

.CopyFileName:
		move.b	(a1)+,(a2)+
		dbf	d1,.CopyFileName
		rts

; -------------------------------------------------------------------------
; Find a file
; -------------------------------------------------------------------------
; PARAMETERS
;	a0.l  - File name
; rETURNS:
;	a0.l  - Found file information
;	cc/cs - Found/Not found
; -------------------------------------------------------------------------

FileFunc_FindFile:
		move.l	a2,-(sp)			; save a2
		moveq	#0,d1				; Prepare to find file
		movea.l	a0,a1
		move.w	#FILENAMESZ-2,d0

.GetNameLength:
		tst.b	(a1)				; is this character a termination character?
		beq.s	.GotNameLength			; if so, branch
		cmpi.b	#';',(a1)			; is this character a semicolon?
		beq.s	.GotNameLength			; if so, branch
		cmpi.b	#' ',(a1)			; is this character a space?
		beq.s	.GotNameLength			; if so, branch

		addq.w	#1,d1				; increment length
		addq.w	#1,a1				; Next character
		dbf	d0,.GetNameLength		; Loop until finished

.GotNameLength:
		move.w	fe_filecount(a5),d0		; Prepare to scan file list
		movea.l	a0,a1
		lea	fe_filelist(a5),a0

		lea	.FirstFile(pc),a2		; Are we retrieving the first file?
		bsr.w	CompareStrings
		beq.w	.Done				; if so, branch

		movea.l	a0,a2				; start scanning list
		subq.w	#1,d0

.FindFile:
		bsr.w	CompareStrings			; is this file entry the one we are looking for?
		beq.s	.FileFound			; if so, branch
		adda.w	#FILEENTRYSZ,a2		; go to next file
		dbf	d0,.FindFile			; Loop until file is found or until all files are scanned
		bra.s	.FileNotFound			; File not found

.FileFound:
		moveq	#1,d0				; Mark as found
		movea.l	a2,a0				; get file entry

.Done:
		movea.l	(sp)+,a2			; restore a2
		rts

.FileNotFound:
		move	#1,ccr				; Mark as not found
		bra.s	.Done

; -------------------------------------------------------------------------

.FirstFile:
		dc.b	"\          ", 0
		even

; -------------------------------------------------------------------------
; read sectors from CD
; -------------------------------------------------------------------------

ReadSectors:
		move.l	(sp)+,fe_returnaddr(a5)		; save return address
		move.w	#0,fe_sectorsread(a5)		; reset sectors read count
		move.w	#30,fe_retries(a5)		; set retry counter

.StartRead:
		move.b	fe_cdcmode(a5),(mcd_cdd_mode).w	; set CDC device

		lea	fe_sector(a5),a0			; get sector information
		move.l	(a0),d0				; get sector frame (in BCD)
		divu.w	#75,d0
		swap	d0
		ext.l	d0
		divu.w	#10,d0
		move.b	d0,d1
		lsl.b	#4,d1
		swap	d0
		move	#0,ccr
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)

		move.w	#CDCSTOP,d0			; stop CDC
		jsr	(_CDBIOS).w
		move.w	#ROMREADN,d0			; start reading
		jsr	(_CDBIOS).w
		move.w	#600,fe_waittime(a5)		; set wait timer

.Bookmark:
		bsr.w	FileMode_SetOperMark		; set bookmark

.CheckReady:
		move.w	#CDCSTAT,d0			; Check if data is ready
		jsr	(_CDBIOS).w
		bcc.s	.ReadData			; if so, branch
		subq.w	#1,fe_waittime(a5)		; Decrement wait v_time
		bge.s	.Bookmark			; if we are still waiting, branch
		subq.w	#1,fe_retries(a5)		; if we waited too long, decrement retry counter
		bge.s	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.ReadData:
		move.w	#CDCREAD,d0			; read data
		jsr	(_CDBIOS).w
		bcs.w	.ReadRetry			; if the data isn't read, branch
		move.l	d0,fe_readtime(a5)		; get v_time of sector read
		move.b	fe_sectorframe(a5),d0		; Does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.WaitDataSet			; if so, branch

.ReadRetry:
		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.WaitDataSet:
		move.w	#$800-1,d0			; Wait for data set

.WaitDataSetLoop:
		btst	#6,GACDCDEVICE&$FFFFFF
		dbne	d0,.WaitDataSetLoop		; Loop until ready or until it takes too long
		bne.s	.Transfe_rData			; if the data is ready to be transfe_red, branch

		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.Transfe_rData:
		cmpi.b	#2,fe_cdcmode(a5)			; is the CDC device set to "Main CPU"
		beq.w	.MainCPUTransfe_r		; if so, branch

		move.w	#CDCTRN,d0			; Transfe_r data
		movea.l	fe_readbuffer(a5),a0
		lea	fe_readtime(a5),a1
		jsr	(_CDBIOS).w
		bcs.s	.CopyRetry			; if it wasn't successful, branch

		move.b	fe_sectorframe(a5),d0		; Does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.IncSectorFrame			; if so, branch

.CopyRetry:
		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.IncSectorFrame:
		move	#0,ccr				; Next sector frame
		moveq	#1,d1
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)
		cmpi.b	#$75,fe_sectorframe(a5)		; should we wrap it?
		bcs.s	.FinishSectorRead		; if not, branch
		move.b	#0,fe_sectorframe(a5)		; if so, wrap it

.FinishSectorRead:
		move.w	#CDCACK,d0			; Finish data read
		jsr	(_CDBIOS).w

		move.w	#6,fe_waittime(a5)		; set new wait v_time
		move.w	#30,fe_retries(a5)		; set new retry counter
		addi.l	#$800,fe_readbuffer(a5)		; Advance read buffer
		addq.w	#1,fe_sectorsread(a5)		; increment sectors read counter
		addq.l	#1,fe_sector(a5)			; Next sector
		subq.l	#1,fe_sectorcount(a5)		; Decrement sectors to read
		bgt.w	.CheckReady			; if there are still sectors to read, branch
		move.w	#FSTAT_OK,fe_status(a5)		; Mark as successful

.Done:
		move.b	fe_cdcmode(a5),GACDCDEVICE&$FFFFFF	; set CDC device
		movea.l	fe_returnaddr(a5),a0		; go to saved return address
		jmp	(a0)

.ReadFailed:
		move.w	#FSTAT_READFAIL,fe_status(a5)	; Mark as failed
		bra.s	.Done

.MainCPUTransfe_r:
		move.w	#6,fe_waittime(a5)		; set new wait v_time

.WaitMainCopy:
		bsr.w	FileMode_SetOperMark		; set bookmark
		btst	#7,GACDCDEVICE&$FFFFFF		; Has the data been transfe_rred?
		bne.s	.FinishSectorRead		; if so, branch
		subq.w	#1,fe_waittime(a5)		; Decrement wait v_time
		bge.s	.WaitMainCopy			; if we are still waiting, branch
		bra.s	.ReadFailed			; if we have waited too long, branch

; -------------------------------------------------------------------------
; Compare two strings
; -------------------------------------------------------------------------
; PARAMETERS:
;	d1.w  - Number of characters to compare
;	a1.l  - Pointer to string 1
;	a2.l  - Pointer to string 2
; rETURNS:
;	eq/ne - Same/Diffe_rent
; -------------------------------------------------------------------------

CompareStrings:
		movem.l	d1/a1-a2,-(sp)			; save registers

.Compare:
		cmpm.b	(a1)+,(a2)+			; Compare characters
		bne.s	.Done				; if they aren't the same branch
		dbf	d1,.Compare			; Loop until all characters are scanned

		moveq	#0,d1				; Mark strings as the same

.Done:
		movem.l	(sp)+,d1/a1-a2			; restore registers
		rts

; -------------------------------------------------------------------------
; Load an FMV
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l - File name
; -------------------------------------------------------------------------

FileFunc_LoadFMV:
		move.b	#1<<FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 1
		move.w	#FMODE_LOADFMV,fe_opermode(a5)	; set operation mode to "load FMV"
		move.l	#FMVPCMBUF,fe_readbuffer(a5)	; Prepare to read PCM data
		move.w	#0,fe_fmv_sectframe(a5)		; reset FMV sector frame
		bset	#FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 1

		movea.l	a0,a1				; Copy file name
		lea	fe_filename(a5),a2
		move.w	#FILENAMESZ-1,d1

.CopyFileName:
		move.b	(a1)+,(a2)+
		dbf	d1,.CopyFileName
		rts

; -------------------------------------------------------------------------
; "Load FMV" operation
; -------------------------------------------------------------------------

FileMode_LoadFMV:
		move.b	#3,fe_cdcmode(a5)			; set CDC device to "Sub CPU"
		lea	fe_filename(a5),a0		; Find file
		bsr.w	FileFunc_FindFile
		bcs.w	.FileNotFound			; if it wasn't found, branch

		move.l	fileSector(a0),fe_sector(a5)	; get file sector
		move.l	fileLength(a0),d1		; get file size
		move.l	d1,fe_filesize(a5)

		move.l	#1,fe_sectorcount(a5)		; get file size in sectors

.GetSectors:
		subi.l	#$800,d1
		ble.s	.ReadFile
		addq.l	#1,fe_sectorcount(a5)
		bra.s	.GetSectors

.ReadFile:
		bsr.w	ReadFMVSectors			; read FMV file data
		cmp.w	#FSTAT_OK,fe_status(a5)		; Was the operation a success?
		beq.s	.Done				; if so, branch
		move.w	#FSTAT_LOADFAIL,fe_status(a5)	; Mark as failed

.Done:
		move.w	#FMODE_NONE,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation			; Loop back

.FileNotFound:
		move.w	#FSTAT_NOTFOUND,fe_status(a5)	; Mark as not found
		bra.s	.Done

; -------------------------------------------------------------------------
; read FMV file data from CD
; -------------------------------------------------------------------------

ReadFMVSectors:
		move.l	(sp)+,fe_returnaddr(a5)		; save return address
		move.w	#0,fe_sectorsread(a5)		; reset sectors read count
		move.w	#10,fe_retries(a5)		; set retry counter

.StartRead:
		move.b	fe_cdcmode(a5),GACDCDEVICE&$FFFFFF	; set CDC device

		lea	fe_sector(a5),a0			; get sector information
		move.l	(a0),d0				; get sector frame (in BCD)
		divu.w	#75,d0
		swap	d0
		ext.l	d0
		divu.w	#10,d0
		move.b	d0,d1
		lsl.b	#4,d1
		swap	d0
		move	#0,ccr
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)

		move.w	#CDCSTOP,d0			; stop CDC
		jsr	(_CDBIOS).w
		move.w	#ROMREADN,d0			; start reading
		jsr	(_CDBIOS).w
		move.w	#600,fe_waittime(a5)		; set wait timer

.Bookmark:
		bsr.w	FileMode_SetOperMark		; set bookmark

.CheckReady:
		move.w	#CDCSTAT,d0			; Check if data is ready
		jsr	(_CDBIOS).w
		bcc.s	.ReadData			; if so, branch
		subq.w	#1,fe_waittime(a5)		; Decrement wait v_time
		bge.s	.Bookmark			; if we are still waiting, branch
		subq.w	#1,fe_retries(a5)		; if we waited too long, decrement retry counter
		bge.s	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.ReadData:
		move.w	#CDCREAD,d0			; read data
		jsr	(_CDBIOS).w
		bcs.w	.ReadRetry			; if the data isn't read, branch
		move.l	d0,fe_readtime(a5)		; get v_time of sector read
		move.b	fe_sectorframe(a5),d0		; Does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.WaitDataSet			; if so, branch

.ReadRetry:
		addq.l	#1,fe_fmvfailcount(a5)		; increment fail counter
		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.WaitDataSet:
		move.w	#$800-1,d0			; Wait for data set

.WaitDataSetLoop:
		btst	#6,GACDCDEVICE&$FFFFFF
		dbne	d0,.WaitDataSetLoop		; Loop until ready or until it takes too long
		bne.s	.Transfe_rData			; if the data is ready to be transfe_red, branch

		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.Transfe_rData:
		cmpi.b	#2,fe_cdcmode(a5)			; is the CDC device set to "Main CPU"
		beq.w	.MainCPUTransfe_r		; if so, branch

		move.w	#CDCTRN,d0			; Transfe_r data
		movea.l	fe_readbuffer(a5),a0
		lea	fe_readtime(a5),a1
		jsr	(_CDBIOS).w
		bcs.s	.CopyRetry			; if it wasn't successful, branch

		move.b	fe_sectorframe(a5),d0		; Does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.IncSectorFrame			; if so, branch

.CopyRetry:
		addq.l	#1,fe_fmvfailcount(a5)		; increment fail counter
		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.IncSectorFrame:
		move	#0,ccr				; Next sector frame
		moveq	#1,d1
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)
		cmpi.b	#$75,fe_sectorframe(a5)		; should we wrap it?
		bcs.s	.FinishSectorRead		; if not, branch
		move.b	#0,fe_sectorframe(a5)		; if so, wrap it

.FinishSectorRead:
		move.w	#CDCACK,d0			; Finish data read
		jsr	(_CDBIOS).w

		move.w	#6,fe_waittime(a5)		; set new wait v_time
		move.w	#10,fe_retries(a5)		; set new retry counter

		move.w	fe_fmv_sectframe(a5),d0		; get current sector frame
		cmpi.w	#15,d0				; is it v_time to load graphics data now?
		beq.s	.PCMDone			; if so, branch
		cmpi.w	#74,d0				; Are we done loading graphics data?
		beq.s	.GfxDone			; if so, branch
		addi.l	#$800,fe_readbuffer(a5)		; Advance read buffer
		bra.w	.Advance

.PCMDone:
		move.b	#FMVT_GFX,fe_fmv_datatype(a5)	; set graphics data type
		bclr	#FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 2
		move.l	#FMVGFXBUF,fe_readbuffer(a5)	; set read buffer for graphics data
		bra.w	.Advance

.GfxDone:
		bset	#0,mcd_sub_flag.w			; sync with Main CPU
		bset	#FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 1
		bset	#FMVF_READY,fe_fmv(a5)		; Mark as ready

.WaitMain:
		btst	#0,mcd_main_flag.w			; Wait for Main CPU
		beq.s	.WaitMain
		btst	#0,mcd_main_flag.w
		beq.s	.WaitMain
		bclr	#0,mcd_sub_flag.w

		bchg	#0,mcd_mem_mode.w			; swap Word RAM banks

.WaitWordRAM:
		btst	#1,mcd_mem_mode.w
		bne.s	.WaitWordRAM

		move.b	#FMVT_PCM,fe_fmv_datatype(a5)	; set PCM data type
		move.l	#FMVPCMBUF,fe_readbuffer(a5)	; set read buffer for PCM data
		bset	#FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 1

.Advance:
		addq.w	#1,fe_sectorsread(a5)		; increment sectors read counter
		addq.l	#1,fe_sector(a5)			; Next sector
		addq.w	#1,fe_fmv_sectframe(a5)		; increment FMV sector frame
		cmpi.w	#75,fe_fmv_sectframe(a5)		; should we wrap it?
		bcs.s	.CheckSectorsLeft		; if not, branch
		move.w	#0,fe_fmv_sectframe(a5)		; if so, wrap it

.CheckSectorsLeft:
		subq.l	#1,fe_sectorcount(a5)		; Decrement sectors to read
		bgt.w	.CheckReady			; if there are still sectors to read, branch
		move.w	#FSTAT_OK,fe_status(a5)		; Mark as successful

.Done:
		move.b	fe_cdcmode(a5),GACDCDEVICE&$FFFFFF	; set CDC device
		movea.l	fe_returnaddr(a5),a0		; go to saved return address
		jmp	(a0)

.ReadFailed:
		move.w	fe_fmv_sectframe(a5),d0		; get current sector frame
		cmpi.w	#15,d0				; is it v_time to load graphics data now?
		beq.s	.PCMDone2			; if so, branch
		cmpi.w	#74,d0				; Are we done loading graphics data?
		beq.s	.GfxDone2			; if so, branch
		addi.l	#$800,fe_readbuffer(a5)		; Advance read buffer
		bra.w	.Advance2

.PCMDone2:
		move.b	#FMVT_GFX,fe_fmv_datatype(a5)	; set graphics data type
		bclr	#FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 2
		move.l	#FMVGFXBUF,fe_readbuffer(a5)	; set read buffer for graphics data
		bra.w	.Advance2

.GfxDone2:
		bset	#0,mcd_sub_flag.w			; sync with Main CPU
		bset	#FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 1
		bset	#FMVF_READY,fe_fmv(a5)		; Mark as ready

.WaitMain2:
		btst	#0,mcd_main_flag.w			; Wait for Main CPU
		beq.s	.WaitMain2
		btst	#0,mcd_main_flag.w
		beq.s	.WaitMain2
		bclr	#0,mcd_sub_flag.w

		bchg	#0,mcd_mem_mode.w			; swap Word RAM banks

.WaitWordRAM2:
		btst	#1,mcd_mem_mode.w
		bne.s	.WaitWordRAM2

		move.b	#FMVT_PCM,fe_fmv_datatype(a5)	; set PCM data type
		move.l	#FMVPCMBUF,fe_readbuffer(a5)	; set read buffer for PCM data
		bset	#FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 1

.Advance2:
		addq.w	#1,fe_sectorsread(a5)		; increment sectors read counter
		addq.l	#1,fe_sector(a5)			; Next sector
		addq.w	#1,fe_fmv_sectframe(a5)		; increment FMV sector frame
		cmpi.w	#75,fe_fmv_sectframe(a5)		; should we wrap it?
		bcs.s	.CheckSectorsLeft2		; if not, branch
		move.w	#0,fe_fmv_sectframe(a5)		; if so, wrap it

.CheckSectorsLeft2:
		subq.l	#1,fe_sectorcount(a5)		; Decrement sectors to read
		bgt.w	.StartRead			; if there are still sectors to read, branch
		move.w	#FSTAT_FMVFAIL,fe_status(a5)	; Mark as failed
		bra.w	.Done

.MainCPUTransfe_r:
		move.w	#6,fe_waittime(a5)		; set new wait v_time

.WaitMainCopy:
		bsr.w	FileMode_SetOperMark		; set bookmark
		btst	#7,GACDCDEVICE&$FFFFFF		; Has the data been transfe_rred?
		bne.w	.FinishSectorRead		; if so, branch
		subq.w	#1,fe_waittime(a5)		; Decrement wait v_time
		bge.s	.WaitMainCopy			; if we are still waiting, branch
		bra.w	.ReadFailed			; if we have waited too long, branch

; -------------------------------------------------------------------------
; Load a mute FMV
; -------------------------------------------------------------------------
; PARAMETERS:
;	a0.l - File name
; -------------------------------------------------------------------------

FileFunc_LoadMuteFMV:
		move.b	#1<<FMVF_SECT,fe_fmv(a5)		; Mark as reading data section 1
		move.w	#FMODE_LOADFMVM,fe_opermode(a5)	; set operation mode to "load mute FMV"
		move.l	#FMVGFXBUF,fe_readbuffer(a5)	; Prepare to read graphics data
		move.w	#0,fe_fmv_sectframe(a5)		; reset FMV sector frame

		movea.l	a0,a1				; Copy file name
		lea	fe_filename(a5),a2
		move.w	#FILENAMESZ-1,d1

.CopyFileName:
		move.b	(a1)+,(a2)+
		dbf	d1,.CopyFileName
		rts

; -------------------------------------------------------------------------
; "Load mute FMV" operation
; -------------------------------------------------------------------------

FileMode_LoadMuteFMV:
		move.b	#3,fe_cdcmode(a5)			; set CDC device to "Sub CPU"
		lea	fe_filename(a5),a0		; Find file
		bsr.w	FileFunc_FindFile
		bcs.w	.FileNotFound			; if it wasn't found, branch

		move.l	fileSector(a0),fe_sector(a5)	; get file sector
		move.l	fileLength(a0),d1		; get file size
		move.l	d1,fe_filesize(a5)

		move.l	#0,fe_sectorcount(a5)		; get file size in sectors

.GetSectors:
		subi.l	#$800,d1
		ble.s	.ReadFile
		addq.l	#1,fe_sectorcount(a5)
		bra.s	.GetSectors

.ReadFile:
		bsr.w	ReadMuteFMVSectors		; read FMV file data
		cmp.w	#FSTAT_OK,fe_status(a5)		; Was the operation a success?
		beq.s	.Done				; if so, branch
		move.w	#FSTAT_LOADFAIL,fe_status(a5)	; Mark as failed

.Done:
		move.w	#FMODE_NONE,fe_opermode(a5)	; set operation mode to "none"
		bra.w	FileOperation			; Loop back

.FileNotFound:
		move.w	#FSTAT_NOTFOUND,fe_status(a5)	; Mark as not found
		bra.s	.Done

; -------------------------------------------------------------------------
; read mute FMV file data from CD
; -------------------------------------------------------------------------

ReadMuteFMVSectors:
		move.l	(sp)+,fe_returnaddr(a5)		; save return address
		move.w	#0,fe_sectorsread(a5)		; reset sectors read count
		move.w	#10,fe_retries(a5)		; set retry counter

.StartRead:
		move.b	fe_cdcmode(a5),GACDCDEVICE&$FFFFFF	; set CDC device

		lea	fe_sector(a5),a0			; get sector information
		move.l	(a0),d0				; get sector frame (in BCD)
		divu.w	#75,d0
		swap	d0
		ext.l	d0
		divu.w	#10,d0
		move.b	d0,d1
		lsl.b	#4,d1
		swap	d0
		move	#0,ccr
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)

		move.w	#CDCSTOP,d0			; stop CDC
		jsr	(_CDBIOS).w
		move.w	#ROMREADN,d0			; start reading
		jsr	(_CDBIOS).w
		move.w	#600,fe_waittime(a5)		; set wait timer

.Bookmark:
		bsr.w	FileMode_SetOperMark		; set bookmark

.CheckReady:
		move.w	#CDCSTAT,d0			; Check if data is ready
		jsr	(_CDBIOS).w
		bcc.s	.ReadData			; if so, branch
		subq.w	#1,fe_waittime(a5)		; Decrement wait v_time
		bge.s	.Bookmark			; if we are still waiting, branch
		subq.w	#1,fe_retries(a5)		; if we waited too long, decrement retry counter
		bge.s	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.ReadData:
		move.w	#CDCREAD,d0			; read data
		jsr	(_CDBIOS).w
		bcs.w	.ReadRetry			; if the data isn't read, branch
		move.l	d0,fe_readtime(a5)		; get v_time of sector read
		move.b	fe_sectorframe(a5),d0		; Does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.WaitDataSet			; if so, branch

.ReadRetry:
		addq.l	#1,fe_fmvfailcount(a5)		; increment fail counter
		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.WaitDataSet:
		move.w	#$800-1,d0			; Wait for data set

.WaitDataSetLoop:
		btst	#6,GACDCDEVICE&$FFFFFF
		dbne	d0,.WaitDataSetLoop		; Loop until ready or until it takes too long
		bne.s	.Transfe_rData			; if the data is ready to be transfe_red, branch

		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.Transfe_rData:
		cmpi.b	#2,fe_cdcmode(a5)			; is the CDC device set to "Main CPU"
		beq.w	.MainCPUTransfe_r		; if so, branch

		move.w	#CDCTRN,d0			; Transfe_r data
		movea.l	fe_readbuffer(a5),a0
		lea	fe_readtime(a5),a1
		jsr	(_CDBIOS).w
		bcs.s	.CopyRetry			; if it wasn't successful, branch

		move.b	fe_sectorframe(a5),d0		; Does the read sector match the sector we want?
		cmp.b	fe_readframe(a5),d0
		beq.s	.IncSectorFrame			; if so, branch

.CopyRetry:
		addq.l	#1,fe_fmvfailcount(a5)		; increment fail counter
		subq.w	#1,fe_retries(a5)		; Decrement retry counter
		bge.w	.StartRead			; if we can still retry, do it
		bra.w	.ReadFailed			; give up

.IncSectorFrame:
		move	#0,ccr				; Next sector frame
		moveq	#1,d1
		abcd	d1,d0
		move.b	d0,fe_sectorframe(a5)
		cmpi.b	#$75,fe_sectorframe(a5)		; should we wrap it?
		bcs.s	.FinishSectorRead		; if not, branch
		move.b	#0,fe_sectorframe(a5)		; if so, wrap it

.FinishSectorRead:
		move.w	#CDCACK,d0			; Finish data read
		jsr	(_CDBIOS).w

		move.w	#6,fe_waittime(a5)		; set new wait v_time
		move.w	#10,fe_retries(a5)		; set new retry counter
		addq.w	#1,fe_sectorsread(a5)		; increment sectors read counter
		addq.l	#1,fe_sector(a5)			; Next sector
		addq.w	#1,fe_fmv_sectframe(a5)		; increment FMV sector frame

		move.w	fe_fmv_sectframe(a5),d0		; get current sector frame
		cmpi.w	#5,d0				; Are we done loading graphics data?
		beq.s	.GfxDone			; if so, branch
		addi.l	#$800,fe_readbuffer(a5)		; Advance read buffer
		bra.w	.Advance

.GfxDone:
		bset	#0,mcd_sub_flag.w			; sync with Main CPU

.WaitMain:
		btst	#0,mcd_main_flag.w			; Wait for Main CPU
		beq.s	.WaitMain
		btst	#0,mcd_main_flag.w
		beq.s	.WaitMain
		bclr	#0,mcd_sub_flag.w

		bchg	#0,mcd_mem_mode.w			; swap Word RAM banks

.WaitWordRAM:
		btst	#1,mcd_mem_mode.w
		bne.s	.WaitWordRAM

		move.l	#FMVGFXBUF,fe_readbuffer(a5)	; set read buffer for graphics data
		move.w	#0,fe_fmv_sectframe(a5)		; reset FMV sector frame

.Advance:
		subq.l	#1,fe_sectorcount(a5)		; Decrement sectors to read
		bgt.w	.CheckReady			; if there are still sectors to read, branch
		move.w	#FSTAT_OK,fe_status(a5)		; Mark as successful

.Done:
		move.b	fe_cdcmode(a5),GACDCDEVICE&$FFFFFF	; set CDC device
		movea.l	fe_returnaddr(a5),a0		; go to saved return address
		jmp	(a0)

.ReadFailed:
		move.w	#FSTAT_FMVFAIL,fe_status(a5)	; Mark as failed
		bra.s	.Done

.MainCPUTransfe_r:
		move.w	#6,fe_waittime(a5)		; set new wait v_time

.WaitMainCopy:
		bsr.w	FileMode_SetOperMark		; set bookmark
		btst	#7,GACDCDEVICE&$FFFFFF		; Has the data been transfe_rred?
		bne.w	.FinishSectorRead		; if so, branch
		subq.w	#1,fe_waittime(a5)		; Decrement wait v_time
		bge.s	.WaitMainCopy			; if we are still waiting, branch
		bra.s	.ReadFailed			; if we have waited too long, branch

; -------------------------------------------------------------------------
; reset file engine
; -------------------------------------------------------------------------

FileFunc_EngineReset:
		bsr.w	FileFunc_EngineInit
		rts
