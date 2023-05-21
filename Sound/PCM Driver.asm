; -------------------------------------------------------------------------
; Sonic CD Disassembly
; By Ralakimus 2021
; -------------------------------------------------------------------------
; SMPS-PCM driver
; -------------------------------------------------------------------------

		include	"Sound Drivers/PCM/_Variables.i"
		include	"Sound Drivers/PCM/_Macros.i"
		include	"Sound Drivers/PCM/_smps2asm_inc.i"

; -------------------------------------------------------------------------
; Driver origin point
; -------------------------------------------------------------------------
		
DriverOrigin:

; -------------------------------------------------------------------------
; Driver update entry point
; -------------------------------------------------------------------------

		jmp	UpdateDriver(pc)

; -------------------------------------------------------------------------
; Driver initialization entry point
; -------------------------------------------------------------------------

		jmp	InitDriver(pc)

; -------------------------------------------------------------------------
; Variables
; -------------------------------------------------------------------------

Variables:
		dcb.b	sizeof_pcmallvars,0

; -------------------------------------------------------------------------
; Update driver
; -------------------------------------------------------------------------

UpdateDriver:
		jsr	GetPointers(pc)			; Get driver pointers
		if BOSS<>0
			addq.b	#1,v_unknown_counter(a5)	; Increment unknown counter
		endif
		jsr	ProcSoundQueue(pc)		; Process sound queue
		jsr	PlaySoundID(pc)			; Play sound from queue
		jsr	HandlePause(pc)			; Handle pausing
		jsr	HandleTempo(pc)			; Handle tempo
		jsr	HandleFadeOut(pc)		; Handle fading out
		jsr	UpdateTracks(pc)		; Update tracks
		move.b	v_enabled_channels(a5),pcm_channel_onoff-pcm_regs(a4)	; Update channels on/off array
		rts

; -------------------------------------------------------------------------
; Update tracks
; -------------------------------------------------------------------------
; PARAMETERS:
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

UpdateTracks:
		clr.b	f_sfx(a5)			; Song mode

		lea	song_rhythmtrk(a5),a3		; Update song PCM tracks
		moveq	#PCM_TRACK_CNT-1,d7

.SongTracks:
		adda.w	#sizeof_trackvars,a3			; Next track
		tst.b	(a3)				; Is this track playing?
		bpl.s	.NextSongTrack			; If not, branch
		jsr	UpdateTrack(pc)			; Update track

.NextSongTrack:
		dbf	d7,.SongTracks			; Loop until all song tracks are updated

		lea	sfx_pcm1(a5),a3		; Update SFX PCM tracks
		move.b	#$80,f_sfx(a5)		; SFX mode
		moveq	#PCM_TRACK_CNT-1,d7

.SFXTracks:
		tst.b	(a3)				; Is this track playing?
		bpl.s	.NextSFXTrack			; If not, branch
		jsr	UpdateTrack(pc)			; Update track

.NextSFXTrack:
		adda.w	#sizeof_trackvars,a3			; Next track
		dbf	d7,.SFXTracks			; Loop until all SFX tracks are updated
		rts

; -------------------------------------------------------------------------
; Update track
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
;	a6.l - Pointer to driver information table
; -------------------------------------------------------------------------

UpdateTrack:
		subq.b	#1,ch_delay(a3)		; Decrement duration counter
		bne.s	.Update				; If it hasn't run out, branch
		bclr	#chf_rest_bit,(a3)		; Clear legato flag
		jsr	ParseTrackData(pc)		; Parse track data
		jsr	StartStream(pc)			; Start streaming sample data
		jsr	UpdateFreq(pc)			; Update frequency
		bra.w	NoteOn				; Set note on

.Update:
		jsr	UpdateSample(pC)		; Update sample

		; BUG: The developers removed vibrato support and optimized
		; this call, but they accidentally left in the stack pointer shift
		; in the routine. See the routine for more information.

		bra.w	HandleStaccato			; Handle staccato

; -------------------------------------------------------------------------
; Parse track data
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
;	a6.l - Pointer to driver information table
; -------------------------------------------------------------------------

ParseTrackData:
		movea.l	ch_dataptr(a3),a2		; Get track data pointer
		bclr	#chf_rest_bit,(a3)			; Clear rest flag

.ParseLoop:
		moveq	#0,d5				; Read byte
		move.b	(a2)+,d5
		cmpi.b	#$E0,d5				; Is it a command?
		bcs.s	.NotCommand			; If not, branch
		jsr	TrackCommand(pc)		; Run track command
		bra.s	.ParseLoop			; Read another byte

.NotCommand:
		tst.b	d5				; Is it a note?
		bpl.s	.Duration			; If not, branch
		jsr	GetFreq(pc)			; Get frequency from note
		move.b	(a2)+,d5			; Read another byte
		bpl.s	.Duration			; If it's a duration, branch
		subq.w	#1,a2				; Otherwise, revert read
		bra.w	FinishTrackParse		; Finish up

.Duration:
		jsr	CalcDuration(pc)		; Calculate duration
		bra.w	FinishTrackParse		; Finish up

; -------------------------------------------------------------------------
; Get frequency
; -------------------------------------------------------------------------
; PARAMETERS:
;	d5.b - Note ID
;	a3.l - Pointer to track variables
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

GetFreq:
		subi.b	#$80,d5				; Subtract note value base
		beq.w	RestTrack			; If it's a rest note, branch

		lea	FreqTable(pc),a0		; Frequency table
		add.b	ch_transpose(a3),d5		; Add transposition
		andi.w	#$7F,d5				; Get frequency
		lsl.w	#1,d5
		move.w	(a0,d5.w),ch_freq(a3)
		rts

; -------------------------------------------------------------------------
; Finish up track parsing
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

FinishTrackParse:
		move.l	a2,ch_dataptr(a3)		; Update track data pointer
		move.b	ch_saved_delay(a3),ch_delay(a3)	; Reset duration counter

		btst	#chf_rest_bit,(a3)		; Is legato enabled?
		bne.s	.End				; If so, branch

		jsr	NoteOff(pc)			; Reset track data for next note
		move.b	ch_stac(a3),ch_stac_cnt(a3)
		move.l	ch_samplstart(a3),ch_samplptr(a3)
		move.l	ch_sampsize(a3),ch_samplremain(a3)
		move.b	ch_samplstac(a3),ch_samplstac_cnt(a3)
		move.l	#pcm_waveram,ch_samplram(a3)
		clr.w	ch_samplprevpos(a3)
		clr.w	ch_samplramoff(a3)
		clr.b	ch_samplbnk(a3)
		move.b	#7,ch_samplblks(a3)

