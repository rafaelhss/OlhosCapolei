.export     MoveMeleeCrab
.export     DrawMeleeCrab
.export    UpdateTargetSector

.p816
.a8
.i16

.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Util.inc"

WALK_SPEED = $01
WALK_ANIM_SPEED = $08 

PREPARING_ANIM_SPEED = 10
PREPARING_DURATION_FRAMES = 30
PREPARING_MAX_FRAMES = 3

ATTACKING_ANIM_SPEED = 15   
ATTACKING_DURATION_FRAMES = 45
ATTACK_MAX_FRAMES = 2  


ENEMY_ATTACK_DISTANCE = $1   ; Distância de engajamento do ataque da IA. Com  introduçao do Setor de Ataque, esse valor perdeu sentido.  
ENEMY_ATTACK_Y_RANGE  = $08   ; Tolerância no eixo Y para alinhamento tridimensional

ENEMY_HURTBOX_WIDTH  = $10
ENEMY_HURTBOX_HEIGHT = $20      

.import BigHero
.import FrameCounter
.import MeleeCrab

;-------------------------------------------------------------------------------
;   MoveMeleeCrab - ORQUESTRADOR PRINCIPAL
;-------------------------------------------------------------------------------
.proc MoveMeleeCrab
        ;Recupera o índice do inimigo na pilha
        rep #$20                        
        .a16
        lda 3,s                         
        tay                             
        sep #$20                        
        .a8


        LDA a:MeleeCrabStruct::State, y
        CMP #STATE_DEAD
        bne @CheckDying
        rts                 ; Morto: sai imediatamente sem atualizar física ou hurtbox!

@CheckDying:
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_DYING
        bne CheckHurt
        jsr UpdateDyingState
        rts                 ; Enquanto morre, não executa IA nem atualiza hurtbox
       

CheckHurt:
        ; Verifica se o inimigo está em animação de dano (Hurt)
        lda a:MeleeCrabStruct::HurtTimer, y
        beq @ProcessIA                  
        

        ; Se estiver em dano, decrementa o timer de dano com segurança
        sec
        sbc #1
        sta a:MeleeCrabStruct::HurtTimer, y
        brl Done   

@ProcessIA:
        ; --- RASTREAMENTO DINÂMICO DE FACING DURANTE O PREPARO [ eu acho que isso nao tinha que ser feito aqui e sim no UpdatePreparingState...]---
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_PREPARING            
        bne @AvaliaEstados              
        
        lda a:MeleeCrabStruct::X_Pos, y
        cmp BigHero + BigHeroStruct::X_Pos
        bcc @OlhaDireitaPreparo

@OlhaEsquerdaPreparo:
        lda #0
        sta a:MeleeCrabStruct::Facing, y
        bra @AvaliaEstados

@OlhaDireitaPreparo:
        lda #1
        sta a:MeleeCrabStruct::Facing, y

@AvaliaEstados:
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_ATACKING
        bne @CheckPreparing  ;Se nao esta atacando, verifica se está preparando
        jsr UpdateAttackingState ;Esta atacando, atualiza o estado de ataque
        bra Done ;Apos atualizar o estado de ataque, fim

@CheckPreparing:
        cmp #STATE_PREPARING
        bne @CheckResting ;Se nao esta preparando, verifica se está descansando
        jsr UpdatePreparingState ;Esta preparando, atualiza o estado de preparo
        bra Done ;Apos atualizar o estado de preparo, fim

@CheckResting:
        ; Verifica primeiro se o timer já zerou para evitar underflow cíclico
        lda a:MeleeCrabStruct::Resting_Timer, y
        beq @RestingFim                ; Se já for 0, o descanso acabou

        ; Decrementa o timer de descanso com segurança
        sec
        sbc #1
        sta a:MeleeCrabStruct::Resting_Timer, y
        bra @ProcessResting            ; Enquanto for maior que 0, processa o repouso

@RestingFim:
        ; --- QUEBRA DE DEADLOCK: O tempo de descanso acabou! ---
        ; Se o estado ainda for STATE_RESTING, força a volta para STATE_WALKING
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_RESTING
        bne @SegueFluxoCaminhada
        lda #STATE_WALKING
        sta a:MeleeCrabStruct::State, y ;Nao vale a pena atualizar sem checar antes por que atualizar é caro no hardware, entao so atualiza se for necessario
        ; Se é o fim do descanso, vamos caminhar. Segue automaticamente para @SegueFluxoCaminhada

@SegueFluxoCaminhada:
        ; Processa animação de caminhada padrão
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_WALKING
        bne Done ;Se nao estiver caminhando, Sai Fora.
        
        jsr UpdateWalkAnimation
        bra @ExecuteMovement

@ProcessResting:
        JSR UpdateRestingState
        ; Depois de atualizar o estado de descanso, fim


