; ---------------- -------------------------------------------------------------
;   File: VaderCrab.s
;   Description: Subroutines to move VaderCrab
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     MoveVaderCrab
.export     DrawVaderCrab
.export     DrawVaderHitboxDebug

;-------------------------------------------------------------------------------

;----- Assembler Directives ----------------------------------------------------
.p816                           ; tell the assembler this is 65816 code
.a8
.i16
;-------------------------------------------------------------------------------

;----- Includes ----------------------------------------------------------------
.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Util.inc"
;-------------------------------------------------------------------------------

.import VaderCrab
.import BigHero


WALK_SPEED = $01
WALK_ANIM_SPEED = $08 ; quanto menor mais rapido

PREPARING_ANIM_SPEED = 40
PREPARING_DURATION_FRAMES = 120
PREPARING_MAX_FRAMES = 4

;attackin speed e frames. Se for iguais o ataque tem 1 frame. Se forem um metade do outro, dois frames. e assim vai
ATTACKING_ANIM_SPEED = 30   
ATTACKING_DURATION_FRAMES = 60
ATTACK_MAX_FRAMES = 2  ; Altere este número para quantos frames a arte tiver! (3, 4, 5...)

REST_TIME = 30 ;  

.segment "CODE"
;-------------------------------------------------------------------------------
;   This subroutines move enemy
;-------------------------------------------------------------------------------
.proc   MoveVaderCrab
    ; 1. Reduz o timer de animacao
 


AttackFrameUpdate:
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_ATACKING
    beq @ProcessandoAtaque
    brl PreparingFrameUpdate ; se nao esta atacando, vai ver a animacao de prepare

@ProcessandoAtaque:  
    inc VaderCrab + VaderCrabStruct::Attacking_Timer
    lda VaderCrab + VaderCrabStruct::Attacking_Timer
    cmp #ATTACKING_DURATION_FRAMES
    bne AttackingAnim

    ; --- ACABOU O ATAQUE: Limpa e Desativa a Hitbox de Dano ---
    stz VaderCrab + VaderCrabStruct::Hitbox_Active
    ;stz VaderCrab + VaderCrabStruct::Hitbox_X1
    ;stz VaderCrab + VaderCrabStruct::Hitbox_X2
    ;stz VaderCrab + VaderCrabStruct::Hitbox_Y1
    ;stz VaderCrab + VaderCrabStruct::Hitbox_Y2

    ;Acabou o ataque. Volta pro prepare
    lda #STATE_PREPARING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Attacking_Timer ;zera o timer. Acabou o ataque ne...
    brl Move ;Antes de voltar pro prepare, se se o maluco saiu fora

AttackingAnim:
    dec VaderCrab + VaderCrabStruct::Attacking_Anim_Timer
    beq ContinueAttackAnim ;gambiarra para erro de range
    brl Move ; Se nao chegou a zero, nao faz nada ainda.
ContinueAttackAnim:
    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #ATTACKING_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta VaderCrab + VaderCrabStruct::Attacking_Anim_Timer
    
   ; 2. Avança de forma linear para o próximo frame
    lda VaderCrab + VaderCrabStruct::Attacking_Anim_Frame
    clc
    adc #1                          ; Incrementa o ID do frame (+1)
    
    ; 3. COMPARAÇÃO COM O TETO (Módulo Dinâmico)
    cmp #ATTACK_MAX_FRAMES          ; Checa se atingiu o limite de N frames da arte
    bcc @SaveFrame                  ; Se for MENOR, pula o reset e salva direto
    
    lda #0                          ; Se for IGUAL, estourou a animação! Reseta para o frame 0

@SaveFrame:
    sta VaderCrab + VaderCrabStruct::Attacking_Anim_Frame

@AtualizarHitbox:
    ; =========================================================================
    ; 🦀 GERADOR DINÂMICO DE HITBOX (CONCEITO DE CAIXA DE COLISÃO)
    ; =========================================================================
    ; Só queremos ativar o rastro de dano no Frame 1 (quando ele realmente estica a garra)
    lda VaderCrab + VaderCrabStruct::Attacking_Anim_Frame
    cmp #1
    beq @AtivarHitbox
    
    ; Se for Frame 0 (recolhendo a garra), desativa a hitbox temporariamente
    stz VaderCrab + VaderCrabStruct::Hitbox_Active
    brl Move


    ;brl Move ;Ataquei Pulo o prepare e vejo se o hero fugiu

