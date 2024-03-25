EntryPoint:
		lea	SetupValues(pc),a0			; load setup array
		move.w	(a0)+,sr				; ensure interrupts are disabled (e.g., if falling through from an error reset a la S3K)
		moveq	#0,d4					; DMA fill/memory clear/Z80 stop bit test value
		move.l	d4,d1					; clear d1, d2, d3, and d6 (d0, d5, and d7 are used with longwords or moveq first thing, so skip them)
		move.l	d4,d2
		move.l	d4,d3
		move.l	d4,d6
		movea.l d4,a4
		move.l	a4,usp					; clear user stack pointer
		movem.l (a0)+,a1-a6				; Z80 RAM start, work RAM start, MCD memory mode register, CD BIOS name in bootrom header, VDP data port, VDP control port
		movem.w (a0)+,d1/d2				; VDP register increment/value for Z80 stop and reset release ($100),  first VDP register value ($8004)
		move.l	(Header).w,d7			; 'SEGA' for TMSS fulfillment and checking MCD bootrom
		moveq	#sizeof_SetupVDP-1,d5		; VDP registers loop counter

		move.b	console_version-mcd_mem_mode(a3),d6	; load hardware version
		move.b	d6,d3					; copy to d3 for checking revision (d6 will be used later to set region and speed)
		andi.b	#console_revision,d3			; get only hardware version ID
		beq.s	.wait_dma				; if Model 1 VA4 or earlier (ID = 0), branch
   		move.l	d4,d3					; clear d3 so it can be used for init error index if necessary (unnecessary if no TMSS, as the above andi will have cleared the register)
		move.l	d7,tmss_sega-mcd_mem_mode(a3)	; satisfy the TMSS

	.wait_dma:
		move.w	(a6),ccr				; copy status register to CCR, clearing the VDP write latch and setting the overflow flag if a DMA is in progress
		bvs.s	.wait_dma				; if a DMA was in progress during a soft reset, wait until it is finished

	.loop_vdp:
		move.w	d2,(a6)					; set VDP register
		add.w	d1,d2					; advance register ID
		move.b	(a0)+,d2				; load next register value
		dbf	d5,.loop_vdp				; repeat for all registers; final value loaded will be used later to initialize I/0 ports

		move.l	(a0)+,(a6)				; set DMA fill destination
		move.w	d4,(a5)					; set DMA fill value (0000), clearing the VRAM

		move.w	(a0)+,d5				; (sizeof_workram/4)-1
	.loop_ram:
		move.l	d4,(a2)+				; clear 4 bytes of workram
		dbf	d5,.loop_ram				; repeat until entire workram has been cleared

		move.w	d1,z80_bus_request-mcd_mem_mode(a3)					; stop the Z80 (we will clear the VSRAM and CRAM while waiting for it to stop)
		move.w	d1,z80_reset-mcd_mem_mode(a3)	; deassert Z80 reset (ZRES is held high on console reset until we clear it)

		move.w	(a0)+,(a6)				; set VDP increment to 2

		move.l	(a0)+,(a6)				; set VDP to VSRAM write
		moveq	#(sizeof_vsram/4)-1,d5			; loop counter
	.loop_vsram:
		move.l	d4,(a5)					; clear 4 bytes of VSRAM
		dbf	d5,.loop_vsram				; repeat until entire VSRAM has been cleared

		move.l	(a0)+,(a6)				; set VDP to CRAM write
		moveq	#(sizeof_pal_all/4)-1,d5		; loop counter
	.loop_cram:
		move.l	d4,(a5)					; clear two palette entries
		dbf	d5,.loop_cram				; repeat until entire CRAM has been cleared

		move.w	(a0)+,d5				; sizeof_z80_ram-1
	.clear_Z80_ram:
		move.b 	d4,(a1)+				; clear one byte of Z80 RAM
		dbf	d5,.clear_Z80_ram			; repeat until entire Z80 RAM has been cleared

		moveq	#4-1,d5					; set number of PSG channels to mute
	.psg_loop:
		move.b	(a0)+,psg_input-vdp_data_port(a5)	; set the PSG channel volume to null (no sound)
		dbf	d5,.psg_loop				; repeat for all channels

	;.find_bios:
		btst	#console_mcd_bit,d6	; is there anything in the expansion slot?
		bne.w	InitFailure1		; if not, branch
		cmp.l	cd_bios_signature-cd_bios_name(a4),d7	; is the "SEGA" signature present?
		bne.w	InitFailure1					; if not, branch
		cmpi.w	#"BR",cd_bios_sw_type-cd_bios_name(a4)		; is the "Boot ROM" software type present?
		bne.w	InitFailure1					; if not, branch

		; Determine which MEGA CD device is attached.
		movea.l	a0,a2				; a2 = index table of BIOS data
		addq.w	#4,a0
		movea.l a0,a1				; a1 = base address of index + 4 (to skip over payload address)
		moveq	#(sizeof_MCDBIOSList/2)-1,d0
		moveq	#id_MCDBIOS_JP1,d7		; first BIOS ID

	.findloop:
		adda.w	(a2)+,a1			; a1 = pointer to BIOS data
		movea.l	a4,a5				; a6 = BIOS name in bootrom

	.checkname:
		move.b	(a1)+,d1			; get character
		beq.s	.namematch			; branch if we've reached the end of the name
		cmp.b	(a5)+,d1			; does the BIOS name match so far?
		bne.s	.nextBIOS			; if not, go check the next BIOS
		bra.s	.checkname			; loop until name is fully checked
