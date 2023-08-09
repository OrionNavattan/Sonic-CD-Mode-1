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
; driver origin point
; -------------------------------------------------------------------------
		
DriverOrigin:

; -------------------------------------------------------------------------
; driver update entry point
; -------------------------------------------------------------------------

		jmp	UpdateSound(pc)

; -------------------------------------------------------------------------
; driver initialization entry point
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

UpdateSound:
		jsr	GetPointers(pc)			; get driver pointers
		jsr	CycleSoundQueue(pc)		; process sound queue
		jsr	PlaySoundID(pc)			; play sound from queue
		jsr	PauseMusic(pc)			; handle pausing
		jsr	TempoWait(pc)			; handle tempo
		jsr	DoFadeOut(pc)			; handle fading out
		jsr	UpdateTracks(pc)		; update tracks
		move.b	v_enabled_channels(a5),pcm_channel_onoff-pcm_regs(a4)	; update channels on/off array
		rts

; -------------------------------------------------------------------------
; Subroutine to update all tracks

; input:
;	a4.l = pointer to PCM registers
;	a5.l = pointer to driver variables
; -------------------------------------------------------------------------

UpdateTracks:
		clr.b	f_sfx(a5)			; song mode

		lea	song_rhythmtrk(a5),a3		; update song PCM tracks
		moveq	#countof_pcmtracks-1,d7

.bgmloop:
		adda.w	#sizeof_trackvars,a3			; next track
		tst.b	ch_flags(a3)				; is this track playing?
		bpl.s	.bgmnext			; branch if not
		jsr	UpdateTrack(pc)			; update track

	.bgmnext:
		dbf	d7,.bgmloop			; loop until all song tracks are updated

		lea	sfx_pcm1(a5),a3		; update SFX PCM tracks
		move.b	#$80,f_sfx(a5)		; SFX mode (could be st.b)
		moveq	#countof_pcmtracks-1,d7

.sfxloop:
		tst.b	ch_flags(a3)				; is this track playing?
		bpl.s	.sfxnext			; if not, branch
		jsr	UpdateTrack(pc)			; update track

	.sfxnext:
		adda.w	#sizeof_trackvars,a3			; next track
		dbf	d7,.sfxloop			; loop until all SFX tracks are updated
		rts

; -------------------------------------------------------------------------
; Subroutine to update a single track

; input:
;	a3.l = pointer to track variables
;	a4.l = pointer to PCM registers
;	a5.l = pointer to driver variables
;	a6.l = pointer to driver information table
; -------------------------------------------------------------------------

UpdateTrack:
		subq.b	#1,ch_delay(a3)		; decrement duration counter
		bne.s	.notegoing				; branch if time remains
		bclr	#chf_tie_bit,(a3)		; clear 'do not attack next note' bit
		jsr	PCMDoNext(pc)		; parse track data
		jsr	StartStream(pc)			; start streaming sample data
		jsr	PCMUpdateFreq(pc)			; update frequency
		bra.w	PCMNoteOn				; Set note on
; ===========================================================================

.notegoing:
		jsr	UpdateSample(pC)		; update sample

		; BUG: The developers removed vibrato support and optimized
		; this call, but they accidentally left in the stack pointer shift
		; in the routine. See the routine for more information.

		bra.w	NoteTimeoutUpdate			; apply "note fill" (time until cut-off); Will not return here if "note fill" expires

; -------------------------------------------------------------------------
; Subroutine to parse track data

; input:
;	a3.l = pointer to track variables
;	a4.l = pointer to PCM registers
;	a5.l = pointer to driver variables
;	a6.l = pointer to driver information table
; -------------------------------------------------------------------------

PCMDoNext:
		movea.l	ch_dataptr(a3),a2		; get track data pointer
		bclr	#chf_rest_bit,(a3)			; clear 'track at rest' bit

	.noteloop:
		moveq	#0,d5				; get byte from track
		move.b	(a2)+,d5
		cmpi.b	#$E0,d5				; is it a command? (_firstCom)
		bcs.s	.gotnote			; if not, branch
		jsr	SongCommand(pc)		; run track command
		bra.s	.noteloop			; read another byte
; ===========================================================================

.gotnote:
		tst.b	d5				; is it a duration?
		bpl.s	.gotduration			; if so, branch
		jsr	PCMSetFreq(pc)			; get frequency from note
		move.b	(a2)+,d5			; read another byte
		bpl.s	.Duration			; if it's a duration, branch
		subq.w	#1,a2				; otherwise, put it back
		bra.w	FinishTrackUpdate		; finish up

.gotduration:
		jsr	SetDuration(pc)		; set duration
		bra.w	FinishTrackUpdate		; finish up

; -------------------------------------------------------------------------
; Subroutine to get the frequency for a given note

; input:
;	d5.b - Note ID
;	a3.l - pointer to track variables
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

