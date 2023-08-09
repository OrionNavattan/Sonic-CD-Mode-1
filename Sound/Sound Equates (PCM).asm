; ---------------------------------------------------------------------------
; Ricoh RF5C164 addresses and constants
; ---------------------------------------------------------------------------

; Control Registers (write-only)
pcm_regs:		equ	$FF0000	; PCM register base
pcm_env:		equ	$FF0001	; channel volume
pcm_pan:		equ	$FF0003	; channel panning
pcm_freq_low:	equ	$FF0005	; sample frequency low byte
pcm_freq_hi:	equ	$FF0007	; sample frequency high byte
pcm_lsl:		equ	$FF0009	; wave memory stop address (low byte)
pcm_lsh:		equ	$FF000B	; wave memory stop address (high byte)
pcm_st:			equ	$FF000D	; wave memory start address
pcm_ctrl:		equ	$FF000F	; PCM control register
	channel_select:	equ 7		; bits 0-2; when mod bit is set, selects PCM channel that settings in the above 7 registers are applied to
	waveram_bank:	equ $F		; bits 0-3; when mod bit is clear, selects the wave ram bank that is accessed via the wave RAM window

	waveram_buffer_bit:	equ 3	; when clear, accessing channels 1-4, when set, accessing channels 5-8
	mod_bit:		equ 6	; controls the function of bits 0-3, see above for explanation
	pcm_onoff_bit:	equ 7	; enable or disable all channels (be warned, waveram writes may not work correctly if sounding is disabled with this )
	pcm_on:			equ 1<<pcm_onoff_bit
pcm_channel_onoff:	equ	$FF0011	; mute a single channel by setting the bit of this register corresponding to its ID
	

; Wave RAM internal addresses
; Read-only, returns the internal address that the chip is currently reading from within the specified bank.
; Wave RAM is $10000 bytes, divided into two $8000 byte buffers, each internally addressed 0-$7FFF.
; Channels 1-4 use buffer 1; 5-8 use buffer 2
pcm_addr:		equ	$FF0021	; Wave addresss
pcm_addr_1L:	equ	pcm_addr	; PCM Channel 1 address (low byte)
pcm_addr_1H:	equ	$FF0023	; PCM 1 address (high byte)
pcm_addr_2L:	equ	$FF0025	; PCM 2 address (low byte)
pcm_addr_2H:	equ	$FF0027	; PCM 2 address (high byte)
pcm_addr_3L:	equ	$FF0029	; PCM 3 address (low byte)
pcm_addr_3H:	equ	$FF002B	; PCM 3 address (high byte)
pcm_addr_4L:	equ	$FF002D	; PCM 4 address (low byte)
pcm_addr_4H:	equ	$FF002F	; PCM 4 address (high byte)
pcm_addr_5L:	equ	$FF0031	; PCM 5 address (low byte)
pcm_addr_5H:	equ	$FF0033	; PCM 5 address (high byte)
pcm_addr_6L:	equ	$FF0035	; PCM 6 address (low byte)
pcm_addr_6H:	equ	$FF0037	; PCM 6 address (high byte)
pcm_addr_7L:	equ	$FF0039	; PCM 7 address (low byte)
pcm_addr_7H:	equ	$FF003B	; PCM 7 address (high byte)
pcm_addr_8L:	equ	$FF003D	; PCM 8 address (low byte)
pcm_addr_8H:	equ	$FF003F	; PCM 8 address (high byte)
pcm_waveram:	equ	$FF2001	; $1000 byte wave RAM window (only odd bytes are accessible!)
pcm_waveram_end:	equ $FF3FFF	; wave ram window end

sizeof_waveramblock:	equ $200	; size of blocks within waveram banks
sizeof_waverambank:			equ $200*$10	; $2000


; PCM channel IDs
pcm_ch_1:		equ 0
pcm_ch_2:		equ 1
pcm_ch_3:		equ 2
pcm_ch_4:		equ 3
pcm_ch_5:		equ 4
pcm_ch_6:		equ 5
pcm_ch_7:		equ 6
pcm_ch_8:		equ 7

countof_rhythmtracks:	equ	1			; number of rhythm tracks
countof_pcmtracks:		equ	8			; number of PCM tracks

; -------------------------------------------------------------------------
; Offsets of global driver variables 
; -------------------------------------------------------------------------

	rsreset
v_current_tempo:	rs.b 1			; tempo value
v_tempo_counter:	rs.b 1			; tempo counter
v_enabled_channels:	rs.b 1			; channels on/off array
v_priority:			rs.b 1			; saved SFX priority level
v_timing:			rs.b 1			; communication flag
v_cdda_loop:		rs.b 1			; CDDA music loop flag
v_unknown_counter:	rs.b 1			; unknown counter
		rs.b	2	; unused