@AtivarHitbox:
    lda #1
    sta VaderCrab + VaderCrabStruct::Hitbox_Active

    ; --- 1. Definir os limites Verticais (Eixo Y) ---
    ; A garra atinge a altura do corpo dele. Vamos pegar o Y dele e dar uma altura de 16 pixels
    lda VaderCrab + VaderCrabStruct::Y_Pos
    clc
    adc #16                             ; Margem superior da garra
    sta VaderCrab + VaderCrabStruct::Hitbox_Y1
    clc
    adc #16                             ; Caixa com 16 pixels de altura vertical
    sta VaderCrab + VaderCrabStruct::Hitbox_Y2

    ; --- 2. Definir os limites Horizontais (Eixo X) com base no Lado (Facing) ---
    lda VaderCrab + VaderCrabStruct::Facing
    bne @HitboxDireita                  ; Se Facing != 0 (Olhando para a Direita)

@HitboxEsquerda:
    ; Se está olhando para a esquerda, a garra projeta-se à esquerda do X_Pos dele
    lda VaderCrab + VaderCrabStruct::X_Pos
    sec
    sbc #32                            ; A garra estica 16 pixels para fora do corpo dele
    sta VaderCrab + VaderCrabStruct::Hitbox_X1
    
    lda VaderCrab + VaderCrabStruct::X_Pos ; O limite direito da garra morre no próprio corpo
    sta VaderCrab + VaderCrabStruct::Hitbox_X2
    brl Move

@HitboxDireita:
    ; Se está olhando para a direita, a garra projeta-se à direita do corpo de 64px de largura
    lda VaderCrab + VaderCrabStruct::X_Pos
    clc
    adc #64                             ; Começa perto do fim do corpo
    sta VaderCrab + VaderCrabStruct::Hitbox_X1
    clc
    adc #32                             ; Estica mais 24 pixels para a direita
    sta VaderCrab + VaderCrabStruct::Hitbox_X2
    brl Move

PreparingFrameUpdate:
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_PREPARING
    bne WalkFrameUpdate ; se nao esta Preparando, vai ver a animacao de andar
    ;aqui vou colocar o codigo para PreparingFrameUpdate
    
    inc VaderCrab + VaderCrabStruct::Preparing_Timer
    lda VaderCrab + VaderCrabStruct::Preparing_Timer
    cmp #PREPARING_DURATION_FRAMES
    bne PreparingAnim
 
    lda #STATE_ATACKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer
    brl Done

PreparingAnim:
    dec VaderCrab + VaderCrabStruct::Preparing_Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda

    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #PREPARING_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta VaderCrab + VaderCrabStruct::Preparing_Anim_Timer
    
   ; 2. Avança de forma linear para o próximo frame
    lda VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
    clc
    adc #1                          ; Incrementa o ID do frame (+1)
    
    ; 3. COMPARAÇÃO COM O TETO (Módulo Dinâmico)
    cmp #PREPARING_MAX_FRAMES          ; Checa se atingiu o limite de N frames da arte
    bcc @SaveFramePrep                  ; Se for MENOR, pula o reset e salva direto
    
    lda #0                          ; Se for IGUAL, estourou a animação! Reseta para o frame 0

@SaveFramePrep:
    sta VaderCrab + VaderCrabStruct::Preparing_Anim_Frame




 WalkFrameUpdate:
    ; 1. Decrementa o timer do descanso direto na memória RAM
    DEC VaderCrab + VaderCrabStruct::Resting_Timer
    ; 2. Checa o resultado usando a Negative Flag (N) que o DEC acabou de afetar
    BMI ContinueWalkFrameUpdate
    BRL RestFrameUpdate    ; Se N=0 (Valores de 127 a 0), pula para a rotina de descanso
    
   
 ContinueWalkFrameUpdate:
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_WALKING
    bne Move 

    dec VaderCrab + VaderCrabStruct::Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda
    
    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #WALK_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta VaderCrab + VaderCrabStruct::Anim_Timer
    
    ; 3. Alterna o Frame (Se era 0 vira 1, se era 1 vira 0)
    lda VaderCrab + VaderCrabStruct::Anim_Frame
    eor #$01 ; Logica XOR inverte o bit 0 perfeitamente (0 <-> 1)
    sta VaderCrab + VaderCrabStruct::Anim_Frame