; ===========================================================================

	.namematch:
		move.b	(a1)+,d1			; is this BIOS region specific?
		beq.s	.found				; branch if not
		cmp.b	cd_bios_region-cd_bios_name(a4),d1			; does the BIOS region match?
		beq.s	.found				; branch if so

	.nextBIOS:
		addq.b	#1,d7				; increment BIOS ID
		movea.l	a0,a1				; reset a1
		dbf	d0,.findloop			; loop until all BIOSes are checked

	;.notfound:
		bra.w	InitFailure2
; ===========================================================================

.found:
		move.b	d7,(v_bios_id).w				; save BIOS ID
		andi.b	#console_region+console_speed,d6
		move.b	d6,(v_console_region).w			; set region variable in RAM

		move.b	d2,port_1_control-mcd_mem_mode(a3)	; initialize port 1
		move.b	d2,port_2_control-mcd_mem_mode(a3)	; initialize port 2
		move.b	d2,port_e_control-mcd_mem_mode(a3)	; initialize port e

		move.w	#$FF00,mcd_write_protect-mcd_mem_mode(a3)	; reset the sub CPU gate array
		move.b	#3,mcd_reset-mcd_mem_mode(a3)				; these four values written to these address in this order trigger the reset
		move.b	#2,mcd_reset-mcd_mem_mode(a3)
		move.b	d4,mcd_reset-mcd_mem_mode(a3)				; d4 = 0

		moveq	#$80-1,d2			; wait for gate array reset to complete
		dbf	d2,*

		; If you're loading a Z80 sound driver, this is the place to do it, replacing
		; the above two lines.

		move.w	#$100-1,d2	; maximum time to wait for response
	.req_bus:
		bset	#sub_bus_request_bit,mcd_reset-mcd_mem_mode(a3)			; request the sub CPU bus
		dbne	d2,.req_bus							; if it has not been granted, wait
		bne.s	.reset									; branch if it has been granted
		bra.w	InitFailure3							; if sub CPU is unresponsive

	.reset:
		bclr	#sub_reset_bit,mcd_reset-mcd_mem_mode(a3)		; set sub CPU to reset
		bne.s	.reset			; wait for completion

	;.clear_prgram:
		clr.b	mcd_write_protect-mcd_mem_mode(a3)			; disable write protect on Sub CPU memory
		move.b	(a3),d6			; get current bank setting
		andi.b	#(~program_ram_bank)&$FF,d6		; set program ram bank to 0
		move.b	d6,(a3)
		bsr.s	.clearbank

		move.b	(a3),d6			; get current bank setting
		addi.b	#$40,d6
		move.b	d6,(a3)		; advance to second bank
		bsr.s	.clearbank

		move.b	(a3),d6			; get current bank setting
		addi.b	#$40,d6
		move.b	d6,(a3)		; advance to third bank
		bsr.s	.clearbank

		move.b	(a3),d6			; get current bank setting
		addi.b	#$40,d6
		move.b	d6,(a3)		; advance to fourth and final bank
		pea	.clearcoms(pc)	; 'return' to next step of init

	.clearbank:
		lea (program_ram).l,a0
		move.w  #(sizeof_program_ram_window/4)-1,d5

	.loop:
		move.l  d4,(a0)+	; clear 4 bytes of the program ram bank
		dbf d5,.loop	; repeat for whole bank
		rts

	.clearcoms:
		lea mcd_maincoms-mcd_mem_mode(a3),a0
		move.b	d4,mcd_com_flags-mcd_maincoms(a0)	; clear main CPU communication flag
		move.l	d4,(a0)+		; clear main CPU communication registers
		move.l	d4,(a0)+
		move.l	d4,(a0)+
		move.l	d4,(a0)

	;.load_bios:
		move.b	(a3),d6			; get current bank setting
		andi.b	#(~program_ram_bank)&$FF,d6		; set program ram bank to 0
		move.b	d6,(a3)

		lea	(program_ram).l,a1		; start of program RAM
		move.b	(v_bios_id).w,d4	; get BIOS ID
		add.w	d4,d4				; make index
		lea MCDBIOSList(pc),a0
		move.w	-2(a0,d4.w),d1	; -2 since IDs start at 1
		movea.l	(a0,d1.w),a0	; a0 = start of compressed BIOS payload

		bsr.w	KosDec					; decompress the sub CPU BIOS (uses a0, a1, a4, a5)
		bsr.w	Decompress_SubCPUProgram	; decompress the sub CPU program

		move.b	#sub_bios_end>>9,mcd_write_protect-mcd_mem_mode(a3)		; enable write protect on BIOS code in program RAM
		move.b	#sub_run,mcd_reset-mcd_mem_mode(a3)		; start the sub CPU

		move.w	#vdp_enable_vint,d0
		or.b	SetupVDP(pc),d0
		move.w	d0,(a6)			; enable VBlank on VDP
		enable_ints

	.waitwordram:
		btst	#wordram_swapmain_bit,(a3)	; has sub CPU given us the word RAM?
		beq.s	.waitwordram		; if not, wait

		lea (wordram_2M).l,a0
		moveq_	((sizeof_wordram_2M/4)-1),d5
		moveq	#0,d4

	.clear_wordram:
		move.l d4,(a0)+		; clear 4 bytes of wordram
		dbf d5,.clear_wordram	; repeat for entire wordram

		bra.w	WaitSubInit	; wait for sub CPU initialization to finish
