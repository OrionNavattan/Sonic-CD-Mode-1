; ---------------------------------------------------------------------------
; RAM Addresses - Variables (v) and Flags (f)
; ---------------------------------------------------------------------------

		pusho						; save options
		opt	ae+					; enable auto evens

		rsset workram_start
v_kosm_buffer:			rs.b $1000
;v_16x16_tiles:			rs.b $2000
v_level_layout:			rs.b $800
v_hscroll_buffer: 		rs.b $400		; horizontal scroll buffer
v_sprite_queue:         rs.b $400
v_sprite_buffer:		rs.b $280		; sprite table buffer
v_image_buffer:			rs.b $5800		; main CPU-side buffer for transformed images in title screen, special stage, and DA garden
v_16x16_tiles:			equ  v_image_buffer

v_stack:			rs.b $FFFF8000-__rs
;		rsset	$FFFF8000
v_stack_pointer:	equ __rs

; -------------------------------------------------------------------------
; Global variables - persist across game modes, death, or time warp
; -------------------------------------------------------------------------

v_vblank_primary_routine:	rs.l 1
v_disc_status:		rs.b	1

;	rsset	WORKRAM+$F00
;MAINVARS		rs.b	0		; Main CPU global variables
;f_ipx_vblank		rs.b	1		; IPX VSync flag
v_gamemode:			rs.b 	1
f_time_attack		rs.b	1		; v_time attack mode flag
v_saved_zone		rs.w	1		; Saved level
			rs.b	$C
v_time_attack_time		rs.l	1		; v_time attack v_time
v_time_attack_zone		rs.w	1		; v_time attack level
v_vdp_mode_buffer		rs.w	1		; IPX VDP register 1
v_time_attack_unlock	rs.b	1		; Last unlocked v_time attack v_zone
v_unused_backup_ram		rs.b	1		; Unknown Backup RAM variable
v_good_futures		rs.b	1		; Good futures achieved flags
			rs.b	1
v_demo_num			rs.b	1		; Demo ID
v_title_flags		rs.b	1		; Title screen flags
			rs.b	1
f_save_disabled		rs.b	1		; Save disabled flag
v_time_stones		rs.b	1		; v_time stones retrieved flags
v_special_stage		rs.b	1		; Current special stage
v_pal_clear		rs.b	1		; Palette clear flags
			rs.b	1
f_ending		rs.b	1		; Ending ID
f_special_lost		rs.b	1		; Special stage lost flag
			rs.b	$DA
v_unk_buffer 		rs.b	$200		; Unknown level buffer

OBJFLAGSCNT		EQU	$2FC		; Saved object flags entry count
v_respawn_list 		rs.b	2+OBJFLAGSCNT	; Saved object flags

			rs.l	1
v_restart		rs.w	1		; Level restart flag
v_frame_counter 		rs.w	1		; Level frame counter
;v_zone			rs.b	0		; v_zone and v_act ID
v_zone			rs.b	1		; v_zone ID
v_act			rs.b	1		; Act ID
v_lives			rs.b	1		; Life count
f_player2 		rs.b	1		; Use player 2
v_air 		rs.w	1		; Drown timer
f_time_over 		rs.b	1		; Level v_time over
v_ring_reward 		rs.b	1		; v_lives flags
f_hud_lives_update 		rs.b	1		; Update HUD life count
v_hud_rings_update 		rs.b	1		; Update HUD ring count
f_hud_time_update 		rs.b	1		; Update HUD timer
f_hud_score_update 		rs.b	1		; Update HUD v_score
v_rings			rs.w	1		; Ring count
v_time			rs.b	1		; v_time
v_time_min		rs.b	1		; Minutes
v_time_sec		rs.b	1		; Seconds
v_time_frames		rs.b	1		; Centiseconds
v_score			rs.l	1		; v_score
v_plc_load_flags		rs.b	1		; PLC load flags
v_palfade_flags		rs.b	1		; Palette fade flags
f_shield			rs.b	1		; f_shield flag
f_invincible 		rs.b	1		; f_invincible flag
f_shoes 		rs.b	1		; Speed shoes flag
f_timewarp 		rs.b	1		; v_time warp flag
v_spawn_mode		rs.b	1		; Spawn mode flag
v_spawn_mode_lampcopy		rs.b	1		; Saved spawn mode flag
v_sonic_x_pos_lampcopy 			rs.w	1		; Saved X position
v_sonic_y_pos_lampcopy 			rs.w	1		; Saved Y position
v_rings_warpcopy		rs.w	1		; v_time warp ring count
v_time_lampcopy 		rs.l	1		; Saved v_time
v_timezone		rs.b	1		; v_time v_zone
			rs.b	1