;=== logica para mover
;=== logica para mover
Move:
    ; 1. Calcular a distância absoluta em X: |VaderCrab_X - BigHero_X|
    lda VaderCrab + VaderCrabStruct::X_Pos
    clc
    adc #16                          ; Ajusta o centro do VaderCrab em relação ao Hero. Hero 16, Vader 32. Dist = Vader + 32 - Hero + 16 -> Dist = Vader + 16
    sec
    sbc BigHero + BigHeroStruct::X_Pos
    bcs CalculateAbsoluteDistance   ; Se VaderCrab_X >= BigHero_X, o resultado já é positivo

    ; Se for negativo, aplica o complemento de 2 para positivar o valor (Módulo)
    eor #$FF                
    clc
    adc #1                  

CalculateAbsoluteDistance:   
    ; Agora o Acumulador contém a distância real em pixels no eixo X
    cmp #ENEMY_ATTACK_DISTANCE
    bcc StopHorizontalMove  ; Se a distância for MENOR que a de ataque, PARA de andar em X
    beq StopHorizontalMove  ; Se for IGUAL, também PARA e fica na distância ideal

    ; Se a distância for maior que o alcance, decide para qual lado andar
    lda VaderCrab + VaderCrabStruct::X_Pos
    cmp BigHero + BigHeroStruct::X_Pos
    bcc WalkRight           ; Se VaderCrab_X < BigHero_X, vai para a direita

WalkLeft:
    sec
    sbc #WALK_SPEED                 ; Move 1 pixel por frame para a esquerda
    sta VaderCrab + VaderCrabStruct::X_Pos
    
    ;lda #WALK_ANIM_SPEED
    ;sta VaderCrab + VaderCrabStruct::Walk_Anim_Speed
    stz VaderCrab + VaderCrabStruct::Facing ;Olhando para a esquerda

    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer

    bra CheckVerticalMove
    
WalkRight:
    clc
    adc #WALK_SPEED                  ; Move 1 pixel por frame para a direita
    sta VaderCrab + VaderCrabStruct::X_Pos
    
    ;lda #WALK_ANIM_SPEED
    ;sta VaderCrab + VaderCrabStruct::Walk_Anim_Speed
    lda #1
    sta VaderCrab + VaderCrabStruct::Facing ;Olhando para a direita
    
    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer

    bra CheckVerticalMove

StopHorizontalMove:
    ; Espaço reservado: Aqui você poderá setar o State de ataque no futuro
    ;stz VaderCrab + VaderCrabStruct::Walk_Anim_Speed
    
    lda #STATE_ATACKING
    cmp VaderCrab + VaderCrabStruct::State
    beq CheckVerticalMove
    
    lda #STATE_PREPARING
    sta VaderCrab + VaderCrabStruct::State

CheckVerticalMove:

    ; === Alinhamento no Eixo Y com tolerancia===
     ; === 1. Calcular a distância absoluta em Y: |VaderCrab_Y - BigHero_Y|
    lda VaderCrab + VaderCrabStruct::Y_Pos
    sec
    sbc BigHero + BigHeroStruct::Y_Pos
    bcs CalculateAbsoluteY          ; Se VaderCrab_Y >= BigHero_Y, o resultado já é positivo

    ; Se for negativo, aplica o complemento de 2 para positivar o valor (Módulo)
    eor #$FF                
    clc
    adc #1 