; ExecuteMovement: Aplica movimentação e física do inimigo caminhando. Atacando, preparando ou descansando nao entra aqui.
@ExecuteMovement:
        jsr ApplyEnemyMovement

Done:
        jsr UpdateMeleeCrabGeometry
        rts
.endproc

.proc UpdateRestingState
        lda #STATE_RESTING
        sta a:MeleeCrabStruct::State, y
        rts
.endproc



DYING_DURATION_FRAMES = 45
DYING_ANIM_SPEED      = 15
DYING_MAX_FRAMES      = 2

.proc UpdateDyingState
        ; 1. Timer total da morte
        lda a:MeleeCrabStruct::Dying_Timer, y
        clc
        adc #1
        sta a:MeleeCrabStruct::Dying_Timer, y
        cmp #DYING_DURATION_FRAMES
        bne @Anim

        ; Acabou o tempo de morte -> Transiciona para DEAD definitivo
        lda #STATE_DEAD
        sta a:MeleeCrabStruct::State, y
        rts

@Anim:
        ; 2. Timer de troca de frame da animação de morte
        lda a:MeleeCrabStruct::Dying_Anim_Timer, y
        sec
        sbc #1
        sta a:MeleeCrabStruct::Dying_Anim_Timer, y
        bne @Done

        lda #DYING_ANIM_SPEED
        sta a:MeleeCrabStruct::Dying_Anim_Timer, y

        lda a:MeleeCrabStruct::Dying_Anim_Frame, y
        clc
        adc #1
        cmp #DYING_MAX_FRAMES
        bcc @SaveFrame
        lda #0                          ; Alterna entre frame 0 e 1 (ou trave no último)
@SaveFrame:
        sta a:MeleeCrabStruct::Dying_Anim_Frame, y
@Done:
        rts
.endproc



.proc UpdateWalkAnimation
        lda a:MeleeCrabStruct::Anim_Timer, y
        sec
        sbc #1
        sta a:MeleeCrabStruct::Anim_Timer, y
        bne @Done 
        
        lda #WALK_ANIM_SPEED 
        sta a:MeleeCrabStruct::Anim_Timer, y
        
        ;TODO perguntar pra IA o que ta acontecendo aqui.
        lda a:MeleeCrabStruct::Anim_Frame, y 
        eor #$01 
        sta a:MeleeCrabStruct::Anim_Frame, y
@Done:
        rts
.endproc


; Define a hurtbox do inimigo MeleeCrab com base na posição atual
.proc UpdateMeleeCrabGeometry
        lda a:MeleeCrabStruct::X_Pos, y
        sta a:MeleeCrabStruct::Hurtbox_X1, y
        clc
        adc #48
        sta a:MeleeCrabStruct::Hurtbox_X2, y
        lda a:MeleeCrabStruct::Y_Pos, y
        sta a:MeleeCrabStruct::Hurtbox_Y1, y
        clc
        adc #64
        sta a:MeleeCrabStruct::Hurtbox_Y2, y
        rts
.endproc


.proc UpdatePreparingState
        lda a:MeleeCrabStruct::Preparing_Timer, y
        clc
        adc #1
        sta a:MeleeCrabStruct::Preparing_Timer, y
        cmp #PREPARING_DURATION_FRAMES
        bne @Anim
 
        lda #STATE_ATACKING
        sta a:MeleeCrabStruct::State, y
        lda #0
        sta a:MeleeCrabStruct::Preparing_Timer, y
        sta a:MeleeCrabStruct::Attacking_Anim_Frame, y 
        sta a:MeleeCrabStruct::Attacking_Timer, y
        
        lda #ATTACKING_ANIM_SPEED
        sta a:MeleeCrabStruct::Attacking_Anim_Timer, y
        rts

@Anim:
        lda a:MeleeCrabStruct::Preparing_Anim_Timer, y
        sec
        sbc #1
        sta a:MeleeCrabStruct::Preparing_Anim_Timer, y
        bne @Done 

        lda #PREPARING_ANIM_SPEED 
        sta a:MeleeCrabStruct::Preparing_Anim_Timer, y
        
        lda a:MeleeCrabStruct::Preparing_Anim_Frame, y
        clc
        adc #1                          
        cmp #PREPARING_MAX_FRAMES          
        bcc @SaveFramePrep                  
        lda #0                          
@SaveFramePrep:
        sta a:MeleeCrabStruct::Preparing_Anim_Frame, y
@Done:
        rts
.endproc


.proc UpdateAttackingState
        lda a:MeleeCrabStruct::Attacking_Timer, y
        clc
        adc #1
        sta a:MeleeCrabStruct::Attacking_Timer, y
        cmp #ATTACKING_DURATION_FRAMES
        bne @Anim

        ; Fim do Golpe: Sanitização Atômica e Chamada de preparing
        lda #0
        sta a:MeleeCrabStruct::Hitbox_Active, y  
        sta a:MeleeCrabStruct::Attacking_Timer, y
        sta a:MeleeCrabStruct::Attacking_Anim_Frame, y
        sta a:MeleeCrabStruct::Attacking_Anim_Timer, y
        sta a:MeleeCrabStruct::Preparing_Timer, y
        sta a:MeleeCrabStruct::Preparing_Anim_Frame, y
        sta a:MeleeCrabStruct::Preparing_Anim_Timer, y

        lda #STATE_WALKING              
        sta a:MeleeCrabStruct::State, y
        rts