PCMSetFreq:
		subi.b	#$80,d5				; make it a zero-based index (_firstNote-1)
		beq.w	TrackSetRest			; if it's a rest note, branch

		lea	FreqTable(pc),a0		; frequency table
		add.b	ch_transpose(a3),d5		; add track transposition
		andi.w	#$7F,d5				; clear high byte and sign bit
		lsl.w	#1,d5
		move.w	(a0,d5.w),ch_freq(a3)	; get frequency
		rts

; -------------------------------------------------------------------------
; Subroutine to finish a track update
; -------------------------------------------------------------------------

FinishTrackUpdate:
		move.l	a2,ch_dataptr(a3)		; update track data pointer
		move.b	ch_saved_delay(a3),ch_delay(a3)	; reset duration counter

		btst	#chf_tie_bit,(a3)		; is track set to not attack note?
		bne.s	.exit				; if so, branch

		jsr	NoteOff(pc)			; reset track data for next note
		move.b	ch_savedgate(a3),ch_gate(a3)			; reset note fill
		move.l	ch_samplstart(a3),ch_samplptr(a3)	; reset sample variables
		move.l	ch_sampsize(a3),ch_samplremain(a3)
		move.b	ch_samplstac(a3),ch_samplstac_cnt(a3)
		move.l	#pcm_waveram,ch_samplram(a3)
		clr.w	ch_samplprevpos(a3)
		clr.w	ch_samplramoff(a3)
		clr.b	ch_samplbnk(a3)
		move.b	#7,ch_samplblks(a3)

	.exit:
		rts

; -------------------------------------------------------------------------
; Subroutine to calculate note duration

; input:
;	d5.b = new note duration
; -------------------------------------------------------------------------

SetDuration:
		move.b	d5,d0				; copy duration
		move.b	ch_tick(a3),d1		; get dividing timing

	.multloop:
		subq.b	#1,d1				; multiply duration by tick multiplier
		beq.s	.donemult
		add.b	d5,d0
		bra.s	.multloop
; ===========================================================================

.donemult:
		move.b	d0,ch_saved_delay(a3)		; save duration
		move.b	d0,ch_delay(a3)		; save duration timeout
		rts

; -------------------------------------------------------------------------
; Subroutine to apply note fill (aka, staccato)
; -------------------------------------------------------------------------

NoteTimeoutUpdate:
		tst.b	ch_gate(a3)			; is note fill on?
		beq.s	.exit				; if not, exit
		subq.b	#1,ch_gate(a3)		; decrement note fill timeout
		bne.s	.exit				; if not zero, exit
		jsr	TrackSetRest(pc)				; set rest bit
		
		; BUG: In the original SMPS 68k, the call path goes driver -> track -> staccato.
		; However, here, they put the staccato handler on the same call level as the track handler,
		; so instead of skipping to the next track, it just outright exits the driver. As a result,
		; the tracks after the current one don't get updated for the current frame, causing them
		; to desync a frame.

		addq.w	#4,sp				; Supposed to skip right to the next track, but actually exits the driver

	.exit:
		rts

; -------------------------------------------------------------------------
; Subroutine to update frequency
; -------------------------------------------------------------------------

PCMUpdateFreq:
		btst	#chf_rest_bit,ch_flags(a3)	; is track resting>
		bne.s	.exit				; if so, exit

		move.w	ch_freq(a3),d5			; get frequency
		move.b	ch_detune(a3),d0		; add detune
		ext.w	d0
		add.w	d0,d5

		move.w	d5,d1				; set frequency
		move.b	ch_id(a3),d0
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)
		move.b	d1,pcm_freq_low-pcm_regs(a4)
		lsr.w	#8,d1
		move.b	d1,pcm_freq_hi-pcm_regs(a4)
		rts

	.exit:
		addq.w	#4,sp				; Skip right to the next track
		rts

; -------------------------------------------------------------------------
; Subroutine to initiate streaming sample data
; -------------------------------------------------------------------------

StartStream:
		tst.b	ch_samplmode(a3)		; is this track streaming sample data?
		bne.s	.exit				; if not, exit
		btst	#chf_rest_bit,ch_flags(a3)	; is track resting?
		bne.s	.exit				; if so, exit
		bra.w	StreamSample			; stream sample data

	.exit:
		rts

; -------------------------------------------------------------------------
; Subroutine to update sample
; -------------------------------------------------------------------------

