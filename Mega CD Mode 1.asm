; ---------------------------------------------------------------------------
; Mega CD Mode 1 Main CPU hardware addresses
; ---------------------------------------------------------------------------

;expansion:		equ $400000
;expansion_end:	equ $800000
;expansion_size:	equ	expansion_end-expansion


cd_bios:			equ $400000 	 ; Mega CD BIOS ROM (executed when booting in mode 2; in Mode 1 we're simply reading its header)
cd_bios_signature:	equ cd_bios+$100 ; $400100 ; SEGA signature in BIOS header
cd_bios_name:		equ cd_bios+$120 ; $400120 ; Name of Sub-CPU device in BIOS header (Mega CD, CDX, WonderMega. etc.)
cd_bios_sw_type:	equ cd_bios+$180 ; $400180 ; Software type in BIOS header (should be "BR")
cd_bios_region:		equ cd_bios+$1F0 ; $4001F0 ; CD BIOS region

cd_bios_setVDPregs:	EQU	cd_bios+$2B0 ; $4002B0 ; Set up VDP registers
cd_bios_DMA68k:		EQU	cd_bios+$2D4 ; $4002D4 ; DMA 68000 data to VDP memory

	
;cd_bios_end:	equ $420000
;cd_bios_size:	equ cd_bios_end-cd_bios

program_ram:		equ	$420000 ; Mega CD Program RAM
;program_ram_end:	equ	$440000	; MCD PRG-RAM bank end
;program_ram_size:	equ	program_ram_end-program_ram	
;program_ram_subaddr: equ $000000

word_ram:			equ $600000 ; Mega CD Word RAM

gate_array:			equ $A12000 			; Gate array
ga_irq_2:			equ	gate_array			; $A12000 ; IRQ2 send
ga_reset:			equ	gate_array+1		; $A12001 ; Reset
ga_write_protect:	equ	gate_array+2		; $A12002 ; Write protection
ga_mem_mode:		equ	gate_array+3		; $A12003 ; Memory mode
ga_cdc_mode:		equ	gate_array+4		; $A12004 ; CDC mode/Device destination (word)
ga_user_hblank:		equ	gate_array+6		; $A12006 ; User H-INT address
ga_cdc_host:		equ	gate_array+8		; $A12008 ; 16-bit CDC data to host
ga_stopwatch:		equ	gate_array+$C		; $A1200C ; Stopwatch
ga_com_flags:		equ	gate_array+$E		; $A1200E ; Communication flags
ga_main_flag:		equ	ga_com_flags		; $A1200E ; Main CPU communication flag
ga_sub_flag:		equ	gate_array+$F		; $A1200F ; Sub CPU communication flag
ga_com_cmds:		equ	gate_array+$10		; $A12010 ; Communication commands
ga_com_cmd_0:		equ	ga_com_cmds			; $A12010 ; Communication command 0
ga_com_cmd_1:		equ	gate_array+$11		; $A12011 ; Communication command 0
ga_com_cmd_2:		equ	gate_array+$12		; $A12012 ; Communication command 1
ga_com_cmd_3:		equ	gate_array+$13		; $A12013 ; Communication command 1
ga_com_cmd_4:		equ	gate_array+$14		; $A12014 ; Communication command 2
ga_com_cmd_5:		equ	gate_array+$15		; $A12015 ; Communication command 2
ga_com_cmd_6:		equ	gate_array+$16		; $A12016 ; Communication command 3
ga_com_cmd_7:		equ	gate_array+$17		; $A12017 ; Communication command 3
ga_com_cmd_8:		equ	gate_array+$18		; $A12018 ; Communication command 4
ga_com_cmd_9:		equ	gate_array+$19		; $A12019 ; Communication command 4
ga_com_cmd_A:		equ	gate_array+$1A		; $A1201A ; Communication command 5
ga_com_cmd_B:		equ	gate_array+$1B		; $A1201B ; Communication command 5
ga_com_cmd_C:		equ	gate_array+$1C		; $A1201C ; Communication command 6
ga_com_cmd_D:		equ	gate_array+$1D		; $A1201D ; Communication command 6
ga_com_cmd_E:		equ	gate_array+$1E		; $A1201E ; Communication command 7
ga_com_cmd_F:		equ	gate_array+$1F		; $A1201F ; Communication command 7
ga_com_statuses:	equ	gate_array+$20		; $A12020 ; Communication statuses
ga_com_status_0:	equ	ga_com_statuses		; $A12020 ; Communication status 0
ga_com_status_1:	equ	gate_array+$21		; $A12021 ; Communication status 0
ga_com_status_2:	equ	gate_array+$22		; $A12022 ; Communication status 1
ga_com_status_3:	equ	gate_array+$23		; $A12023 ; Communication status 1
ga_com_status_4:	equ	gate_array+$24		; $A12024 ; Communication status 2
ga_com_status_5:	equ	gate_array+$25		; $A12025 ; Communication status 2
ga_com_status_6:	equ	gate_array+$26		; $A12026 ; Communication status 3
ga_com_status_7:	equ	gate_array+$27		; $A12027 ; Communication status 3
ga_com_status_8:	equ	gate_array+$28		; $A12028 ; Communication status 4
ga_com_status_9:	equ	gate_array+$29		; $A12029 ; Communication status 4
ga_com_status_A:	equ	gate_array+$2A		; $A1202A ; Communication status 5
ga_com_status_B:	equ	gate_array+$2B		; $A1202B ; Communication status 5
ga_com_status_C:	equ	gate_array+$2C		; $A1202C ; Communication status 6
ga_com_status_D:	equ	gate_array+$2D		; $A1202D ; Communication status 6
ga_com_status_E:	equ	gate_array+$2E		; $A1202E ; Communication status 7
ga_com_status_F:	equ	gate_array+$2F		; $A1202F ; Communication status 7