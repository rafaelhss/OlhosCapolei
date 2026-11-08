; -----------------------------------------------------------------------------
;   File: VaderCrab.s (VERSÃO REVISADA SEM RANGE ERROR - CA65)
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

DP_DRAW_ENEMY_TYPE = $10

.segment "CODE"

;===============================================================================
;   SISTEMA DE MOVIMENTAÇÃO (IA E FÍSICA)
;===============================================================================

;-------------------------------------------------------------------------------
;   MoveVaderCrab - ORQUESTRADOR PRINCIPAL
;-------------------------------------------------------------------------------
.proc MoveVaderCrab
        rep #$20                        
        .a16
        lda 3,s                         
        tay                             
        sep #$20                        
        .a8

        ; Verifica se o inimigo está em animação de dano (Hurt)
        lda a:VaderCrabStruct::HurtTimer, y
        beq @ProcessIA                  
        
        sec
        sbc #1
        sta a:VaderCrabStruct::HurtTimer, y
        brl @Done   

@ProcessIA:
        ; --- RASTREAMENTO DINÂMICO DE FACING DURANTE O PREPARO ---
        lda a:VaderCrabStruct::State, y
        cmp #STATE_PREPARING            
        bne @AvaliaEstados              
        
        lda a:VaderCrabStruct::X_Pos, y
        cmp BigHero + BigHeroStruct::X_Pos
        bcc @OlhaDireitaPreparo

@OlhaEsquerdaPreparo:
        lda #0
        sta a:VaderCrabStruct::Facing, y
        bra @AvaliaEstados

@OlhaDireitaPreparo:
        lda #1
        sta a:VaderCrabStruct::Facing, y

@AvaliaEstados:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_ATACKING
        bne @CheckPreparing
        jsr UpdateAttackingState
        bra @ApplyMovement

@CheckPreparing:
        cmp #STATE_PREPARING
        bne @CheckResting
        jsr UpdatePreparingState
        bra @ApplyMovement

@CheckResting:
        ; Se o cronômetro de descanso estiver ativo, processa o repouso
        lda a:VaderCrabStruct::Resting_Timer, y
        sec
        sbc #1
        sta a:VaderCrabStruct::Resting_Timer, y
        bpl @ProcessResting

        ; --- QUEBRA DE DEADLOCK: O tempo de descanso acabou! ---
        ; Se o estado ainda for STATE_RESTING, força a volta para STATE_WALKING
        lda a:VaderCrabStruct::State, y
        cmp #STATE_RESTING
        bne @SegueFluxoCaminhada
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y

@SegueFluxoCaminhada:
        ; Processa animação de caminhada padrão
        lda a:VaderCrabStruct::State, y
        cmp #STATE_WALKING
        bne @ApplyMovement
        
        jsr UpdateWalkAnimation
        bra @ApplyMovement

@ProcessResting:
        jsr UpdateRestingState

@ApplyMovement:
        ; Bloqueia alteração de física/posição enquanto golpeia ou descansa
        lda a:VaderCrabStruct::State, y
        cmp #STATE_ATACKING
        beq @Done
        cmp #STATE_RESTING              
        beq @Done
        
        lda FrameCounter
        and #%00000001
        beq @ExecutePhysics
        bra @Done

@ExecutePhysics:
        jsr ApplyEnemyPhysics

@Done:
        jsr UpdateVaderGeometry
        rts
.endproc

;-------------------------------------------------------------------------------
.proc UpdateAttackingState
        lda a:VaderCrabStruct::Attacking_Timer, y
        clc
        adc #1
        sta a:VaderCrabStruct::Attacking_Timer, y
        cmp #ATTACKING_DURATION_FRAMES
        bne @Anim

        ; Fim do Golpe: Sanitização Atômica e Chamada de Descanso
        lda #0
        sta a:VaderCrabStruct::Hitbox_Active, y  
        sta a:VaderCrabStruct::Attacking_Timer, y
        sta a:VaderCrabStruct::Attacking_Anim_Frame, y
        sta a:VaderCrabStruct::Attacking_Anim_Timer, y
        sta a:VaderCrabStruct::Preparing_Timer, y
        sta a:VaderCrabStruct::Preparing_Anim_Frame, y
        sta a:VaderCrabStruct::Preparing_Anim_Timer, y

        lda #STATE_RESTING              
        sta a:VaderCrabStruct::State, y
        
        ;Rest_time
        jsr rand                        
        and #$3F                        
        clc
        adc #30                         
        sta a:VaderCrabStruct::Resting_Timer, y
        rts