; ===========================================================================

SetupValues:
		dc.w	$2700					; disable interrupts

		dc.l	z80_ram				; a1
		dc.l	workram_start		; a2
		dc.l	mcd_mem_mode		; a3
		dc.l	cd_bios_name		; a4
		dc.l	vdp_data_port		; a5
		dc.l	vdp_control_port	; a6

		dc.w	vdp_mode_register2-vdp_mode_register1	; d1, VDP Reg increment value & opposite initialisation flag for Z80
		dc.w	vdp_md_color				; d2, $8004; normal color mode, horizontal interrupts disabled
	SetupVDP:
		dc.b	(vdp_enable_dma|vdp_ntsc_display|vdp_md_display)&$FF ;  $8134; mode 5, NTSC, DMA enabled
		dc.b	(vdp_fg_nametable+(vram_fg>>10))&$FF	; $8230; foreground nametable starts at $C000
		dc.b	(vdp_window_nametable+(vram_window>>10))&$FF ; $8328; window nametable starts at $A000
		dc.b	(vdp_bg_nametable+(vram_bg>>13))&$FF	; $8407; background nametable starts at $E000
		dc.b	(vdp_sprite_table+(vram_sprites>>9))&$FF ; $857C; sprite attribute table starts at $F800
		dc.b	vdp_sprite_table2&$FF			; $8600; unused (high bit of sprite attribute table address for 128KB VRAM)
		dc.b	(vdp_bg_color+0)&$FF			; $8700; background color (palette line 0 color 0)
		dc.b	vdp_sms_hscroll&$FF			; $8800; unused (mode 4 hscroll register)
		dc.b	vdp_sms_vscroll&$FF			; $8900; unused (mode 4 vscroll register)
		dc.b	(vdp_hint_counter+0)&$FF		; $8A00; horizontal interrupt register (set to 0 for now)
		dc.b	(vdp_full_vscroll|vdp_full_hscroll)&$FF	; $8B00; full-screen vertical/horizontal scrolling
		dc.b	vdp_320px_screen_width&$FF		; $8C81; H40 display mode
		dc.b	(vdp_hscroll_table+(vram_hscroll>>10))&$FF ; $8D3F; hscroll table starts at $FC00
		dc.b	vdp_nametable_hi&$FF			; $8E00: unused (high bits of fg and bg nametable addresses for 128KB VRAM)
		dc.b	(vdp_auto_inc+1)&$FF			; $8F01; VDP increment size (will be changed to 2 later)
		dc.b	(vdp_plane_width_64|vdp_plane_height_32)&$FF ; $9001; 64x32 plane size
		dc.b	vdp_window_x_pos&$FF			; $9100; unused (window horizontal position)
		dc.b	vdp_window_y_pos&$FF			; $9200; unused (window vertical position)

		dc.w	sizeof_vram-1				; $93FF/$94FF - DMA length
		dc.w	0					; VDP $9500/9600 - DMA source
		dc.b	vdp_dma_vram_fill&$FF			; VDP $9780 - DMA fill VRAM

		dc.b	$40					; I/O port initialization value

		arraysize SetupVDP

		dc.l	vram_dma				; DMA fill VRAM
		dc.w	(sizeof_ram/4)-1	; workram clear loop counter
		dc.w	vdp_auto_inc+2				; VDP increment
		dc.l	vsram_write				; VSRAM write mode
		dc.l	cram_write				; CRAM write mode
   		dc.w	sizeof_z80_ram-1		; Z80 ram clear loop counter

		dc.b	$9F,$BF,$DF,$FF				; PSG mute values (PSG 1 to 4)