UpdateSample:
		tst.b	ch_samplstac_cnt(a3)		; does this sample have staccato?
		beq.s	.chkstream			; if not, branch
		subq.b	#1,ch_samplstac_cnt(a3)		; decrement staccato counter
		beq.w	TrackSetRest			; if it has run out, branch

	.chkstream:
		tst.b	ch_samplmode(a3)		; is this track streaming sample data?
		bne.w	.exit				; if not, branch
		btst	#chf_rest_bit,ch_flags(a3)	; is this track rested?
		bne.w	.exit				; if so, branch

		; Get current sample playback position.
		lea	(pcm_addr-1).l,a0		; a0 =  waveram internal read registers
		moveq	#0,d0
		moveq	#0,d1
		move.b	ch_id(a3),d1		; get channel ID
		lsl.w	#2,d1				; d1 = index to register for this channel
		move.l	(a0,d1.w),d0		; get current read position of the bank for this channel
		move.l	d0,d1
		lsl.w	#8,d0
		swap	d1
		move.b	d1,d0

		move.w	ch_samplprevpos(a3),d1		
		move.w	d0,ch_samplprevpos(a3)
		cmp.w	d1,d0					; has it looped back to the start of sample RAM?
		bcc.s	.chknewblock			; if not, branch
		subi.w	#sizeof_waverambank-sizeof_waveramblock,ch_samplramoff(a3)	; if so, wrap back to start

	.chknewblock:
		andi.w	#$1FFF,d0				; only need bits that are not channel-specific
		addi.w	#$1000,d0				; stay $1000 bytes ahead of the chip
		move.w	ch_samplramoff(a3),d1
		cmp.w	d1,d0					; is it time to stream a new block of sample data?
		bhi.s	StreamSample			; if so, branch

	.exit:
		rts

; -------------------------------------------------------------------------
; Subroutine to stream sample data to a single block of waveram
; -------------------------------------------------------------------------

StreamSample:
		addi.w	#sizeof_waveramblock,ch_samplramoff(a3)	; advance sample RAM offset

		move.l	ch_samplremain(a3),d6		; get number of bytes remaining in sample
		movea.l	ch_samplptr(a3),a2		; get pointer to sample data
		movea.l	ch_samplram(a3),a0		; get pointer to sample RAM

		move.b	ch_id(a3),d1		; get waveram bank to access
		lsl.b	#1,d1
		add.b	ch_samplbnk(a3),d1
		ori.b	#pcm_on,d1			; pcm_on (as entire register is written, not setting this will silence all channels)
		move.b	d1,pcm_ctrl-pcm_regs(a4)	; set waveram bank

		move.l	#sizeof_waveramblock,d0			; $200 bytes per block
		move.l	d0,d1

.streamloop:
		cmp.l	d0,d6				; is the remaining sample data less than the block size?
		bcc.s	.preparestream			; if not, branch
		move.l	d6,d0				; only stream what's remaining

	.preparestream:
		sub.l	d0,d6				; subtract bytes to be streamed from remaining sample size
		sub.l	d0,d1				; subtract bytes to be streamed from block size
		subq.l	#1,d0				; subtract 1 for loop counter

	.copy:
		move.b	(a2)+,(a0)+			; copy one byte of sample data
		addq.w	#1,a0				; skip over even addresses
		dbf	d0,.copy			; loop until sample data is copied

		tst.l	d1				; is there space left in the block?
		beq.s	.blockdone			; if not, branch

		moveq	#0,d0				; loop sample
		move.l	ch_sampsize(a3),d0		; get sample size
		sub.l	ch_samplloop(a3),d0		; d0 = loop size
		suba.l	d0,a2					; move sample pointer back to loop offset
		add.l	d0,d6					; loop size = remaining sample data for next run of stream loop
		move.l	d1,d0					; d0 = remaining space in block
		bra.s	.streamloop			; start streaming more data
; ===========================================================================

.blockdone:
		tst.l	d6				; are we at the end of the sample?
		bne.s	.nextblock			; branch if not

		moveq	#0,d0				; loop sample
		move.l	ch_sampsize(a3),d0	; get sample size
		sub.l	ch_samplloop(a3),d0	; d0 = loop size
		suba.l	d0,a2				; move sample pointer back to loop offset
		move.l	d0,d6				; loop size = remaining sample data for next run of stream loop

.nextblock:
		move.l	d6,ch_samplremain(a3)		; store remaining sample size
		move.l	a2,ch_samplptr(a3)		; store sample pointer

		subq.b	#1,ch_samplblks(a3)		; decrement blocks left in bank
		bmi.s	.nextbank				; branch if we've run out
		move.l	a0,ch_samplram(a3)	; update sample RAM pointer
		rts

.nextbank:
		move.l	#pcm_waveram,ch_samplram(a3)	; reset sample RAM pointer
		tst.b	ch_samplbnk(a3)		; were we in the second bank?
		bne.s	.bank1				; if so, branch
		move.b	#7-1,ch_samplblks(a3)		; set number of blocks to stream in second bank
		move.b	#1,ch_samplbnk(a3)		; set to bank 2
		rts

	.bank1:
		move.b	#8-1,ch_samplblks(a3)		; set number of blocks to stream in first bank
		clr.b	ch_samplbnk(a3)		; set to bank 1
		rts

; -------------------------------------------------------------------------
; Subroutine to load static samples
; -------------------------------------------------------------------------

LoadStaticSamples:
		lea	SampleIndex(pc),a0		; sample index
		move.l	(a0)+,d0			; get number of samples
		beq.s	.exit				; if there are none, branch
		bmi.s	.exit				; if there are none, branch
		subq.w	#1,d0				; subtract 1 for loop counter

