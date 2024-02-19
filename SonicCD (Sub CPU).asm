;  =========================================================================
; |					       Sonic the Hedgehog CD Mode 1						|
; |								Sub CPU Program								|
;  =========================================================================


		opt l.					; . is the local label symbol
		opt ae-					; automatic evens are disabled by default
		opt ws+					; allow statements to contain white-spaces
		opt w+					; print warnings
		opt op+					; optimize to PC relative if possible
		opt os+					; optimize backwards branches to .s if possible
		opt ow+					; optimize to absolute short if possible
		opt oz+					; optimize address register indirect with displacement to plain address register indirect if displacement = 0
		opt	oaq+				; optimize addi and adda to addq if possible
		opt osq+				; optimize subi and suba to subq if possible

		include "AXM68K 68k Only.asm"
		include "Mega CD Sub CPU.asm"
		include "includes/Debugger Macros and Common Defs.asm"
		include "Common Macros.asm"
		include "Constants (Sub CPU).asm"
		include "RAM Addresses (Sub CPU).asm"
	;	include "includes/Sub CPU Commands.asm"


		org	sp_start

SubPrgHeader:	index.l *
		dc.b	'MAIN       ',0				; module name (always MAIN), flag (always 0)
		dc.w	0,0							; version, type
		dc.l	0							; pointer to next module
		dc.l	0			; size of program
		ptr		UserCallTable	; pointer to usercall table
		dc.l	0							; workram size
; ===========================================================================

		include_SubCPUGlobalVars	; space for a few global variables
; ===========================================================================

UserCallTable:	index *
		ptr	Init		; Call 0; initialization
		ptr	Main		; Call 1; main
		ptr	VBlank		; Call 2; user VBlank
		ptr	NullRTS		; Call 3; unused
		dc.w	0		; required spacer word
; ===========================================================================

Init:
		lea SetupValues(pc),a0 ; pointers to exception entry points
		lea (_AddressError).w,a1	; first error vector in jump table
		moveq	#10-1,d0			; 9 vectors + GFX int

	.vectorloop:
		addq.w	#2,a1		; skip over instruction word
		move.l	(a0)+,(a1)+	; set table entry to point to exception entry point
		dbf d0,.vectorloop	; repeat for all vectors and GFX int

		move.l	(a0)+,(_TimerInt+2).w			; set timer interrupt address
		move.b	2(a0),(mcd_timerint_interval).w	; set timer interrupt interval

		moveq	#DriveInit,d0
		jsr	(_CDBIOS).w				; initialize the drive and get TOC

		moveq	#0,d0
		clear_ram.w	SubCPUGlobalVars,sizeof_SubCPUGlobalVars	; clear global variables
		clear_ram.pc	FileVars,sizeof_FileVars				; clear file engine variables

		moveq	#id_FileFunc_EngineInit,d0
		jsr	(FileFunction).w		; initialize the file engine
		jmp	(DriverInit).l			; initialize the PCM driver
; ===========================================================================

SetupValues:
		dc.l AddressError
		dc.l IllegalInstr
		dc.l ZeroDivide
		dc.l ChkInstr
		dc.l TrapvInstr
		dc.l PrivilegeViol
		dc.l Trace
		dc.l Line1010Emu
		dc.l Line1111Emu
		dc.l GFXInt			; GFX int address
		dc.l RunPCMDriver	; timer int address
		dc.b 1,$FF			; drive init parameters
		dc.b 255			; timer interrupt interval

DiscType:
		dc.b 	'SEGADISCSYSTEM  '
	;	dc.b	'SEGADATADISC    '
		arraysize	DiscType
HeaderTitle:
		dc.b	'SONIC THE HEDGEHOG-CD                           '
	;	dc.b 	'SONIC THE HEDGEHOG CD MODE 1 DATA DISC          '
		arraysize	HeaderTitle
		even
; ===========================================================================