CalculateAbsoluteY:
    ; Agora o Acumulador contém a distância vertical exata em pixels
    cmp #ENEMY_ATTACK_Y_RANGE
    bcc StopVerticalMove            ; Se a distância for MENOR que o range, o Y está alinhado!
    beq StopVerticalMove            ; Se for IGUAL ao range, também está alinhado e PARA

    ; === 2. Fora do Range: Decidir se deve subir ou descer ===
    lda VaderCrab + VaderCrabStruct::Y_Pos
    cmp BigHero + BigHeroStruct::Y_Pos    
    bcc MoveDown                    ; Se VaderCrab_Y < BigHero_Y, ele está acima, então desce (+1)


    lda VaderCrab + VaderCrabStruct::Y_Pos
    cmp BigHero + BigHeroStruct::Y_Pos    
    beq ExitMovement        ; Se igual, mantém
    bcc MoveDown            ; Se VaderCrab_Y < BigHero_Y, ele está ACIMA, então deve DESCER (+1)

MoveUp:
    sec
    sbc #WALK_SPEED                  ; Está abaixo, então SOBE (-1) em direção ao herói
    sta VaderCrab + VaderCrabStruct::Y_Pos
    
    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer
    bra ExitMovement
    
MoveDown:
    clc
    adc #WALK_SPEED                  ; Está acima, então DESCE (+1) em direção ao herói
    sta VaderCrab + VaderCrabStruct::Y_Pos
    
    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer
    bra ExitMovement
    
StopVerticalMove:
    ; O Y está perfeitamente dentro da janela de ataque! 
    ; Não altera a posição Y neste frame, mantendo o inimigo estável na linha.
    


    lda #STATE_ATACKING
    cmp VaderCrab + VaderCrabStruct::State
    beq Done

    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_WALKING
    beq ExitMovement

    lda #STATE_PREPARING
    sta VaderCrab + VaderCrabStruct::State

ExitMovement:
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_WALKING
    bne Done
    lda #WALK_ANIM_SPEED
    sta VaderCrab + VaderCrabStruct::Walk_Anim_Speed
    bra Done

RestFrameUpdate:
    ;decrementa mais, para ficar mais tempo andando que descansando
    DEC VaderCrab + VaderCrabStruct::Resting_Timer
    
    jsr rand            ; Chama a sua rotina aleatória. Retorna valor em A (8-bits ativo aqui)
    and #$10            ; Isola o primeiro bit (Resultado será apenas 0 ou 1)
    beq RestFrameUpdate ; Se for 1 (50% de chance), ele desiste do ataque neste ciclo!

    
    lda #STATE_RESTING
    sta VaderCrab + VaderCrabStruct::State
    
    bra Done

DesistirMover:
Done:
    rts
               
                               
.endproc
;-------------------------------------------------------------------------------

; Formato por linha: Offset_X, Offset_Y, Tile_ID, Atributos(Paleta/Flip)
VaderCrab_Layout:
    ; === CABECA (4x2 de 16) ===
    .byte 0,  0,  $EE, $01     ; pedaco 1-1
    .byte 16,  0,  $00, $01     ; pedaco 1-2
    .byte 32,  0,  $02, $01     ; pedaco 1-3
    .byte 48,  0,  $EE, $01     ; pedaco 1-4
    
    .byte 0,  16,  $EE, $01     ; pedaco 2-1
    .byte 16,  16,  $20, $01     ; pedaco 2-2
    .byte 32,  16,  $22, $01     ; pedaco 2-3
    .byte 48,  16,  $EE, $01     ; pedaco 2-4

    ; === CORPO (4x2 de 16) ===
    .byte 0,  32,  $64, $00     ; pedaco 1-1
    .byte 16,  32,  $66, $00     ; pedaco 1-2
    .byte 32,  32,  $68, $00     ; pedaco 1-3
    .byte 48,  32,  $6A, $00     ; pedaco 1-4
    
    .byte 0,  48,  $84, $00     ; pedaco 2-1
    .byte 16,  48,  $86, $00     ; pedaco 2-2
    .byte 32,  48,  $88, $00     ; pedaco 2-3
    .byte 48,  48,  $8A, $00     ; pedaco 2-4