v_boundary_bottom_lampcopy		rs.w	1		; Saved bottom boundary
v_camera_x_pos_lampcopy		rs.w	1		; Saved camera X position
v_camera_y_pos_lampcopy		rs.w	1		; Saved camera Y position
v_bg1_x_pos_lampcopy		rs.w	1		; Saved background camera X position
v_bg1_y_pos_lampcopy		rs.w	1		; Saved background camera Y position
v_bg2_x_pos_lampcopy		rs.w	1		; Saved background camera X position 2
v_bg2_y_pos_lampcopy		rs.w	1		; Saved background camera Y position 2
v_bg3_x_pos_lampcopy		rs.w	1		; Saved background camera X position 3
v_bg3_y_pos_lampcopy		rs.w	1		; Saved background camera Y position 3
v_water_height_normal_lampcopy	rs.b	1		; Saved water height
v_water_routine_lampcopy	rs.b	1		; Saved water routine
f_water_pal_full_lampcopy		rs.b	1		; Saved water fullscreen flag
v_ring_reward_warpcopy		rs.b	1		; v_time warp v_lives flags
v_spawn_mode_warpcopy		rs.b	1		; v_time warp spawn mode flag
			rs.b	1
v_sonic_x_pos_warpcopy 			rs.w	1		; v_time warp X position
v_sonic_y_pos_warpcopy 			rs.w	1		; v_time warp Y position
v_sonic_status_lampcopy		rs.b	1		; v_time warp flags
			rs.b	1
v_boundary_bottom_warpcopy		rs.w	1		; v_time warp bottom boundary
v_camera_x_pos_warpcopy		rs.w	1		; v_time warp camera X position
v_camera_y_pos_warpcopy		rs.w	1		; v_time warp camera Y position
v_bg1_x_pos_warpcopy		rs.w	1		; v_time warp background camera X position
v_bg1_y_pos_warpcopy		rs.w	1		; v_time warp background camera Y position
v_bg2_x_pos_warpcopy		rs.w	1		; v_time warp background camera X position 2
v_bg2_y_pos_warpcopy		rs.w	1		; v_time warp background camera Y position 2
v_bg3_x_pos_warpcopy		rs.w	1		; v_time warp background camera X position 3
v_bg3_y_pos_warpcopy		rs.w	1		; v_time warp background camera Y position 3
v_water_height_normal_warpcopy		rs.w	1		; v_time warp water height
v_water_routine_warpcopy	rs.b	1		; v_time warp water routine
f_water_pal_full_warpcopy		rs.b	1		; v_time warp water fullscreen flag
v_sonic_inertia_warpcopy 		rs.w	1		; v_time warp ground velocity
v_sonic_x_vel_warpcopy 		rs.w	1		; v_time warp X velocity
v_sonic_y_vel_warpcopy 		rs.w	1		; v_time warp Y velocity
f_good_future		rs.b	1		; Good future flag
v_powerup			rs.b	1		; v_powerup ID
f_unk_stage 		rs.b	1		; Unknown level flag
f_projecter_destroyed		rs.b	1		; Projector destroyed flag
f_special_stage		rs.b	1		; Special stage flag
f_combine_ring 		rs.b	1		; Combine ring flag (leftover)
v_time_warpcopy 		rs.l	1		; v_time warp v_time
v_section_id		rs.w	1		; Section ID
			rs.b	1
f_amy_captured		rs.b	1		; Amy captured flag
v_score_next_life		rs.l	1		; Next life v_score
v_sonic_angle1_unused 		rs.b	1		; Debug angle
v_sonic_angle2_unused		rs.b	1		; Debug angle (shifted)
v_sonic_angle3_unused		rs.b	1		; Debug quadrant
v_sonic_floor_dist_unused 		rs.b	1		; Debug floor distance
v_demo_mode		rs.w	1		; Demo mode flag
			rs.w	1