@Anim:
        lda a:MeleeCrabStruct::Attacking_Anim_Timer, y
        sec
        sbc #1
        sta a:MeleeCrabStruct::Attacking_Anim_Timer, y
        bne @Done

        lda #ATTACKING_ANIM_SPEED 
        sta a:MeleeCrabStruct::Attacking_Anim_Timer, y
        
        lda a:MeleeCrabStruct::Attacking_Anim_Frame, y
        clc
        adc #1                          
        cmp #ATTACK_MAX_FRAMES          
        bcc @SaveFrame                  
        lda #0                          
@SaveFrame:
        sta a:MeleeCrabStruct::Attacking_Anim_Frame, y

        CMP #1
        beq @AtivarHitbox
        
        lda #0
        sta a:MeleeCrabStruct::Hitbox_Active, y
        bra @Done

@AtivarHitbox:
        lda #1
        sta a:MeleeCrabStruct::Hitbox_Active, y

        lda a:MeleeCrabStruct::Y_Pos, y
        clc
        adc #16                             
        sta a:MeleeCrabStruct::Hitbox_Y1, y
        clc
        adc #ENEMY_HURTBOX_HEIGHT                             
        sta a:MeleeCrabStruct::Hitbox_Y2, y

        lda a:MeleeCrabStruct::Facing, y
        bne @HitboxDireitaAtaque                  

@HitboxEsquerdaAtaque:
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc #ENEMY_HURTBOX_WIDTH                            
        sta a:MeleeCrabStruct::Hitbox_X1, y
        lda a:MeleeCrabStruct::X_Pos, y 
        sta a:MeleeCrabStruct::Hitbox_X2, y
        bra @Done

@HitboxDireitaAtaque:
        lda a:MeleeCrabStruct::X_Pos, y
        clc
        adc #64                             
        sta a:MeleeCrabStruct::Hitbox_X1, y
        clc
        adc #ENEMY_HURTBOX_WIDTH                             
        sta a:MeleeCrabStruct::Hitbox_X2, y
@Done:
        rts
.endproc

;-------------------------------------------------------------------------------
;   ApplyEnemyMovement - INTELEGÊNCIA DE FILTRO E EVASÃO DE CORPO
;-------------------------------------------------------------------------------
.proc ApplyEnemyMovement
        sty z:DP_ENEMY_STRUCT_PTR

        ; 1. Calcula o alvo com base no setor do inimigo
        ;jsr UpdateTargetSector

        ; 2. Verifica se há colisão/necessidade de evasão de corpo do hero
        jsr HandleBodyEvasion
        bcc @FisicaPadrao               ; Se o Carry estiver limpo, segue física normal
        rts                             ; Se evadiu, encerra o frame

@FisicaPadrao:
        ; 3. Executa a aproximação e lógica de ataque regular
        jsr HandleNormalPhysics
        rts
.endproc

;-------------------------------------------------------------------------------
;   SUB-ROTINA: UpdateTargetSector
;   Calcula os deslocamentos (offsets) com base no quadrante do inimigo
;-------------------------------------------------------------------------------
.proc UpdateTargetSector

        rep #$20                        
        .a16
        lda 3,s                         
        tay                             
        sep #$20                        
        .a8

        lda a:MeleeCrabStruct::Attack_Sector, y
        cmp #0                          
        beq @SetorSupDireito
        cmp #1                          
        beq @SetorSupEsquerdo
        cmp #2                          
        beq @SetorInfDireito

@SetorInfEsquerdo:
        lda z:DP_HERO_CENTER_X
        sec
        sbc #20 + 64
        STA a:MeleeCrabStruct::Target_Attack_X, y
        ;sta z:DP_TARGET_ENEMY_X_DEBUGDENGUE               
        lda z:DP_HERO_CENTER_Y
        ;clc
        ;adc #SECTOR_OFFSET_Y
        ; SEC
        ; ;SBC #SECTOR_OFFSET_Y
        ; SBC #16
        STA a:MeleeCrabStruct::Target_Attack_Y, y
        ;sta z:DP_TARGET_ENEMY_Y_DEBUGDENGUE               
        rts

@SetorSupDireito:
        lda z:DP_HERO_CENTER_X
        clc
        adc #20
        STA a:MeleeCrabStruct::Target_Attack_X, y
        ;sta z:DP_TARGET_ENEMY_X_DEBUGDENGUE
        lda z:DP_HERO_CENTER_Y
        sec
        ;SBC #SECTOR_OFFSET_Y
        SBC #64
        STA a:MeleeCrabStruct::Target_Attack_Y, y
        ;sta z:DP_TARGET_ENEMY_Y_DEBUGDENGUE
        rts