; =============================================================================
; FRAME 1: INIMIGO ANDANDO (Proximas posicoes livres de Tile)
; =============================================================================
VaderCrab_Layout_Frame1:
    ; === CABECA (4x2 de 16) ===
    .byte 0,  0,  $EE, $01     ; pedaco 1-1
    .byte 16,  0,  $00, $01     ; pedaco 1-2
    .byte 32,  0,  $02, $01     ; pedaco 1-3
    .byte 48,  0,  $EE, $01     ; pedaco 1-4
    
    .byte 0,  16,  $EE, $01     ; pedaco 2-1
    .byte 16,  16,  $20, $01     ; pedaco 2-2
    .byte 32,  16,  $22, $01     ; pedaco 2-3
    .byte 48,  16,  $EE, $01     ; pedaco 2-4

    ; === CORPO (4x2 de 16) ===
    .byte 0,  32,  $A5, $00     ; pedaco 1-1
    .byte 16,  32,  $A7, $00     ; pedaco 1-2
    .byte 32,  32,  $A9, $00     ; pedaco 1-3
    .byte 48,  32,  $AB, $00     ; pedaco 1-4
    
    .byte 0,  48,  $C5, $00     ; pedaco 2-1
    .byte 16,  48,  $C7, $00     ; pedaco 2-2
    .byte 32,  48,  $C9, $00     ; pedaco 2-3
    .byte 48,  48,  $CB, $00     ; pedaco 2-4

; =============================================================================
; FRAME 0: INIMIGO Preparing 
; =============================================================================
VaderCrab_Layout_FramePreparing0:
    ; === CABECA (4x2 de 16) ===
    .byte 0,  0,  $24, $00     ; pedaco 1-1
    .byte 16,  0,  $2C, $00     ; pedaco 1-2
    .byte 32,  0,  $28, $00     ; pedaco 1-3
    .byte 48,  0,  $2A, $00     ; pedaco 1-4
    
    .byte 0,  16,  $44, $00     ; pedaco 2-1
    .byte 16,  16,  $46, $00     ; pedaco 2-2
    .byte 32,  16,  $48, $00     ; pedaco 2-3
    .byte 48,  16,  $4A, $00     ; pedaco 2-4

    ; === CORPO (4x2 de 16) ===
    .byte 0,  32,  $A5, $00     ; pedaco 1-1
    .byte 16,  32,  $A9, $00     ; pedaco 1-2
    .byte 32,  32,  $A7, $00     ; pedaco 1-3
    .byte 48,  32,  $AB, $00     ; pedaco 1-4
    
    .byte 0,  48,  $C5, $00     ; pedaco 2-1
    .byte 16,  48,  $C9, $00     ; pedaco 2-2
    .byte 32,  48,  $C7, $00     ; pedaco 2-3
    .byte 48,  48,  $CB, $00     ; pedaco 2-4

; =============================================================================
; FRAME 1: INIMIGO Preparing 
; =============================================================================
VaderCrab_Layout_FramePreparing1:
    ; === CABECA (4x2 de 16) ===
    .byte 0,  0,  $24, $00     ; pedaco 1-1
    .byte 16,  0,  $2C, $00     ; pedaco 1-2
    .byte 32,  0,  $2E, $00     ; pedaco 1-3
    .byte 48,  0,  $2A, $00     ; pedaco 1-4
    
    .byte 0,  16,  $44, $00     ; pedaco 2-1
    .byte 16,  16,  $46, $00     ; pedaco 2-2
    .byte 32,  16,  $48, $00     ; pedaco 2-3
    .byte 48,  16,  $4A, $00     ; pedaco 2-4

    ; === CORPO (4x2 de 16) ===
    .byte 0,  32,  $A5, $00     ; pedaco 1-1
    .byte 16,  32,  $A9, $00     ; pedaco 1-2
    .byte 32,  32,  $A7, $00     ; pedaco 1-3
    .byte 48,  32,  $AB, $00     ; pedaco 1-4
    
    .byte 0,  48,  $C5, $00     ; pedaco 2-1
    .byte 16,  48,  $C9, $00     ; pedaco 2-2
    .byte 32,  48,  $C7, $00     ; pedaco 2-3
    .byte 48,  48,  $CB, $00     ; pedaco 2-4