Main:
		addq.w #4,sp	; throw away return address to BIOS call loop, as we will not be returning there

	.waitinit:
		move.w	#BIOSStatus,d0
		jsr	(_CDBIOS).w					; get BIOS status
		move.b	(a0),d0

		cmpi.b	#no_disc,d0
		beq.s	.nodisc			; branch if no disc was found

		cmpi.b	#tray_open,d0
		beq.s	.nodisc			; branch if drive was open

		andi.b	#drive_init_nybble,d0
		bne.s	.waitinit			; branch if drive is not ready

		move.w	#TOCRead,d0
		moveq	#1,d1
		jsr	(_CDBIOS).w				; fetch TOC entry for track 1

		tst.b	d1
		beq.w	.checktrackcount	; branch if it's audio (most likely an audio CD)

		jsr	(LoadDiscHeader).w		; load the disc's header (first sector)

		cmpi.w	#fstatus_ok,d0		; was the operation a success?
		bne.s	.nodisc				; if not, assume no disc

		lea FileVars+fe_dirreadbuf(pc),a1	; a1 = disc type in header
		lea DiscType(pc),a2					; header type we're checking for
		moveq	#sizeof_DiscType-1,d1

		jsr	(CompareStrings).w				; does the type in the header match?
		bne.s	.checktrackcount			; if not, branch

		lea	FileVars+fe_dirreadbuf+domestic_title(pc),a1	; game title in header
		lea HeaderTitle(pc),a2
		moveq	#sizeof_HeaderTitle-1,d1

		jsr	(CompareStrings).w		; does the title in the header match?
		beq.s	.getfiles			; if so, branch

	.checktrackcount:
		cmpi.b	#35,(_CDDStatus+CDD_LastTrack).w		; does this CD have at least 35 tracks?
		bcc.s	.audiocd				; if so, we can play music from this CD
		bra.s	.nodisc					; otherwise, we can't use it; assume no disc
; ===========================================================================

.getfiles:
		moveq	#id_FileFunc_GetFiles,d0
		bsr.s	FileFunction			; load the disc's filesystem

	.waitfiles:
		jsr	(_WaitForVBlank).w			; file engine only runs during VBlank

		moveq	#id_FileFunc_GetStatus,d0		; is the operation finished?
		bsr.s	FileFunction
		bcs.s	.waitfiles				; if not, wait

		addq.b	#1,(v_disc_status).w	; 2 = full CD audio and FMV support

	.audiocd:
		addq.b	#1,(v_disc_status).w	; 1 = CD audio only

	.nodisc:
		move.b	(v_disc_status).w,(mcd_subcom_1).w	; give disc status to main CPU

		moveq	#'R',d0
		move.b	d0,(mcd_subcom_0).w		; signal initialization success

WaitReady:
		cmpi.b	#$FF,(mcd_main_flag).w	; is main CPU OK?
		beq.s	MainCrash1			; branch if so
		cmp.b	(mcd_maincom_0).w,d0		; has main CPU acknowledged?
		bne.s	WaitReady			; branch if not

		moveq	#0,d0
		move.b	d0,(mcd_subcom_0).w		; we are ready to accept commands once main CPU clears its com register
		move.b	d0,(mcd_subcom_1).w

	.waitmainready:
		tst.b	(mcd_maincom_0).w	; is main CPU ready to send commands?
		bne.s	.waitmainready		; branch if not

		bra.w	MainCommandLoop		; continue to main command loop

; -------------------------------------------------------------------------
; Main CPU crash
; -------------------------------------------------------------------------

MainCrash1:
		trap #0
; ===========================================================================

		include "includes/sub/VBlank and GFXInt.asm"
		include "includes/sub/File Engine.asm"

		include "includes/sub/Mega CD Exception Handler (Sub CPU).asm"
		include "includes/sub/Command Handlers.asm"

NullRTS:
DriverInit:
		rts

RunPCMDriver:
		rte

FileVars:
		dcb.b	sizeof_FileVars,$FF
		even

FileTable:
File_R11A:
		dc.b	"R11A__.MMD;1", 0		; Palmtree Panic Act 1 Present
File_R11B:
		dc.b	"R11B__.MMD;1", 0		; Palmtree Panic Act 1 Past
File_R11C:
		dc.b	"R11C__.MMD;1", 0		; Palmtree Panic Act 1 Good Future
File_R11D:
		dc.b	"R11D__.MMD;1", 0		; Palmtree Panic Act 1 Bad Future
File_MDInit:
		dc.b	"MDINIT.MMD;1", 0		; Mega Drive initialization
File_SoundTest:
		dc.b	"SOSEL_.MMD;1", 0		; Sound test
File_StageSelect:
		dc.b	"STSEL_.MMD;1", 0		; Stage select
File_R12A:
		dc.b	"R12A__.MMD;1", 0		; Palmtree Panic Act 2 Present
File_R12B:
		dc.b	"R12B__.MMD;1", 0		; Palmtree Panic Act 2 Past
File_R12C:
		dc.b	"R12C__.MMD;1", 0		; Palmtree Panic Act 2 Good Future
File_R12D:
		dc.b	"R12D__.MMD;1", 0		; Palmtree Panic Act 2 Bad Future