MCDBIOSList:	index offset(*),1
		ptr	MCDBIOS_JP1			; 1
		ptr	MCDBIOS_US1			; 2
		ptr	MCDBIOS_EU1			; 3
		ptr	MCDBIOS_CD2			; 4
		ptr	MCDBIOS_CDX			; 5
		ptr	MCDBIOS_LaserActive	; 6
		ptr	MCDBIOS_Wondermega1	; 7
		ptr	MCDBIOS_Wondermega2	; 8
		arraysize MCDBIOSList

MCDBIOS_JP1:
		dc.l	$416000
		dc.b	"MEGA-CD BOOT ROM",0		; Japanese Model 1
		dc.b	"J"
		even

MCDBIOS_US1:
		dc.l	$415800
		dc.b	"SEGA-CD BOOT ROM",0		; North American Model 1
		dc.b	0
		even

MCDBIOS_EU1:
		dc.l	$415800
		dc.b	"MEGA-CD BOOT ROM",0		; PAL Model 1
		dc.b	"E"
		even

MCDBIOS_CD2:
		dc.l	$416000
		dc.b	"CD2 BOOT ROM    ",0		; All Model 2s, Aiwa Mega-CD
		dc.b	0
		even

MCDBIOS_CDX:
		dc.l	$416000
		dc.b	"CDX BOOT ROM    ",0		; MultiMega, CDX
		dc.b	0
		even

MCDBIOS_LaserActive:
		dc.l	$41AD00
		dc.b	"MEGA-LD BOOT ROM",0		; Pioneer LaserActive MEGA-LD Pak
		dc.b	0
		even

MCDBIOS_Wondermega1:
		dc.l	$416000
		dc.b	"WONDER-MEGA BOOTROM",0		; Victor WonderMega 1, Sega WonderMega
		dc.b	0
		even

