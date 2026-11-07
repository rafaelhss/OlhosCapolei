; -----------------------------------------------------------------------------
;   File: VaderCrab.s (VERSÃO INTEGRAL - COMPILAÇÃO DIRETA CA65)
;   Description: Subroutines to move and draw VaderCrab and RapaCrab dynamic elements
; -----------------------------------------------------------------------------

.export     MoveVaderCrab
.export     DrawVaderCrab
.export     DrawVaderHitboxDebug

.p816
.a8
.i16

.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Util.inc"

.import VaderCrab
.import BigHero
.import FrameCounter

WALK_SPEED = $01
WALK_ANIM_SPEED = $08 

PREPARING_ANIM_SPEED = 30
PREPARING_DURATION_FRAMES = 89
PREPARING_MAX_FRAMES = 3

ATTACKING_ANIM_SPEED = 15   
ATTACKING_DURATION_FRAMES = 45
ATTACK_MAX_FRAMES = 2  

REST_TIME = 30 

DP_DRAW_ENEMY_TYPE = $10

.segment "CODE"

;-------------------------------------------------------------------------------
;   MoveVaderCrab (IA e Física Parametrizadas via Pilha)
;-------------------------------------------------------------------------------
.proc MoveVaderCrab
        rep #$20                        
        .a16
        lda 3,s                         
        tay                             
        sep #$20                        
        .a8

        lda a:VaderCrabStruct::HurtTimer, y
        beq @ProcessIA                  
        
        sec
        sbc #1
        sta a:VaderCrabStruct::HurtTimer, y
        brl Done   

@ProcessIA:
AttackFrameUpdate:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_ATACKING
        beq @ProcessandoAtaque
        brl PreparingFrameUpdate 

@ProcessandoAtaque:  
        lda a:VaderCrabStruct::Attacking_Timer, y
        clc
        adc #1
        sta a:VaderCrabStruct::Attacking_Timer, y
        cmp #ATTACKING_DURATION_FRAMES
        bne AttackingAnim

        ; --- SANITIZAÇÃO ATÔMICA DA HITBOX E TIMERS NO FIM DO GOLPE ---
        lda #0
        sta a:VaderCrabStruct::Hitbox_Active, y  
        sta a:VaderCrabStruct::Attacking_Timer, y
        sta a:VaderCrabStruct::Attacking_Anim_Frame, y
        sta a:VaderCrabStruct::Attacking_Anim_Timer, y
        sta a:VaderCrabStruct::Preparing_Timer, y
        sta a:VaderCrabStruct::Preparing_Anim_Frame, y
        sta a:VaderCrabStruct::Preparing_Anim_Timer, y

        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
        
        lda #60
        sta a:VaderCrabStruct::Resting_Timer, y
        brl Move 

AttackingAnim:
        lda a:VaderCrabStruct::Attacking_Anim_Timer, y
        sec
        sbc #1
        sta a:VaderCrabStruct::Attacking_Anim_Timer, y
        beq ContinueAttackAnim 
        brl Move 

ContinueAttackAnim:
        lda #ATTACKING_ANIM_SPEED 
        sta a:VaderCrabStruct::Attacking_Anim_Timer, y
        
        lda a:VaderCrabStruct::Attacking_Anim_Frame, y
        clc
        adc #1                          
        cmp #ATTACK_MAX_FRAMES          
        bcc @SaveFrame                  
        lda #0                          

@SaveFrame:
        sta a:VaderCrabStruct::Attacking_Anim_Frame, y

@AtualizarHitbox:
        lda a:VaderCrabStruct::Attacking_Anim_Frame, y
        cmp #1
        beq @AtivarHitbox
        
        lda #0
        sta a:VaderCrabStruct::Hitbox_Active, y
        bra @FinalizaHitbox

@AtivarHitbox:
        lda #1
        sta a:VaderCrabStruct::Hitbox_Active, y

        lda a:VaderCrabStruct::Y_Pos, y
        clc
        adc #16                             
        sta a:VaderCrabStruct::Hitbox_Y1, y
        clc
        adc #16                             
        sta a:VaderCrabStruct::Hitbox_Y2, y

        lda a:VaderCrabStruct::Facing, y
        bne @HitboxDireitaAtaque                  

@HitboxEsquerdaAtaque:
        lda a:VaderCrabStruct::X_Pos, y
        sec
        sbc #32                            
        sta a:VaderCrabStruct::Hitbox_X1, y
        lda a:VaderCrabStruct::X_Pos, y 
        sta a:VaderCrabStruct::Hitbox_X2, y
        bra @FinalizaHitbox

