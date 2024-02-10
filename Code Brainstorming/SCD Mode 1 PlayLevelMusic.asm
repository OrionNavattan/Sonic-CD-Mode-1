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
		bsr.w	SubCPUCommand			; send to sub CPU
		clr.w	(mcd_maincom_1_lo).l	; clear command used to transfer the music ID
		rts


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
		move.w	#MSCPLAY1,d0	; play the track once (speed shoes, invincibility, end-of-level, game over, or sound test)
		tst.b	d1
		bpl.s	.play			; branch if we want track to play once

		move.w	#MSCPLAYR,d0	; play track on loop
		andi.b	$7F,d1			; clear loop bit

	.play:
		add.w	d1,d1			; make index
		lea	TrackIDs(pc,d1.w),a0	; a0 = pointer to track name
		jmp	(_CDBIOS).w			; send command to BIOS

TrackIDs:
		; Array of word-length track IDs for CDDA audio per BIOS specifications.
		; Past CDDA tracks are appended to the end for compatibility with copies
		; of the Mode 2 version.

;=========================================================================================
; input:	d0 = id of module to load

LoadPCMModule:
		lea PCM_Modules(pc.d0.w),a6	; get module pointer list
		move.w	(a6)+,d7			; number of items to decompress
		lea (wordram_2m).l,a1	; destination
		waitwordram

	.loop:
		movea.l	(a6)+,a0	; get source
		jsr	(KosDec).w		; decompress
		dbf	d7,.loop		; repeat for all items in list

		suba.l	#wordram_2m,a1	; get total number of bytes to copy
		move.l	a1,(mcd_maincom_2).l	; give to sub CPU
		givewordram				; give wordram to the sub CPU

	.waitsubCPU:
		chksubcpu
		tst.b (mcd_sub_flag).l	; has sub CPU finished copy?
		beq.s	.waitsubCPU
		clr.l	(mcd_maincom_2).l
		rts

PCM_Modules: index offset(*)
		ptr ModulePtrs_PPZ
		ptr ModulePtrs_CCZ
		ptr ModulePtrs_TTZ
		ptr ModulePtrs_QQZ
		ptr ModulePtrs_WWZ
		ptr ModulePtrs_SSZ
		ptr ModulePtrs_MMZ

ModulePtrs_PPZ:
		dc.w	1-1
		dc.l	PCMModule_PPZ

ModulePtrs_CCZ:
		dc.w	2-1
		dc.l	PCMModule_CCZ
		dc.l	PCMSamp_Tambourine

ModulePtrs_TTZ:
		dc.w	1-1
		dc.l	PCMModule_TTZ

ModulePtrs_QQZ:
		dc.w	3-1
		dc.l	PCMModule_QQZ
		dc.l	PCMSamp_Snare2
		dc.l	PCMSamp_Kick1

ModulePtrs_WWZ:
		dc.w	2-1
		dc.l	PCMModule_WWZ
		dc.l	PCMSamp_Tambourine

ModulePtrs_SSZ:
		dc.w	2-1
		dc.l	PCMModule_SSZ
		dc.l	PCMSamp_Snare3

ModulePtrs_MMZ:
		dc.w	4-1
		dc.l	PCMModule_MMZ
		dc.l	PCMSamp_Snare2
		dc.l	PCMSamp_Snare3
		dc.l	PCMSamp_Kick1
;=========================================================================================

; Everything here is assembled beforehand and compressed in ROM
		org 0
PCMModule_TTZ: index 0,1
		ptr SampleIndex_TTZ
		ptr	Mus_TTZ

SampleIndex_TTZ:
    	; sample metaadata pointers


SFXSampleMetadata:
    	; sample metadata table
    	; sample pointers themselves are longword relative to start of module;
    	; samples that are not asssembled with module have their pointers
    	; calculated via macro + filesize function

Mus_TTZ:
		include	"sound/PCM/Music/TTZ.asm"	; include the bytecode

PCMSamp_Marimba:
		incbin 	"sound/PCM/Samples/Marimbia.pcm"	; include all unique samples


;=========================================================================================
v_current_musmodule:	; id of currently loaded PCM music module

; Play a PCM track
; input = track ID in mcd_com_cmd_1

SubCmd_PlayPCMMusic:
		moveq	#0,d1
		move.b	(mcd_maincom_1),d1	; get PCM track ID
		cmp.b	d1,(v_current_musmodule).l	; is the data for this track already loaded?
		beq.s	.noload				; if so, branch

		move.b d1,(v_current_musmodule).l	; set new music module
		tas	(mcd_sub_flag).w	; let the main CPU know we need a new sample bank
		move.w	(mcd_maincom_0).w,(mcd_subcom_0).w	; acknowledge main CPUU
		jsr	(ResetDriver).l		; reset the driver (stopping any sounds that are already playing)
		jsr (ClearSamples).l	; clear waveram
		jsr	(ClearModule).l		; clear the music module ram

		waitwordram			; wait while main CPU decompressed the module

		lea	(word_ram_2M).l,a1	; source of decompressed data
		lea	(MusicModule).l,a2	; area of PRGRAM reserved for music samples
		move.w	(mcd_maincom_2).w,d0		; get count of bytes to copy

		jsr	(MassCopy).w		; copy to program RAM

		clr.b	(mcd_sub_flag).w 	; clear flag
		givewordram		; return word RAM to main CPU

	.noload:
		move.b	#pcmcmd_PlayMus,(v_pcm_queue).l	; tell driver to start playing the music
		move.w	(mcd_maincom_0).w,(mcd_subcom_0).w	; tell the main CPU we are done

	.waitmain:
		move.w	(mcd_maincom_0).w,d0	; is the main CPU ready?
		bne.s	.waitmain
		clr.w	(mcd_subcom_0).w		; mark as ready to receive commands again
		rts

