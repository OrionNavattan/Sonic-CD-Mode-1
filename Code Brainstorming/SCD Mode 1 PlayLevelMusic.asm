v_music_mode:	; Music mode: 0 if FM/PSG/PCM only, 1 if PCM past and CCDA Present/Future, 2 if all CDDA audio. Set in options menu, with later two options disabled depending on the disc provided (or absence of one)
fm_pcm_only:	equ 0
pcm_cdda:		equ 1
cdda_only:		equ 2

v_timezone:
time_past: 		equ 0
time_present: 	equ 1
time_future:	equ 2

;=========================================================================================	
; Main CPU code
; Subroutine to play level music

PlayLevelMusic:
		move.b	(v_zone).w,d0			; get zone number
		lsl.w	#2,d0					; multiply by 4 to get past music index for both lists	
		tst.b	(v_music_mode).w
		beq.w	GetFM_PCM	; branch if in FM/PSG/PCM only mode
		cmpi.b	#cdda_only,(v_music_mode).w
		beq.s	Get_CDDA	; branch if in CDDA only mode
		
		; if in CDDA-PCM mode, like Mode 2 version of game	
		tst.b (v_timezone).w
		beq.w	GetFM_PCM	; branch if we are in the past
		
	Get_CDDA:	
		tst.b	(v_timezone).w					; are we in the past?
		beq.s	.past							; if so, branch
		cmpi.b	#time_present,(v_timezone).w	; are we in the present?
		beq.s	.present						; if so, branch
		tst.b	(f_good_future).w				; are we in the the good future?
		beq.s	.badfuture						; if not, branch
		
	;.goodfuture:
		addq.w	#1,d0		; add 3 to get command for good future
	
	.badfuture:
		addq.w	#1,d0		; add 2 to get command for bad future
		
	.present:	
		addq.w	#1,d0		; add 1	to get command for present
		
	.past:		
		move.b	CDDA_Playlist(pc,d0.w),(mcd_maincom_1_lo).l	; get track ID for CDDA music we want to play
		move.w	#SPCmd_PlayCDDA,d0		; command to play CDDA audio (both looped and unlooped)
		bra.w	SubCPUCommand
		
	CDDA_Playlist:
		; IDS for all CDDA level tracks, or'ed with $80 to enable looping
		dc.w	cdda_PPZ_Past|$80
		dc.w	cdda_PPZ_Present|$80
		dc.w	cdda_PPZ_BadFuture|$80
		dc.w	cdda_PPZ_GoodFuture|$80
		;...
		
		
GetFM_PCM:
		tst.b	(v_timezone).w					; are we in the past?
		beq.s	GetPCM							; if so, branch
		cmpi.b	#time_present,(v_timezone).w	; are we in the present?
		beq.s	.present						; if so, branch
		tst.b	(f_good_future).w				; are we in the the good future?
		beq.s	.badfuture						; if not, branch

	;.get_fm:
	;.goodfuture:
		addq.w	#1,d0		; add 3 to get command for good future
	
	.badfuture:
		addq.w	#1,d0		; add 2 to get command for bad future
		
	.present:	
		addq.w	#1,d0		; add 1	to get command for present
		moveq	#0,d1	
		move.b	FM_PCM_Playlist(pc,d0.w),d1	; get sound ID for FM/PSG music
		bra.w	PlayFMSound


FM_PCM_Playlist:
		; sound IDS for FM/PSG tracks and PCM tracks
		dc.w	muspcm_PPZ_Past
		dc.w	musfm_PPZ_Present
		dc.w	musfm_PPZ_BadFuture
		dc.w	musfm_PPZ_GoodFuture
		;...
		
Get_PCM:
		move.b	FM_PCM_Playlist(pc,d0.w),(mcd_maincom_1_lo).l	; get track ID for PCM music
		move.w	#id_SubCmd_PlayPCMMusic,(mcd_com_cmd_0).l		; send command to sub-CPU
	
	.waitsubCPU1:	
		move.w	(mcd_subcom_0).l,d0		; has the Sub CPU received and processed the command?
		beq.s	.waitsubCPU1			; if not, wait
		btst	#7,(mcd_sub_flag).l	; do we need to load new samples?
		beq.s	.no_load			; branch if not
		
		lea	(word_ram_2M).l,a1			; decompress to word RAM (we will already have access)
		movea.l	PCM_Pointers(pc,d1.w),a2	; get bank list (PCM track ID is also index to the sample bank)
		move.w	(a2)+,(a1)+			; loop counter for sub CPU when copying decompressed samples
		move.w	(a2)+,d0			; loop counter for number of samples to decompress
		
	.loop:
		movea.l	(a2)+,a0			; get address of compressed sample
		bsr.w	KosDec				; decompress the sample into word ram
		dbf	d0,.loop				; repeat for all samples
		
		bsr.w	GiveWordRAMAccess	; give the word ram to the sub CPU
	
	.waitsubCPU2:
		move.w	(mcd_subcom_0).l,d0	; has the sub CPU finished copying the decompressed samples?
		beq.s	.waitsubCPU2			; if not, wait
		
	.no_load:
		clr.w	(mcd_maincom_1).l	; clear command used to transfer the music ID
		clr.w	(mcd_maincom_0).l	; mark as ready to send commands again
		
	.waitsubCPUdone:
		move.w	(mcd_subcom_0).l,d0	; is the Sub CPU finished?
		bne.s	.waitsubCPUdone			; if not, wait
		rts
	
