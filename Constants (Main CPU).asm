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

sizeof_ost:		equ $40