File_TitleMain:
		dc.b	"TITLEM.MMD;1", 0		; Title screen (Main CPU)
File_TitleSub:
		dc.b	"TITLES.BIN;1", 0		; Title screen (Sub CPU)
File_Warp:
		dc.b	"WARP__.MMD;1", 0		; Warp sequence
File_TimeAttackMain:
		dc.b	"ATTACK.MMD;1", 0		; Time attack (Main CPU)
File_TimeAttackSub:
		dc.b	"ATTACK.BIN;1", 0		; Time attack (Main CPU)
File_IPX:
		dc.b	"IPX___.MMD;1", 0		; Main program
File_PencilTestData:
		dc.b	"PTEST.STM;1 ", 0		; Pencil test FMV data
File_OpeningData:
		dc.b	"OPN.STM;1   ", 0		; Opening FMV data
File_BadEndData:
		dc.b	"BADEND.STM;1", 0		; Bad ending FMV data
File_GoodEndData:
		dc.b	"GOODEND.STM;1", 0		; Good ending FMV data
File_OpeningMain:
		dc.b	"OPEN_M.MMD;1", 0		; Opening FMV (Main CPU)
File_OpeningSub:
		dc.b	"OPEN_S.BIN;1", 0		; Opening FMV (Sub CPU)
File_CominSoon:
		dc.b	"COME__.MMD;1", 0		; "Comin' Soon" screen
File_DAGardenMain:
		dc.b	"PLANET_M.MMD;1", 0		; D.A. Garden (Main CPU)
File_DAGardenSub:
		dc.b	"PLANET_S.BIN;1", 0		; D.A. Garden (Sub CPU)
File_R31A:
		dc.b	"R31A__.MMD;1", 0		; Collision Chaos Act 1 Present
File_R31B:
		dc.b	"R31B__.MMD;1", 0		; Collision Chaos Act 1 Past
File_R31C:
		dc.b	"R31C__.MMD;1", 0		; Collision Chaos Act 1 Good Future
File_R31D:
		dc.b	"R31D__.MMD;1", 0		; Collision Chaos Act 1 Bad Future
File_R32A:
		dc.b	"R32A__.MMD;1", 0		; Collision Chaos Act 2 Present
File_R32B:
		dc.b	"R32B__.MMD;1", 0		; Collision Chaos Act 2 Past
File_R32C:
		dc.b	"R32C__.MMD;1", 0		; Collision Chaos Act 2 Good Future
File_R32D:
		dc.b	"R32D__.MMD;1", 0		; Collision Chaos Act 2 Bad Future
File_R33C:
		dc.b	"R33C__.MMD;1", 0		; Collision Chaos Act 3 Good Future
File_R33D:
		dc.b	"R33D__.MMD;1", 0		; Collision Chaos Act 3 Bad Future
File_R13C:
		dc.b	"R13C__.MMD;1", 0		; Palmtree Panic Act 3 Good Future
File_R13D:
		dc.b	"R13D__.MMD;1", 0		; Palmtree Panic Act 3 Bad Future
File_R41A:
		dc.b	"R41A__.MMD;1", 0		; Tidal Tempest Act 1 Present
File_R41B:
		dc.b	"R41B__.MMD;1", 0		; Tidal Tempest Act 1 Past
File_R41C:
		dc.b	"R41C__.MMD;1", 0		; Tidal Tempest Act 1 Good Future
File_R41D:
		dc.b	"R41D__.MMD;1", 0		; Tidal Tempest Act 1 Bad Future
File_R42A:
		dc.b	"R42A__.MMD;1", 0		; Tidal Tempest Act 2 Present
File_R42B:
		dc.b	"R42B__.MMD;1", 0		; Tidal Tempest Act 2 Past
File_R42C:
		dc.b	"R42C__.MMD;1", 0		; Tidal Tempest Act 2 Good Future
File_R42D:
		dc.b	"R42D__.MMD;1", 0		; Tidal Tempest Act 2 Bad Future
File_R43C:
		dc.b	"R43C__.MMD;1", 0		; Tidal Tempest Act 3 Good Future
File_R43D:
		dc.b	"R43D__.MMD;1", 0		; Tidal Tempest Act 3 Bad Future
File_R51A:
		dc.b	"R51A__.MMD;1", 0		; Quartz Quadrant Act 1 Present
File_R51B:
		dc.b	"R51B__.MMD;1", 0		; Quartz Quadrant Act 1 Past
File_R51C:
		dc.b	"R51C__.MMD;1", 0		; Quartz Quadrant Act 1 Good Future