.End:
		rts

; -------------------------------------------------------------------------
; Calculate note duration
; -------------------------------------------------------------------------
; PARAMETERS:
;	d5.b - Base note duration
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

CalcDuration:
		move.b	d5,d0				; Copy duration
		move.b	ch_tick(a3),d1		; Get tick multiplier

.Multiply:
		subq.b	#1,d1				; Multiply duration by tick multiplier
		beq.s	.Done
		add.b	d5,d0
		bra.s	.Multiply

.Done:
		move.b	d0,ch_saved_delay(a3)		; Set duration
		move.b	d0,ch_delay(a3)		; Set duration counter
		rts

; -------------------------------------------------------------------------
; Handle staccato
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

HandleStaccato:
		tst.b	ch_stac_cnt(a3)			; Is staccato enabled?
		beq.s	.End				; If not, branch
		subq.b	#1,ch_stac_cnt(a3)		; Decrement staccato counter
		bne.s	.End				; If it hasn't run out, branch
		jsr	RestTrack(pc)			; If it has, set track as rested
		
		; BUG: In the original SMPS 68k, the call path goes driver -> track -> staccato.
		; However, here, they put the staccato handler on the same call level as the track handler,
		; so instead of skipping to the next track, it just outright exits the driver. As a result,
		; the tracks after the current one don't get updated for the current frame, causing them
		; to desync a frame.

		addq.w	#4,sp				; Supposed to skip right to the next track, but actually exits the driver

.End:
		rts

; -------------------------------------------------------------------------
; Update frequency
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
; -------------------------------------------------------------------------

UpdateFreq:
		btst	#chf_rest_bit,ch_flags(a3)	; Is this track rested?
		bne.s	.End				; If so, branch

		move.w	ch_freq(a3),d5			; Get frequency
		move.b	ch_detune(a3),d0		; Add detune
		ext.w	d0
		add.w	d0,d5

		move.w	d5,d1				; Set frequency
		move.b	ch_id(a3),d0
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)
		move.b	d1,pcm_freq_low-pcm_regs(a4)
		lsr.w	#8,d1
		move.b	d1,pcm_freq_hi-pcm_regs(a4)
		rts

.End:
		addq.w	#4,sp				; Skip right to the next track
		rts

; -------------------------------------------------------------------------
; Start streaming sample data
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
; -------------------------------------------------------------------------

StartStream:
		tst.b	ch_samplmode(a3)		; Is this track streaming sample data?
		bne.s	.End				; If not, branch
		btst	#chf_rest_bit,ch_flags(a3)	; Is this track rested?
		bne.s	.End				; If so, branch
		bra.w	StreamSample			; Stream sample data

.End:
		rts

; -------------------------------------------------------------------------
; Update sample
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
; -------------------------------------------------------------------------

UpdateSample:
		tst.b	ch_samplstac_cnt(a3)		; Does this sample have staccato?
		beq.s	.CheckStream			; If not, branch
		subq.b	#1,ch_samplstac_cnt(a3)		; Decrement staccato counter
		beq.w	RestTrack			; If it has run out, branch

.CheckStream:
		tst.b	ch_samplmode(a3)		; Is this track streaming sample data?
		bne.w	.End				; If not, branch
		btst	#chf_rest_bit,ch_flags(a3)	; Is this track rested?
		bne.w	.End				; If so, branch

		lea	(pcm_addr-1).l,a0			; Get current sample playback position
		moveq	#0,d0
		moveq	#0,d1
		move.b	ch_id(a3),d1
		lsl.w	#2,d1
		move.l	(a0,d1.w),d0
		move.l	d0,d1
		lsl.w	#8,d0
		swap	d1
		move.b	d1,d0

		move.w	ch_samplprevpos(a3),d1		; Has it looped back to the start of sample RAM?
		move.w	d0,ch_samplprevpos(a3)
		cmp.w	d1,d0
		bcc.s	.CheckNewBlock			; If not, branch
		subi.w	#$1E00,ch_samplramoff(a3)	; If so, wrap back to start

.CheckNewBlock:
		andi.w	#$1FFF,d0			; Is it time to stream a new block of sample data?
		addi.w	#$1000,d0
		move.w	ch_samplramoff(a3),d1
		cmp.w	d1,d0
		bhi.s	StreamSample			; If so, branch

.End:
		rts

; -------------------------------------------------------------------------
; Stream sample data
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
; -------------------------------------------------------------------------

StreamSample:
		addi.w	#$200,ch_samplramoff(a3)	; Advance sample RAM offset

		move.l	ch_samplremain(a3),d6		; Get number of bytes remaining in sample
		movea.l	ch_samplptr(a3),a2		; Get pointer to sample data
		movea.l	ch_samplram(a3),a0		; Get pointer to sample RAM

		move.b	ch_id(a3),d1		; Get up sample RAM bank to access
		lsl.b	#1,d1
		add.b	ch_samplbnk(a3),d1
		ori.b	#$80,d1
		move.b	d1,pcm_ctrl-pcm_regs(a4)

		move.l	#$200,d0			; $200 bytes per block
		move.l	d0,d1

.StreamLoop:
		cmp.l	d0,d6				; Is the remaining sample data less than the block size?
		bcc.s	.PrepareStream			; If not, branch
		move.l	d6,d0				; If so, only stream what's remaining

.PrepareStream:
		sub.l	d0,d6				; Subtract bytes to be streamed from remaining sample size
		sub.l	d0,d1				; Subtract bytes to be streamed from block size
		subq.l	#1,d0				; Subtract 1 for dbf

.CopySampleData:
		move.b	(a2)+,(a0)+			; Copy sample data
		addq.w	#1,a0				; Skip over even addresses
		dbf	d0,.CopySampleData		; Loop until sample data is copied

		tst.l	d1				; Have we reached the end of the sample before the block was filled up?
		beq.s	.BlockDone			; If not, branch

		moveq	#0,d0				; Loop sample
		move.l	ch_sampsize(a3),d0
		sub.l	ch_samplloop(a3),d0
		suba.l	d0,a2
		add.l	d0,d6
		move.l	d1,d0
		bra.s	.StreamLoop			; Start streaming more data

.BlockDone:
		tst.l	d6				; Are we at the end of the sample?
		bne.s	.NextBlock			; If not, branch

		moveq	#0,d0				; Loop sample
		move.l	ch_sampsize(a3),d0
		sub.l	ch_samplloop(a3),d0
		suba.l	d0,a2
		move.l	d0,d6