.loadsample:
		movea.l	(a0)+,a1			; get sample data
		adda.l	v_drvptroffset(a5),a1
		tst.b	sample_mode(a1)			; is this sample to be streamed?
		beq.s	.nextsample			; if so, branch

		movea.l	sample_addr(a1),a2			; get sample address
		adda.l	v_drvptroffset(a5),a2

		move.w	sample_dest(a1),d1			; get destination address in sample RAM
		move.w	d1,d5
		rol.w	#4,d1				; get bank ID
		ori.b	#$80,d1
		andi.w	#$F00,d5			; get offset within bank

		move.l	sample_size(a1),d2			; get sample size
		move.w	d2,d3				; get number of banks the sample takes up
		rol.w	#4,d3
		andi.w	#$F,d3

	.loadbankdata:
		move.b	d1,pcm_ctrl-pcm_regs(a4)		; set sample RAM bank
		move.w	d2,d4				; get remaining sample size
		cmpi.w	#sizeof_waverambank/2,d2			; is it greater than the size of a bank?
		bls.s	.copydata			; if not, branch
		move.w	#sizeof_waverambank/2,d4			; if so, cap at the size of a bank

	.copydata:
		add.w	d5,d2				; add bank offset to sample size (fake having written up to offset)
		sub.w	d5,d4				; subtract bank offset from copy length
		subq.w	#1,d4				; subtract 1 for dbf

		lea	(pcm_waveram).l,a3			; sample RAM
		adda.w	d5,a3				; add bank offset
		adda.w	d5,a3

	.copyloop:
		move.b	(a2)+,(a3)+			; copy one byte of sample data
		addq.w	#1,a3				; skip even addresses
		dbf	d4,.copyloop		; loop until sample data is loaded into the bank

		subi.w	#sizeof_waverambank/2,d2			; subtract bank size from sample size
		addq.b	#1,d1				; next bank
		moveq	#0,d5				; set bank offset to 0
		dbf	d3,.loadbankdata		; loop until all of the sample is loaded

	.nextsample:
		dbf	d0,.loadsample			; loop until all samples are loaded

	.exit:
		rts

; -------------------------------------------------------------------------
; Process sound queue
; -------------------------------------------------------------------------
; input:
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

CycleSoundQueue:
		tst.l	v_soundqueue(a5)			; are any of the queue slots occupied?
		beq.s	.exit				; if not, branch

		lea	v_soundqueue(a5),a1		; get queue
		move.b	v_priority(a5),d3		; get saved SFX priority level
		moveq	#4-1,d4				; number of queue slots

.inputloop:
		moveq	#0,d0				
		move.b	(a1),d0			; move track number to d0
		move.b	d0,d1
		clr.b	(a1)+				; clear slot

		cmpi.b	#PCMM_START,d0			; is a song queued? (is it the Startmusic command?)	; _firstMusic
		bcs.s	.nextinput			; if not, branch
		cmpi.b	#PCMM_END,d0
		bls.w	.havesong				; if so, branch

		cmpi.b	#PCMS_START,d0			; is a sound effect queued?
		bcs.s	.nextinput			; if not, branch
		cmpi.b	#PCMS_END,d0
		bls.w	.havesfx				; if so, branch

		cmpi.b	#PCMC_START,d0			; is a command queued?
		bcs.s	.nextinput			; if not, branch
		cmpi.b	#PCMC_END,d0
		bls.w	.havecmd				; if so, branch

		bra.s	.nextinput			; go to next slot
; ===========================================================================

.chkpriority:
		move.b	(a0,d0.w),d2			; get sound type
		cmp.b	d3,d2				; does this sound have a higher priority?
		bcs.s	.nextinput			; if not, branch
		move.b	d2,d3				; store new priority level
		move.b	d1,v_soundtoplay(a5)		; queue sound to play

.nextinput:
		dbf	d4,.inputloop			; loop until all slots are checked
		
		tst.b	d3				; is this a SFX priority level?
		bmi.s	.exit				; if not, branch
		move.b	d3,v_priority(a5)		; if so, save it

.exit:
		rts
; ===========================================================================

.havesong:
		subi.b	#PCMM_START,d0			; get priority level
		lea	SongPriorities(pc),a0
		bra.s	.chkpriority			; check it

.havesfx:
		subi.b	#PCMS_START,d0			; get priority level
		lea	SFXPriorities(pc),a0
		bra.s	.chkpriority			; check it

.havecmd:
		subi.b	#PCMC_START,d0			; get priority level
		lea	CmdPriorities(pc),a0
		bra.s	.chkpriority			; check it

; -------------------------------------------------------------------------
; Subroutine to begin playing a sound
; -------------------------------------------------------------------------

