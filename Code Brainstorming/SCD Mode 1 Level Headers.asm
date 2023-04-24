lhead:	macro plc1,plc2,palette,art,map16x16,map128x128
		dc.l (plc1<<24)+art
		dc.l (plc2<<24)+map16x16
		dc.l (palette<<24)|map128x128
	endm
	
lheadnull:	macros
		dc.l	0,0,0	
		
; LevelArtPointers:		
LevelHeaders:	
	
		lhead id_PLC_PPZ_Past1,			id_PLC_PPZ_Past2,			id_Pal_PPZ_Past,			Kos_PPZ1_Past,			BM16_PPZ1_Past,			BM256_PPZ1_Past 		; 0 ; Palmtree Panic 1 Past
		lhead id_PLC_PPZ_Present1,		id_PLC_PPZ_Present2,		id_Pal_PPZ_Present,			Kos_PPZ1_Present,		BM16_PPZ1_present,		BM256_PPZ1_Present 		; 1 ; Palmtree Panic 1 Present
		lhead id_PLC_PPZ_Future1,		id_PLC_PPZ_Future2,			id_Pal_PPZ_BadFuture,		Kos_PPZ1_BadFuture,		BM16_PPZ1_BadFuture,	BM256_PPZ1_BadFuture 	; 2 ; Palmtree Panic 1 Bad Future
		lhead id_PLC_PPZ_Future1,		id_PLC_PPZ_Future2,			id_Pal_PPZ_GoodFuture,		Kos_PPZ1_GoodFuture,	BM16_PPZ1_GoodFuture,	BM256_PPZ1_GoodFuture 	; 3 ; Palmtree Panic 1 Good Future
				
		lhead id_PLC_PPZ_Past1,			id_PLC_PPZ_Past2,			id_Pal_PPZ_Past,			Kos_PPZ2_Past,			BM16_PPZ2_Past,			BM256_PPZ2_Past 		; 4 ; Palmtree Panic 2 Past
		lhead id_PLC_PPZ_Present1,		id_PLC_PPZ_Present2,		id_Pal_PPZ_Present,			Kos_PPZ2_Present,		BM16_PPZ2_present,		BM256_PPZ2_Present 		; 5 ; Palmtree Panic 2 Present
		lhead id_PLC_PPZ_Future1,		id_PLC_PPZ_Future2,			id_Pal_PPZ_BadFuture,		Kos_PPZ2&3_BadFuture,	BM16_PPZ2_BadFuture,	BM256_PPZ2_BadFuture 	; 6 ; Palmtree Panic 2 Bad Future
		lhead id_PLC_PPZ_Future1,		id_PLC_PPZ_Future2,			id_Pal_PPZ_GoodFuture,		Kos_PPZ2&3_GoodFuture,	BM16_PPZ2_GoodFuture,	BM256_PPZ2_GoodFuture 	; 7 ; Palmtree Panic 2 Good Future			
		lheadnull
		lheadnull	
		lhead id_PLC_PPZ_Future1,		id_PLC_PPZ_Future2,			id_Pal_PPZ_BadFuture,		Kos_PPZ2&3_BadFuture,	BM16_PPZ3_BadFuture,	BM256_PPZ3_BadFuture 	; $A ; Palmtree Panic 3 Bad Future
		lhead id_PLC_PPZ_Future1,		id_PLC_PPZ_Future2,			id_Pal_PPZ_GoodFuture,		Kos_PPZ2&3_GoodFuture,	BM16_PPZ3_GoodFuture,	BM256_PPZ3_GoodFuture 	; $B ; Palmtree Panic 3 Good Future		