.NextBlock:
		move.l	d6,ch_samplremain(a3)		; Update remaining sample size
		move.l	a2,ch_samplptr(a3)		; Update sample pointer

		subq.b	#1,ch_samplblks(a3)		; Decrement blocks left in bank
		bmi.s	.NextBank			; If we have run out, branch
		move.l	a0,ch_samplram(a3)		; Update sample RAM pointer
		rts

.NextBank:
		move.l	#pcm_waveram,ch_samplram(a3)	; Reset sample RAM pointer
		tst.b	ch_samplbnk(a3)		; Were we in the second bank?
		bne.s	.Bank1				; If so, branch
		move.b	#7-1,ch_samplblks(a3)		; Set number of blocks to stream in second bank
		move.b	#1,ch_samplbnk(a3)		; Set to bank 2
		rts

.Bank1:
		move.b	#8-1,ch_samplblks(a3)		; Set number of blocks to stream in first bank
		clr.b	ch_samplbnk(a3)		; Set to bank 1
		rts

; -------------------------------------------------------------------------
; Load samples
; -------------------------------------------------------------------------
; PARAMETERS:
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

LoadSamples:
		lea	SampleIndex(pc),a0		; Sample index
		move.l	(a0)+,d0			; Get number of samples
		beq.s	.End				; If there are none, branch
		bmi.s	.End				; If there are none, branch
		subq.w	#1,d0				; Subtract 1 for dbf

.LoadSample:
		movea.l	(a0)+,a1			; Get sample data
		adda.l	v_drvptroffset(a5),a1
		tst.b	sample_mode(a1)			; Is this sample to be streamed?
		beq.s	.NextSample			; If so, branch

		movea.l	sample_addr(a1),a2			; Get sample address
		adda.l	v_drvptroffset(a5),a2

		move.w	sample_dest(a1),d1			; Get destination address in sample RAM
		move.w	d1,d5
		rol.w	#4,d1				; Get bank ID
		ori.b	#$80,d1
		andi.w	#$F00,d5			; Get offset within bank

		move.l	sample_size(a1),d2			; Get sample size
		move.w	d2,d3				; Get number of banks the sample takes up
		rol.w	#4,d3
		andi.w	#$F,d3

.LoadBankData:
		move.b	d1,pcm_ctrl-pcm_regs(a4)		; Set sample RAM bank
		move.w	d2,d4				; Get remaining sample size
		cmpi.w	#$1000,d2			; Is it greater than the size of a bank
		bls.s	.CopyData			; If not, branch
		move.w	#$1000,d4			; If so, cap at the size of a bank

.CopyData:
		add.w	d5,d2				; Add bank offset to sample size (fake having written up to offset)
		sub.w	d5,d4				; Subtract bank offset from copy length
		subq.w	#1,d4				; Subtract 1 for dbf

		lea	(pcm_waveram).l,a3			; Sample RAM
		adda.w	d5,a3				; Add bank offset
		adda.w	d5,a3

.CopyDataLoop:
		move.b	(a2)+,(a3)+			; Copy sample data
		addq.w	#1,a3				; Skip even addresses
		dbf	d4,.CopyDataLoop		; Loop until sample data is loaded into the bank

		subi.w	#$1000,d2			; Subtract bank size from sample size
		addq.b	#1,d1				; Next bank
		moveq	#0,d5				; Set bank offset to 0
		dbf	d3,.LoadBankData		; Loop until all of the sample is loaded

.NextSample:
		dbf	d0,.LoadSample			; Loop until all samples are loaded

.End:
		rts

; -------------------------------------------------------------------------
; Process sound queue
; -------------------------------------------------------------------------
; PARAMETERS:
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

ProcSoundQueue:
		tst.l	v_soundqueue(a5)			; Are any of the queue slots filled up?
		beq.s	.End				; If not, branch

		lea	v_soundqueue(a5),a1		; Get queue
		move.b	v_priority(a5),d3		; Get saved SFX priority level
		moveq	#4-1,d4				; Number of queue slots

.QueueLoop:
		moveq	#0,d0				; Get queue slot data
		move.b	(a1),d0
		move.b	d0,d1
		clr.b	(a1)+				; Clear slot

		cmpi.b	#PCMM_START,d0			; Is a song queued?
		bcs.s	.NextSlot			; If not, branch
		cmpi.b	#PCMM_END,d0
		bls.w	.SongID				; If so, branch

		cmpi.b	#PCMS_START,d0			; Is a sound effect queued?
		bcs.s	.NextSlot			; If not, branch
	;	if BOSS<>0
	;		cmpi.b	#$BA,d0
	;	else
		cmpi.b	#PCMS_END,d0
	;	endif
		bls.w	.SFXID				; If so, branch

		cmpi.b	#PCMC_START,d0			; Is a song queued?
		bcs.s	.NextSlot			; If not, branch
		cmpi.b	#PCMC_END,d0
		bls.w	.CmdID				; If so, branch

		bra.s	.NextSlot			; Go to next slot

.CheckPriority:
		move.b	(a0,d0.w),d2			; Get priority level
		cmp.b	d3,d2				; Does this sound have a higher priority?
		bcs.s	.NextSlot			; If not, branch
		move.b	d2,d3				; Move up to the new priority level
		move.b	d1,v_soundtoplay(a5)		; Set sound to play

.NextSlot:
		dbf	d4,.QueueLoop			; Loop until all slots are checked
		tst.b	d3				; Is this a SFX priority level?
		bmi.s	.End				; If not, branch
		move.b	d3,v_priority(a5)		; If so, save it

.End:
		rts

.SongID:
		subi.b	#PCMM_START,d0			; Get priority level
		lea	SongPriorities(pc),a0
		bra.s	.CheckPriority			; Check it

.SFXID:
		subi.b	#PCMS_START,d0			; Get priority level
		lea	SFXPriorities(pc),a0
		bra.s	.CheckPriority			; Check it

.CmdID:
		subi.b	#PCMC_START,d0			; Get priority level
		lea	CmdPriorities(pc),a0
		bra.s	.CheckPriority			; Check it

; -------------------------------------------------------------------------
; Play a sound from the queue
; -------------------------------------------------------------------------
; PARAMETERS:
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