PlaySoundID:
		moveq	#0,d7				
		move.b	v_soundtoplay(a5),d7	; get sound pulled from the queue
		beq.w	InitDriver			; branch if it's sound 0 (initialize the driver)
		bpl.w	Cmd_Stop			; if we are stopping all sound, branch
		move.b	#$80,v_soundtoplay(a5)		; mark sound queue as processed ; cmd_Null

		cmpi.b	#PCMM_START,d7			; is it a song?
		bcs.s	.exit				; if not, branch
		cmpi.b	#PCMM_END,d7
		bls.w	PlaySong			; if so, branch

		cmpi.b	#PCMS_START,d7			; is it a sound effect?
		bcs.s	.exit				; if not, branch
	;	if BOSS<>0
	;		cmpi.b	#$BA,d7
	;	else
		cmpi.b	#PCMS_END,d7
	;	endif
		bls.w	PlaySFX				; if so, branch

		cmpi.b	#PCMC_START,d7			; is it a command?
		bcs.s	.exit				; if not, branch
		cmpi.b	#PCMC_END,d7
		bls.w	SongCommand			; if so, branch

.exit:
		rts

; -------------------------------------------------------------------------
; Play a song

; input:
;	d7.b = Song ID
; -------------------------------------------------------------------------

PlaySong:
		jsr	ResetDriver(pc)			; Reset driver

		lea	SongIndex(pc),a2		; get pointer to song
		subi.b	#PCMM_START,d7
		andi.w	#$7F,d7
		lsl.w	#2,d7
		movea.l	(a2,d7.w),a2
		adda.l	v_drvptroffset(a5),a2
		movea.l	a2,a0

		moveq	#0,d7				; get number of tracks
		move.b	2(a2),d7
		move.b	4(a2),d1			; get tick multiplier
		move.b	5(a2),v_current_tempo(a5)		; get tempo
		move.b	5(a2),v_tempo_counter(a5)
		addq.w	#6,a2

		lea	song_rhythmtrk(a5),a3		; Start with the rhythm track
		lea	ChannelIDs(pc),a1		; Channel ID array
		move.b	#ch_stack,d2		; Call stack base
		subq.w	#1,d7				; Subtract 1 from track count for dbf

.InitTracks:
		moveq	#0,d0				; get track address
		move.w	(a2)+,d0
		add.l	a0,d0
		move.l	d0,ch_dataptr(a3)
		move.w	(a2)+,ch_transpose(a3)		; Set transposition and volume

		move.b	(a1)+,d0			; get channel ID
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

		adda.w	#sizeof_trackvars,a3			; next track
		dbf	d7,.InitTracks			; loop until all tracks are set up
		
		clr.b	song_rhythmtrk+ch_flags(a5)	; disable rhythm track
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
; input:
;	d7.b - SFX ID
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

PlaySFX:
		lea	SFXIndex(pc),a2			; get pointer to SFX
		subi.b	#PCMS_START,d7
		andi.w	#$7F,d7
		lsl.w	#2,d7
		movea.l	(a2,d7.w),a2
		adda.l	v_drvptroffset(a5),a2
		movea.l	a2,a0

		moveq	#0,d7				; get number of tracks
		move.b	3(a2),d7
		move.b	2(a2),d1			; get tick multiplier
		addq.w	#4,a2

		lea	ChannelIDs(pc),a1		; Channel ID array (unused here)
		move.b	#ch_stack,d2		; Call stack base
		subq.w	#1,d7				; Subtract 1 from track count for dbf

.InitTracks:
		lea	sfx_pcm1(a5),a3		; get PCM track data
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
		moveq	#0,d0				; get track address
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
		move.b	#0,ch_savedgate(a3)		; Reset staccato
		move.b	#0,ch_detune(a3)		; Reset detune

		dbf	d7,.InitTracks			; loop until all tracks are set up
		rts

; -------------------------------------------------------------------------
; Handle fading out
; -------------------------------------------------------------------------
; input:
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

DoFadeOut:
		moveq	#0,d0				; get number of steps left
		move.b	v_fadeout_counter(a5),d0
		beq.s	.exit				; if there are none, branch

		move.b	v_fadeout_delay_counter(a5),d0		; get fade out delay counter
		beq.s	.FadeOut			; if it has run out, branch
		subq.b	#1,v_fadeout_delay_counter(a5)		; if it hasn't decrement it

.exit:
		rts

.FadeOut:
		subq.b	#1,v_fadeout_counter(a5)		; decrement step counter
		beq.w	ResetDriver			; if it has run out, branch
		move.b	v_fadeout_delay(a5),v_fadeout_delay_counter(a5)

		lea	song_rhythmtrk(a5),a3		; Fade out song tracks
		moveq	#RHY_TRACK_CNT+countof_pcmtracks-1,d7
		move.b	v_fadeout_speed(a5),d6		; get fade speed
		add.b	d6,v_fadeout_unk(a5)		; Add to unknown fade volume

.FadeTracks:
		tst.b	(a3)				; is this track playing?
		bpl.s	.NextTrack			; if not, branch
		sub.b	d6,ch_volume(a3)		; Fade out track
		bcc.s	.UpdateVolume			; if it hasn't gone silent yet, branch
		clr.b	ch_volume(a3)			; Otherwise, cap volume at 0
		bclr	#chf_enable_bit,(a3)			; Stop track