File_R51D:
		dc.b	"R51D__.MMD;1", 0		; Quartz Quadrant Act 1 Bad Future
File_R52A:
		dc.b	"R52A__.MMD;1", 0		; Quartz Quadrant Act 2 Present
File_R52B:
		dc.b	"R52B__.MMD;1", 0		; Quartz Quadrant Act 2 Past
File_R52C:
		dc.b	"R52C__.MMD;1", 0		; Quartz Quadrant Act 2 Good Future
File_R52D:
		dc.b	"R52D__.MMD;1", 0		; Quartz Quadrant Act 2 Bad Future
File_R53C:
		dc.b	"R53C__.MMD;1", 0		; Quartz Quadrant Act 3 Good Future
File_R53D:
		dc.b	"R53D__.MMD;1", 0		; Quartz Quadrant Act 3 Bad Future
File_R61A:
		dc.b	"R61A__.MMD;1", 0		; Wacky Workbench Act 1 Present
File_R61B:
		dc.b	"R61B__.MMD;1", 0		; Wacky Workbench Act 1 Past
File_R61C:
		dc.b	"R61C__.MMD;1", 0		; Wacky Workbench Act 1 Good Future
File_R61D:
		dc.b	"R61D__.MMD;1", 0		; Wacky Workbench Act 1 Bad Future
File_R62A:
		dc.b	"R62A__.MMD;1", 0		; Wacky Workbench Act 2 Present
File_R62B:
		dc.b	"R62B__.MMD;1", 0		; Wacky Workbench Act 2 Past
File_R62C:
		dc.b	"R62C__.MMD;1", 0		; Wacky Workbench Act 2 Good Future
File_R62D:
		dc.b	"R62D__.MMD;1", 0		; Wacky Workbench Act 2 Bad Future
File_R63C:
		dc.b	"R63C__.MMD;1", 0		; Wacky Workbench Act 3 Good Future
File_R63D:
		dc.b	"R63D__.MMD;1", 0		; Wacky Workbench Act 3 Bad Future
File_R71A:
		dc.b	"R71A__.MMD;1", 0		; Stardust Speedway Act 1 Present
File_R71B:
		dc.b	"R71B__.MMD;1", 0		; Stardust Speedway Act 1 Past
File_R71C:
		dc.b	"R71C__.MMD;1", 0		; Stardust Speedway Act 1 Good Future
File_R71D:
		dc.b	"R71D__.MMD;1", 0		; Stardust Speedway Act 1 Bad Future
File_R72A:
		dc.b	"R72A__.MMD;1", 0		; Stardust Speedway Act 2 Present
File_R72B:
		dc.b	"R72B__.MMD;1", 0		; Stardust Speedway Act 2 Past
File_R72C:
		dc.b	"R72C__.MMD;1", 0		; Stardust Speedway Act 2 Good Future
File_R72D:
		dc.b	"R72D__.MMD;1", 0		; Stardust Speedway Act 2 Bad Future
File_R73C:
		dc.b	"R73C__.MMD;1", 0		; Stardust Speedway Act 3 Good Future
File_R73D:
		dc.b	"R73D__.MMD;1", 0		; Stardust Speedway Act 3 Bad Future
File_R81A:
		dc.b	"R81A__.MMD;1", 0		; Metallic Madness Act 1 Present
File_R81B:
		dc.b	"R81B__.MMD;1", 0		; Metallic Madness Act 1 Past
File_R81C:
		dc.b	"R81C__.MMD;1", 0		; Metallic Madness Act 1 Good Future
File_R81D:
		dc.b	"R81D__.MMD;1", 0		; Metallic Madness Act 1 Bad Future
File_R82A:
		dc.b	"R82A__.MMD;1", 0		; Metallic Madness Act 2 Present
File_R82B:
		dc.b	"R82B__.MMD;1", 0		; Metallic Madness Act 2 Past
File_R82C:
		dc.b	"R82C__.MMD;1", 0		; Metallic Madness Act 2 Good Future
File_R82D:
		dc.b	"R82D__.MMD;1", 0		; Metallic Madness Act 2 Bad Future
File_R83C:
		dc.b	"R83C__.MMD;1", 0		; Metallic Madness Act 3 Good Future
File_R83D:
		dc.b	"R83D__.MMD;1", 0		; Metallic Madness Act 3 Bad Future
File_SpecialMain:
		dc.b	"SPMM__.MMD;1", 0		; Special Stage (Main CPU)
File_SpecialSub:
		dc.b	"SPSS__.BIN;1", 0		; Special Stage (Sub CPU)