PlaySoundID:
		moveq	#0,d7				; Get sound pulled from the queue
		move.b	v_soundtoplay(a5),d7
		beq.w	InitDriver			; If a sound hasn't been queued yet, initialize the driver
		bpl.w	Cmd_Stop			; If we are stopping all sound, branch
		move.b	#$80,v_soundtoplay(a5)		; Mark sound queue as processed

		cmpi.b	#PCMM_START,d7			; Is it a song?
		bcs.s	.End				; If not, branch
		cmpi.b	#PCMM_END,d7
		bls.w	PlaySong			; If so, branch

		cmpi.b	#PCMS_START,d7			; Is it a sound effect?
		bcs.s	.End				; If not, branch
		if BOSS<>0
			cmpi.b	#$BA,d7
		else
			cmpi.b	#PCMS_END,d7
		endif
		bls.w	PlaySFX				; If so, branch

		cmpi.b	#PCMC_START,d7			; Is it a command?
		bcs.s	.End				; If not, branch
		cmpi.b	#PCMC_END,d7
		bls.w	RunCommand			; If so, branch

.End:
		rts

; -------------------------------------------------------------------------
; Play a song
; -------------------------------------------------------------------------
; PARAMETERS:
;	d7.b - Song ID
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

PlaySong:
		jsr	ResetDriver(pc)			; Reset driver

		lea	SongIndex(pc),a2		; Get pointer to song
		subi.b	#PCMM_START,d7
		andi.w	#$7F,d7
		lsl.w	#2,d7
		movea.l	(a2,d7.w),a2
		adda.l	v_drvptroffset(a5),a2
		movea.l	a2,a0

		moveq	#0,d7				; Get number of tracks
		move.b	2(a2),d7
		move.b	4(a2),d1			; Get tick multiplier
		move.b	5(a2),pdrvTempo(a5)		; Get tempo
		move.b	5(a2),f_tempo_counter(a5)
		addq.w	#6,a2

		lea	song_rhythmtrk(a5),a3		; Start with the rhythm track
		lea	ChannelIDs(pc),a1		; Channel ID array
		move.b	#ch_stack,d2		; Call stack base
		subq.w	#1,d7				; Subtract 1 from track count for dbf

.InitTracks:
		moveq	#0,d0				; Get track address
		move.w	(a2)+,d0
		add.l	a0,d0
		move.l	d0,ch_dataptr(a3)
		move.w	(a2)+,ch_transpose(a3)		; Set transposition and volume

		move.b	(a1)+,d0			; Get channel ID
		move.b	d0,ch_id(a3)

		ori.b	#$C0,d0				; Set up PCM registers for channel
		move.b	d0,pcm_ctrl-pcm_regs(a4)

		lsl.b	#5,d0
		move.b	d0,pcm_st-pcm_regs(a4)
		move.b	d0,pcm_lsh-pcm_regs(a4)
		move.b	#0,pcm_lsl-pcm_regs(a4)
		move.b	#$FF,pcm_pan-pcm_regs(a4)
		move.b	ch_volume(a3),pcm_env-pcm_regs(a4)

		move.b	d1,ch_tick(a3)		; Set tick multiplier
		move.b	d2,ch_stackptr(a3)		; Set call stack pointer
		move.b	#1<<chf_enable_bit,ch_flags(a3)	; Mark track as playing
		move.b	#1,ch_delay(a3)		; Set initial note duration

		adda.w	#sizeof_trackvars,a3			; Next track
		dbf	d7,.InitTracks			; Loop until all tracks are set up
		
		clr.b	song_rhythmtrk+ch_flags(a5)	; Disable rhythm track
		move.b	#$FF,v_enabled_channels(a5)			; Silence all channels
		rts

; -------------------------------------------------------------------------
; Channel ID array
; -------------------------------------------------------------------------

ChannelIDs:
		;dc.b	7				; Rhythm; ch 8
		dc.b	0				; PCM1; ch 1
		dc.b	1				; PCM2; ch 2
		dc.b	2				; PCM3; ch 3
		dc.b	3				; PCM4; ch 4
		dc.b	4				; PCM5; ch 5
		dc.b	5				; PCM6; ch 6
		dc.b	7				; PCM7; ch 8
		dc.b	6				; PCM8; ch 7
		even

; -------------------------------------------------------------------------
; Play a sound effect
; -------------------------------------------------------------------------
; PARAMETERS:
;	d7.b - SFX ID
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

PlaySFX:
		lea	SFXIndex(pc),a2			; Get pointer to SFX
		subi.b	#PCMS_START,d7
		andi.w	#$7F,d7
		lsl.w	#2,d7
		movea.l	(a2,d7.w),a2
		adda.l	v_drvptroffset(a5),a2
		movea.l	a2,a0

		moveq	#0,d7				; Get number of tracks
		move.b	3(a2),d7
		move.b	2(a2),d1			; Get tick multiplier
		addq.w	#4,a2

		lea	ChannelIDs(pc),a1		; Channel ID array (unused here)
		move.b	#ch_stack,d2		; Call stack base
		subq.w	#1,d7				; Subtract 1 from track count for dbf

.InitTracks:
		lea	sfx_pcm1(a5),a3		; Get PCM track data
		moveq	#0,d0
		move.b	1(a2),d0
		if sizeof_trackvars=$80
			lsl.w	#7,d0
		else
			mulu.w	#sizeof_trackvars,d0
		endif
		adda.w	d0,a3

		movea.l	a3,a1				; Clear track data
		move.w	#sizeof_trackvars/4-1,d0

.ClearTrack:
		clr.l	(a1)+
		dbf	d0,.ClearTrack
		if (sizeof_trackvars&2)<>0
			clr.w	(a1)+
		endif
		if (sizeof_trackvars&1)<>0
			clr.b	(a1)+
		endif

		move.w	(a2)+,(a3)			; Set track flags and channel ID
		moveq	#0,d0				; Get track address
		move.w	(a2)+,d0
		add.l	a0,d0
		move.l	d0,ch_dataptr(a3)
		move.w	(a2)+,ch_transpose(a3)		; Set transposition and volume

		move.b	ch_id(a3),d0		; Set up PCM registers for channel
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)

		lsl.b	#5,d0
		move.b	d0,pcm_st-pcm_regs(a4)
		move.b	d0,pcm_lsh-pcm_regs(a4)
		move.b	#0,pcm_lsl-pcm_regs(a4)
		move.b	#$FF,pcm_pan-pcm_regs(a4)
		move.b	ch_volume(a3),pcm_env-pcm_regs(a4)

		move.b	d1,ch_tick(a3)		; Set tick multiplier
		move.b	d2,ch_stackptr(a3)		; Set call stack pointer
		move.b	#1,ch_delay(a3)		; Set initial note duration
		move.b	#0,ch_stac(a3)		; Reset staccato
		move.b	#0,ch_detune(a3)		; Reset detune

		dbf	d7,.InitTracks			; Loop until all tracks are set up
		rts