@SetorSupEsquerdo:
        lda z:DP_HERO_CENTER_X
        sec
        sbc #20 + 64
        STA a:MeleeCrabStruct::Target_Attack_X, y
        ;sta z:DP_TARGET_ENEMY_X_DEBUGDENGUE
        lda z:DP_HERO_CENTER_Y
        sec
        ;SBC #SECTOR_OFFSET_Y
        SBC #64
        STA a:MeleeCrabStruct::Target_Attack_Y, y
        ;sta z:DP_TARGET_ENEMY_Y_DEBUGDENGUE
        rts

@SetorInfDireito:
        lda z:DP_HERO_CENTER_X
        clc
        adc #20
        STA a:MeleeCrabStruct::Target_Attack_X, y
        ;sta z:DP_TARGET_ENEMY_X_DEBUGDENGUE
        lda z:DP_HERO_CENTER_Y
        ;clc
        ;adc #SECTOR_OFFSET_Y
        ; SEC
        ; SBC #
        STA a:MeleeCrabStruct::Target_Attack_Y, y
        ;sta z:DP_TARGET_ENEMY_Y_DEBUGDENGUE
        rts
.endproc

;-------------------------------------------------------------------------------
;   SUB-ROTINA: HandleBodyEvasion
;   Retorna: Carry SET se houve evasão (bloqueia física padrão), CLEAR se não.
;-------------------------------------------------------------------------------
.proc HandleBodyEvasion
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc BigHero + BigHeroStruct::X_Pos
        bcs @AbsCorpoX
        eor #$FF
        clc
        adc #1
@AbsCorpoX:
        cmp #24
        bcs @SemEvasao

        lda a:MeleeCrabStruct::Y_Pos, y
        sec
        sbc BigHero + BigHeroStruct::Y_Pos
        bcs @AvaliaInimigoAbaixo
        eor #$FF
        clc
        adc #1
@AvaliaInimigoAbaixo:
        cmp #16
        bcs @SemEvasao

        ; --- Executa Evasão ---
        lda a:MeleeCrabStruct::Y_Pos, y
        cmp BigHero + BigHeroStruct::Y_Pos
        bcs @ContornarPorCima
@ContornarPorBaixo:
        lda a:MeleeCrabStruct::Y_Pos, y
        clc
        adc #WALK_SPEED
        sta a:MeleeCrabStruct::Y_Pos, y
        bra @AplicaMovimentoX

@ContornarPorCima:
        lda a:MeleeCrabStruct::Y_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:MeleeCrabStruct::Y_Pos, y

@AplicaMovimentoX:
        lda a:MeleeCrabStruct::X_Pos, y
        cmp a:MeleeCrabStruct::Target_Attack_X, y
        bcc @EvasaoDireita

@EvasaoEsquerda:
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:MeleeCrabStruct::X_Pos, y
        lda #0
        sta a:MeleeCrabStruct::Facing, y
        bra @FinalizaEvasao              
@EvasaoDireita:
        lda a:MeleeCrabStruct::X_Pos, y
        clc
        adc #WALK_SPEED
        sta a:MeleeCrabStruct::X_Pos, y
        lda #1
        sta a:MeleeCrabStruct::Facing, y

@FinalizaEvasao:
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_WALKING
        beq @FimEvasao
        lda #STATE_WALKING
        sta a:MeleeCrabStruct::State, y
@FimEvasao:
        sec                             ; Avisa o orquestrador que houve evasão
        rts

@SemEvasao:
        clc                             ; Continua para física normal
        rts
.endproc

;-------------------------------------------------------------------------------
;   SUB-ROTINA: HandleNormalPhysics
;   Move o inimigo até o setor e engaja o estado de preparação de ataque
;-------------------------------------------------------------------------------
.proc HandleNormalPhysics
        ; --- 1. ISOLAMENTO ABSOLUTO DO EIXO X ---
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc a:MeleeCrabStruct::Target_Attack_X, y
        bcs @CalcAbsX
        eor #$FF
        clc
        adc #1
@CalcAbsX:
        cmp #ENEMY_ATTACK_DISTANCE
        bcc @PertoNoX                   

        ; --- CASO A: LONGE NO X (Limitador de velocidade por FrameCounter) ---
        lda FrameCounter
        and #%00000001
        beq @ContinuaAndar
        rts

@ContinuaAndar:
        lda a:MeleeCrabStruct::X_Pos, y
        cmp a:MeleeCrabStruct::Target_Attack_X, y
        bcc @WalkRight

@WalkLeft:
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:MeleeCrabStruct::X_Pos, y
        lda #0
        sta a:MeleeCrabStruct::Facing, y
        bra @ForcaAndarX