@Anim:
        lda a:VaderCrabStruct::Attacking_Anim_Timer, y
        sec
        sbc #1
        sta a:VaderCrabStruct::Attacking_Anim_Timer, y
        bne @Done

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

        CMP #1
        beq @AtivarHitbox
        
        lda #0
        sta a:VaderCrabStruct::Hitbox_Active, y
        bra @Done

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
        bra @Done

@HitboxDireitaAtaque:
        lda a:VaderCrabStruct::X_Pos, y
        clc
        adc #64                             
        sta a:VaderCrabStruct::Hitbox_X1, y
        clc
        adc #32                             
        sta a:VaderCrabStruct::Hitbox_X2, y
@Done:
        rts
.endproc

;-------------------------------------------------------------------------------
.proc UpdatePreparingState
        lda a:VaderCrabStruct::Preparing_Timer, y
        clc
        adc #1
        sta a:VaderCrabStruct::Preparing_Timer, y
        cmp #PREPARING_DURATION_FRAMES
        bne @Anim
 
        lda #STATE_ATACKING
        sta a:VaderCrabStruct::State, y
        lda #0
        sta a:VaderCrabStruct::Preparing_Timer, y
        sta a:VaderCrabStruct::Attacking_Anim_Frame, y 
        sta a:VaderCrabStruct::Attacking_Timer, y
        
        lda #ATTACKING_ANIM_SPEED
        sta a:VaderCrabStruct::Attacking_Anim_Timer, y
        rts

@Anim:
        lda a:VaderCrabStruct::Preparing_Anim_Timer, y
        sec
        sbc #1
        sta a:VaderCrabStruct::Preparing_Anim_Timer, y
        bne @Done 

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
@Done:
        rts
.endproc

;-------------------------------------------------------------------------------
.proc UpdateWalkAnimation
        lda a:VaderCrabStruct::Anim_Timer, y
        sec
        sbc #1
        sta a:VaderCrabStruct::Anim_Timer, y
        bne @Done 
        
        lda #WALK_ANIM_SPEED 
        sta a:VaderCrabStruct::Anim_Timer, y
        
        lda a:VaderCrabStruct::Anim_Frame, y
        eor #$01 
        sta a:VaderCrabStruct::Anim_Frame, y
@Done:
        rts
.endproc

;-------------------------------------------------------------------------------
.proc UpdateRestingState
        lda #STATE_RESTING
        sta a:VaderCrabStruct::State, y
        rts
.endproc

;-------------------------------------------------------------------------------
;   ApplyEnemyPhysics - INTELEGÊNCIA DE FILTRO E EVASÃO DE CORPO
;-------------------------------------------------------------------------------
.proc ApplyEnemyPhysics
        sty z:DP_ENEMY_STRUCT_PTR

        lda a:VaderCrabStruct::State, y
        cmp #STATE_RESTING
        bne @Continue
        jmp @AbortaFisica

@Continue:
        lda a:VaderCrabStruct::Attack_Sector, y
        cmp #0                          
        beq @SetorSupDireito
        cmp #1                          
        beq @SetorSupEsquerdo
        cmp #2                          
        beq @SetorInfDireito

@SetorInfEsquerdo:
        lda BigHero + BigHeroStruct::X_Pos
        sec
        sbc #SECTOR_OFFSET_X
        sta z:DP_TEMP_04                
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #SECTOR_OFFSET_Y
        sta z:DP_TEMP_05                
        bra @ProcessaPerseguicao

@SetorSupDireito:
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #SECTOR_OFFSET_X
        sta z:DP_TEMP_04
        lda BigHero + BigHeroStruct::Y_Pos
        sec
        sbc #SECTOR_OFFSET_Y
        sta z:DP_TEMP_05
        bra @ProcessaPerseguicao

@SetorSupEsquerdo:
        lda BigHero + BigHeroStruct::X_Pos
        sec
        sbc #SECTOR_OFFSET_X
        sta z:DP_TEMP_04
        lda BigHero + BigHeroStruct::Y_Pos
        sec
        sbc #SECTOR_OFFSET_Y
        sta z:DP_TEMP_05
        bra @ProcessaPerseguicao

@SetorInfDireito:
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #SECTOR_OFFSET_X
        sta z:DP_TEMP_04
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #SECTOR_OFFSET_Y
        sta z:DP_TEMP_05