; -------------------------------------------------------------------------
; Handle fading out
; -------------------------------------------------------------------------
; PARAMETERS:
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

HandleFadeOut:
		moveq	#0,d0				; Get number of steps left
		move.b	v_fadeout_counter(a5),d0
		beq.s	.End				; If there are none, branch

		move.b	v_fadeout_delay_counter(a5),d0		; Get fade out delay counter
		beq.s	.FadeOut			; If it has run out, branch
		subq.b	#1,v_fadeout_delay_counter(a5)		; If it hasn't decrement it

.End:
		rts

.FadeOut:
		subq.b	#1,v_fadeout_counter(a5)		; Decrement step counter
		beq.w	ResetDriver			; If it has run out, branch
		move.b	v_fadeout_delay(a5),v_fadeout_delay_counter(a5)

		lea	song_rhythmtrk(a5),a3		; Fade out song tracks
		moveq	#RHY_TRACK_CNT+PCM_TRACK_CNT-1,d7
		move.b	v_fadeout_speed(a5),d6		; Get fade speed
		add.b	d6,v_fadeout_unk(a5)		; Add to unknown fade volume

.FadeTracks:
		tst.b	(a3)				; Is this track playing?
		bpl.s	.NextTrack			; If not, branch
		sub.b	d6,ch_volume(a3)		; Fade out track
		bcc.s	.UpdateVolume			; If it hasn't gone silent yet, branch
		clr.b	ch_volume(a3)			; Otherwise, cap volume at 0
		bclr	#chf_enable_bit,(a3)			; Stop track

.UpdateVolume:
		move.b	ch_id(a3),d0		; Update volume register
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)
		move.b	ch_volume(a3),pcm_env-pcm_regs(a4)

.NextTrack:
		adda.w	#sizeof_trackvars,a3			; Next track
		dbf	d7,.FadeTracks			; Loop until all tracks are processed
		rts

; -------------------------------------------------------------------------
; Handle pausing
; -------------------------------------------------------------------------
; PARAMETERS:
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

HandlePause:
		tst.b	v_pausemode(a5)		; Are we already paused?
		beq.s	.End				; If not, branch
		bmi.s	.Unpause			; If we are unpausing, branch
		cmpi.b	#2,v_pausemode(a5)		; Has the pause already been processed?
		beq.s	.Paused				; If so, branch
		
		move.b	#$FF,pcm_channel_onoff-pcm_regs(a4)	; Mute all channels
		move.b	#2,v_pausemode(a5)		; Mark pause as processed

.Paused:
		addq.w	#4,sp				; Exit the driver

.End:
		rts

.Unpause:
		clr.b	v_pausemode(a5)		; Unpause
		rts

; -------------------------------------------------------------------------
; Handle tempo
; -------------------------------------------------------------------------
; PARAMETERS:
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

HandleTempo:
		tst.b	pdrvTempo(a5)			; Is the tempo set to 0?
		beq.s	.End				; If so, branch
		
		subq.b	#1,f_tempo_counter(a5)		; Decrement tempo counter
		bne.s	.End				; If it hasn't run out, branch
		move.b	pdrvTempo(a5),f_tempo_counter(a5)	; Reset counter

		lea	song_rhythmtrk(a5),a0		; Delay tracks by 1 tick
		move.w	#sizeof_trackvars,d1
		moveq	#RHY_TRACK_CNT+PCM_TRACK_CNT-1,d0

.DelayTracks:
		addq.b	#1,ch_delay(a0)
		adda.w	d1,a0
		dbf	d0,.DelayTracks

.End:
		rts

; -------------------------------------------------------------------------
; Set track as rested
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

RestTrack:
		move.b	ch_id(a3),d0		; Mute track
		bset	d0,v_enabled_channels(a5)
		bset	#chf_rest_bit,ch_flags(a3)	; Mark track as rested
		rts

; -------------------------------------------------------------------------
; Set note off for track
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

NoteOff:
		move.b	ch_id(a3),d0		; Mute track
		bset	d0,v_enabled_channels(a5)
		move.b	v_enabled_channels(a5),pcm_channel_onoff-pcm_regs(a4)	; Update channels on/off array
		rts

; -------------------------------------------------------------------------
; Set note on for track
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

NoteOn:
		btst	#chf_rest_bit,(a3)		; Is legato enabled?
		bne.s	.End				; If so, branch
		move.b	ch_id(a3),d0		; Unmute track
		bclr	d0,v_enabled_channels(a5)

.End:
		rts

; -------------------------------------------------------------------------
; Run a driver command
; -------------------------------------------------------------------------
; PARAMETERS:
;	d7.b - Command ID
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

RunCommand:
		move.b	d7,d0				; Run command
		subi.b	#PCMC_START,d7
		lsl.w	#2,d7
		jmp	.Commands(pc,d7.w)

; -------------------------------------------------------------------------

.Commands:
		jmp	Cmd_FadeOut(pc)			; Fade out
		jmp	Cmd_Stop(pc)			; Stop
		jmp	Cmd_Pause(pc)			; Pause
		jmp	Cmd_Unpause(pc)			; Unpause
		jmp	Cmd_Mute(pc)			; Mute

; -------------------------------------------------------------------------
; Fade out command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

Cmd_FadeOut:
		move.b	#$60,v_fadeout_counter(a5)		; Initialize fade out
		move.b	#1,v_fadeout_delay(a5)
		move.b	#2,v_fadeout_speed(a5)
		rts

; -------------------------------------------------------------------------
; Pause command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

Cmd_Pause:
		move.b	#1,v_pausemode(a5)
		rts

; -------------------------------------------------------------------------
; Unpause command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

Cmd_Unpause:
		move.b	#$80,v_pausemode(a5)
		rts

; -------------------------------------------------------------------------
; Mute command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a4.l - Pointer to PCM registers
; -------------------------------------------------------------------------

Cmd_Mute:
		move.b	#$FF,pcm_channel_onoff-pcm_regs(a4)	; Mute all channels
		rts

; -------------------------------------------------------------------------
; Reset driver
; -------------------------------------------------------------------------
; PARAMETERS:
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

ResetDriver:
		move.b	#$FF,pcm_channel_onoff-pcm_regs(a4)	; Mute all channels
		move.l	v_drvptroffset(a5),d1		; Save pointer offset

		movea.l	a5,a0				; Clear variables
		move.w	#pdrvSize/4-1,d0

