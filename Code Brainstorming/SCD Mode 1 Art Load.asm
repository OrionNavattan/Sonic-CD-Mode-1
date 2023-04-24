time_past: 		equ 0
time_present: 	equ 1
time_future:	equ 2
v_256x256_tiles: equ $600000 ; located in Mega-CD wordram due to their size

LevelArtLoad:
		moveq	#0,d0
		move.b	d0,d1
		move.b	d0,d2
		move.b	(v_zone).w,d0	; get current zone
		move.b	d0,d1
		lsl.w	#3,d0
		lsl.w	#2,d1			; multiply by $C, the number of header entries for each zone
		add.w	d1,d0			; d0 = number of first header for the zone

		move.b	(v_act).w,d2	; get current act
		lsl.w	#2,d2			; multiply by 4
		add.w	d2,d0			; d0 = pointer to past of current act
		
		tst.b	(v_timezone).b					; are we in the past?
		beq.s	.past							; if so, branch
		cmpi.b	#time_present,(v_timezone).b	; are we in the present?
		beq.s	.present						; if so, branch
		tst.b	(f_good_future).b				; are we in the the good future?
		beq.s	.badfuture						; if not, branch
		
	;.goodfuture:
		addq.w	#1,d0		; add 3 to make good future index
	
	.badfuture:
		addq.w	#1,d0		; add 2 to make bad future index
		
	.present:	
		addq.w	#1,d0		; add 1	to make present index
			
	.past:
		add.w	d0,d0
		add.w	d0,d0
		move.w	d0,d1
		add.w	d0,d0
		add.w	d1,d0	; multiply by $12 (the size of each header), making index into level header array		
		
		lea	(LevelHeaders).l,a2		; load level header array
		lea	(a2,d0.w),a2			; a2 = first longword of level header
		move.l	(a2),d0				
		andi.l	#$FFFFFF,d0			; d0 = pointer to compressed level art 
		movea.l	d0,a0
		lea	(v_256x256_tiles),a1		; 256x256 mappings RAM is used as decompression buffer
		bsr.w	KosDec				; decompress the level art
		move.w	a1,d3				; end address of decompressed tiles	
			

.prepare_dma:
		; Transfer the decompressed art to VRAM, starting  with the highest tiles and 
		; working backwards in $1000 byte chunks. 
		move.w	d3,d7		; d3 & d7 = end address of decompressed tiles
		andi.w	#$FFF,d3	; divide lower 12 bits by 2
		lsr.w	#1,d3		; d3 = size of first DMA transfer in words
		rol.w	#4,d7		; divide by 4
		andi.w	#$F,d7		; d7 = number of DMAs needed to transfer everything-1

	.loop:				
		move.w	d7,d2		; get loop counter
		lsl.w	#7,d2		; multiply by $1000
		lsl.w	#5,d2		; destination is nearest multiple of $1000 that does not exceed size
		move.l	#$FFFFFF,d1	
		move.w	d2,d1		; d1 = source
		bsr.w	AddDMA		; queue the DMA transfer
		pushr.w	d7			; back up loop counter
		move.b	#id_VBlank_LevelLoad,(v_vblank_routine).w	
		bsr.w	WaitForVBlank			; wait for VBlank to run DMA
		bsr.w	RunPLC					; process any pending PLCs		
		popr.w	d7						; restore loop counter
		move.w	#$800,d3	; all remaining transfers are $1000 bytes in length
		dbf	d7,.loop		; repeat until everything has been transferred
		rts			