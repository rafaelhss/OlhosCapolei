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


SPAWNING_ANIM_SPEED = 15   
SPAWNING_DURATION_FRAMES = 45
SPAWNING_MAX_FRAMES = 2  


ENEMY_ATTACK_DISTANCE = $1   ; Distância de engajamento do ataque da IA. Com  introduçao do Setor de Ataque, esse valor perdeu sentido.  
ENEMY_ATTACK_Y_RANGE  = $08   ; Tolerância no eixo Y para alinhamento tridimensional

ENEMY_HURTBOX_WIDTH  = $10
ENEMY_HURTBOX_HEIGHT = $20     

DYING_DURATION_FRAMES = 45
DYING_ANIM_SPEED      = 15
DYING_MAX_FRAMES      = 2

.import BigHero
.import FrameCounter
.import VaderCrab
.import Camera_X


.segment "CODE"
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
        bne @CheckPreSpawn
        jsr UpdateDyingState
        rts                 ; Enquanto morre, não executa IA nem atualiza hurtbox
       
@CheckPreSpawn:
        lda a:MeleeCrabStruct::State, y
        cmp #STATE_PRE_SPAWN
        bne @CheckSpawningState
        jsr UpdatePreSpawnState
        rts                             ; Sai sem atualizar Hurtbox!

@CheckSpawningState:
        cmp #STATE_SPAWNING
        bne CheckHurt
        jsr UpdateSpawningState
        rts                             ; Sai sem atualizar Hurtbox durante o salto!


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
        
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        cmp BigHero + BigHeroStruct::X_Pos
        sep #$20
        .a8
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

.proc UpdatePreSpawnState
        ; 1. Pisca o olho na rachadura a cada 12 frames
        lda FrameCounter
        and #$3F
        bne @CheckTrigger
        lda a:MeleeCrabStruct::Anim_Frame, y
        eor #$01
        sta a:MeleeCrabStruct::Anim_Frame, y

@CheckTrigger:
        ; 2. Espera o Spawn_Delay acabar (ou se for 0, pula quando o herói chegar perto!)
        lda a:MeleeCrabStruct::Spawn_Delay, y
        beq @CheckProximity
        sec
        sbc #1
        sta a:MeleeCrabStruct::Spawn_Delay, y
        rts

@CheckProximity:
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc BigHero + BigHeroStruct::X_Pos
        bcs @AbsDist
        eor #$FFFF
        clc
        adc #1
@AbsDist:
        cmp #96                         ; Pula quando o herói estiver a 96 pixels!
        sep #$20
        .a8
        bcs @Wait

        ; --- INICIA O PULO MICHAEL JACKSON! ---
        lda #STATE_SPAWNING
        sta a:MeleeCrabStruct::State, y
        lda a:MeleeCrabStruct::Y_Pos, y
        sta a:MeleeCrabStruct::Base_Ground_Y, y ; Salva o chão exato
        lda #<(-6)                      ; Impulso inicial para cima (-6 px/frame)
        sta a:MeleeCrabStruct::Spawn_Vel_Y, y
        lda #0
        sta a:MeleeCrabStruct::Anim_Frame, y

        ; Olha na direção do herói antes de saltar
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        cmp BigHero + BigHeroStruct::X_Pos
        sep #$20
        .a8
        bcc @FaceRight
        lda #0
        sta a:MeleeCrabStruct::Facing, y
        rts
@FaceRight:
        lda #1
        sta a:MeleeCrabStruct::Facing, y
@Wait:
        rts
.endproc

.proc UpdateSpawningState
        ; 1. Aplica velocidade vertical ao Y_Pos
        lda a:MeleeCrabStruct::Y_Pos, y
        clc
        adc a:MeleeCrabStruct::Spawn_Vel_Y, y
        sta a:MeleeCrabStruct::Y_Pos, y

        ; 2. Gravidade suave (a cada 2 frames aumenta +1 na velocidade)
        lda FrameCounter
        and #$01
        bne @CheckLanding
        lda a:MeleeCrabStruct::Spawn_Vel_Y, y
        clc
        adc #1
        sta a:MeleeCrabStruct::Spawn_Vel_Y, y

        ; Troca frame de animação no ápice do pulo (quando começa a cair)
        lda a:MeleeCrabStruct::Spawn_Vel_Y, y
        bmi @CheckLanding
        lda #1
        sta a:MeleeCrabStruct::Anim_Frame, y