@ProcessaPerseguicao:
        ldy z:DP_ENEMY_STRUCT_PTR
        lda a:VaderCrabStruct::X_Pos, y
        sec
        sbc BigHero + BigHeroStruct::X_Pos
        bcs @AbsCorpoX
        eor #$FF
        clc
        adc #1
@AbsCorpoX:
        cmp #24
        bcs @FisicaNormal

        lda a:VaderCrabStruct::Y_Pos, y
        sec
        sbc BigHero + BigHeroStruct::Y_Pos
        bcs @AvaliaInimigoAbaixo
        eor #$FF
        clc
        adc #1
@AvaliaInimigoAbaixo:
        cmp #16
        bcs @FisicaNormal

        lda a:VaderCrabStruct::Y_Pos, y
        cmp BigHero + BigHeroStruct::Y_Pos
        bcs @ContornarPorCima
@ContornarPorBaixo:
        lda a:VaderCrabStruct::Y_Pos, y
        clc
        adc #WALK_SPEED
        sta a:VaderCrabStruct::Y_Pos, y
        bra @AplicaMovimentoX

@ContornarPorCima:
        lda a:VaderCrabStruct::Y_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:VaderCrabStruct::Y_Pos, y

@AplicaMovimentoX:
        lda a:VaderCrabStruct::X_Pos, y
        cmp z:DP_TEMP_04
        bcc @EvasaoDireita

@EvasaoEsquerda:
        lda a:VaderCrabStruct::X_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:VaderCrabStruct::X_Pos, y
        lda #0
        sta a:VaderCrabStruct::Facing, y
        brl @FinalizaEvasao              ; Mudado para BRL longo
@EvasaoDireita:
        lda a:VaderCrabStruct::X_Pos, y
        clc
        adc #WALK_SPEED
        sta a:VaderCrabStruct::X_Pos, y
        lda #1
        sta a:VaderCrabStruct::Facing, y

@FinalizaEvasao:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_WALKING
        beq @JumpFimEixoX
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
@JumpFimEixoX:
        brl @CheckFimEixoX              ; Mudado para BRL longo

@FisicaNormal:
        lda a:VaderCrabStruct::X_Pos, y
        sec
        sbc z:DP_TEMP_04
        bcs @CalcAbsX
        eor #$FF
        clc
        adc #1
@CalcAbsX:
        cmp #ENEMY_ATTACK_DISTANCE
        bcc @StopHorizontal

        lda a:VaderCrabStruct::X_Pos, y
        cmp z:DP_TEMP_04
        bcc @WalkRight

@WalkLeft:
        lda a:VaderCrabStruct::X_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:VaderCrabStruct::X_Pos, y
        lda #0
        sta a:VaderCrabStruct::Facing, y

        lda a:VaderCrabStruct::State, y
        cmp #STATE_WALKING
        beq @JumpCheckVertical
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
@JumpCheckVertical:
        jmp @CheckVertical              

@WalkRight:
        lda a:VaderCrabStruct::X_Pos, y
        clc
        adc #WALK_SPEED
        sta a:VaderCrabStruct::X_Pos, y
        lda #1
        sta a:VaderCrabStruct::Facing, y

        lda a:VaderCrabStruct::State, y
        cmp #STATE_WALKING
        beq @JumpCheckVertical2
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
@JumpCheckVertical2:
        jmp @CheckVertical              

@StopHorizontal:
        lda #STATE_PREPARING
        sta a:VaderCrabStruct::State, y

@CheckVertical:
        lda a:VaderCrabStruct::Y_Pos, y
        sec
        sbc z:DP_TEMP_05
        bcs @CalcAbsY
        eor #$FF
        clc
        adc #1
@CalcAbsY:
        cmp #ENEMY_ATTACK_Y_RANGE
        bcc @StopVertical

        lda a:VaderCrabStruct::Y_Pos, y
        cmp z:DP_TEMP_05
        bcc @MoveDown
@MoveUp:
        lda a:VaderCrabStruct::Y_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:VaderCrabStruct::Y_Pos, y

        lda a:VaderCrabStruct::State, y
        cmp #STATE_WALKING
        beq @JumpFim1
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
@JumpFim1:
        brl @CheckFimEixoX              ; Mudado para BRL Longo (Mata o erro da linha 415)

@MoveDown:
        lda a:VaderCrabStruct::Y_Pos, y
        clc
        adc #WALK_SPEED
        sta a:VaderCrabStruct::Y_Pos, y

        lda a:VaderCrabStruct::State, y
        cmp #STATE_WALKING
        beq @JumpFim2
        lda #STATE_WALKING
        sta a:VaderCrabStruct::State, y