v_s1_credits_num		rs.w	1		; Credits index (leftover from Sonic 1)
			rs.b	1
f_debug_cheat		rs.w	1		; Debug cheat flag
f_init 		rs.l	1		; Initialized flag
v_last_lamppost		rs.b	1		; v_last_lamppost ID
			rs.b	1
v_good_future_flags		rs.b	1		; Good future flags
f_mini_lampcopy		rs.b	1		; Saved mini Sonic flag
			rs.b	1
f_mini_warpcopy		rs.b	1		; v_time warp mini Sonic flag
			rs.b	$6C
v_flower_positions		rs.b	$300		; Flower position buffer
v_flower_count		rs.b	3		; Flower count
f_enable_display_fade	rs.b	1		; Enable display when fading
v_debug_item_index 		rs.b	1		; Level debug object
			rs.b	1
f_debug_active 		rs.w	1		; Level debug mode
			rs.w	1
v_vblank_counter	rs.l	1		; Level V-BLANK interrupt counter
v_timestop_timer		rs.w	1		; v_time stop timer
v_syncani_0_time	rs.b	1		; Log spike animation timer (leftover from Sonic 1)
v_syncani_0_frame	rs.b	1		; Log spike animation frame (leftover from Sonic 1)
v_syncani_1_time		rs.b	1		; Ring animation timer
v_syncani_1_frame		rs.b	1		; Ring animation frame
v_syncani_2_time		rs.b	1		; Unknown animation timer (leftover from Sonic 1)
v_syncani_2_frame		rs.b	1		; Unknown animation frame (leftover from Sonic 1)
v_syncani_3_time	rs.b	1		; Ring loss animation timer
v_syncani_3_frame	rs.b	1		; Ring loss animation frame
v_syncani_3_accumulator	rs.w	1		; Ring loss animation accumulator
			rs.b	$C
v_camera_x_pos_copy		rs.l	1		; Camera X position copy
v_camera_y_pos_copy		rs.l	1		; Camera Y position copy
v_bg1_x_pos_copy		rs.l	1		; Camera background X position copy
v_bg1_y_pos_copy		rs.l	1		; Camera background Y position copy
v_bg2_x_pos_copy		rs.l	1		; Camera background X position 2 copy
v_bg2_y_pos_copy		rs.l	1		; Camera background Y position 2 copy
v_bg3_x_pos_copy		rs.l	1		; Camera background X position 3 copy
v_bg3_y_pos_copy		rs.l	1		; Camera background Y position 3 copy
v_fg_redraw_direction_copy		rs.w	1		; Scroll flags copy
v_bg1_redraw_direction_copy	rs.w	1		; Scroll flags copy (background)
v_bg2_redraw_direction_copy	rs.w	1		; Scroll flags copy (background 2)
v_bg3_redraw_direction_copy	rs.w	1		; Scroll flags copy (background 3)
v_debug_blockid 		rs.w	1		; Level debug block ID
			rs.l	1
v_debug_subtype_2		rs.b	1		; Level debug subtype 2 ID
v_water_sway_angle		rs.b	1		; Water sway angle
v_layer			rs.b	1		; v_layer ID
f_level_started		rs.b	1		; Level started flag
f_boss_music		rs.b	1		; Boss music flag
			rs.b	1
v_wwz_beam_mode		rs.b	1		; Wacky Workbench electric beam mode
f_mini 		rs.b	1		; Mini Sonic flag
			rs.b	$24
v_aniart_buffer 		rs.b	$480		; Animated art buffer
v_scroll_section_speeds		rs.b	$200		; Scroll section speeds
;MAINVARSSZ		EQU	__rs-MAINVARS	; Size of Main CPU global variables area

; -------------------------------------------------------------------------
; Shared non-retained variables - cleared on each game mode change
; -------------------------------------------------------------------------

;	rsset	WORKRAM+$FF00A000
;levelLayout 		rs.b	$800		; Level layout
;deformBuffer		rs.b	$200		; Deformation buffer
;nemBuffer		rs.b	$200		; Nemesis decompression buffer
;objDrawQueue		rs.b	$400		; Object draw queue
;			rs.b	$1800
;sonicArtBuf 		rs.b	$300		; Sonic art buffer