.UpdateVolume:
		move.b	ch_id(a3),d0		; update volume register
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)
		move.b	ch_volume(a3),pcm_env-pcm_regs(a4)

.NextTrack:
		adda.w	#sizeof_trackvars,a3			; next track
		dbf	d7,.FadeTracks			; loop until all tracks are processed
		rts

; -------------------------------------------------------------------------
; Handle pausing
; -------------------------------------------------------------------------
; input:
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

PauseMusic:
		tst.b	v_pausemode(a5)		; Are we already paused?
		beq.s	.exit				; if not, branch
		bmi.s	.Unpause			; if we are unpausing, branch
		cmpi.b	#2,v_pausemode(a5)		; Has the pause already been processed?
		beq.s	.Paused				; if so, branch
		
		move.b	#$FF,pcm_channel_onoff-pcm_regs(a4)	; Mute all channels
		move.b	#2,v_pausemode(a5)		; Mark pause as processed

.Paused:
		addq.w	#4,sp				; Exit the driver

.exit:
		rts

.Unpause:
		clr.b	v_pausemode(a5)		; Unpause
		rts

; -------------------------------------------------------------------------
; Handle tempo
; -------------------------------------------------------------------------
; input:
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TempoWait:
		tst.b	v_current_tempo(a5)			; is the tempo set to 0?
		beq.s	.exit				; if so, branch
		
		subq.b	#1,v_tempo_counter(a5)		; has main tempo timer expired?
		bne.s	.exit				; branch if not
		move.b	v_current_tempo(a5),v_tempo_counter(a5)	; Reset counter

		lea	song_rhythmtrk(a5),a0		; delay tracks by 1 tick
		move.w	#sizeof_trackvars,d1
		moveq	#countof_rhythmtracks+countof_pcmtracks-1,d0

.DelayTracks:
		addq.b	#1,ch_delay(a0)
		adda.w	d1,a0
		dbf	d0,.DelayTracks

.exit:
		rts

; -------------------------------------------------------------------------
; Set track as rested
; -------------------------------------------------------------------------
; input:
;	a3.l - pointer to track variables
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TrackSetRest:
		move.b	ch_id(a3),d0		; Mute track
		bset	d0,v_enabled_channels(a5)
		bset	#chf_rest_bit,ch_flags(a3)	; Mark track as rested
		rts

; -------------------------------------------------------------------------
; Set note off for track
; -------------------------------------------------------------------------
; input:
;	a3.l - pointer to track variables
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

NoteOff:
		move.b	ch_id(a3),d0		; Mute track
		bset	d0,v_enabled_channels(a5)
		move.b	v_enabled_channels(a5),pcm_channel_onoff-pcm_regs(a4)	; update channels on/off array
		rts

; -------------------------------------------------------------------------
; Set note on for track
; -------------------------------------------------------------------------
; input:
;	a3.l - pointer to track variables
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

PCMNoteOn:
		btst	#chf_rest_bit,(a3)		; is legato enabled?
		bne.s	.exit				; if so, branch
		move.b	ch_id(a3),d0		; Unmute track
		bclr	d0,v_enabled_channels(a5)

.exit:
		rts

; -------------------------------------------------------------------------
; Run a driver command
; -------------------------------------------------------------------------
; input:
;	d7.b - Command ID
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

SongCommand:
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
; input:
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

Cmd_FadeOut:
		move.b	#$60,v_fadeout_counter(a5)		; initialize fade out
		move.b	#1,v_fadeout_delay(a5)
		move.b	#2,v_fadeout_speed(a5)
		rts

; -------------------------------------------------------------------------
; Pause command
; -------------------------------------------------------------------------
; input:
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

Cmd_Pause:
		move.b	#1,v_pausemode(a5)
		rts

; -------------------------------------------------------------------------
; Unpause command
; -------------------------------------------------------------------------
; input:
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

Cmd_Unpause:
		move.b	#$80,v_pausemode(a5)
		rts

; -------------------------------------------------------------------------
; Mute command
; -------------------------------------------------------------------------
; input:
;	a4.l - pointer to PCM registers
; -------------------------------------------------------------------------

Cmd_Mute:
		move.b	#$FF,pcm_channel_onoff-pcm_regs(a4)	; Mute all channels
		rts

; -------------------------------------------------------------------------
; Reset driver
; -------------------------------------------------------------------------
; input:
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
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
; input:
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

Cmd_Stop:
		jsr	ResetDriver(pc)			; mute driver and clear variables
		jsr	ClearSamples(pc)		; clear waveram
		bra.w	LoadStaticSamples			; reload static samples

; -------------------------------------------------------------------------
; Clear samples
; -------------------------------------------------------------------------
; input:
;	a4.l - pointer to PCM registers
; -------------------------------------------------------------------------

ClearSamples:
		move.b	#$80,d3				; Start with bank 0
		moveq	#$10-1,d1			; number of banks