v_soundtoplay:		rs.b 1			; sound to play next
v_soundqueue:		rs.b 4			; sound queue slots
f_sfx:				rs.b 1			; SFX mode
v_pausemode:		rs.b 1			; pause mode; unused
v_drvptroffset:		rs.l 1			; pointer offset
v_fadeout_counter:	rs.b 1		; fade out step count
v_fadeout_speed:	rs.b 1			; fade out speed
v_fadeout_delay:	rs.b 1			; fade out delay value
v_fadeout_delay_counter:	rs.b 1			; fade out delay counter
v_fadeout_unk:	rs.b	1			; Unknown fade out volume
		rs.b	$80-__rs
song_rhythmtrk:	rs.b	ptrkSize		; Rhythm track (unused)
song_pcm1:	rs.b	ptrkSize		; Music PCM1 track
song_pcm2:	rs.b	ptrkSize		; Music PCM2 track
song_pcm3:	rs.b	ptrkSize		; Music PCM3 track
song_pcm4:	rs.b	ptrkSize		; Music PCM4 track
song_pcm5:	rs.b	ptrkSize		; Music PCM5 track
song_pcm6:	rs.b	ptrkSize		; Music PCM6 track
song_pcm7:	rs.b	ptrkSize		; Music PCM7 track
song_pcm8:	rs.b	ptrkSize		; Music PCM8 track
sfx_pcm1:	rs.b	ptrkSize		; SFX PCM1 track
sfx_pcm2:	rs.b	ptrkSize		; SFX PCM2 track
sfx_pcm3:	rs.b	ptrkSize		; SFX PCM3 track
sfx_pcm4:	rs.b	ptrkSize		; SFX PCM4 track
sfx_pcm5:	rs.b	ptrkSize		; SFX PCM5 track
sfx_pcm6:	rs.b	ptrkSize		; SFX PCM6 track
sfx_pcm7:	rs.b	ptrkSize		; SFX PCM7 track
sfx_pcm8:	rs.b	ptrkSize		; SFX PCM8 track

sizeof_pcmvglobalvars	equ	__rs			; Size of structure

countof_musictracks:	equ 8
countof_sfxtracks:		equ 8


; -------------------------------------------------------------------------
; Track variables structure
; -------------------------------------------------------------------------

	rsreset
ch_flags:		rs.b 1				; 0
	chf_rest_bit:	equ 1					; track is at rest
	chf_tie_bit:	equ 4					; do not attack next note
	chf_enable_bit: equ 7					; track is playing	
	chf_rest:	equ 1<<chf_rest_bit	
	chf_tie:	equ 1<<chf_tie_bit
	chf_enable: equ 1<<chf_enable_bit

ch_id:			rs.b 1			; 1; channel ID
ch_tick:		rs.b 1			; 2; tick multiplier
ch_pan:			rs.b 1			; 3; panning
ch_dataptr:		rs.l 1			; 4; data address
ch_transpose:	rs.b 1			; 8; transposition
ch_volume:		rs.b 1			; 9; volume
ch_stackptr:	rs.b 1			; $A; call stack pointer
ch_delay:		rs.b 1			; $B; duration counter
ch_saved_delay:	rs.b 1			; $C; duration value
ch_gate:	rs.b 1			; $D; staccato counter
ch_savedgate:		rs.b 1			; $E; staccato value
ch_detune:		rs.b 1			; $F; detune
ch_freq:		rs.w 1			; $10; frequency
ch_samplbnk:	rs.b 1			; $12; sample RAM bank ID
ch_samplblks:	rs.b 1			; $13; sample stream block counter
ch_samplprevpos:	rs.w 1			; $14; previous sample playback position
ch_samplramoff:	rs.w 1			; $16; sample RAM offset
ch_samplram:	rs.l 1			; $18; sample RAM address
ch_sampsize:	rs.l 1			; $1C; sample size
ch_samplremain:	rs.l 1			; $20; sample bytes remaining
ch_samplptr:	rs.l 1			; $24; sample data address
ch_samplstart:	rs.l 1			; $28; sample start address
ch_samplloop:	rs.l 1			; $2C; sample loop address
ch_samplstac:	rs.b 1			; $30; sample staccato value
ch_samplstac_cnt:	rs.b 1			; $31; sample staccato counter
ch_samplmode:	rs.b 1			; $32; sample mode
				rs.b $E			; unused
ch_loopcounters:	equ __rs		; $40; loop counters
ch_stack:			rs.b $40		; $80; call stack base
sizeof_trackvars:	equ __rs		; $80; length of each set of track variables


; -------------------------------------------------------------------------
; Sample data structure
; -------------------------------------------------------------------------

	rsreset
sample_addr:			rs.l 1			; sample address
sample_size:			rs.l 1			; sample size
sample_loopoffset:		rs.l 1			; sample loop offset
sample_staccato:		rs.b 1			; sample staccato time
sample_mode:			rs.b 1			; sample mode
sample_dest:			rs.w 1			; sample destination address

; -------------------------------------------------------------------------