playerCtrl		rs.b	0		; Player controller data
playerCtrlHold 		rs.b	1		; Player held controller data
playerCtrlTap		rs.b	1		; Player tapped controller data
p1CtrlData		rs.b	0		; Player 1 controller data
p1CtrlHold 		rs.b	1		; Player 1 held controller data
p1CtrlTap		rs.b	1		; Player 1 tapped controller data
p2CtrlData		rs.b	0		; Player 2 controller data
p2CtrlHold 		rs.b	1		; Player 2 held controller data
p2CtrlTap		rs.b	1		; Player 2 tapped controller data

sonicRecordBuf		rs.b	$100		; Sonic position record buffer


objects			rs.b	0		; Object pool
resObjects		rs.b	0		; Reserved objects
objPlayerSlot 		rs.b	sizeof_ost		; Player slot
objPlayerSlot2 		rs.b	sizeof_ost		; Player 2 slot
objHUDScoreSlot		rs.b	sizeof_ost		; HUD (v_score) slot
objHUDLivesSlot		rs.b	sizeof_ost		; HUD (v_lives) slot
objTtlCardSlot		rs.b	sizeof_ost		; Title card slot
objHUDRingsSlot		rs.b	sizeof_ost		; HUD (v_rings) slot
objShieldSlot 		rs.b	sizeof_ost		; f_shield slot
objBubblesSlot 		rs.b	sizeof_ost		; Bubbles slot
objInvStar1Slot		rs.b	sizeof_ost		; Invincibility star 1 slot
objInvStar2Slot		rs.b	sizeof_ost		; Invincibility star 2 slot
objInvStar3Slot		rs.b	sizeof_ost		; Invincibility star 3 slot
objInvStar4Slot		rs.b	sizeof_ost		; Invincibility star 4 slot
objTimeStar1Slot	rs.b	sizeof_ost		; v_time warp star 1 slot
objTimeStar2Slot	rs.b	sizeof_ost		; v_time warp star 2 slot
objTimeStar3Slot	rs.b	sizeof_ost		; v_time warp star 3 slot
objTimeStar4Slot	rs.b	sizeof_ost		; v_time warp star 4 slot
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
			rs.b	sizeof_ost
objHUDIconSlot		rs.b	sizeof_ost		; HUD (life icon) slot
resObjectsEnd		rs.b	0

dynObjects 		rs.b	$60*sizeof_ost	; Dynamic objects
dynObjectsEnd		rs.b	0
objectsEnd		rs.b	0

OBJCOUNT		EQU	(objectsEnd-objects)/sizeof_ost
RESOBJCOUNT		EQU	(resObjectsEnd-resObjects)/sizeof_ost
DYNOBJCOUNT		EQU	(dynObjectsEnd-dynObjects)/sizeof_ost

			rs.b	$A
fmSndQueue1 		rs.b	1		; FM sound queue 1
fmSndQueue2 		rs.b	1		; FM sound queue 2
fmSndQueue3 		rs.b	1		; FM sound queue 3
			rs.b	$5F3
;gameMode 		rs.b	1		; Game mode
	;		rs.b	1

	;		rs.l	1
vdpReg01 		rs.w	1		; VDP register 1
			rs.b	6
vintTimer 		rs.w	1		; V-BLANK interrupt timer
vscrollScreen 		rs.l	1		; Vertical scroll (full screen)
hscrollScreen 		rs.l	1		; Horizontal scroll (full screen)
			rs.b	6
vdpReg0A 		rs.w	1		; H-BLANK interrupt counter
palFadeInfo		rs.b	0		; Palette fade info
palFadeStart		rs.b	1		; Palette fade start
palFadeLen 		rs.b	1		; Palette fade length

miscVariables		rs.b	0
vintECount 		rs.b	1		; V-BLANK interrupt routine E counter
			rs.b	1
;vintRoutine 		rs.b	1		; V-BLANK interrupt routine ID
			rs.b	1
spriteCount 		rs.b	1		; Sprite count
			rs.b	9
rngSeed 		rs.l	1		; RNG seed
paused 			rs.w	1		; Paused flag
			rs.l	1
dmaCmdLow		rs.w	1		; DMA command low word buffer