@CheckLanding:
        ; 3. Verifica se voltou para o chão original (Base_Ground_Y)
        lda a:MeleeCrabStruct::Spawn_Vel_Y, y
        bmi @StillInAir                 ; Se ainda está subindo (< 0), não pousou

        lda a:MeleeCrabStruct::Y_Pos, y
        cmp a:MeleeCrabStruct::Base_Ground_Y, y
        bcc @StillInAir

        ; --- POUSOU NO CHÃO! ---
        lda a:MeleeCrabStruct::Base_Ground_Y, y
        sta a:MeleeCrabStruct::Y_Pos, y
        lda #STATE_WALKING
        sta a:MeleeCrabStruct::State, y
        lda #0
        STA a:MeleeCrabStruct::Anim_Frame, y
        LDA #WALK_ANIM_SPEED                    
        sta a:MeleeCrabStruct::Anim_Timer, y
@StillInAir:
        rts
.endproc

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
        
        lda #08 
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
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        sta a:MeleeCrabStruct::Hurtbox_X1, y
        clc
        adc #48
        sta a:MeleeCrabStruct::Hurtbox_X2, y
        sep #$20
        .a8

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
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc #ENEMY_HURTBOX_WIDTH
        bcs @SaveHitLeft
        lda #0
@SaveHitLeft:
        sta a:MeleeCrabStruct::Hitbox_X1, y
        lda a:MeleeCrabStruct::X_Pos, y 
        sta a:MeleeCrabStruct::Hitbox_X2, y
        sep #$20
        .a8
        bra @Done

@HitboxDireitaAtaque:
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        clc
        adc #64                             
        sta a:MeleeCrabStruct::Hitbox_X1, y
        clc
        adc #ENEMY_HURTBOX_WIDTH                             
        sta a:MeleeCrabStruct::Hitbox_X2, y
        sep #$20
        .a8
@Done:
        rts
.endproc

;-------------------------------------------------------------------------------
;   ApplyEnemyMovement - INTELEGÊNCIA DE FILTRO E EVASÃO DE CORPO
;-------------------------------------------------------------------------------
.proc ApplyEnemyMovement
        sty z:DP_ENEMY_STRUCT_PTR


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
        rep #$20
        .a16
        lda z:DP_HERO_CENTER_X
        sec
        sbc #(20 + 64)
        bcs @SaveX_IE
        lda #0
@SaveX_IE:
        sta a:MeleeCrabStruct::Target_Attack_X, y
        sep #$20
        .a8
        lda z:DP_HERO_CENTER_Y
        sta a:MeleeCrabStruct::Target_Attack_Y, y
        rts

@SetorSupDireito:
        rep #$20
        .a16
        lda z:DP_HERO_CENTER_X
        clc
        adc #20
        sta a:MeleeCrabStruct::Target_Attack_X, y
        sep #$20
        .a8
        lda z:DP_HERO_CENTER_Y
        sec
        sbc #64
        sta a:MeleeCrabStruct::Target_Attack_Y, y
        rts

@SetorSupEsquerdo:
        rep #$20
        .a16
        lda z:DP_HERO_CENTER_X
        sec
        sbc #(20 + 64)
        bcs @SaveX_SE
        lda #0
@SaveX_SE:
        sta a:MeleeCrabStruct::Target_Attack_X, y
        sep #$20
        .a8
        lda z:DP_HERO_CENTER_Y
        sec
        sbc #64
        sta a:MeleeCrabStruct::Target_Attack_Y, y
        rts

@SetorInfDireito:
        rep #$20
        .a16
        lda z:DP_HERO_CENTER_X
        clc
        adc #20
        sta a:MeleeCrabStruct::Target_Attack_X, y
        sep #$20
        .a8
        lda z:DP_HERO_CENTER_Y
        sta a:MeleeCrabStruct::Target_Attack_Y, y
        rts
.endproc

;-------------------------------------------------------------------------------
;   SUB-ROTINA: HandleBodyEvasion
;   Retorna: Carry SET se houve evasão (bloqueia física padrão), CLEAR se não.
;-------------------------------------------------------------------------------
.proc HandleBodyEvasion
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc BigHero + BigHeroStruct::X_Pos
        bcs @AbsCorpoX
        eor #$FFFF
        clc
        adc #1
