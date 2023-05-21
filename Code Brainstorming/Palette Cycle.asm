PaletteCycle:				
		moveq	#0,d2
		moveq	#0,d0
		move.b	(v_zone).w,d0				; get zone number
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
		add.w	d0,d0					; multiply by index stride (2 bytes)
		move.w	PCycle_Index(pc,d0.w),d0		
		jmp	PCycle_Index(pc,d0.w)			; jump to relevant palette routine
		
PCycle_Index:	index offset(*)
		ptr	PCycle_PPZPast
		ptr	PCycle_PPZPresent
		ptr	PCycle_PPZBadFuture
		ptr	PCycle_PPZGoodFuture
		
		ptr	PCycle_CCZPast
		ptr	PCycle_CCZPresent
		ptr	PCycle_CCZBadFuture
		ptr	PCycle_CCZGoodFuture
		
		ptr	PCycle_TTZPast
		ptr	PCycle_TTZPresent
		ptr	PCycle_TTZBadFuture
		ptr	PCycle_TTZGoodFuture
		
		ptr	PCycle_QQZPast
		ptr	PCycle_QQZPresent
		ptr	PCycle_QQZBadFuture
		ptr	PCycle_QQZGoodFuture
		
		ptr	PCycle_WWZPast
		ptr	PCycle_WWZPresent
		ptr	PCycle_WWZBadFuture
		ptr	PCycle_WWZGoodFuture
		
		ptr	PCycle_SSZPast
		ptr	PCycle_SSZPresent
		ptr	PCycle_SSZBadFuture
		ptr	PCycle_SSZGoodFuture
		
		ptr	PCycle_MMZPast
		ptr	PCycle_MMZPresent
		ptr	PCycle_MMZBadFuture
		ptr	PCycle_MMZGoodFuture
		