; =============================================================================
; FRAME 2: INIMIGO Preparing 
; =============================================================================
VaderCrab_Layout_FramePreparing2:
    ; === CABECA (4x2 de 16) ===
    .byte 0,  0,  $24, $00     ; pedaco 1-1
    .byte 16,  0,  $2C, $00     ; pedaco 1-2
    .byte 32,  0,  $2E, $00     ; pedaco 1-3
    .byte 48,  0,  $2A, $00     ; pedaco 1-4
    
    .byte 0,  16,  $44, $00     ; pedaco 2-1
    .byte 16,  16,  $4C, $00     ; pedaco 2-2
    .byte 32,  16,  $48, $00     ; pedaco 2-3
    .byte 48,  16,  $4A, $00     ; pedaco 2-4

    ; === CORPO (4x2 de 16) ===
    .byte 0,  32,  $A5, $00     ; pedaco 1-1
    .byte 16,  32,  $A9, $00     ; pedaco 1-2
    .byte 32,  32,  $A7, $00     ; pedaco 1-3
    .byte 48,  32,  $AB, $00     ; pedaco 1-4
    
    .byte 0,  48,  $C5, $00     ; pedaco 2-1
    .byte 16,  48,  $C9, $00     ; pedaco 2-2
    .byte 32,  48,  $C7, $00     ; pedaco 2-3
    .byte 48,  48,  $CB, $00     ; pedaco 2-4


; =============================================================================
; FRAME 3: INIMIGO Preparing 
; =============================================================================
VaderCrab_Layout_FramePreparing3:
    ; === CABECA (4x2 de 16) ===
    .byte 0,  0,  $24, $00     ; pedaco 1-1
    .byte 16,  0,  $2C, $00     ; pedaco 1-2
    .byte 32,  0,  $2E, $00     ; pedaco 1-3
    .byte 48,  0,  $2A, $00     ; pedaco 1-4
    
    .byte 0,  16,  $44, $00     ; pedaco 2-1
    .byte 16,  16,  $4C, $00     ; pedaco 2-2
    .byte 32,  16,  $4E, $00     ; pedaco 2-3
    .byte 48,  16,  $4A, $00     ; pedaco 2-4

    ; === CORPO (4x2 de 16) ===
    .byte 0,  32,  $A5, $00     ; pedaco 1-1
    .byte 16,  32,  $A9, $00     ; pedaco 1-2
    .byte 32,  32,  $A7, $00     ; pedaco 1-3
    .byte 48,  32,  $AB, $00     ; pedaco 1-4
    
    .byte 0,  48,  $C5, $00     ; pedaco 2-1
    .byte 16,  48,  $C9, $00     ; pedaco 2-2
    .byte 32,  48,  $C7, $00     ; pedaco 2-3
    .byte 48,  48,  $CB, $00     ; pedaco 2-4


; =============================================================================
; FRAME 0: INIMIGO Attacking 
; =============================================================================
VaderCrab_Layout_FrameAttacking0:
    ; === CABECA (4x2 de 16) ===
    .byte 0,  0,  $44, $00     ; pedaco 1-1
    .byte 16,  0,  $28, $00     ; pedaco 1-2
    .byte 32,  0,  $26, $00     ; pedaco 1-3
    .byte 48,  0,  $4A, $00     ; pedaco 1-4
    
    .byte 0,  16,  $A5, $00     ; pedaco 2-1
    .byte 16,  16,  $48, $00     ; pedaco 2-2
    .byte 32,  16,  $46, $00     ; pedaco 2-3
    .byte 48,  16,  $AB, $00     ; pedaco 2-4

    ; === CORPO (4x2 de 16) ===
    .byte 0,  32,  $A5, $00     ; pedaco 1-1
    .byte 16,  32,  $A9, $00     ; pedaco 1-2
    .byte 32,  32,  $A7, $00     ; pedaco 1-3
    .byte 48,  32,  $AB, $00     ; pedaco 1-4
    
    .byte 0,  48,  $C5, $00     ; pedaco 2-1
    .byte 16,  48,  $C9, $00     ; pedaco 2-2
    .byte 32,  48,  $C7, $00     ; pedaco 2-3
    .byte 48,  48,  $CB, $00     ; pedaco 2-4