plcBuffer 		rs.b	$60		; PLC buffer
plcNemWrite 		rs.l	1		; PLC
plcRepeat 		rs.l	1		; PLC
plcPixel 		rs.l	1		; PLC
plcRow 			rs.l	1		; PLC
plcRead 		rs.l	1		; PLC
plcShift 		rs.l	1		; PLC
plcTileCount 		rs.w	1		; PLC
plcProcTileCnt 		rs.w	1		; PLC
hintFlag 		rs.w	1		; H-BLANK interrupt flag

lagCounter	rs.l	1			; Lag counter

scrollFlags		rs.w	1		; Scroll flags
scrollFlagsBg		rs.w	1		; Scroll flags (background)
scrollFlagsBg2		rs.w	1		; Scroll flags (background 2)
scrollFlagsBg3		rs.w	1		; Scroll flags (background 3)1

waterFadePal		rs.b	$80		; Water fade palette buffer (uses part of sprite buffer)
waterPalette		rs.b	$80		; Water palette buffer
palette 		rs.b	$80		; Palette buffer
fadePalette 		rs.b	$80		; Fade palette buffer

savedSR 		rs.w	1		; Saved status register
demoDataPtr 		rs.l	1		; Demo data pointer

; -------------------------------------------------------------------------
; Mode-specific variables: Level
; -------------------------------------------------------------------------

v_modespecifc_vars:	equ __rs
waterHeight 		rs.w	1		; Water height (with swaying)
waterHeight2		rs.w	1		; Water height (without swaying)
destWaterHeight		rs.w	1		; Water height destination
waterMoveSpeed		rs.b	1		; Water height move speed
waterRoutine		rs.b	1		; Water routine ID
waterFullscreen 	rs.b	1		; Water fullscreen flag
			rs.b	$17
aniArtFrames		rs.b	6		; Animated art frames
aniArtTimers		rs.b	6		; Animated art timers
			rs.b	$E

cameraX 		rs.l	1		; Camera X position
cameraY 		rs.l	1		; Camera Y position
cameraBgX 		rs.l	1		; Background camera X position
cameraBgY 		rs.l	1		; Background camera Y position
cameraBg2X 		rs.l	1		; Background 2 camera X position
cameraBg2Y 		rs.l	1		; Background 2 camera Y position
cameraBg3X 		rs.l	1		; Background 3 camera X position
cameraBg3Y 		rs.l	1		; Background 3 camera Y position
destLeftBound		rs.w	1		; Camera left boundary destination
destRightBound		rs.w	1		; Camera right boundary destination
destTopBound		rs.w	1		; Camera top boundary destination
destBottomBound		rs.w	1		; Camera bottom boundary destination
leftBound 		rs.w	1		; Camera left boundary
rightBound 		rs.w	1		; Camera right boundary
topBound 		rs.w	1		; Camera top boundary
bottomBound 		rs.w	1		; Camera bottom boundary
unusedF730 		rs.w	1
leftBound3 		rs.w	1
			rs.b	6
scrollXDiff		rs.w	1		; Horizontal scroll difference
scrollYDiff		rs.w	1		; Vertical scroll difference
camYCenter 		rs.w	1		; Camera Y center
unusedF740 		rs.b	1
unusedF741 		rs.b	1
eventRoutine		rs.w	1		; Level event routine ID
scrollLock 		rs.w	1		; Scroll lock flag
unusedF746 		rs.w	1
unusedF748 		rs.w	1
horizBlkCrossed		rs.b	1		; Horizontal block crossed flag
vertiBlkCrossed		rs.b	1		; Vertical block crossed flag
horizBlkCrossedBg	rs.b	1		; Horizontal block crossed flag (background)
vertiBlkCrossedBg	rs.b	1		; Vertical block crossed flag (background)
horizBlkCrossedBg2	rs.b	2		; Horizontal block crossed flag (background 2)
horizBlkCrossedBg3	rs.b	1		; Horizontal block crossed flag (background 3)
;			rs.b	1
;			rs.b	1
;			rs.b	1

btmBoundShift		rs.w	1		; Bottom boundary shifting flag
			rs.b	1
sneezeFlag		rs.b	1		; Sneeze flag (prototype leftover)

sonicTopSpeed		rs.w	1		; Sonic top speed
sonicAcceleration	rs.w	1		; Sonic acceleration
sonicDeceleration	rs.w	1		; Sonic deceleration
sonicLastFrame		rs.b	1		; Sonic's last sprite frame ID
updateSonicArt		rs.b	1		; Update Sonic's art flag
primaryAngle		rs.b	1		; Primary angle
			rs.b	1