.ClearVars:
		clr.l	(a0)+
		dbf	d0,.ClearVars
		if (pdrvSize&2)<>0
			clr.w	(a0)+
		endif
		if (pdrvSize&1)<>0
			clr.b	(a0)+
		endif

		move.l	d1,v_drvptroffset(a5)		; Restore pointer offset
		move.b	#$FF,v_enabled_channels(a5)			; Mute all channels
		move.b	#$80,v_soundtoplay(a5)		; Mark sound queue as processed
		rts

; -------------------------------------------------------------------------
; Stop command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

Cmd_Stop:
		jsr	ResetDriver(pc)			; Reset driver
		jsr	ClearSamples(pc)		; Clear samples
		bra.w	LoadSamples			; Reload samples

; -------------------------------------------------------------------------
; Clear samples
; -------------------------------------------------------------------------
; PARAMETERS:
;	a4.l - Pointer to PCM registers
; -------------------------------------------------------------------------

ClearSamples:
		move.b	#$80,d3				; Start with bank 0
		moveq	#$10-1,d1			; Number of banks

.ClearBank:
		lea	pcm_waveram,a0			; Sample RAM
		move.b	d3,pcm_ctrl-pcm_regs(a4)		; Set bank ID
		moveq	#-1,d2				; Fill with loop flag
		move.w	#$1000-1,d0			; Number of bytes to fill

.ClearBankLoop:
		move.b	d2,(a0)+			; Clear sample RAM bank
		addq.w	#1,a0				; Skip over even addresses
		dbf	d0,.ClearBankLoop		; Loop until bank is cleared

		addq.w	#1,d3				; Next bank
		dbf	d1,.ClearBank			; Loop until all banks are cleared
		rts

; -------------------------------------------------------------------------
; Initialize driver
; -------------------------------------------------------------------------

InitDriver:
		jsr	GetPointers(pc)			; Get driver pointers

		move.b	#$FF,pcm_channel_onoff-pcm_regs(a4)	; Mute all channels
		move.b	#$80,pcm_ctrl-pcm_regs(a4)	; Set to sample RAM bank 0

		lea	DriverOrigin(pc),a0		; Get pointer offset
		suba.l	$1C(a6),a0
		move.l	a0,v_drvptroffset(a5)

		bra.s	Cmd_Stop			; Stop any sound

; -------------------------------------------------------------------------
; Get driver pointers
; -------------------------------------------------------------------------
; RETURNS:
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
;	a6.l - Pointer to driver information table
; -------------------------------------------------------------------------

GetPointers:
		lea	DriverInfo(pc),a6		; Driver info
		lea	Variables(pc),a5		; Driver variables
		lea	(pcm_regs).l,a4			; PCM registers
		rts

; -------------------------------------------------------------------------
; Frequency table
; -------------------------------------------------------------------------

FreqTable:
		;	C      C#/Db  D      D#/Eb  E      F      F#/Gb  G      G#/Ab  A      A#/Bb  B
		dc.w	0				; Rest
		dc.w	$0104, $0113, $0124, $0135, $0148, $015B, $0170, $0186, $019D, $01B5, $01D0, $01EB
		dc.w	$0208, $0228, $0248, $026B, $0291, $02B8, $02E1, $030E, $033C, $036E, $03A3, $03DA
		dc.w	$0415, $0454, $0497, $04DD, $0528, $0578, $05CB, $0625, $0684, $06E8, $0753, $07C4
		dc.w	$083B, $08B0, $093D, $09C7, $0A60, $0AF8, $0BA8, $0C55, $0D10, $0DE2, $0EBE, $0FA4
		dc.w	$107A, $1186, $1280, $1396, $14CC, $1624, $1746, $18DE, $1A38, $1BE0, $1D94, $1F65
		dc.w	$20FF, $2330, $2526, $2753, $29B7, $2C63, $2F63, $31E0, $347B, $377B, $3B41, $3EE8
		dc.w	$4206, $4684, $4A5A, $4EB5, $5379, $58E1, $5DE0, $63C0, $68FF, $6EFF, $783C, $7FC2
		dc.w	$83FC, $8D14, $9780, $9D80, $AA5D, $B1F9, $BBBA, $CC77, $D751, $E333, $F0B5

; -------------------------------------------------------------------------
; Process track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	d5.w - Track command ID
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrackCommand:
		subi.w	#$E0,d5				; Run track command
		lsl.w	#2,d5
		jmp	.Commands(pc,d5.w)
		
; -------------------------------------------------------------------------

.Commands:
		jmp	TrkCmd_Panning(pc)		; Set panning
		jmp	TrkCmd_Detune(pc)		; Set detune
		jmp	TrkCmd_CommFlag(pc)		; Set communication flag
		jmp	TrkCmd_SetCDDALoop(pc)		; Set CDDA loop flag
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Volume(pc)		; Add volume
		jmp	TrkCmd_Legato(pc)		; Set legato
		jmp	TrkCmd_Staccato(pc)		; Set staccato
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Tempo(pc)		; Set tempo
		jmp	TrkCmd_PlaySound(pc)		; Play sound
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Instrument(pc)		; Set instrument
		jmp	TrkCmd_Stop(pc)			; Stop
		jmp	TrkCmd_Stop(pc)			; Stop
		jmp	TrkCmd_Stop(pc)			; Stop
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Jump(pc)			; Jump
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Jump(pc)			; Jump
		jmp	TrkCmd_Repeat(pc)		; Repeat
		jmp	TrkCmd_Call(pc)			; Call
		jmp	TrkCmd_Return(pc)		; Return
		jmp	TrkCmd_TrackTickMult(pc)	; Set track tick multiplier
		jmp	TrkCmd_Transpose(pc)		; Transpose
		jmp	TrkCmd_GlobalTickMult(pc)	; Set global tick multiplier
		jmp	TrkCmd_Null(pc)			; Null
		jmp	TrkCmd_Invalid(pc)		; Invalid

; -------------------------------------------------------------------------
; Null track command
; -------------------------------------------------------------------------

TrkCmd_Null:
		rts

; -------------------------------------------------------------------------
; Panning track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
; -------------------------------------------------------------------------

TrkCmd_Panning:
		move.b	ch_id(a3),d0		; Set channel
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)

		move.b	(a2),ch_pan(a3)		; Set panning
		move.b	(a2)+,pcm_pan-pcm_regs(a4)
		rts

; -------------------------------------------------------------------------
; Detune track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Detune:
		move.b	(a2)+,ch_detune(a3)		; Set detune
		rts

; -------------------------------------------------------------------------
; Communication flag track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_CommFlag:
		move.b	(a2)+,v_timing(a5)		; Set communication flag
		rts

