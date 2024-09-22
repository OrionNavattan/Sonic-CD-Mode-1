; -------------------------------------------------------------------------
; Main CPU program constants
; -------------------------------------------------------------------------

countof_color:		equ 16					; colors per palette line
countof_pal:		equ 4					; total palette lines
sizeof_pal:		equ countof_color*2			; total bytes in 1 palette line (32 bytes)
sizeof_pal_all:		equ sizeof_pal*countof_pal		; bytes in all palette lines (128 bytes)
vram_window:		equ $A000				; window nametable - unused
vram_fg:			equ $C000			; foreground nametable ($1000 bytes); extends until $CFFF
vram_bg:			equ $E000			; background nametable ($1000 bytes); extends until $EFFF
vram_sprites:			equ $F800			; sprite attribute table ($280 bytes)
vram_hscroll:			equ $FC00			; horizontal scroll table ($380 bytes); extends until $FF7F

cGreen:		equ $0E0					; color green
cRed:		equ $00E					; color red
cBlue:		equ $E00					; color blue
cWhite:		equ $EEE
cBlack:		equ 0

sizeof_ost:		equ $40

; --------------------------------------------------------------------------
; VDP tile settings
; --------------------------------------------------------------------------

tile_xflip_bit:	equ 3
tile_yflip_bit:	equ 4
tile_pal12_bit:	equ 5
tile_pal34_bit:	equ 6
tile_hi_bit:	equ 7

tile_xflip:	equ (1<<tile_xflip_bit)<<8		; $800
tile_yflip:	equ (1<<tile_yflip_bit)<<8		; $1000
tile_line0:	equ (0<<tile_xflip_bit)<<8		; 0
tile_line1:	equ (1<<tile_pal12_bit)<<8		; $2000
tile_line2:	equ (1<<tile_pal34_bit)<<8		; $4000
tile_line3:	equ ((1<<tile_pal34_bit)|(1<<tile_pal12_bit))<<8 ; $6000
tile_hi:	equ (1<<tile_hi_bit)<<8			; $8000

tile_palette:	equ tile_line3				; $6000
tile_settings:	equ	tile_xflip|tile_yflip|tile_palette|tile_hi ; $F800
tile_vram:		equ (~tile_settings)&$FFFF	; $7FF
tile_draw:		equ	(~tile_hi)&$FFFF	; $7FFF

; --------------------------------------------------------------------------
; Joypad input
; --------------------------------------------------------------------------

bitStart:	equ 7
bitA:		equ 6
bitC:		equ 5
bitB:		equ 4
bitR:		equ 3
bitL:		equ 2
bitDn:		equ 1
bitUp:		equ 0
btnStart:	equ 1<<bitStart					; Start button	($80)
btnA:		equ 1<<bitA					; A		($40)
btnC:		equ 1<<bitC					; C		($20)
btnB:		equ 1<<bitB					; B		($10)
btnR:		equ 1<<bitR					; Right		($08)
btnL:		equ 1<<bitL					; Left		($04)
btnDn:		equ 1<<bitDn					; Down		($02)
btnUp:		equ 1<<bitUp					; Up		($01)
btnDir:		equ btnL+btnR+btnDn+btnUp			; Any direction	($0F)
btnABC:		equ btnA+btnB+btnC				; A, B or C	($70)