; =============================================================================
; FRAME 1: INIMIGO Attacking 
; =============================================================================
VaderCrab_Layout_FrameAttacking1:
    ; === CABECA (4x2 de 16) ===
    .byte 0,  0,  $28, $00     ; pedaco 1-1
    .byte 16,  0,  $A9, $00     ; pedaco 1-2
    .byte 32,  0,  $26, $00     ; pedaco 1-3
    .byte 48,  0,  $22, $00     ; pedaco 1-4
    
    .byte 0,  16,  $CB, $00     ; pedaco 2-1
    .byte 16,  16,  $48, $00     ; pedaco 2-2
    .byte 32,  16,  $C5, $00     ; pedaco 2-3
    .byte 48,  16,  $44, $00     ; pedaco 2-4

    ; === CORPO (4x2 de 16) ===
    .byte 0,  32,  $AB, $00     ; pedaco 1-1
    .byte 16,  32,  $A9, $00     ; pedaco 1-2
    .byte 32,  32,  $26, $00     ; pedaco 1-3
    .byte 48,  32,  $A5, $00     ; pedaco 1-4
    
    .byte 0,  48,  $CB, $00     ; pedaco 2-1
    .byte 16,  48,  $24, $00     ; pedaco 2-2
    .byte 32,  48,  $22, $00     ; pedaco 2-3
    .byte 48,  48,  $C5, $00     ; pedaco 2-4


;-------------------------------------------------------------------------------
;   DrawVaderCrab
;-------------------------------------------------------------------------------
.proc DrawVaderCrab

        ldy #$0000              ; Indice Y vai caminhar pela tabela de Layout

DrawLoop:
        ; === 1. PROCESSAR POSIÇÃO X COM ESPELHAMENTO ===
        lda VaderCrab + VaderCrabStruct::Facing
        bne DrawXNormal         ; Se Facing != 0 (Direita/Padrão), pula para o cálculo normal

DrawXInverted:
        ; Se estiver olhando para a esquerda, aplica a inversão de colunas:
        ; X_Global + (Largura_Total - 16) - Offset_X_Do_Bloco
        ; Para 64px de largura, (Largura_Total - 16) = 48
        lda #48
        sec
        sbc VaderCrab_Layout, Y ; Subtrai o Offset X atual (0, 16, 32 ou 48)
        clc
        adc VaderCrab + VaderCrabStruct::X_Pos ; Soma a ancoragem global
        sta OAMMIRROR, X
        bra ProcessY

DrawXNormal:
        clc
        lda VaderCrab + VaderCrabStruct::X_Pos    
        adc VaderCrab_Layout, Y ; Le o Offset X padrão (Y + 0)
        sta OAMMIRROR, X                          

ProcessY:
        inx                                       
        iny                     ; Aponta para o Offset Y (Y + 1)

; === 2. PROCESSAR POSIÇÃO Y ===
        clc
        lda VaderCrab + VaderCrabStruct::Y_Pos    
        adc VaderCrab_Layout, Y ; Le o Offset Y (Y + 1)
        sta OAMMIRROR, X                          
        inx
        iny                     ; Aponta para o Tile ID (Y + 2)

; === 3. SELEÇÃO DINÂMICA DE TILE ID BASEADO NO FRAME ===

        lda VaderCrab + VaderCrabStruct::State
        cmp #STATE_PREPARING
        beq DrawPreparing
        cmp #STATE_ATACKING
        beq DrawAttacking
        bra DrawWalking

DrawPreparing:        
        lda VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
        cmp #1
        beq JumpToFramePreparing1
        cmp #2
        beq JumpToFramePreparing2
        cmp #3
        beq JumpToFramePreparing3

FramePreparing0:
        lda VaderCrab_Layout_FramePreparing0, Y
        bra WriteTile

JumpToFramePreparing1:
        lda VaderCrab_Layout_FramePreparing1, Y
        bra WriteTile

JumpToFramePreparing2:
        lda VaderCrab_Layout_FramePreparing2, Y
        bra WriteTile

JumpToFramePreparing3:
        lda VaderCrab_Layout_FramePreparing3, Y
        bra WriteTile


DrawAttacking:

        stz VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
        lda VaderCrab + VaderCrabStruct::Attacking_Anim_Frame
        beq FrameAttacking0