@HitboxDireitaAtaque:
        lda a:VaderCrabStruct::X_Pos, y
        clc
        adc #64                             
        sta a:VaderCrabStruct::Hitbox_X1, y
        clc
        adc #32                             
        sta a:VaderCrabStruct::Hitbox_X2, y

@FinalizaHitbox:
        jmp Move

PreparingFrameUpdate:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_PREPARING
        bne WalkFrameUpdate 
        
        lda a:VaderCrabStruct::Preparing_Timer, y
        clc
        adc #1
        sta a:VaderCrabStruct::Preparing_Timer, y
        cmp #PREPARING_DURATION_FRAMES
        bne PreparingAnim
 
        lda #STATE_ATACKING
        sta a:VaderCrabStruct::State, y
        lda #0
        sta a:VaderCrabStruct::Preparing_Timer, y
        sta a:VaderCrabStruct::Attacking_Anim_Frame, y 
        sta a:VaderCrabStruct::Attacking_Timer, y
        
        lda #ATTACKING_ANIM_SPEED
        sta a:VaderCrabStruct::Attacking_Anim_Timer, y
        jmp Done

PreparingAnim:
        lda a:VaderCrabStruct::Preparing_Anim_Timer, y
        sec
        sbc #1
        sta a:VaderCrabStruct::Preparing_Anim_Timer, y
        bne Move 

        lda #PREPARING_ANIM_SPEED 
        sta a:VaderCrabStruct::Preparing_Anim_Timer, y
        
        lda a:VaderCrabStruct::Preparing_Anim_Frame, y
        clc
        adc #1                          
        cmp #PREPARING_MAX_FRAMES          
        bcc @SaveFramePrep                  
        lda #0                          

@SaveFramePrep:
        sta a:VaderCrabStruct::Preparing_Anim_Frame, y

WalkFrameUpdate:
        lda a:VaderCrabStruct::Resting_Timer, y
        sec
        sbc #1
        sta a:VaderCrabStruct::Resting_Timer, y
        bmi ContinueWalkFrameUpdate
        brl RestFrameUpdate    
    
ContinueWalkFrameUpdate:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_WALKING
        bne Move 

        lda a:VaderCrabStruct::Anim_Timer, y
        sec
        sbc #1
        sta a:VaderCrabStruct::Anim_Timer, y
        bne Move 
        
        lda #WALK_ANIM_SPEED 
        sta a:VaderCrabStruct::Anim_Timer, y
        
        lda a:VaderCrabStruct::Anim_Frame, y
        eor #$01 
        sta a:VaderCrabStruct::Anim_Frame, y

Move:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_ATACKING
        bne ContinuaFisicaNormal
        jmp Done                        

ContinuaFisicaNormal:
        sty z:DP_ENEMY_STRUCT_PTR

        lda a:VaderCrabStruct::X_Pos, y
        clc
        adc #16                          
        sec
        sbc BigHero + BigHeroStruct::X_Pos
        bcs CalculateAbsoluteDistance   

        eor #$FF                
        clc
        adc #1                  

CalculateAbsoluteDistance:   
        ldy z:DP_ENEMY_STRUCT_PTR   
        cmp #ENEMY_ATTACK_DISTANCE
        bcc StopHorizontalMove  
        beq StopHorizontalMove  

        lda a:VaderCrabStruct::X_Pos, y
        cmp BigHero + BigHeroStruct::X_Pos
        bcc WalkRight           

WalkLeft:
        lda a:VaderCrabStruct::X_Pos, y
        sec
        sbc #WALK_SPEED                 
        sta a:VaderCrabStruct::X_Pos, y
        
        lda #0
        sta a:VaderCrabStruct::Facing, y 
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
        lda #0
        sta a:VaderCrabStruct::Preparing_Timer, y
        bra CheckVerticalMove

WalkRight:
        lda a:VaderCrabStruct::X_Pos, y
        clc
        adc #WALK_SPEED                  
        sta a:VaderCrabStruct::X_Pos, y
        
        lda #1
        sta a:VaderCrabStruct::Facing, y 
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
        lda #0
        sta a:VaderCrabStruct::Preparing_Timer, y
        bra CheckVerticalMove