secondaryAngle		rs.b	1		; Secondary angle
			rs.b	1

objSpawnRoutine		rs.b	1		; Object spawn routine ID
			rs.b	1
objPrevChunk		rs.w	1		; Previous object layout chunk position
objChunkRight		rs.l	1		; Object layout right chunk
objChunkLeft		rs.l	1		; Object layout left chunk
objChunkNullR		rs.l	1		; Object layout right chunk (null)
objChunkNullL		rs.l	1		; Object layout left chunk 2  (null)
boredTimer 		rs.w	1		; Bored timer
boredTimerP2 		rs.w	1		; Player 2 bored timer
timeWarpDir		rs.b	1		; v_time warp direction
			rs.b	1
v_time_warp_timer:		rs.w	1		; v_time warp timer
lookMode 		rs.b	1		; Look mode
			rs.b	1
demoDataIndex 		rs.w	1		; Demo data index
demoS1Index 		rs.w	1		; Demo index (Sonic 1 leftover)
			rs.l	1
collisionPtr		rs.l	1		; Collision data pointer
			rs.b	6
camXCenter 		rs.w	1		; Camera X center
			rs.b	5
bossFlags		rs.b	1		; Boss flags
sonicRecordIndex	rs.w	1		; Sonic position record buffer index
bossFight 		rs.b	1		; Boss fight flag
			rs.b	1
specialChunks 		rs.l	1		; Special chunk IDs
palCycleSteps 		rs.b	7		; Palette cycle steps
palCycleTimers		rs.b	7		; Palette cycle timers
			rs.b	9
windTunnelFlag		rs.b	1		; Wind tunnel flag
			rs.b	1
			rs.b	1
waterSlideFlag 		rs.b	1		; Water slide flag
			rs.b	1
ctrlLocked 		rs.b	1		; Controls locked flag
			rs.b	3
scoreChain		rs.w	1		; v_score chain
timeBonus		rs.w	1		; v_time bonus
ringBonus		rs.w	1		; Ring bonus
updateHUDBonus		rs.b	1		; Update results bonus flag
;			rs.b	3

;			rs.b	4
switchFlags		rs.b	$20		; Switch press flags
;sprites 		rs.b	$200		; Sprite buffer

; -------------------------------------------------------------------------
; Mode-specific variables: Special Stage
; -------------------------------------------------------------------------

	rsset	v_modespecifc_vars
;VARSSTART	rs.b	0			; Start of variables
;IMGLENGTH:	= $3000
;stageImage	rs.b	IMGLENGTH		; Stage image buffer
;sprites		rs.b	80*8			; Sprite buffer
		rs.b	4
splashArtLoad	rs.b	1			; Splash art load flag
;scrollFlags	rs.b	1			; Scroll flags
		rs.b	$7A
sonicArtBuf	rs.b	$300			; Sonic art buffer
		rs.b	$100
mapKosBuffer	rs.b	0			; Map Kosinski decompression buffer
bgHScroll	rs.b	$200			; Background horizontal scroll buffer (integer)
bgHScrollFrac	rs.b	$200			; Background horizontal scroll buffer (fraction)
stageHScroll1	rs.b	$100			; Stage horizontal scroll buffer (buffer 1)
stageHScroll2	rs.b	$100			; Stage horizontal scroll buffer (buffer 2)
		rs.b	$300
demoData	rs.b	$700			; Demo data bufffer
;nemBuffer	rs.b	$200			; Nemesis decompression buffer
;palette		rs.w	$40			; Palette buffer
;fadePalette	rs.w	$40			; Fade palette buffer
;paused		rs.b	1			; Paused flag
		rs.b	1
demoActive	rs.b	1			; Demo active flag
fadedOut	rs.b	1			; Faded out flag
flagsCopy	rs.b	1			; Copy of special stage flags
		rs.b	$3B
;vintRoutine	rs.w	1			; V-INT routine ID
resultsTimer	rs.w	1			; Results timer
vintCounter	rs.w	1			; V-INT counter
;savedSR		rs.w	1			; Saved status register
extraPlayerCnt	rs.w	1			; Extra player count
		rs.b	$56