FrameAttacking1:
        lda VaderCrab_Layout_FrameAttacking1, Y        ; Le o Tile ID do Layout 1 (Y + 2)
        bra WriteTile

FrameAttacking0:
        lda VaderCrab_Layout_FrameAttacking0, Y               ; Le o Tile ID do Layout 0 (Y + 2)
        bra WriteTile

DrawWalking:
        stz VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
        stz VaderCrab + VaderCrabStruct::Attacking_Anim_Frame
        
        lda VaderCrab + VaderCrabStruct::Anim_Frame
        beq Frame0
    
Frame1:
        lda VaderCrab_Layout_Frame1, Y        ; Le o Tile ID do Layout 1 (Y + 2)
        bra WriteTile

Frame0:
        lda VaderCrab_Layout, Y               ; Le o Tile ID do Layout 0 (Y + 2)

WriteTile:
        sta OAMMIRROR, X
        inx
        iny                     ; Aponta para os Atributos (Y + 3)

        ; === 4. PROCESSAR ATRIBUTOS E INJETAR H-FLIP HIERÁRQUICO ===
        lda VaderCrab_Layout, Y ; Le o Atributo original (Y + 3)
        
        ; Protege o registrador Y empilhando-o para não quebrar o loop de leitura
        phy                     
        
        lda VaderCrab + VaderCrabStruct::Facing
        bne @NoFlip             ; Se Facing != 0 (Direita), mantém a paleta padrão intacta

@ApplyFlip:
        lda VaderCrab_Layout, Y ; Recarrega o atributo original no acumulador
        ora #%01000000          ; Injeta o Bit 6 (Horizontal Flip) via hardware da PPU
        bra @SaveAttributes

@NoFlip:
        lda VaderCrab_Layout, Y ; Garante o atributo limpo original se estiver para a direita

@SaveAttributes:
        ply                     ; Restaura o ponteiro Y original de volta para o registrador
        sta OAMMIRROR, X        ; Grava na OAM física do espelho
        
        inx
        iny                     ; Avança para o proximo bloco (X do proximo sprite)

        ; Checa se ja desenhou todos os 16 blocos do inimigo (16 * 4 = 64 bytes lidos)
        cpy #64                 
        beq @Finish
        brl DrawLoop ; tinha que ser somengte bne, mas da erro de range, entao tem que fazer essa gambiarra
@Finish:
        rts
.endproc



;---------------- DEBUG ---------------
.proc DrawVaderHitboxDebug
    ; Primeiro, checa se a hitbox está ativa. Se não estiver, não desenha nada!
    ;lda VaderCrab + VaderCrabStruct::Hitbox_Active
    ;bne @Desenhar
    ;rts

@Desenhar:
    ; --- SPRITE 1 (Lado Esquerdo da Hitbox) ---
    ; Posição X
    lda VaderCrab + VaderCrabStruct::Hitbox_X1
    sta a:OAMMIRROR, X
    inx
    
    ; Posição Y
    lda VaderCrab + VaderCrabStruct::Hitbox_Y1
    sta a:OAMMIRROR, X
    inx
    
    ; Tile ID (Substitua por um ID de tile quadrado do seu jogo)
    lda #$A0            ; Exemplo: tile $FE é um quadrado vermelho/branco
    sta a:OAMMIRROR, X
    inx
    
    ; Atributos (Paleta de debug para ficar visível)
    lda #$31      ; Escolha uma paleta com cor forte (ex: Paleta 4, prioridade alta)
    sta a:OAMMIRROR, X
    inx

    ; --- SPRITE 2 --
    ; Posição X
    lda VaderCrab + VaderCrabStruct::Hitbox_X2
    ;sec
    ;sbc #16
    sta a:OAMMIRROR, X
    inx
    
    ; Posição Y (Mesmo Y)
    lda VaderCrab + VaderCrabStruct::Hitbox_Y2
    sta a:OAMMIRROR, X
    inx
    
    ; Mesmo Tile ID
    lda #$A2            
    sta a:OAMMIRROR, X
    inx
    
    ; Mesmo Atributo
    lda #$31      
    sta OAMMIRROR, X    
    inx

    rts
.endproc


;------------FIM DEBUG -------------