@AbsCorpoX:
        CMP #24
        sep #$20
        .a8
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
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        cmp a:MeleeCrabStruct::Target_Attack_X, y
        bcc @EvasaoDireita

@EvasaoEsquerda:
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc #WALK_SPEED
        bcs @SaveEvLeft
        lda #0
@SaveEvLeft:
        sta a:MeleeCrabStruct::X_Pos, y
        sep #$20
        .a8
        lda #0
        sta a:MeleeCrabStruct::Facing, y
        bra @FinalizaEvasao
@EvasaoDireita:
        lda a:MeleeCrabStruct::X_Pos, y
        clc
        adc #WALK_SPEED
        sta a:MeleeCrabStruct::X_Pos, y
        sep #$20
        .a8
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
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc a:MeleeCrabStruct::Target_Attack_X, y
        bcs @CalcAbsX
        eor #$FFFF
        clc
        ADC #1
        
@CalcAbsX:
        CMP #ENEMY_ATTACK_DISTANCE
        sep #$20
        .a8
        bcs @ContinuaAndar
        jmp @PertoNoX                  

        ; --- CASO A: LONGE NO X (Limitador de velocidade por FrameCounter) ---
        ; lda FrameCounter
        ; and #%00000001
        ; beq @ContinuaAndar
        ; rts

@ContinuaAndar:
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        cmp a:MeleeCrabStruct::Target_Attack_X, y
        bcc @WalkRight

@WalkLeft:

        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc #WALK_SPEED
        bcs @SaveWalkL
        lda #0
@SaveWalkL:
        sta a:MeleeCrabStruct::X_Pos, y
        sep #$20
        .a8
        lda #0
        sta a:MeleeCrabStruct::Facing, y
        bra @ForcaAndarX

@WalkRight:
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        clc
        adc #WALK_SPEED
        sta a:MeleeCrabStruct::X_Pos, y
        sep #$20
        .a8
        
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
        rep #$20
        .a16
        LDA a:MeleeCrabStruct::X_Pos, y
        STA a:$E1
        LDA a:MeleeCrabStruct::Target_Attack_X, y
        STA a:$E3
        
        LDA VaderCrab + MeleeCrabStruct::X_Pos
        STA a:$E5
        LDA VaderCrab + MeleeCrabStruct::Target_Attack_X
        STA a:$E7 
        sep #$20
        .a8
        rts

@PertoNoX:
        rep #$20
        .a16
        LDA a:MeleeCrabStruct::X_Pos, y
        STA a:$F1
        LDA a:MeleeCrabStruct::Target_Attack_X, y
        STA a:$F3
        
        LDA VaderCrab + MeleeCrabStruct::X_Pos
        STA a:$F5
        LDA VaderCrab + MeleeCrabStruct::Target_Attack_X
        STA a:$F7 
        
        LDA BigHero + BigHeroStruct::X_Pos
        STA a:$F9
        LDA Camera_X 
        STA a:$FA 
        
        sep #$20
        .a8 


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
        ; Recupera o índice do inimigo na pilha
        rep #$20
        .a16
        lda 3,s
        tay
        sep #$20
        .a8
        .i16

        lda a:MeleeCrabStruct::State, y
        cmp #STATE_DEAD
        bne CheckHurtTimer
        rts

CheckHurtTimer:
        ; --- LÓGICA DE PISCAR (FLICKER EM HIT STUN) ---
        lda a:MeleeCrabStruct::HurtTimer, y
        beq @IniciaDesenho

        and #%00000001
        beq @AbortaDesenho

@IniciaDesenho:
        ; 1. Calcula Screen_X = World_X - Camera_X em 16-bit
        rep #$20
        .a16
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc Camera_X
        sta z:DP_ENEMY_DRAW_X                ; DP_TEMP_07 ($32-$33) = Screen_X assinado (-2048..+2048)

        ; 2. Culling Horizontal: Só desenha se -64 <= Screen_X < 256
        clc
        adc #64                         ; Desloca [-64..255] para [0..319]
        cmp #(256 + 64)                 ; Se >= 320, está totalmente fora da tela!
        sep #$20
        .a8
        bcs @AbortaDesenho

        ; 3. Guarda Y_Pos, Facing e índice do frame
        lda a:MeleeCrabStruct::Y_Pos, y
        sta z:DP_ENEMY_DRAW_Y
        lda a:MeleeCrabStruct::Facing, y
        sta z:DP_TEMP_03

        jsr ResolveAnimationFrame
        sta z:DP_TEMP_00                ; Índice do frame (agora seguro pois Screen_X está em DP_TEMP_07)
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
        LDA a:MeleeCrabStruct::State, y
        cmp #STATE_PRE_SPAWN
        bne @CheckSpawning
        lda a:MeleeCrabStruct::Anim_Frame, y
        bne @PreSpawn1
        lda #20                         ; RapaNuiCrab_Layout_PreSpawning0
        rts