MCDBIOS_Wondermega2:
		dc.l	$416000
		dc.b	"WONDERMEGA2 BOOTROM",0		; Victor WonderMega 2, JVC X'Eye
		dc.b	0
		even
; ===========================================================================

; d3 is already 0
InitFailure3:
		addq.b	#2,d3		; 4 = sub CPU timeout

InitFailure2:
		addq.b	#2,d3		; 2 = unidentified sub CPU
							; 0 = no sub CPU found
InitFailure1:
		disable_ints
		lea	-sizeof_Console_RAM(sp),sp
		lea (sp),a3
		pushr.w	d3
		jsr	(ErrorHandler_SetupVDP).l
		jsr	(Error_InitConsole).l		; set up console
		popr.w	d3

		move.w	FailureText_Index(pc,d3.w),d3
		lea FailureText_Index-6(pc,d3.w),a5		; a5 = start of data for failure message
		move.w	(a5)+,d5				; d5 = loop counter
		movem.w	(a5)+,d0/d1			; d0/d1 = starting x and y pos
		jsr	(Console_SetPosAsXY).l		; set starting pos for message
		moveq	#0,d4			; first line of message

	.loop:
		move.w	(a5,d4.w),d3
		lea	(a5,d3.w),a0	; a0 = line of message
		jsr	(Console_WriteLine).l	; write line
		jsr	(Console_StartNewLine).l		; skip a line
		addq.w	#2,d4		; next line
		dbf	d5,.loop		; repeat for all lines of message

	.done:
		nop
		nop
		bra.s	.done		; stay here forever
; ===========================================================================

FailureText_Index:	index offset(*),,2
		ptr	SubCPU_NotFound_Index	; 0
		ptr	SubCPU_NotIdentified_Index ; 2
		ptr	SubCPU_Unresponsive_Index ; 4
; ===========================================================================

		dc.w	(sizeof_SubCPU_NotFound_Index/2)-1
		dc.w	0,9	; x pos, y pos
SubCPU_NotFound_Index:	index offset(*),,2
		ptr	.line1
		ptr	.line2
		ptr	.line3
		ptr	.line4
		ptr	.line5
		arraysize	SubCPU_NotFound_Index


.line1:	dc.b	'     Sorry, this test requires the      ',0
		even
.line2:	dc.b	'    Mega CD addon or equivalent, or     ',0
		even
.line3:	dc.b	'       Genesis Plus GX, BlastEm,        ',0
		even
.line4:	dc.b	'      Mega EverDrive Pro or MegaSD      ',0
		even
.line5:	dc.b	'    with a properly configured BIOS.    ',0
		even
; ===========================================================================

		dc.w	(sizeof_SubCPU_NotIdentified_Index/2)-1
		dc.w	0,9	; x pos, y pos
SubCPU_NotIdentified_Index:	index offset(*),,2
		ptr	.line1
		ptr	.line2
		ptr	.line3
		ptr	.line4
		ptr	.line5
		arraysize	SubCPU_NotIdentified_Index


.line1:	dc.b	'   A Mega CD device was detected, but   ',0
		even
.line2:	dc.b	'   it could not be identified. Please   ',0
		even
.line3:	dc.b	'     contact OrionNavattan, as this     ',0
		even
.line4:	dc.b	'      may be a previously unknown       ',0
		even
.line5:	dc.b	'            Mega CD device.             ',0
		even
; ===========================================================================

		dc.w	(sizeof_SubCPU_Unresponsive_Index/2)-1
		dc.w	0,10	; x pos, y pos
SubCPU_Unresponsive_Index:	index offset(*),,2
		ptr	.line1
		ptr	.line2
		ptr	.line3
		ptr	.line4
		arraysize	SubCPU_Unresponsive_Index


.line1:	dc.b	'      The attached Mega CD device       ',0
		even
.line2:	dc.b	'    is not responding. Please verify    ',0
		even
.line3:	dc.b	'        that it is connected or         ',0
		even
.line4:	dc.b	'    otherwise functioning correctly.    ',0
		even