.ClearBank:
		lea	pcm_waveram,a0			; Sample RAM
		move.b	d3,pcm_ctrl-pcm_regs(a4)		; Set bank ID
		moveq	#-1,d2				; Fill with loop flag
		move.w	#$1000-1,d0			; number of bytes to fill

.ClearBankLoop:
		move.b	d2,(a0)+			; Clear sample RAM bank
		addq.w	#1,a0				; Skip over even addresses
		dbf	d0,.ClearBankLoop		; loop until bank is cleared

		addq.w	#1,d3				; next bank
		dbf	d1,.ClearBank			; loop until all banks are cleared
		rts

; -------------------------------------------------------------------------
; initialize driver
; -------------------------------------------------------------------------

InitDriver:
		jsr	GetPointers(pc)			; get driver pointers

		move.b	#$FF,pcm_channel_onoff-pcm_regs(a4)	; Mute all channels
		move.b	#$80,pcm_ctrl-pcm_regs(a4)	; Set to sample RAM bank 0

		lea	DriverOrigin(pc),a0		; get pointer offset
		suba.l	$1C(a6),a0
		move.l	a0,v_drvptroffset(a5)

		bra.s	Cmd_Stop			; Stop any sound

; -------------------------------------------------------------------------
; get driver pointers
; -------------------------------------------------------------------------
; RETURNS:
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
;	a6.l - pointer to driver information table
; -------------------------------------------------------------------------

GetPointers:
		lea	DriverInfo(pc),a6		; driver info
		lea	Variables(pc),a5		; driver variables
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
; input:
;	d5.w - Track command ID
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

SongCommand:
		subi.w	#$E0,d5				; Run track command
		lsl.w	#2,d5
		jmp	.Commands(pc,d5.w)
		
; -------------------------------------------------------------------------

.Commands:
		jmp	TrkCmd_Panning(pc)		; Set panning
		jmp	TrkCmd_Detune(pc)		; Set detune
		jmp	TrkCmd_CommFlag(pc)		; Set communication flag
		jmp	TrkCmd_SetCDDALoop(pc)		; Set CDDA loop flag
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Volume(pc)		; Add volume
		jmp	TrkCmd_Legato(pc)		; Set legato
		jmp	TrkCmd_Staccato(pc)		; Set staccato
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Tempo(pc)		; Set tempo
		jmp	TrkCmd_PlaySound(pc)		; Play sound
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Instrument(pc)		; Set instrument
		jmp	TrkCmd_Stop(pc)			; Stop
		jmp	TrkCmd_Stop(pc)			; Stop
		jmp	TrkCmd_Stop(pc)			; Stop
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Jump(pc)			; Jump
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Jump(pc)			; Jump
		jmp	TrkCmd_Repeat(pc)		; Repeat
		jmp	TrkCmd_Call(pc)			; Call
		jmp	TrkCmd_Return(pc)		; Return
		jmp	TrkCmd_TrackTickMult(pc)	; Set track tick multiplier
		jmp	TrkCmd_Transpose(pc)		; Transpose
		jmp	TrkCmd_GlobalTickMult(pc)	; Set global tick multiplier
		jmp	TrkCmd_Null(pc)			; null
		jmp	TrkCmd_Invalid(pc)		; invalid

; -------------------------------------------------------------------------
; null track command
; -------------------------------------------------------------------------

TrkCmd_Null:
		rts

; -------------------------------------------------------------------------
; Panning track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
;	a4.l - pointer to PCM registers
; -------------------------------------------------------------------------

TrkCmd_Panning:
		move.b	ch_id(a3),d0		; Set channel
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)

		move.b	(a2),ch_pan(a3)		; Set panning
		move.b	(a2)+,pcm_pan-pcm_regs(a4)
		rts

; -------------------------------------------------------------------------
; detune track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Detune:
		move.b	(a2)+,ch_detune(a3)		; Set detune
		rts

; -------------------------------------------------------------------------
; Communication flag track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a5.l - pointer to driver variables
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
; input:
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_SetCDDALoop:
		move.b	#1,v_cdda_loop(a5)		; Set CDDA loop flag
		rts

; -------------------------------------------------------------------------
; Volume track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
;	a4.l - pointer to PCM registers
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_Volume:
		move.b	ch_id(a3),d0		; Set channel
		ori.b	#$C0,d0
		move.b	d0,pcm_ctrl-pcm_regs(a4)

		move.b	(a2)+,d0			; get volume modifier
		bmi.s	.VolumeDown			; if we are turning the volume down, branch

.VolumeUp:
		add.b	d0,ch_volume(a3)		; Add volume
		bcs.s	.CapVolumeAt0			; if it has overflowed, branch
		bra.w	.UpdateVolume			; update volume

.VolumeDown:
		add.b	d0,ch_volume(a3)		; Subtract volume
		bcc.s	.CapVolumeAt0			; if it has underflowed, branch

.UpdateVolume:
		move.b	ch_volume(a3),pcm_env-pcm_regs(a4)

.exit:
		rts