PCM_Pointers:
		; Pointers to the PCM bank lists. Each list consists of a loop counter for the 
		; sub CPU (generated via macro). the number of samples to copy - 1, 
		; and longword pointers to the Kosinski-compressed PCM samples required for each track.

		dc.l	PCMList_PPZ
		dc.l	PCMList_CCZ
		dc.l	PCMList_TTZ
		dc.l	PCMList_QQZ
		dc.l	PCMList_WWZ
		dc.l	PCMList_SSZ
		dc.l	PCMList_MMZ

;=========================================================================================	
;=========================================================================================
; Sub-CPU code
; Play a CDDA track. Using a second command register to pass an additional argument with
; the command? That's all it takes to eliminate 40+ different commands for playing the tracks!

SubCmd_PlayCDDA:
		moveq	#0,d1
		move.b	(mcd_maincom_1_lo).l,d1	; get track ID
		bsr.w	Play_CDDA				; play the track
		bra.w	SubCmdFinish
		
;=========================================================================================
; Play a CDDA track
; input: d1 = id of CDDA track, bit 7 set set if track is to be looped
; called by SPCmd_PlayCDDA in level or in sound test
; called by the sub-cpu code on special stage, title screen, and DA garden

PlayCDDA:
		bsr.w	ResetCDDAVol	; reset CD volume	
		move.w	#MSCPLAYR,d0	; loop track
		tst.b	d1	
		bmi.s	.play			; branch if we want track to loop
		move.w	#MSCPLAY1,d0	; only play the track once (speed shoes, invincibility, end-of-level, game over, or sound test)

	.play:
		andi.b	$7F,d1			; clear loop bit
		add.w	d1,d1			; make index
		movea.l	TrackIDs(pc,d1.w),a0	; a0 = pointer to track name
		jmp	(_CDBIOS).w			; send command to BIOS
		
TrackIDs:
		; Array of word-length track IDs for CDDA audio per BIOS specifications. 
		; Past CDDA tracks are appended to the end for compatibility with copies
		; of the Mode 2 version.	

;=========================================================================================

v_pcm_bank:	; id of currently loaded PCM music track (also used as index to their bytecode and metadata, and for getting their sample bank)

; Play a PCM track
; input = track ID in mcd_com_cmd_1
	
SubCmd_PlayPCMMusic:
		moveq	#0,d1
		move.b	(mcd_maincom_1),d1	; get PCM track ID
		cmp.b	d1,(v_pcm_bank).l	; is the data for this track already loaded?
		beq.s	.noload				; if so, branch
		
		move.b d1,(v_pcm_bank).l	; set current PCM bank 
		jsr	(ResetDriver).l		; reset the driver (stopping any sounds that are already playing)
		jsr	(ClearSampleRAM).l	; clear the sample RAM
		bset	#7,(mcd_sub_flag).w	; let the main CPU know we need a new sample bank			
	
		move.w	(mcd_maincom_0).w,(mcd_subcom_0).w	; tell the main CPU we got the memo
		
		bsr.w	WaitWordRAMAccess			; wait while main CPU loads the samples
	
		lea	(word_ram_2M).l,a0	; source of decompressed data
		lea	(Music_Samples).l,a1	; area of PRGRAM reserved for music samples
		move.w	(a0)+,d3		; set loop counter
		
	.loop:	
		move.l	(a0)+,(a1)+	; copy the samples to the destination
		dbf	d3,.loop
		
		bclr	#7,(mcd_sub_flag).w 	; clear flag 
		bsr.w	GiveWordRamAccess		; return word RAM to main CPU
		
	.noload:
		move.b	#pcmcmd_PlayMus,(v_pcm_queue).l	; tell driver to start playing the music	
		move.w	(mcd_maincom_0).w,(mcd_subcom_0).w	; tell the main CPU we are done
		
	.waitmain:	
		move.w	(mcd_maincom_0).w,d0	; is the main CPU ready?
		bne.s	.waitmain
		clr.w	(mcd_subcom_0).w		; mark as ready to receive commands again
		rts	
			