StopHorizontalMove:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_ATACKING
        beq @KeepStateX
        cmp #STATE_PREPARING
        beq @KeepStateX
        
        lda #STATE_PREPARING
        sta a:VaderCrabStruct::State, y
        
        lda #0
        sta a:VaderCrabStruct::Preparing_Timer, y
        sta a:VaderCrabStruct::Preparing_Anim_Frame, y
        sta a:VaderCrabStruct::Hitbox_Active, y            
        
        lda #PREPARING_ANIM_SPEED
        sta a:VaderCrabStruct::Preparing_Anim_Timer, y

@KeepStateX:
        bra CheckVerticalMove

CheckVerticalMove:
        sty z:DP_ENEMY_STRUCT_PTR   
        
        lda a:VaderCrabStruct::Y_Pos, y
        sec
        sbc BigHero + BigHeroStruct::Y_Pos
        bcs CalculateAbsoluteY          

        eor #$FF                
        clc
        adc #1 

CalculateAbsoluteY:
        ldy z:DP_ENEMY_STRUCT_PTR   
        cmp #ENEMY_ATTACK_Y_RANGE
        bcc StopVerticalMove            
        beq StopVerticalMove            

        lda a:VaderCrabStruct::Y_Pos, y
        cmp BigHero + BigHeroStruct::Y_Pos    
        bcc MoveDown                    

MoveUp:
        lda a:VaderCrabStruct::Y_Pos, y
        sec
        sbc #WALK_SPEED                  
        sta a:VaderCrabStruct::Y_Pos, y
        
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
        lda #0
        sta a:VaderCrabStruct::Preparing_Timer, y
        bra ExitMovement
    
MoveDown:
        lda a:VaderCrabStruct::Y_Pos, y
        clc
        adc #WALK_SPEED                  
        sta a:VaderCrabStruct::Y_Pos, y
        
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
        lda #0
        sta a:VaderCrabStruct::Preparing_Timer, y
        bra ExitMovement
    
StopVerticalMove:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_ATACKING
        beq Done
        cmp #STATE_PREPARING
        beq Done

        lda a:VaderCrabStruct::State, y
        cmp #STATE_WALKING
        beq ExitMovement

        lda #STATE_PREPARING
        sta a:VaderCrabStruct::State, y
        
        lda #0
        sta a:VaderCrabStruct::Preparing_Timer, y
        sta a:VaderCrabStruct::Preparing_Anim_Frame, y