File_R1PCM:
		dc.b	"SNCBNK1B.BIN;1", 0		; PCM driver (Palmtree Panic)
File_R3PCM:
		dc.b	"SNCBNK3B.BIN;1", 0		; PCM driver (Collision Chaos)
File_R4PCM:
		dc.b	"SNCBNK4B.BIN;1", 0		; PCM driver (Tidal Tempest)
File_R5PCM:
		dc.b	"SNCBNK5B.BIN;1", 0		; PCM driver (Quartz Quadrant)
File_R6PCM:
		dc.b	"SNCBNK6B.BIN;1", 0		; PCM driver (Wacky Workbench)
File_R7PCM:
		dc.b	"SNCBNK7B.BIN;1", 0		; PCM driver (Stardust Speedway)
File_R8PCM:
		dc.b	"SNCBNK8B.BIN;1", 0		; PCM driver (Metallic Madness)
File_BossPCM:
		dc.b	"SNCBNKB1.BIN;1", 0		; PCM driver (Boss)
File_FinalPCM:
		dc.b	"SNCBNKB2.BIN;1", 0		; PCM driver (Final boss)
File_DAGardenData:
		dc.b	"PLANET_D.BIN;1", 0		; D.A Garden track title data
File_Demo11A:
		dc.b	"DEMO11A.MMD;1", 0		; Palmtree Panic Act 1 Present demo
File_VisualMode:
		dc.b	"VM____.MMD;1", 0		; Visual Mode
File_BuRAMInit:
		dc.b	"BRAMINIT.MMD;1", 0		; Backup RAM initialization
File_BuRAMSub:
		dc.b	"BRAMSUB.BIN;1", 0		; Backup RAM functions
File_BuRAMMain:
		dc.b	"BRAMMAIN.MMD;1", 0		; Backup RAM manager
File_ThanksMain:
		dc.b	"THANKS_M.MMD;1", 0		; "Thank You" screen (Main CPU)
File_ThanksSub:
		dc.b	"THANKS_S.BIN;1", 0		; "Thank You" screen (Sub CPU)
File_ThanksData:
		dc.b	"THANKS_D.BIN;1", 0		; "Thank You" screen data
File_EndingMain:
		dc.b	"ENDING.MMD;1", 0		; Ending FMV (Main CPU)
File_BadEndSub:
		dc.b	"GOODEND.BIN;1", 0 		; Bad ending FMV (Sub CPU, not a typo)
File_GoodEndSub:
		dc.b	"BADEND.BIN;1", 0 		; Good ending FMV (Sub CPU, not a typo)
File_FunIsInf:
		dc.b	"NISI.MMD;1", 0			; "Fun is infinite" screen
File_SS8Credits:
		dc.b	"SPEEND.MMD;1", 0		; Special stage 8 credits
File_MCSonic:
		dc.b	"DUMMY0.MMD;1", 0		; M.C. Sonic screen
File_Tails:
		dc.b	"DUMMY1.MMD;1", 0		; Tails screen
File_BatmanSonic:
		dc.b	"DUMMY2.MMD;1", 0		; Batman Sonic screen
File_CuteSonic:
		dc.b	"DUMMY3.MMD;1", 0		; Cute Sonic screen
File_StaffTimes:
		dc.b	"DUMMY4.MMD;1", 0		; Best staff times screen
File_Dummy5:
		dc.b	"DUMMY5.MMD;1", 0		; Copy of prototype sound test (Unused)
File_Dummy6:
		dc.b	"DUMMY6.MMD;1", 0		; Copy of prototype sound test (Unused)
File_Dummy7:
		dc.b	"DUMMY7.MMD;1", 0		; Copy of prototype sound test (Unused)
File_Dummy8:
		dc.b	"DUMMY8.MMD;1", 0		; Copy of prototype sound test (Unused)
File_Dummy9:
		dc.b	"DUMMY9.MMD;1", 0		; Copy of prototype sound test (Unused)
File_PencilTestMain:
		dc.b	"PTEST.MMD;1", 0		; Pencil test FMV (Main CPU)
File_PencilTestSub:
		dc.b	"PTEST.BIN;1", 0		; Pencil test FMV (Sub CPU)
File_Demo43C:
		dc.b	"DEMO43C.MMD;1", 0		; Tidal Tempest Act 3 Good Future demo
File_Demo82A:
		dc.b	"DEMO82A.MMD;1", 0		; Metallic Madness Act 2 Present demo
		even


fmv_pcm_buffer:
		even

		end