@WalkRight:
        lda a:MeleeCrabStruct::X_Pos, y
        clc
        adc #WALK_SPEED
        sta a:MeleeCrabStruct::X_Pos, y
        lda #1
        sta a:MeleeCrabStruct::Facing, y

@ForcaAndarX:
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_WALKING
        beq @ApenasReposicionaY
        lda #STATE_WALKING
        sta a:MeleeCrabStruct::State, y

@ApenasReposicionaY:
        lda a:MeleeCrabStruct::Y_Pos, y
        sec
        sbc a:MeleeCrabStruct::Target_Attack_Y, y
        bcs @AbsYApenas
        eor #$FF
        clc
        adc #1
@AbsYApenas:
        cmp #ENEMY_ATTACK_Y_RANGE
        bcc @FimApenas                  

        lda a:MeleeCrabStruct::Y_Pos, y
        cmp a:MeleeCrabStruct::Target_Attack_Y, y
        bcc @MoveDownApenas
@MoveUpApenas:
        lda a:MeleeCrabStruct::Y_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:MeleeCrabStruct::Y_Pos, y
        rts
@MoveDownApenas:
        lda a:MeleeCrabStruct::Y_Pos, y
        clc
        adc #WALK_SPEED
        sta a:MeleeCrabStruct::Y_Pos, y
@FimApenas:
        rts

@PertoNoX:
        ; --- CASO B: PERTO NO X ---
        lda a:MeleeCrabStruct::Y_Pos, y
        sec
        sbc a:MeleeCrabStruct::Target_Attack_Y, y
        bcs @CalcAbsY
        eor #$FF
        clc
        adc #1
@CalcAbsY:
        cmp #ENEMY_ATTACK_Y_RANGE
        bcc @AtaqueConsolidado          

        ; Perto no X, mas longe no Y: Anda verticalmente
        lda a:MeleeCrabStruct::Y_Pos, y
        cmp a:MeleeCrabStruct::Target_Attack_Y, y
        bcc @MoveDownPertoX

@MoveUpPertoX:
        lda a:MeleeCrabStruct::Y_Pos, y
        sec
        sbc #WALK_SPEED
        sta a:MeleeCrabStruct::Y_Pos, y
        bra @ForcaEstadoAndarPertoX
@MoveDownPertoX:
        lda a:MeleeCrabStruct::Y_Pos, y
        clc
        adc #WALK_SPEED
        sta a:MeleeCrabStruct::Y_Pos, y

@ForcaEstadoAndarPertoX:
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_WALKING
        beq @FimPertoX
        lda #STATE_WALKING
        sta a:MeleeCrabStruct::State, y
@FimPertoX:
        rts

@AtaqueConsolidado:
        lda #STATE_PREPARING
        sta a:MeleeCrabStruct::State, y
        rts
.endproc



.proc DrawMeleeCrab
        ;Recupera o índice do inimigo na pilha
        rep #$20
        .a16
        lda 3,s
        tay
        sep #$20
        .a8
        .i16


        LDA a:MeleeCrabStruct::State, y
        cmp #STATE_DEAD
        bne CheckHurtTimer
        rts

CheckHurtTimer:
        ; --- LÓGICA DE PISCAR (FLICKER EM HIT STUN) ---
        lda a:MeleeCrabStruct::HurtTimer, y  ; Carrega o timer de dano atual
        beq @IniciaDesenho                   ; Se for 0, desenha normalmente

        ; Se estiver em hit stun, testa o bit 0 (saber se o frame é par ou ímpar)
        and #%00000001
        beq @AbortaDesenho                   ; Se o bit for 0 (frame par), pula o desenho e faz piscar!

@IniciaDesenho:
        ; Aloca posições físicas e direção temporariamente
        lda a:MeleeCrabStruct::X_Pos, y
        sta z:DP_TEMP_01
        lda a:MeleeCrabStruct::Y_Pos, y
        sta z:DP_TEMP_02
        lda a:MeleeCrabStruct::Facing, y
        sta z:DP_TEMP_03

        jsr ResolveAnimationFrame
        sta z:DP_TEMP_00
        jsr GetAnimationTablePointer

        lda #$00
        sta z:DP_MELEE_CRAB_STRUCT_PTR+2
        sta z:DP_MELEE_CRAB_LAYOUT_PTR+2

        ldy #0
        lda z:DP_TEMP_00
        clc
        adc z:DP_MELEE_CRAB_STRUCT_PTR
        sta z:DP_TEMP_CALC
        lda z:DP_MELEE_CRAB_STRUCT_PTR+1
        adc #0
        sta z:DP_TEMP_CALC+1
        lda #$00
        sta z:DP_TEMP_CALC+2

        lda [DP_TEMP_CALC], y
        sta z:DP_MELEE_CRAB_LAYOUT_PTR
        iny
        lda [DP_TEMP_CALC], y
        sta z:DP_MELEE_CRAB_LAYOUT_PTR+1

        jsr RenderMeleeCrabSprites