@PreSpawn1:
        lda #22                         ; RapaNuiCrab_Layout_PreSpawning1
        rts

@CheckSpawning:
        cmp #STATE_SPAWNING
        bne @CheckDyingFrame            ; (renomeie o check atual do STATE_DYING para cá)
        lda a:MeleeCrabStruct::Anim_Frame, y
        bne @Spawn1
        lda #24                         ; RapaNuiCrab_Layout_Spawning0
        rts
@Spawn1:
        lda #26                         ; RapaNuiCrab_Layout_Spawning1
        RTS
        
@CheckDyingFrame:
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
        INY
        iny                             ; Aponta para o byte 2 (Tile ID)
        lda [DP_MELEE_CRAB_LAYOUT_PTR], y
        cmp #$FF
        beq @SkipEmptyTile              ; Se for $FF, não gasta slot da OAM nem desenha nada!
        dey
        dey                             ; Volta Y para o byte 0 (Offset X)

        lda #$00
        sta z:DP_MELEE_CRAB_LAYOUT_PTR+2
        lda z:DP_TEMP_03
        bne @DrawXNormal

@DrawXInverted:
        lda #48
        sec
        sbc [DP_MELEE_CRAB_LAYOUT_PTR], y
        bra @CalcTileScreenX

@DrawXNormal:
        lda [DP_MELEE_CRAB_LAYOUT_PTR], y

@CalcTileScreenX:
        ; Soma offset assinado (ex: -3, -6 ou +48) ao Screen_X (16-bit em DP_TEMP_07)
        rep #$20
        .a16
        and #$00FF
        cmp #$0080
        bcc @PosTileOff
        ora #$FF00                      ; Extensão de sinal para offsets negativos (-3, -6)
@PosTileOff:
        clc
        adc z:DP_ENEMY_DRAW_X                ; A = Tile_Screen_X completo (16-bit)
        cmp #256                        ; Fora da tela (< 0 ou >= 256)?
        bcs @TileOffScreen

        ; --- TILE VISÍVEL (0..255) ---
        sep #$20
        .a8
        sta OAMMIRROR, x                ; Grava X na OAM
        inx
        iny

        lda [DP_MELEE_CRAB_LAYOUT_PTR], y
        clc
        adc z:DP_ENEMY_DRAW_Y                ; Soma Y_Pos
        sta OAMMIRROR, x                ; Grava Y na OAM
        inx
        iny
        bra @DrawTileID

@TileOffScreen:
        ; --- TILE FORA DA TELA (< 0 ou >= 256) ---
        sep #$20
        .a8
        sta OAMMIRROR, x
        inx
        iny

        lda #$F0                        ; Esconde o sprite abaixo da tela (Y = 240)
        sta OAMMIRROR, x
        inx
        iny

@DrawTileID:
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
@NextIteration:
        cpy #64
        bne @DrawLoop
        rts

@SkipEmptyTile:
        iny
        iny                             ; Avança Y do byte 2 para o byte 4 (próximo sprite da matriz)
        cpy #64
        bne @DrawLoop
        rts
.endproc