;rngSeed		rs.l	1			; RNG seed
scrollOffset1	rs.l	1			; Background scroll offset 1
scrollOffset2	rs.l	1			; Background scroll offset 2
scrollOffset3	rs.l	1			; Background scroll offset 3
scrollOffset4	rs.l	1			; Background scroll offset 4
scrollOffset5	rs.l	1			; Background scroll offset 5
scrollOffset6	rs.l	1			; Background scroll offset 6
;demoDataPtr	rs.l	1			; Demo data pointer
;		rs.b	$40
;VARSLEN		EQU	__rs-VARSSTART		; Size of variables area


; -------------------------------------------------------------------------
; Mode-specific variables: Title Screen
; -------------------------------------------------------------------------
		rsset	v_modespecifc_vars
;VARSSTART	rs.b	0			; Start of variables
;cloudsImage	rs.b	IMGLENGTH		; Clouds image buffer
;hscroll		rs.b	$380			; Horizontal scroll buffer
;		rs.b	$80
;sprites		rs.b	80*8			; Sprite buffer
;scrollBuf	rs.b	$100			; Scroll buffer
;		rs.b	$B80

;objects		rs.b	0			; Object pool
;object0		rs.b	oSize			; Object 0
;object1		rs.b	oSize			; Object 1
;object2		rs.b	oSize			; Object 2
;object3		rs.b	oSize			; Object 3
;object4		rs.b	oSize			; Object 4
;object5		rs.b	oSize			; Object 5
;object6		rs.b	oSize			; Object 6
;object7		rs.b	oSize			; Object 7
;	if REGION<>JAPAN
;object8		rs.b	oSize			; Object 8
;object9		rs.b	oSize			; Object 9
;	endif
;objectsEnd	rs.b	0			; End of object pool
;OBJCOUNT	EQU	(__rs-objects)/oSize

;	if REGION=JAPAN
;		rs.b	$1200
;	else
;		rs.b	$1180
;	endif

;nemBuffer	rs.b	$200			; Nemesis decompression buffer
;palette		rs.w	$40			; Palette buffer
;fadePalette	rs.w	$40			; Fade palette buffer
		rs.b	1
unkPalFadeFlag	rs.b	1			; Unknown palette fade flag
;palFadeInfo	rs.b	0			; Palette fade info
;palFadeStart	rs.b	1			; Palette fade start
;palFadeLen	rs.b	1			; Palette fade length
titleMode	rs.b	1			; Title screen mode
		rs.b	5
unkObjYSpeed	rs.w	1			; Unknown global object Y speed
palCycleFrame	rs.b	1			; Palette cycle frame
palCycleDelay	rs.b	1			; Palette cycle delay
exitFlag	rs.b	1			; Exit flag
menuSel		rs.b	1			; Menu selection
menuOptions	rs.b	8			; Available menu options
;p2CtrlData	rs.b	0			; Player 2 controller data
;p2CtrlHold	rs.b	1			; Player 2 controller held buttons data
;p2CtrlTap	rs.b	1			; Player 2 controller tapped buttons data
;p1CtrlData	rs.b	0			; Player 1 controller data
;p1CtrlHold	rs.b	1			; Player 1 controller held buttons data
;p1CtrlTap	rs.b	1			; Player 1 controller tapped buttons data
cloudsCtrlFlag	rs.b	1			; Clouds control flag
	;	RSEVEN
;fmSndQueue	rs.b	1			; FM sound queue
	;	RSEVEN
subWaitTime	rs.l	1			; Sub CPU wait time
subFailCount	rs.b	1			; Sub CPU fail count
	;	RSEVEN
enableDisplay	rs.b	1			; Enable display flag
		rs.b	$19
;vintRoutine	rs.w	1			; V-INT routine ID
timer		rs.w	1			; Timer
;vintCounter	rs.w	1			; V-INT counter
;savedSR		rs.w	1			; Saved status register
;spriteCount	rs.b	1			; Sprite count
;		RSEVEN
curSpriteSlot	rs.l	1			; Current sprite slot
		rs.b	$B2
;VARSLEN		EQU	__rs-VARSSTART		; Size of variables area

;lagCounter	rs.l	1			; Lag counter

		rsset 	$FFFFFFFE
v_console_region:	rs.b 1		; $FFFFFFFE
v_bios_id:			rs.b 1		; $FFFFFFFF