@AbortaDesenho:
        rts
.endproc

.proc ResolveAnimationFrame
        lda a:MeleeCrabStruct::HurtTimer, y
        beq @CheckStates
        lda #4                          ; Se tiver HurtTimer ativo, força o frame de Hurt
        rts
@CheckStates:
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_DYING
        bne @CheckResting

        lda a:MeleeCrabStruct::Dying_Anim_Frame, y
        bne @Dying1
@Dying0:
        lda #16
        rts
@Dying1:
        lda #18
        rts
@CheckResting:
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_RESTING              
        beq @Walk0
        cmp #STATE_PREPARING
        bne @CheckAttacking
        lda a:MeleeCrabStruct::Preparing_Anim_Frame, y
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
        lda a:MeleeCrabStruct::Attacking_Anim_Frame, y
        bne @Attack1
@Attack0: lda #12
        rts
@Attack1: lda #14
        rts
@CheckWalking:
        lda a:MeleeCrabStruct::Anim_Frame, y
        bne @Walk1
@Walk0: lda #0
        rts
@Walk1: lda #2
        rts
.endproc

.proc GetAnimationTablePointer
        lda a:MeleeCrabStruct::Enemy_Type, y
        cmp #ENEMY_TYPE_DENGUE
        BEQ @ChaveiaDengue
        cmp #ENEMY_TYPE_VADER
        BEQ @ChaveiaVader
        CMP #ENEMY_TYPE_RAPA
        BEQ @ChaveiaRapa
@ChaveiaVader:
        ldy #.loword(Vader_Animation_Table)
        sty z:DP_MELEE_CRAB_STRUCT_PTR
        rts
@ChaveiaDengue:
        ldy #.loword(Dengue_Animation_Table)
        sty z:DP_MELEE_CRAB_STRUCT_PTR
        RTS
@ChaveiaRapa:
        LDY #.loword(Rapa_Animation_Table)
        sty z:DP_MELEE_CRAB_STRUCT_PTR
        RTS
.endproc



.proc RenderMeleeCrabSprites
        ldy #$0000
@DrawLoop:
        lda #$00
        sta z:DP_MELEE_CRAB_LAYOUT_PTR+2
        lda z:DP_TEMP_03
        bne @DrawXNormal
@DrawXInverted:
        lda #48
        sec
        sbc [DP_MELEE_CRAB_LAYOUT_PTR], y
        clc
        adc z:DP_TEMP_01
        sta OAMMIRROR, x
        bra @ProcessY
@DrawXNormal:
        lda [DP_MELEE_CRAB_LAYOUT_PTR], y
        clc
        adc z:DP_TEMP_01
        sta OAMMIRROR, x
@ProcessY:
        inx
        iny
        lda [DP_MELEE_CRAB_LAYOUT_PTR], y
        clc
        adc z:DP_TEMP_02
        sta OAMMIRROR, x
        inx
        iny
        lda [DP_MELEE_CRAB_LAYOUT_PTR], y
        sta OAMMIRROR, x
        inx
        iny
        lda [DP_MELEE_CRAB_LAYOUT_PTR], y
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


; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO VADERCRAB
; =============================================================================
VaderCrab_Layout:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
VaderCrab_Layout_Frame1:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$00,$01
.byte 0, 32,$48,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
VaderCrab_Layout_Hurt:
.byte 0,  10,$00,$01, 16,  10,$02,$01, 32,  10,$04,$01, 48,  10,$00,$01
.byte 0, 16,$00,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$00,$01
.byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
VaderCrab_Layout_FramePreparing0:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$00,$01
.byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
VaderCrab_Layout_FramePreparing1:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$00,$01
.byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
VaderCrab_Layout_FramePreparing2:
.byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$00,$01
.byte 0, 16,$80,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$00,$01
.byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
.byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01
VaderCrab_Layout_FrameAttacking0:
.byte 0,  0,$00,$01, 16,  0,$0A,$01, 32,  0,$0C,$01, 48,  0,$00,$01
.byte 0, 16,$80,$01, 16, 16,$2A,$01, 32, 16,$2C,$01, 48, 16,$00,$01
.byte 0, 32,$A0,$31, 16, 32,$A2,$31, 32, 32,$A4,$31, 48, 32,$A6,$31
.byte 0, 48,$C0,$31, 16, 48,$C2,$31, 32, 48,$C4,$31, 48, 48,$C6,$31
VaderCrab_Layout_FrameAttacking1:
.byte 0,  0,$00,$01, 16,  0,$0A,$01, 32,  0,$0C,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$2A,$01, 32, 16,$2C,$01, 48, 16,$8E,$01
.byte 0, 32,$A8,$01, 16, 32,$AA,$01, 32, 32,$AC,$01, 48, 32,$AE,$01
.byte 0, 48,$C8,$01, 16, 48,$CA,$01, 32, 48,$CC,$01, 48, 48,$CE,$01
VaderCrab_Layout_Dying0:
.byte 0,  0,$EE,$01, 16,  0,$EE,$01, 32,  0,$EE,$01, 48,  0,$EE,$01
.byte 0, 16,$EE,$01, 16, 16,$EE,$01, 32, 16,$EE,$01, 48, 16,$EE,$01
.byte 0, 32,$EE,$01, 16, 32,$EE,$01, 32, 32,$EE,$01, 48, 32,$EE,$01
.byte 0, 48,$EE,$01, 16, 48,$EE,$01, 32, 48,$EE,$01, 48, 48,$EE,$01
VaderCrab_Layout_Dying1:
.byte 3,  2,$EE,$01, 14,  2,$EE,$01, 30,  1,$EE,$01, 47,  0,$EE,$01
.byte 1, 14,$EE,$01, 18, 14,$EE,$01, 34, 18,$EE,$01, 50, 16,$EE,$01
.byte 2, 30,$EE,$01, 17, 30,$EE,$01, 31, 30,$EE,$01, 49, 32,$EE,$01
.byte 3, 46,$EE,$01, 15, 47,$EE,$01, 33, 50,$EE,$01, 47, 48,$EE,$01

; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO DengueCRAB
; =============================================================================
DengueCrab_Layout:
.byte 30, 18,$EA,$01, 46,  18,$EC,$01, 16,  0,$06,$01, 30,  0,$08,$01
.byte 0, 16,$00,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
DengueCrab_Layout_Frame1:
.byte 30, 18,$EA,$01, 46,  18,$EC,$01, 16,  0,$06,$01, 30,  0,$08,$01
.byte 0, 16,$00,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$00,$01
.byte 0, 32,$48,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
DengueCrab_Layout_Hurt:
.byte 30, 26,$EA,$01, 46,  26,$EC,$01, 16,  8,$06,$01, 30,  8,$08,$01
.byte 0, 24,$00,$01, 16, 24,$26,$01, 32, 24,$28,$01, 48, 24,$00,$01
.byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
DengueCrab_Layout_FramePreparing0:
.byte 27, 18,$EA,$01, 43,  18,$EC,$01, 13,  0,$06,$01, 27,  0,$08,$01
.byte <(-3), 16,$00,$01, 13, 16,$26,$01, 29, 16,$28,$01, 45, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
DengueCrab_Layout_FramePreparing1:
.byte 30, 18,$EA,$01, 46,  18,$EC,$01, 16,  0,$06,$01, 30,  0,$08,$01
.byte 0, 16,$00,$01, 16, 16,$26,$01, 32, 16,$28,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
DengueCrab_Layout_FramePreparing2:
.byte 24, 18,$EA,$01, 40,  18,$EC,$01, 10,  0,$06,$01, 24,  0,$08,$01
.byte <(-6), 16,$00,$01, 10, 16,$26,$01, 26, 16,$28,$01, 42, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
DengueCrab_Layout_FrameAttacking0:
.byte 33, 18,$EA,$01, 49,  18,$EC,$01, 19,  0,$06,$01, 33,  0,$08,$01
.byte 3, 16,$00,$01, 19, 16,$26,$01, 35, 16,$28,$01, 51, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
DengueCrab_Layout_FrameAttacking1:
.byte 36, 18,$EA,$01, 52,  18,$EC,$01, 19,  0,$06,$01, 33,  0,$08,$01
.byte 3, 16,$00,$01, 19, 16,$26,$01, 35, 16,$28,$01, 51, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
DengueCrab_Layout_Dying0:
.byte 0,  0,$EE,$01, 16,  0,$EE,$01, 32,  0,$EE,$01, 48,  0,$EE,$01
.byte 0, 16,$EE,$01, 16, 16,$EE,$01, 32, 16,$EE,$01, 48, 16,$EE,$01
.byte 0, 32,$EE,$01, 16, 32,$EE,$01, 32, 32,$EE,$01, 48, 32,$EE,$01
.byte 0, 48,$EE,$01, 16, 48,$EE,$01, 32, 48,$EE,$01, 48, 48,$EE,$01
DengueCrab_Layout_Dying1:
.byte 3,  2,$EE,$01, 14,  2,$EE,$01, 30,  1,$EE,$01, 47,  0,$EE,$01
.byte 1, 14,$EE,$01, 18, 14,$EE,$01, 34, 18,$EE,$01, 50, 16,$EE,$01
.byte 2, 30,$EE,$01, 17, 30,$EE,$01, 31, 30,$EE,$01, 49, 32,$EE,$01
.byte 3, 46,$EE,$01, 15, 47,$EE,$01, 33, 50,$EE,$01, 47, 48,$EE,$01

; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO RapaCRAB
; =============================================================================
RapaNuiCrab_Layout:
.byte 0,  0,$00,$01, 16,  0,$E2,$01, 32,  0,$E4,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$E6,$01, 32, 16,$E8,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaNuiCrab_Layout_Frame1:
.byte 0,  0,$00,$01, 16,  0,$E2,$01, 32,  0,$E4,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$E6,$01, 32, 16,$E8,$01, 48, 16,$00,$01
.byte 0, 32,$48,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$4E,$01
.byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01
RapaNuiCrab_Layout_Hurt:
.byte 0,  0,$00,$01, 16,  8,$E2,$01, 32,  8,$E4,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$E6,$01, 32, 16,$E8,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaNuiCrab_Layout_FramePreparing0:
.byte 0,  0,$00,$01, 16,  0,$E2,$01, 32,  0,$E4,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$E6,$01, 32, 16,$E8,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaNuiCrab_Layout_FramePreparing1:
.byte 0,  0,$00,$01, 16,  0,$E2,$01, 32,  0,$E4,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$E6,$01, 32, 16,$E8,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaNuiCrab_Layout_FramePreparing2:
.byte 0,  0,$00,$01, 16,  0,$E2,$01, 32,  0,$E4,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$E6,$01, 32, 16,$E8,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaNuiCrab_Layout_FrameAttacking0:
.byte 0,  0,$00,$01, 16,  0,$86,$01, 32,  0,$88,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$82,$01, 32, 16,$84,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaNuiCrab_Layout_FrameAttacking1:
.byte 0,  0,$00,$01, 16,  0,$86,$01, 32,  0,$88,$01, 48,  0,$00,$01
.byte 0, 16,$00,$01, 16, 16,$82,$01, 32, 16,$84,$01, 48, 16,$00,$01
.byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
.byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01
RapaNuiCrab_Layout_Dying0:
.byte 0,  0,$EE,$01, 16,  0,$EE,$01, 32,  0,$EE,$01, 48,  0,$EE,$01
.byte 0, 16,$EE,$01, 16, 16,$EE,$01, 32, 16,$EE,$01, 48, 16,$EE,$01
.byte 0, 32,$EE,$01, 16, 32,$EE,$01, 32, 32,$EE,$01, 48, 32,$EE,$01
.byte 0, 48,$EE,$01, 16, 48,$EE,$01, 32, 48,$EE,$01, 48, 48,$EE,$01
RapaNuiCrab_Layout_Dying1:
.byte 3,  2,$EE,$01, 14,  2,$EE,$01, 30,  1,$EE,$01, 47,  0,$EE,$01
.byte 1, 14,$EE,$01, 18, 14,$EE,$01, 34, 18,$EE,$01, 50, 16,$EE,$01
.byte 2, 30,$EE,$01, 17, 30,$EE,$01, 31, 30,$EE,$01, 49, 32,$EE,$01
.byte 3, 46,$EE,$01, 15, 47,$EE,$01, 33, 50,$EE,$01, 47, 48,$EE,$01



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
.word .loword(VaderCrab_Layout_Dying0)    ; Índice 16 (Dying 0)
.word .loword(VaderCrab_Layout_Dying1)    ; Índice 18 (Dying 1)
Dengue_Animation_Table:
.word .loword(DengueCrab_Layout)
.word .loword(DengueCrab_Layout_Frame1)
.word .loword(DengueCrab_Layout_Hurt)
.word .loword(DengueCrab_Layout_FramePreparing0)
.word .loword(DengueCrab_Layout_FramePreparing1)
.word .loword(DengueCrab_Layout_FramePreparing2)
.word .loword(DengueCrab_Layout_FrameAttacking0)
.word .loword(DengueCrab_Layout_FrameAttacking1)
.word .loword(DengueCrab_Layout_Dying0)    ; Índice 16 (Dying 0)
.word .loword(DengueCrab_Layout_Dying1)    ; Índice 18 (Dying 1)
Rapa_Animation_Table:
.word .loword(RapaNuiCrab_Layout)
.word .loword(RapaNuiCrab_Layout_Frame1)
.word .loword(RapaNuiCrab_Layout_Hurt)
.word .loword(RapaNuiCrab_Layout_FramePreparing0)
.word .loword(RapaNuiCrab_Layout_FramePreparing1)
.word .loword(RapaNuiCrab_Layout_FramePreparing2)
.word .loword(RapaNuiCrab_Layout_FrameAttacking0)
.word .loword(RapaNuiCrab_Layout_FrameAttacking1)
.word .loword(RapaNuiCrab_Layout_Dying0)    ; Índice 16 (Dying 0)
.word .loword(RapaNuiCrab_Layout_Dying1)    ; Índice 18 (Dying 1)
Enemy_Master_Animation_Table:
.word .loword(Vader_Animation_Table)
.word .loword(Dengue_Animation_Table)
.word .loword(Rapa_Animation_Table)