sta a:VaderCrabStruct::Hitbox_Active, y
lda #PREPARING_ANIM_SPEED
sta a:VaderCrabStruct::Preparing_Anim_Timer, y
ExitMovement:
lda a:VaderCrabStruct::State, y
cmp #STATE_WALKING
bne Done
lda #WALK_ANIM_SPEED
sta a:VaderCrabStruct::Walk_Anim_Speed, y
bra Done
RestFrameUpdate:
lda a:VaderCrabStruct::Resting_Timer, y
sec
sbc #1
sta a:VaderCrabStruct::Resting_Timer, y
sty z:DP_ENEMY_STRUCT_PTR
jsr rand
and #$10
beq @VoltaRest
ldy z:DP_ENEMY_STRUCT_PTR
lda #STATE_RESTING
sta a:VaderCrabStruct::State, y
bra Done
@VoltaRest:
ldy z:DP_ENEMY_STRUCT_PTR
brl RestFrameUpdate
Done:
jsr UpdateVaderGeometry
rts
.endproc
.proc UpdateVaderGeometry
lda a:VaderCrabStruct::X_Pos, y
sta a:VaderCrabStruct::Hurtbox_X1, y
clc
adc #48
sta a:VaderCrabStruct::Hurtbox_X2, y
lda a:VaderCrabStruct::Y_Pos, y
sta a:VaderCrabStruct::Hurtbox_Y1, y
clc
adc #64
sta a:VaderCrabStruct::Hurtbox_Y2, y
rts
.endproc
; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO VADERCRAB
; =============================================================================
VaderCrab_Layout:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
VaderCrab_Layout_Frame1:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$48,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
VaderCrab_Layout_Hurt:
.byte 0,  10,$00,$01, 16,  10,$02,$01, 32,  10,$04,$01, 48,  10,$00,$01
.byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
VaderCrab_Layout_FramePreparing0:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
VaderCrab_Layout_FramePreparing1:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
VaderCrab_Layout_FramePreparing2:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$80,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
VaderCrab_Layout_FrameAttacking0:
.byte 0,  0,$00,$01, 16,  0,$0A,$01, 32,  0,$0C,$01, 48,  0,$00,$01
.byte 0, 16,$80,$01, 16, 16,$2A,$01, 32, 16,$2C,$01, 48, 16,$20,$01
.byte 0, 32,$A0,$31, 16, 32,$A2,$31, 32, 32,$A4,$31, 48, 32,$A6,$31
.byte 0, 48,$C0,$31, 16, 48,$C2,$31, 32, 48,$C4,$31, 48, 48,$C6,$31
VaderCrab_Layout_FrameAttacking1:
.byte 0,  0,$00,$01, 16,  0,$0A,$01, 32,  0,$0C,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$2A,$01, 32, 16,$2C,$01, 48, 16,$8E,$01
.byte 0, 32,$A8,$01, 16, 32,$AA,$01, 32, 32,$AC,$01, 48, 32,$AE,$01
.byte 0, 48,$C8,$01, 16, 48,$CA,$01, 32, 48,$CC,$01, 48, 48,$CE,$01
; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO RAPACRAB
; =============================================================================
RapaCrab_Layout:
.byte 0,  0,$00,$01, 16,  0,$06,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$20,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaCrab_Layout_Frame1:
.byte 0,  0,$00,$01, 16,  0,$06,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$20,$01
.byte 0, 32,$48,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
RapaCrab_Layout_Hurt:
.byte 0,  10,$00,$01, 16,  10,$06,$01, 32,  10,$04,$01, 48,  10,$00,$01
.byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
RapaCrab_Layout_FramePreparing0:
.byte 0,  0,$00,$01, 16,  0,$06,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$20,$01
.byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
RapaCrab_Layout_FramePreparing1:
.byte 0,  0,$00,$01, 16,  0,$06,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
RapaCrab_Layout_FramePreparing2:
.byte 0,  0,$00,$01, 16,  0,$06,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$80,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$20,$01
.byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
RapaCrab_Layout_FrameAttacking0:
.byte 0,  0,$00,$01, 16,  0,$06,$01, 32,  0,$0C,$01, 48,  0,$00,$01
.byte 0, 16,$80,$01, 16, 16,$2A,$01, 32, 16,$2C,$01, 48, 16,$20,$01
.byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
RapaCrab_Layout_FrameAttacking1:
.byte 0,  0,$00,$01, 16,  0,$06,$01, 32,  0,$0C,$01, 48,  0,$00,$01
.byte 0, 16,$20,$01, 16, 16,$2A,$01, 32, 16,$2C,$01, 48, 16,$8E,$01
.byte 0, 32,$A8,$01, 16, 32,$AA,$01, 32, 32,$AC,$01, 48, 32,$AE,$01
.byte 0, 48,$C8,$01, 16, 48,$CA,$01, 32, 48,$CC,$01, 48, 48,$CE,$01
; --- Tabelas de Animação de 16-bit ---
Vader_Animation_Table:
.word .loword(VaderCrab_Layout)
.word .loword(VaderCrab_Layout_Frame1)
.word .loword(VaderCrab_Layout_Hurt)
.word .loword(VaderCrab_Layout_FramePreparing0)
.word .loword(VaderCrab_Layout_FramePreparing1)
.word .loword(VaderCrab_Layout_FramePreparing2)
.word .loword(VaderCrab_Layout_FrameAttacking0)
.word .loword(VaderCrab_Layout_FrameAttacking1)
Rapa_Animation_Table:
.word .loword(RapaCrab_Layout)
.word .loword(RapaCrab_Layout_Frame1)
.word .loword(RapaCrab_Layout_Hurt)
.word .loword(RapaCrab_Layout_FramePreparing0)
.word .loword(RapaCrab_Layout_FramePreparing1)
.word .loword(RapaCrab_Layout_FramePreparing2)
.word .loword(RapaCrab_Layout_FrameAttacking0)
.word .loword(RapaCrab_Layout_FrameAttacking1)
Enemy_Master_Animation_Table:
.word .loword(Vader_Animation_Table)
.word .loword(Rapa_Animation_Table)
;-------------------------------------------------------------------------------
;   DrawVaderCrab
;-------------------------------------------------------------------------------
.proc DrawVaderCrab
rep #$20
.a16
lda 3,s
tay
sep #$20
.a8
.i16
lda a:VaderCrabStruct::X_Pos, y
sta z:DP_TEMP_01
lda a:VaderCrabStruct::Y_Pos, y
sta z:DP_TEMP_02
lda a:VaderCrabStruct::Facing, y
sta z:DP_TEMP_03
lda a:VaderCrabStruct::HurtTimer, y
beq @CheckStates
lda #4
bra @ResolvePointer
@CheckStates:
lda a:VaderCrabStruct::State, y
cmp #STATE_PREPARING
bne @CheckAttacking
lda a:VaderCrabStruct::Preparing_Anim_Frame, y
cmp #1
beq @Prep1
cmp #2
beq @Prep2
@Prep0:
lda #6
bra @ResolvePointer
@Prep1:
lda #8
bra @ResolvePointer
@Prep2:
lda #10
bra @ResolvePointer
@CheckAttacking:
cmp #STATE_ATACKING
bne @CheckWalking
lda a:VaderCrabStruct::Attacking_Anim_Frame, y
bne @Attack1
@Attack0:
lda #12
bra @ResolvePointer
@Attack1:
lda #14
bra @ResolvePointer
@CheckWalking:
lda a:VaderCrabStruct::Anim_Frame, y
bne @Walk1
@Walk0:
lda #0
bra @ResolvePointer
@Walk1:
lda #2
@ResolvePointer:
sta z:DP_TEMP_00
lda a:VaderCrabStruct::Enemy_Type, y
cmp #1
beq @ChaveiaRapa
@ChaveiaVader:
ldy #.loword(Vader_Animation_Table)
sty z:DP_ENEMY_STRUCT_PTR
bra @BuscaLayout
@ChaveiaRapa:
ldy #.loword(Rapa_Animation_Table)
sty z:DP_ENEMY_STRUCT_PTR
@BuscaLayout:
lda #$00
sta z:DP_ENEMY_STRUCT_PTR+2
sta z:DP_VADER_LAYOUT_PTR+2
ldy #0
lda z:DP_TEMP_00
clc
adc z:DP_ENEMY_STRUCT_PTR
sta z:DP_TEMP_CALC
lda z:DP_ENEMY_STRUCT_PTR+1
adc #0
sta z:DP_TEMP_CALC+1
lda [DP_TEMP_CALC], y
sta z:DP_VADER_LAYOUT_PTR
iny
lda [DP_TEMP_CALC], y
sta z:DP_VADER_LAYOUT_PTR+1
jsr RenderVaderSprites
rts
.endproc
;-------------------------------------------------------------------------------
;   RenderVaderSprites
;-------------------------------------------------------------------------------
.proc RenderVaderSprites
ldy #$0000
@DrawLoop:
lda #$00
sta z:DP_VADER_LAYOUT_PTR+2
lda z:DP_TEMP_03
bne @DrawXNormal
@DrawXInverted:
lda #48
sec
sbc [DP_VADER_LAYOUT_PTR], y
clc
adc z:DP_TEMP_01
sta OAMMIRROR, x
bra @ProcessY
@DrawXNormal:
lda [DP_VADER_LAYOUT_PTR], y
clc
adc z:DP_TEMP_01
sta OAMMIRROR, x
@ProcessY:
inx
iny
lda [DP_VADER_LAYOUT_PTR], y
clc
adc z:DP_TEMP_02
sta OAMMIRROR, x
inx
iny
lda [DP_VADER_LAYOUT_PTR], y
sta OAMMIRROR, x
inx
iny
lda [DP_VADER_LAYOUT_PTR], y
sta z:DP_TEMP_00
lda z:DP_TEMP_03
bne @NoFlip
lda z:DP_TEMP_00
eor #%01000000
sta z:DP_TEMP_00
@NoFlip:
lda z:DP_TEMP_00
sta OAMMIRROR, x
inx
iny
cpy #64
bne @DrawLoop
rts
.endproc
;-------------------------------------------------------------------------------
;   DrawVaderHitboxDebug
;-------------------------------------------------------------------------------
.proc DrawVaderHitboxDebug
@Desenhar:
lda VaderCrab + VaderCrabStruct::Hitbox_X1
sta a:OAMMIRROR, X
inx
lda VaderCrab + VaderCrabStruct::Hitbox_Y1
sta a:OAMMIRROR, X
inx
lda #$A0
sta a:OAMMIRROR, X
inx
lda #$31
sta a:OAMMIRROR, X
inx
lda VaderCrab + VaderCrabStruct::Hitbox_X2
sta a:OAMMIRROR, X
inx
lda VaderCrab + VaderCrabStruct::Hitbox_Y2
sta a:OAMMIRROR, X
inx
lda #$A2
sta a:OAMMIRROR, X
inx
lda #$31
sta OAMMIRROR, X
inx
rts
.endproc