; -------------------------------------------------------------------------
; CDDA loop flag track command
; -------------------------------------------------------------------------
; This was called in the prototype PCM music loop segments, but still
; didn't function.
; -------------------------------------------------------------------------
; PARAMETERS:
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_SetCDDALoop:
		move.b	#1,v_cdda_loop(a5)		; Set CDDA loop flag
		rts

; -------------------------------------------------------------------------
; Volume track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
;	a4.l - Pointer to PCM registers
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_Volume:
		move.b	ch_id(a3),d0		; Set channel
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)

		move.b	(a2)+,d0			; Get volume modifier
		bmi.s	.VolumeDown			; If we are turning the volume down, branch

.VolumeUp:
		add.b	d0,ch_volume(a3)		; Add volume
		bcs.s	.CapVolumeAt0			; If it has overflowed, branch
		bra.w	.UpdateVolume			; Update volume

.VolumeDown:
		add.b	d0,ch_volume(a3)		; Subtract volume
		bcc.s	.CapVolumeAt0			; If it has underflowed, branch

.UpdateVolume:
		move.b	ch_volume(a3),pcm_env-pcm_regs(a4)

.End:
		rts

.CapVolumeAt0:
		tst.b	v_fadeout_counter(a5)		; Is the music fading out?
		beq.s	.End				; If not, branch
		bclr	#chf_enable_bit,(a3)			; Stop track
		move.b	#0,pcm_env-pcm_regs(a4)		; Set volume to 0
		rts

; -------------------------------------------------------------------------
; Legato track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Legato:
		bset	#chf_rest_bit,(a3)		; Set legato flag
		rts

; -------------------------------------------------------------------------
; Staccato track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Staccato:
		move.b	(a2),ch_stac_cnt(a3)		; Set staccato
		move.b	(a2)+,ch_stac(a3)
		rts

; -------------------------------------------------------------------------
; Tempo track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_Tempo:
		move.b	(a2),f_tempo_counter(a5)		; Set tempo
		move.b	(a2)+,pdrvTempo(a5)
		rts

; -------------------------------------------------------------------------
; Sound play track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_PlaySound:
		move.b	(a2)+,v_soundqueue(a5)		; Play sound
		rts

; -------------------------------------------------------------------------
; Instrument track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_Instrument:
		moveq	#0,d0				; Get sample data
		move.b	(a2)+,d0
		lea	SampleIndex(pc),a0
		addq.w	#4,a0
		lsl.w	#2,d0
		movea.l	(a0,d0.w),a0
		adda.l	v_drvptroffset(a5),a0

		move.b	sample_staccato(a0),ch_samplstac(a3)
		move.b	sample_staccato(a0),ch_samplstac_cnt(a3)
		move.b	sample_mode(a0),ch_samplmode(a3)
		bne.s	.StaticSample			; If it's a static sample, branch

		movea.l	sample_addr(a0),a1			; Set up sample streaming
		adda.l	v_drvptroffset(a5),a1
		move.l	a1,ch_samplstart(a3)
		move.l	a1,ch_samplptr(a3)
		move.l	sample_size(a0),ch_sampsize(a3)
		move.l	sample_size(a0),ch_samplremain(a3)
		move.l	sample_loopoffset(a0),ch_samplloop(a3)
		move.l	#pcm_waveram,ch_samplram(a3)
		clr.b	ch_samplbnk(a3)
		move.b	#8-1,ch_samplblks(a3)
		rts

.StaticSample:
		move.b	ch_id(a3),d0		; Set channel
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)

		move.w	sample_dest(a0),d0			; Set sample start point
		move.w	d0,d1
		lsr.w	#8,d0
		move.b	d0,pcm_st-pcm_regs(a4)

		move.l	sample_loopoffset(a0),d0			; Set sample loop point
		add.w	d1,d0
		move.b	d0,pcm_lsl-pcm_regs(a4)
		lsr.w	#8,d0
		move.b	d0,pcm_lsh-pcm_regs(a4)
		rts

; -------------------------------------------------------------------------
; Stop track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a3.l - Pointer to track variables
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_Stop:
		bclr	#chf_enable_bit,(a3)			; Stop track
		bclr	#chf_rest_bit,(a3)		; Clear legato flag
		jsr	RestTrack(pc)			; Set track as rested

		tst.b	f_sfx(a5)			; Are we in SFX mode?
		beq.w	.End				; If not, branch
		clr.b	v_priority(a5)			; Clear SFX priority level

.End:
		addq.w	#8,sp				; Skip right to the next track
		rts

; -------------------------------------------------------------------------
; Jump track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
; -------------------------------------------------------------------------

TrkCmd_Jump:
		move.b	(a2)+,d0			; Jump to offset
		lsl.w	#8,d0
		move.b	(a2)+,d0
		adda.w	d0,a2
		subq.w	#1,a2
		rts

; -------------------------------------------------------------------------
; Repeat track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Repeat:
		moveq	#0,d0				; Get repeat index
		move.b	(a2)+,d0
		move.b	(a2)+,d1			; Get repeat count

		tst.b	ch_loopcounters(a3,d0.w)		; Is the repeat count already set?
		bne.s	.CheckRepeat			; If so, branch
		move.b	d1,ch_loopcounters(a3,d0.w)	; Set repeat count

.CheckRepeat:
		subq.b	#1,ch_loopcounters(a3,d0.w)	; Decrement repeat count
		bne.s	TrkCmd_Jump			; If it hasn't run out, branch
		addq.w	#2,a2				; If it has, skip past repeat offset
		rts

; -------------------------------------------------------------------------
; Call track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Call:
		moveq	#0,d0				; Get call stack pointer
		move.b	ch_stackptr(a3),d0
		subq.b	#4,d0				; Move up call stack
		move.l	a2,(a3,d0.w)			; Save return address
		move.b	d0,ch_stackptr(a3)		; Update call stack pointer
		bra.s	TrkCmd_Jump			; Jump to offset

; -------------------------------------------------------------------------
; Return track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Return:
		moveq	#0,d0				; Get call stack pointer
		move.b	ch_stackptr(a3),d0
		movea.l	(a3,d0.w),a2			; Go to return address
		addq.w	#2,a2
		addq.b	#4,d0				; Move down stack
		move.b	d0,ch_stackptr(a3)		; Update call stack pointer
		rts

; -------------------------------------------------------------------------
; Track tick multiplier track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_TrackTickMult:
		move.b	(a2)+,ch_tick(a3)		; Set tick multiplier
		rts