@JumpFim2:
        brl @CheckFimEixoX              ; Mudado para BRL Longo (Mata o erro da linha 418)

@StopVertical:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_PREPARING
        bne @CheckFimEixoX

@CheckFimEixoX:
@AbortaFisica:
        rts
.endproc

;-------------------------------------------------------------------------------
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
        jsr ResolveAnimationFrame
        sta z:DP_TEMP_00
        jsr GetAnimationTablePointer
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
        lda #$00
        sta z:DP_TEMP_CALC+2
        lda [DP_TEMP_CALC], y
        sta z:DP_VADER_LAYOUT_PTR
        iny
        lda [DP_TEMP_CALC], y
        sta z:DP_VADER_LAYOUT_PTR+1
        jsr RenderVaderSprites
        rts
.endproc

.proc ResolveAnimationFrame
        lda a:VaderCrabStruct::HurtTimer, y
        beq @CheckStates
        lda #4
        rts
@CheckStates:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_RESTING              
        beq @Walk0
        cmp #STATE_PREPARING
        bne @CheckAttacking
        lda a:VaderCrabStruct::Preparing_Anim_Frame, y
        cmp #1
        beq @Prep1
        cmp #2
        beq @Prep2
@Prep0: lda #6
        rts
@Prep1: lda #8
        rts
@Prep2: lda #10
        rts
@CheckAttacking:
        cmp #STATE_ATACKING
        bne @CheckWalking
        lda a:VaderCrabStruct::Attacking_Anim_Frame, y
        bne @Attack1
@Attack0: lda #12
        rts
@Attack1: lda #14
        rts
@CheckWalking:
        lda a:VaderCrabStruct::Anim_Frame, y
        bne @Walk1
@Walk0: lda #0
        rts
@Walk1: lda #2
        rts
.endproc

.proc GetAnimationTablePointer
        lda a:VaderCrabStruct::Enemy_Type, y
        cmp #1
        beq @ChaveiaRapa
@ChaveiaVader:
        ldy #.loword(Vader_Animation_Table)
        sty z:DP_ENEMY_STRUCT_PTR
        rts
@ChaveiaRapa:
        ldy #.loword(Rapa_Animation_Table)
        sty z:DP_ENEMY_STRUCT_PTR
        rts
.endproc


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

.proc DrawVaderHitboxDebug
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
.byte 30, 18,$EA,$01, 46,  18,$EC,$01, 16,  0,$06,$01, 30,  0,$08,$01
.byte 0, 16,$20,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$20,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaCrab_Layout_Frame1:
.byte 30, 18,$EA,$01, 46,  18,$EC,$01, 16,  0,$06,$01, 30,  0,$08,$01
.byte 0, 16,$20,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$20,$01
.byte 0, 32,$48,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
RapaCrab_Layout_Hurt:
.byte 30, 26,$EA,$01, 46,  26,$EC,$01, 16,  8,$06,$01, 30,  8,$08,$01
.byte 0, 24,$20,$01, 16, 24,$26,$01, 32, 24,$28,$01, 48, 24,$20,$01
.byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
RapaCrab_Layout_FramePreparing0:
.byte 27, 18,$EA,$01, 43,  18,$EC,$01, 13,  0,$06,$01, 27,  0,$08,$01
.byte <(-3), 16,$20,$01, 13, 16,$26,$01, 29, 16,$28,$01, 45, 16,$20,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaCrab_Layout_FramePreparing1:
.byte 30, 18,$EA,$01, 46,  18,$EC,$01, 16,  0,$06,$01, 30,  0,$08,$01
.byte 0, 16,$20,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$20,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaCrab_Layout_FramePreparing2:
.byte 24, 18,$EA,$01, 40,  18,$EC,$01, 10,  0,$06,$01, 24,  0,$08,$01
.byte <(-6), 16,$00,$01, 10, 16,$26,$01, 26, 16,$28,$01, 42, 16,$20,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaCrab_Layout_FrameAttacking0:
.byte 33, 18,$EA,$01, 49,  18,$EC,$01, 19,  0,$06,$01, 33,  0,$08,$01
.byte 3, 16,$00,$01, 19, 16,$26,$01, 35, 16,$28,$01, 51, 16,$20,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaCrab_Layout_FrameAttacking1:
.byte 36, 18,$EA,$01, 52,  18,$EC,$01, 19,  0,$06,$01, 33,  0,$08,$01
.byte 3, 16,$00,$01, 19, 16,$26,$01, 35, 16,$28,$01, 51, 16,$20,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01

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

