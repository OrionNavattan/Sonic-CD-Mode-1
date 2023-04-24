; Ricoh RF5C164 PCM channels:
pcm_ch_1:		equ 0
pcm_ch_2:		equ 1
pcm_ch_3:		equ 2
pcm_ch_4:		equ 3
pcm_ch_5:		equ 4
pcm_ch_6:		equ 5
pcm_ch_7:		equ 6
pcm_ch_8:		equ 7

; Ricoh RF5C164 control registers (write-only)
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
	pcm_onoff_bit:	equ 7	; enable or disable all channels
pcm_channel_onoff:	equ	$FF0011	; mute a single channel by setting the bit of this register corresponding to its ID
	

; Wave RAM internal address;
; Read-only, returns the internal address that the chip is currently reading from within the specified bank.
; Wave RAM is $10000 bytes, divided into two $8000 byte buffers, each internally addressed 0-$7FFF.
; Channels 1-4 use buffer 1; 5-8 use buffer 2
pcm_addr		equ	$FF0021	; Wave addresss
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