.segment "RODATA"
; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO VADERCRAB
; =============================================================================
VaderCrab_Layout:
.byte 0,  0,$FF,$31, 16,  0,$02,$31, 32,  0,$04,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$22,$31, 32, 16,$24,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
VaderCrab_Layout_Frame1:
.byte 0,  0,$FF,$31, 16,  0,$02,$31, 32,  0,$04,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$22,$31, 32, 16,$24,$31, 48, 16,$FF,$31
.byte 0, 32,$48,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$4E,$31
.byte 0, 48,$68,$31, 16, 48,$6A,$31, 32, 48,$6C,$31, 48, 48,$6E,$31
VaderCrab_Layout_Hurt:
.byte 0,  10,$FF,$31, 16,  10,$02,$31, 32,  10,$04,$31, 48,  10,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$22,$31, 32, 16,$24,$31, 48, 16,$FF,$31
.byte 0, 32,$48,$31, 16, 32,$4A,$31, 32, 32,$4C,$31, 48, 32,$4E,$31
.byte 0, 48,$68,$31, 16, 48,$6A,$31, 32, 48,$6C,$31, 48, 48,$6E,$31
VaderCrab_Layout_FramePreparing0:
.byte 0,  0,$FF,$31, 16,  0,$02,$31, 32,  0,$04,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$22,$31, 32, 16,$24,$31, 48, 16,$FF,$31
.byte 0, 32,$48,$31, 16, 32,$4A,$31, 32, 32,$4C,$31, 48, 32,$4E,$31
.byte 0, 48,$C0,$31, 16, 48,$C2,$31, 32, 48,$C4,$31, 48, 48,$C6,$31
VaderCrab_Layout_FramePreparing1:
.byte 0,  0,$FF,$31, 16,  0,$02,$31, 32,  0,$04,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$22,$31, 32, 16,$24,$31, 48, 16,$FF,$31
.byte 0, 32,$A0,$31, 16, 32,$A2,$31, 32, 32,$A4,$31, 48, 32,$A6,$31
.byte 0, 48,$C0,$31, 16, 48,$C2,$31, 32, 48,$C4,$31, 48, 48,$C6,$31
VaderCrab_Layout_FramePreparing2:
.byte 0,  0,$FF,$31, 16,  0,$02,$31, 32,  0,$04,$31, 48,  0,$FF,$31
.byte 0, 16,$80,$31, 16, 16,$22,$31, 32, 16,$24,$31, 48, 16,$FF,$31
.byte 0, 32,$A0,$31, 16, 32,$A2,$31, 32, 32,$A4,$31, 48, 32,$A6,$31
.byte 0, 48,$C0,$31, 16, 48,$C2,$31, 32, 48,$C4,$31, 48, 48,$C6,$31
VaderCrab_Layout_FrameAttacking0:
.byte 0,  0,$FF,$31, 16,  0,$0A,$31, 32,  0,$0C,$31, 48,  0,$FF,$31
.byte 0, 16,$80,$31, 16, 16,$2A,$31, 32, 16,$2C,$31, 48, 16,$FF,$31
.byte 0, 32,$A0,$31, 16, 32,$A2,$31, 32, 32,$A4,$31, 48, 32,$A6,$31
.byte 0, 48,$C0,$31, 16, 48,$C2,$31, 32, 48,$C4,$31, 48, 48,$C6,$31
VaderCrab_Layout_FrameAttacking1:
.byte 0,  0,$FF,$31, 16,  0,$0A,$31, 32,  0,$0C,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$2A,$31, 32, 16,$2C,$31, 48, 16,$8E,$31
.byte 0, 32,$A8,$31, 16, 32,$AA,$31, 32, 32,$AC,$31, 48, 32,$AE,$31
.byte 0, 48,$C8,$31, 16, 48,$CA,$31, 32, 48,$CC,$31, 48, 48,$CE,$31
VaderCrab_Layout_Dying0:
.byte 0,  0,$FF,$31, 16,  0,$EE,$31, 32,  0,$EE,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$EE,$31, 32, 16,$EE,$31, 48, 16,$FF,$31
.byte 0, 32,$EE,$31, 16, 32,$EE,$31, 32, 32,$EE,$31, 48, 32,$EE,$31
.byte 0, 48,$EE,$31, 16, 48,$EE,$31, 32, 48,$EE,$31, 48, 48,$EE,$31
VaderCrab_Layout_Dying1:
.byte 3,  2,$FF,$31, 14,  2,$EE,$31, 30,  1,$EE,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$EE,$31, 34, 18,$EE,$31, 50, 16,$FF,$31
.byte 2, 30,$EE,$31, 17, 30,$EE,$31, 31, 30,$EE,$31, 49, 32,$EE,$31
.byte 3, 46,$EE,$31, 15, 47,$EE,$31, 33, 50,$EE,$31, 47, 48,$EE,$31
VaderCrab_Layout_Spawning0:
.byte 0,  0,$FF,$31, 16,  0,$0A,$31, 32,  0,$0C,$31, 48,  0,$FF,$31
.byte 0, 16,$80,$31, 16, 16,$2A,$31, 32, 16,$2C,$31, 48, 16,$FF,$31
.byte 0, 32,$A0,$31, 16, 32,$A2,$31, 32, 32,$A4,$31, 48, 32,$A6,$31
.byte 0, 48,$C0,$31, 16, 48,$C2,$31, 32, 48,$C4,$31, 48, 48,$C6,$31
VaderCrab_Layout_Spawning1:
.byte 0,  0,$FF,$31, 16,  0,$0A,$31, 32,  0,$0C,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$2A,$31, 32, 16,$2C,$31, 48, 16,$8E,$31
.byte 0, 32,$A8,$31, 16, 32,$AA,$31, 32, 32,$AC,$31, 48, 32,$AE,$31
.byte 0, 48,$C8,$31, 16, 48,$CA,$31, 32, 48,$CC,$31, 48, 48,$CE,$31
VaderCrab_Layout_PreSpawning0:
.byte 3,  2,$FF,$31, 14,  2,$FF,$31, 30,  1,$FF,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$FF,$31, 34, 18,$FF,$31, 50, 16,$FF,$31
.byte 2, 30,$FF,$31, 17, 30,$FF,$31, 31, 30,$FF,$31, 49, 32,$FF,$31
.byte 0, 48,$8C,$31, 16, 48,$00,$71, 32, 48,$8C,$F1, 48, 48,$FF,$71
VaderCrab_Layout_PreSpawning1:
.byte 3,  2,$FF,$31, 14,  2,$FF,$31, 30,  1,$FF,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$FF,$31, 34, 18,$FF,$31, 50, 16,$FF,$31
.byte 2, 30,$FF,$31, 17, 30,$FF,$31, 31, 30,$FF,$31, 49, 32,$FF,$31
.byte 0, 48,$8C,$31, 16, 48,$00,$31, 32, 48,$8C,$F1, 48, 48,$FF,$71


; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO DengueCRAB
; =============================================================================
DengueCrab_Layout:
.byte 30, 18,$EA,$31, 46,  18,$EC,$31, 16,  0,$06,$31, 30,  0,$08,$31
.byte 0, 16,$FF,$31, 16, 16,$26,$31, 32, 16,$28,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
DengueCrab_Layout_Frame1:
.byte 30, 18,$EA,$31, 46,  18,$EC,$31, 16,  0,$06,$31, 30,  0,$08,$31
.byte 0, 16,$FF,$31, 16, 16,$26,$31, 32, 16,$28,$31, 48, 16,$FF,$31
.byte 0, 32,$48,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$4E,$31
.byte 0, 48,$68,$31, 16, 48,$6A,$31, 32, 48,$6C,$31, 48, 48,$6E,$31
DengueCrab_Layout_Hurt:
.byte 30, 26,$EA,$31, 46,  26,$EC,$31, 16,  8,$06,$31, 30,  8,$08,$31
.byte 0, 24,$FF,$31, 16, 24,$26,$31, 32, 24,$28,$31, 48, 24,$FF,$31
.byte 0, 32,$48,$31, 16, 32,$4A,$31, 32, 32,$4C,$31, 48, 32,$4E,$31
.byte 0, 48,$68,$31, 16, 48,$6A,$31, 32, 48,$6C,$31, 48, 48,$6E,$31
DengueCrab_Layout_FramePreparing0:
.byte 27, 18,$EA,$31, 43,  18,$EC,$31, 13,  0,$06,$31, 27,  0,$08,$31
.byte <(-3), 16,$FF,$31, 13, 16,$26,$31, 29, 16,$28,$31, 45, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
DengueCrab_Layout_FramePreparing1:
.byte 30, 18,$EA,$31, 46,  18,$EC,$31, 16,  0,$06,$31, 30,  0,$08,$31
.byte 0, 16,$FF,$31, 16, 16,$26,$31, 32, 16,$28,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
DengueCrab_Layout_FramePreparing2:
.byte 24, 18,$EA,$31, 40,  18,$EC,$31, 10,  0,$06,$31, 24,  0,$08,$31
.byte <(-6), 16,$FF,$31, 10, 16,$26,$31, 26, 16,$28,$31, 42, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
DengueCrab_Layout_FrameAttacking0:
.byte 33, 18,$EA,$31, 49,  18,$EC,$31, 19,  0,$06,$31, 33,  0,$08,$31
.byte 3, 16,$FF,$31, 19, 16,$26,$31, 35, 16,$28,$31, 51, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
DengueCrab_Layout_FrameAttacking1:
.byte 36, 18,$EA,$31, 52,  18,$EC,$31, 19,  0,$06,$31, 33,  0,$08,$31
.byte 3, 16,$FF,$31, 19, 16,$26,$31, 35, 16,$28,$31, 51, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
DengueCrab_Layout_Dying0:
.byte 0,  0,$FF,$31, 16,  0,$EE,$31, 32,  0,$EE,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$EE,$31, 32, 16,$EE,$31, 48, 16,$FF,$31
.byte 0, 32,$EE,$31, 16, 32,$EE,$31, 32, 32,$EE,$31, 48, 32,$EE,$31
.byte 0, 48,$EE,$31, 16, 48,$EE,$31, 32, 48,$EE,$31, 48, 48,$EE,$31
DengueCrab_Layout_Dying1:
.byte 3,  2,$FF,$31, 14,  2,$EE,$31, 30,  1,$EE,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$EE,$31, 34, 18,$EE,$31, 50, 16,$FF,$31
.byte 2, 30,$EE,$31, 17, 30,$EE,$31, 31, 30,$EE,$31, 49, 32,$EE,$31
.byte 3, 46,$EE,$31, 15, 47,$EE,$31, 33, 50,$EE,$31, 47, 48,$EE,$31
DengueCrab_Layout_Spawning0:
.byte 33, 18,$EA,$31, 49,  18,$EC,$31, 19,  0,$06,$31, 33,  0,$08,$31
.byte 3, 16,$FF,$31, 19, 16,$26,$31, 35, 16,$28,$31, 51, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
DengueCrab_Layout_Spawning1:
.byte 36, 18,$EA,$31, 52,  18,$EC,$31, 19,  0,$06,$31, 33,  0,$08,$31
.byte 3, 16,$FF,$31, 19, 16,$26,$31, 35, 16,$28,$31, 51, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
DengueCrab_Layout_PreSpawning0:
.byte 3,  2,$FF,$31, 14,  2,$FF,$31, 30,  1,$FF,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$FF,$31, 34, 18,$FF,$31, 50, 16,$FF,$31
.byte 2, 30,$FF,$31, 17, 30,$FF,$31, 31, 30,$FF,$31, 49, 32,$FF,$31
.byte 0, 48,$8C,$31, 16, 48,$00,$71, 32, 48,$8C,$F1, 48, 48,$FF,$71
DengueCrab_Layout_PreSpawning1:
.byte 3,  2,$FF,$31, 14,  2,$FF,$31, 30,  1,$FF,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$FF,$31, 34, 18,$FF,$31, 50, 16,$FF,$31
.byte 2, 30,$FF,$31, 17, 30,$FF,$31, 31, 30,$FF,$31, 49, 32,$FF,$31
.byte 0, 48,$8C,$31, 16, 48,$00,$31, 32, 48,$8C,$F1, 48, 48,$FF,$71


; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO RapaCRAB
; =============================================================================
RapaNuiCrab_Layout:
.byte 0,  0,$FF,$31, 16,  0,$E2,$31, 32,  0,$E4,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$E6,$31, 32, 16,$E8,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_Frame1:
.byte 0,  0,$FF,$31, 16,  0,$E2,$31, 32,  0,$E4,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$E6,$31, 32, 16,$E8,$31, 48, 16,$FF,$31
.byte 0, 32,$48,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$4E,$31
.byte 0, 48,$68,$31, 16, 48,$6A,$31, 32, 48,$6C,$31, 48, 48,$6E,$31
RapaNuiCrab_Layout_Hurt:
.byte 0,  0,$FF,$31, 16,  8,$E2,$31, 32,  8,$E4,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$E6,$31, 32, 16,$E8,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_FramePreparing0:
.byte 0,  0,$FF,$31, 16,  0,$E2,$31, 32,  0,$E4,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$E6,$31, 32, 16,$E8,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_FramePreparing1:
.byte 0,  0,$FF,$31, 16,  0,$E2,$31, 32,  0,$E4,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$E6,$31, 32, 16,$E8,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_FramePreparing2:
.byte 0,  0,$FF,$31, 16,  0,$E2,$31, 32,  0,$E4,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$E6,$31, 32, 16,$E8,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_FrameAttacking0:
.byte 0,  0,$FF,$31, 16,  0,$86,$31, 32,  0,$88,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$82,$31, 32, 16,$84,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_FrameAttacking1:
.byte 0,  0,$FF,$31, 16,  0,$86,$31, 32,  0,$88,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$82,$31, 32, 16,$84,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_Dying0:
.byte 0,  0,$FF,$31, 16,  0,$EE,$31, 32,  0,$EE,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$EE,$31, 32, 16,$EE,$31, 48, 16,$FF,$31
.byte 0, 32,$EE,$31, 16, 32,$EE,$31, 32, 32,$EE,$31, 48, 32,$EE,$31
.byte 0, 48,$EE,$31, 16, 48,$EE,$31, 32, 48,$EE,$31, 48, 48,$EE,$31
RapaNuiCrab_Layout_Dying1:
.byte 3,  2,$FF,$31, 14,  2,$EE,$31, 30,  1,$EE,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$EE,$31, 34, 18,$EE,$31, 50, 16,$FF,$31
.byte 2, 30,$EE,$31, 17, 30,$EE,$31, 31, 30,$EE,$31, 49, 32,$EE,$31
.byte 3, 46,$EE,$31, 15, 47,$EE,$31, 33, 50,$EE,$31, 47, 48,$EE,$31
RapaNuiCrab_Layout_Spawning0:
.byte 0,  0,$FF,$31, 16,  0,$86,$31, 32,  0,$88,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$82,$31, 32, 16,$84,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_Spawning1:
.byte 0,  0,$FF,$31, 16,  0,$86,$31, 32,  0,$88,$31, 48,  0,$FF,$31
.byte 0, 16,$FF,$31, 16, 16,$82,$31, 32, 16,$84,$31, 48, 16,$FF,$31
.byte 0, 32,$40,$31, 16, 32,$42,$31, 32, 32,$44,$31, 48, 32,$46,$31
.byte 0, 48,$60,$31, 16, 48,$62,$31, 32, 48,$64,$31, 48, 48,$66,$31
RapaNuiCrab_Layout_PreSpawning0:
.byte 3,  2,$FF,$31, 14,  2,$FF,$31, 30,  1,$FF,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$FF,$31, 34, 18,$FF,$31, 50, 16,$FF,$31
.byte 2, 30,$FF,$31, 17, 30,$FF,$31, 31, 30,$FF,$31, 49, 32,$FF,$31
.byte 0, 48,$8C,$31, 16, 48,$00,$71, 32, 48,$8C,$F1, 48, 48,$FF,$71
RapaNuiCrab_Layout_PreSpawning1:
.byte 3,  2,$FF,$31, 14,  2,$FF,$31, 30,  1,$FF,$31, 47,  0,$FF,$31
.byte 1, 14,$FF,$31, 18, 14,$FF,$31, 34, 18,$FF,$31, 50, 16,$FF,$31
.byte 2, 30,$FF,$31, 17, 30,$FF,$31, 31, 30,$FF,$31, 49, 32,$FF,$31
.byte 0, 48,$8C,$31, 16, 48,$00,$31, 32, 48,$8C,$F1, 48, 48,$FF,$71




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
.word .loword(VaderCrab_Layout_PreSpawning0) ; Índice 20 (PreSpawning0 temporário)
.word .loword(VaderCrab_Layout_PreSpawning1) ; Índice 22 (PreSpawning1 temporário)
.word .loword(VaderCrab_Layout_Spawning0) ; Índice 24 (Spawning0 temporário)
.word .loword(VaderCrab_Layout_Spawning1) ; Índice 26 (Spawning1 temporário)
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
.word .loword(DengueCrab_Layout_PreSpawning0) ; Índice 20 (PreSpawning0 temporário)
.word .loword(DengueCrab_Layout_PreSpawning1) ; Índice 22 (PreSpawning1 temporário)
.word .loword(DengueCrab_Layout_Spawning0) ; Índice 24 (Spawning0 temporário)
.word .loword(DengueCrab_Layout_Spawning1) ; Índice 26 (Spawning1 temporário)
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
.word .loword(RapaNuiCrab_Layout_PreSpawning0)    
.word .loword(RapaNuiCrab_Layout_PreSpawning1)    
.word .loword(RapaNuiCrab_Layout_Spawning0)    
.word .loword(RapaNuiCrab_Layout_Spawning1)    

Enemy_Master_Animation_Table:
.word .loword(Vader_Animation_Table)
.word .loword(Dengue_Animation_Table)
.word .loword(Rapa_Animation_Table)