.CapVolumeAt0:
		tst.b	v_fadeout_counter(a5)		; is the music fading out?
		beq.s	.exit				; if not, branch
		bclr	#chf_enable_bit,(a3)			; Stop track
		move.b	#0,pcm_env-pcm_regs(a4)		; Set volume to 0
		rts

; -------------------------------------------------------------------------
; legato track command
; -------------------------------------------------------------------------
; input:
;	a3.l - pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Legato:
		bset	#chf_rest_bit,(a3)		; Set legato flag
		rts

; -------------------------------------------------------------------------
; Staccato track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Staccato:
		move.b	(a2),ch_gate(a3)		; Set staccato
		move.b	(a2)+,ch_savedgate(a3)
		rts

; -------------------------------------------------------------------------
; Tempo track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_Tempo:
		move.b	(a2),v_tempo_counter(a5)		; Set tempo
		move.b	(a2)+,v_current_tempo(a5)
		rts

; -------------------------------------------------------------------------
; Sound play track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_PlaySound:
		move.b	(a2)+,v_soundqueue(a5)		; Play sound
		rts

; -------------------------------------------------------------------------
; instrument track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_Instrument:
		moveq	#0,d0				; get sample data
		move.b	(a2)+,d0
		lea	SampleIndex(pc),a0
		addq.w	#4,a0
		lsl.w	#2,d0
		movea.l	(a0,d0.w),a0
		adda.l	v_drvptroffset(a5),a0

		move.b	sample_staccato(a0),ch_samplstac(a3)
		move.b	sample_staccato(a0),ch_samplstac_cnt(a3)
		move.b	sample_mode(a0),ch_samplmode(a3)
		bne.s	.StaticSample			; if it's a static sample, branch

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
; input:
;	a3.l - pointer to track variables
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_Stop:
		bclr	#chf_enable_bit,(a3)			; Stop track
		bclr	#chf_rest_bit,(a3)		; Clear legato flag
		jsr	TrackSetRest(pc)			; Set track as rested

		tst.b	f_sfx(a5)			; Are we in SFX mode?
		beq.w	.exit				; if not, branch
		clr.b	v_priority(a5)			; Clear SFX priority level

.exit:
		addq.w	#8,sp				; Skip right to the next track
		rts

; -------------------------------------------------------------------------
; Jump track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
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
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Repeat:
		moveq	#0,d0				; get repeat index
		move.b	(a2)+,d0
		move.b	(a2)+,d1			; get repeat count

		tst.b	ch_loopcounters(a3,d0.w)		; is the repeat count already set?
		bne.s	.CheckRepeat			; if so, branch
		move.b	d1,ch_loopcounters(a3,d0.w)	; Set repeat count

.CheckRepeat:
		subq.b	#1,ch_loopcounters(a3,d0.w)	; decrement repeat count
		bne.s	TrkCmd_Jump			; if it hasn't run out, branch
		addq.w	#2,a2				; if it has, skip past repeat offset
		rts

; -------------------------------------------------------------------------
; Call track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Call:
		moveq	#0,d0				; get call stack pointer
		move.b	ch_stackptr(a3),d0
		subq.b	#4,d0				; Move up call stack
		move.l	a2,(a3,d0.w)			; Save return address
		move.b	d0,ch_stackptr(a3)		; update call stack pointer
		bra.s	TrkCmd_Jump			; Jump to offset

; -------------------------------------------------------------------------
; Return track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Return:
		moveq	#0,d0				; get call stack pointer
		move.b	ch_stackptr(a3),d0
		movea.l	(a3,d0.w),a2			; go to return address
		addq.w	#2,a2
		addq.b	#4,d0				; Move down stack
		move.b	d0,ch_stackptr(a3)		; update call stack pointer
		rts

; -------------------------------------------------------------------------
; Track tick multiplier track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_TrackTickMult:
		move.b	(a2)+,ch_tick(a3)		; Set tick multiplier
		rts

; -------------------------------------------------------------------------
; Transpose track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a3.l - pointer to track variables
; -------------------------------------------------------------------------

TrkCmd_Transpose:
		move.b	(a2)+,d0			; Add transposition
		add.b	d0,ch_transpose(a3)
		rts

; -------------------------------------------------------------------------
; global tick multiplier track command
; -------------------------------------------------------------------------
; input:
;	a2.l - pointer to track data
;	a5.l - pointer to driver variables
; -------------------------------------------------------------------------

TrkCmd_GlobalTickMult:
		lea	song_rhythmtrk(a5),a0		; update song tracks
		move.b	(a2)+,d0
		move.w	#sizeof_trackvars,d1
		moveq	#RHY_TRACK_CNT+countof_pcmtracks-1,d2

.SetTickMult:
		move.b	d0,ch_tick(a0)		; Set tick multiplier
		adda.w	d1,a0				; next track
		dbf	d2,.SetTickMult			; loop until all tracks are updated
		rts

; -------------------------------------------------------------------------
; invalid track command
; -------------------------------------------------------------------------

TrkCmd_Invalid:

; -------------------------------------------------------------------------
; driver info
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