; -------------------------------------------------------------------------
; Transpose track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a3.l - Pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Transpose:
		move.b	(a2)+,d0			; Add transposition
		add.b	d0,ch_transpose(a3)
		rts

; -------------------------------------------------------------------------
; Global tick multiplier track command
; -------------------------------------------------------------------------
; PARAMETERS:
;	a2.l - Pointer to track data
;	a5.l - Pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_GlobalTickMult:
		lea	song_rhythmtrk(a5),a0		; Update song tracks
		move.b	(a2)+,d0
		move.w	#sizeof_trackvars,d1
		moveq	#RHY_TRACK_CNT+PCM_TRACK_CNT-1,d2

.SetTickMult:
		move.b	d0,ch_tick(a0)		; Set tick multiplier
		adda.w	d1,a0				; Next track
		dbf	d2,.SetTickMult			; Loop until all tracks are updated
		rts

; -------------------------------------------------------------------------
; Invalid track command
; -------------------------------------------------------------------------

TrkCmd_Invalid:

; -------------------------------------------------------------------------
; Driver info
; -------------------------------------------------------------------------

DriverInfo:
		dc.l	SongPriorities			; Song priority table
		dc.l	*
		dc.l	SongIndex			; Song index
		dc.l	SFXIndex			; SFX index
		dc.l	*
		dc.l	*
		dc.l	PCMS_START			; First SFX ID
		dc.l	PCMDrvOrigin			; Origin
		dc.l	SFXPriorities			; SFX priority table
		dc.l	CmdPriorities			; Command priority table

; -------------------------------------------------------------------------
; Sound effect index
; -------------------------------------------------------------------------

SFXIndex:
		dc.l	SFX_Future
		dc.l	SFX_Past
		dc.l	SFX_Alright
		dc.l	SFX_OuttaHere
		dc.l	SFX_Yes
		dc.l	SFX_Yeah
		dc.l	SFX_AmyGiggle
		dc.l	SFX_AmyYelp
		dc.l	SFX_MechStomp
		dc.l	SFX_Bumper
		dc.l	SFX_Shatter
	
; -------------------------------------------------------------------------
; Song index
; -------------------------------------------------------------------------

SongIndex:
		dc.l	Song_PPZPast
		dc.l	Song_CCZPast
		dc.l	Song_TTZPast	
		dc.l	Song_QQZPast
		dc.l	Song_WWZPast
		dc.l	Song_SSZPast
		dc.l	Song_MMZPast
		
; -------------------------------------------------------------------------
; Command priority table
; -------------------------------------------------------------------------

CmdPriorities:
		dc.b	$80				; Fade out
		dc.b	$80				; Stop
		dc.b	$80				; Pause
		dc.b	$80				; Unpause
		dc.b	$80				; Mute
		even

; -------------------------------------------------------------------------
; Sound effect priority table
; -------------------------------------------------------------------------

SFXPriorities:
		dc.b	$70				; Unknown
		dc.b	$70				; "Future"
		dc.b	$70				; "Past"
		dc.b	$70				; "I'm outta here"
		dc.b	$70				; "Yes"
		dc.b	$70				; Amy giggle
		dc.b	$70				; Amy yelp
		dc.b	$70				; Mech stomp
		dc.b	$70				; Bumper
		dc.b	$70				; Shatter
		even
		
; -------------------------------------------------------------------------
; Song priority table
; -------------------------------------------------------------------------
	
SongPriorities:
		rept 7
		dc.b	$80
		endr
		even		
		
; -------------------------------------------------------------------------
; Sound effects
; -------------------------------------------------------------------------

SFX_Future:
		include	"Sound Drivers/PCM/SFX/Future.asm"
		even
SFX_Past:
		include	"Sound Drivers/PCM/SFX/Past.asm"
		even
SFX_OuttaHere:
		include	"Sound Drivers/PCM/SFX/Outta Here.asm"
		even
SFX_Yes:
		include	"Sound Drivers/PCM/SFX/Yes.asm"
		even
SFX_AmyGiggle:
		include	"Sound Drivers/PCM/SFX/Amy Giggle.asm"
		even
SFX_AmyYelp:
		include	"Sound Drivers/PCM/SFX/Amy Yelp.asm"
		even
SFX_MechStomp:
		include	"Sound Drivers/PCM/SFX/Mech Stomp.asm"
		even
SFX_Bumper:
		include	"Sound Drivers/PCM/SFX/Bumper.asm"
		even
SFX_Shatter:
		include	"Sound Drivers/PCM/SFX/Shatter.asm"
		even

SFXSampleIndex:
		SAMPTBLSTART
		SAMPPTR	Future
		SAMPPTR	Past
		SAMPPTR	OuttaHere
		SAMPPTR	Yes
		SAMPPTR	AmyGiggle
		SAMPPTR	AmyYelp
		SAMPPTR	MechStomp
		SAMPPTR	Bumper
		SAMPPTR	Shatter
		SAMPTBLEND
	
	
SFXSampleMetadata:
		SAMPLE	Future,		$0000, 0, 0, 0
		SAMPLE	Past,		$0000, 0, 0, 0
		SAMPLE	MechStomp,	$0000, 0, 0, 0
		SAMPLE	AmyGiggle,	$0000, 0, 0, 0
		SAMPLE	AmyYelp,	$0000, 0, 0, 0
		SAMPLE	Alright,	$0000, 0, 0, 0
		SAMPLE	OuttaHere,	$0000, 0, 0, 0
		SAMPLE	Yes,		$0000, 0, 0, 0
		SAMPLE	Yeah,		$0000, 0, 0, 0
						

		SAMPDAT	Future,		"Sound Drivers/PCM/Samples/Future.bin"
		SAMPDAT	Past,		"Sound Drivers/PCM/Samples/Past.bin"
		SAMPDAT	MechStomp,	"Sound Drivers/PCM/Samples/Mech Stomp.bin"
		SAMPDAT	AmyGiggle,	"Sound Drivers/PCM/Samples/Amy Giggle.bin"
		SAMPDAT	AmyYelp,	"Sound Drivers/PCM/Samples/Amy Yelp.bin"
		SAMPDAT	Alright,	"Sound Drivers/PCM/Samples/Alright.bin"
		SAMPDAT	OuttaHere,	"Sound Drivers/PCM/Samples/Outta Here.bin"
		SAMPDAT	Yes,		"Sound Drivers/PCM/Samples/Yes.bin"
		
MusicModule:
		; at this location, per-zone music modules including sample indexes. 
		; sample metadata, and samples are loaded. All addresses in module are
		; longwords relative to the start of the module, with an origin of 0.