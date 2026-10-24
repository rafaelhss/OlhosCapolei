; -----------------------------------------------------------------------------
;   File: PennyCrab.s
;   Description: Subroutines to move PennyCrab (Com Inteligência de Rest)
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     MovePennyCrab
.export     DrawPennyCrab
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

.import PennyCrab
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


.segment "CODE"
;-------------------------------------------------------------------------------
;   This subroutines move enemy
;-------------------------------------------------------------------------------
.proc   MovePennyCrab
    ; 1. Reduz o timer de animacao
 


AttackFrameUpdate:
    lda PennyCrab + PennyCrabStruct::State
    cmp #STATE_ATACKING
    bne PreparingFrameUpdate ; se nao esta atacando, vai ver a animacao de prepare
     
    inc PennyCrab + PennyCrabStruct::Attacking_Timer
    lda PennyCrab + PennyCrabStruct::Attacking_Timer
    cmp #ATTACKING_DURATION_FRAMES
    bne AttackingAnim
    ;Acabou o ataque. Volta pro prepare
    lda #STATE_PREPARING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Attacking_Timer ;zera o timer. Acabou o ataque ne...
    brl Move ;Antes de voltar pro prepare, se se o maluco saiu fora

AttackingAnim:
    dec PennyCrab + PennyCrabStruct::Attacking_Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda

    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #ATTACKING_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta PennyCrab + PennyCrabStruct::Attacking_Anim_Timer
    
   ; 2. Avança de forma linear para o próximo frame
    lda PennyCrab + PennyCrabStruct::Attacking_Anim_Frame
    clc
    adc #1                          ; Incrementa o ID do frame (+1)
    
    ; 3. COMPARAÇÃO COM O TETO (Módulo Dinâmico)
    cmp #ATTACK_MAX_FRAMES          ; Checa se atingiu o limite de N frames da arte
    bcc @SaveFrame                  ; Se for MENOR, pula o reset e salva direto
    
    lda #0                          ; Se for IGUAL, estourou a animação! Reseta para o frame 0

@SaveFrame:
    sta PennyCrab + PennyCrabStruct::Attacking_Anim_Frame

    brl Move ;Ataquei Pulo o prepare e vejo se o hero fugiu

PreparingFrameUpdate:
    lda PennyCrab + PennyCrabStruct::State
    cmp #STATE_PREPARING
    bne WalkFrameUpdate ; se nao esta Preparando, vai ver a animacao de andar
    ;aqui vou colocar o codigo para PreparingFrameUpdate
    
    inc PennyCrab + PennyCrabStruct::Preparing_Timer
    lda PennyCrab + PennyCrabStruct::Preparing_Timer
    cmp #PREPARING_DURATION_FRAMES
    bne PreparingAnim
 
    lda #STATE_ATACKING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Preparing_Timer
    brl Done

PreparingAnim:
    dec PennyCrab + PennyCrabStruct::Preparing_Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda

    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #PREPARING_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta PennyCrab + PennyCrabStruct::Preparing_Anim_Timer
    
   ; 2. Avança de forma linear para o próximo frame
    lda PennyCrab + PennyCrabStruct::Preparing_Anim_Frame
    clc
    adc #1                          ; Incrementa o ID do frame (+1)
    
    ; 3. COMPARAÇÃO COM O TETO (Módulo Dinâmico)
    cmp #PREPARING_MAX_FRAMES          ; Checa se atingiu o limite de N frames da arte
    bcc @SaveFramePrep                  ; Se for MENOR, pula o reset e salva direto
    
    lda #0                          ; Se for IGUAL, estourou a animação! Reseta para o frame 0

@SaveFramePrep:
    sta PennyCrab + PennyCrabStruct::Preparing_Anim_Frame



 WalkFrameUpdate:
    ; =========================================================================
    ; 💤 ADICIONADO: INTELIGÊNCIA DE DESCANSO AUTOMÁTICO (UNDERFLOW LOGIC)
    ; =========================================================================
    ; 1. Decrementa o timer do descanso direto na memória RAM do PennyCrab
    dec PennyCrab + PennyCrabStruct::Resting_Timer
    
    ; 2. Checa o resultado usando a Negative Flag (N) que o DEC acabou de afetar
    bmi ContinueWalkFrameUpdate     ; Se N=1 (Valores de 255 a 128), continua para andar
    brl RestFrameUpdate            ; Se N=0 (Valores de 127 a 0), pula para o descanso
    
ContinueWalkFrameUpdate:
     ; Se a velocidade atual for zero, pula o decremento e congela a animação no frame atual
    lda PennyCrab + PennyCrabStruct::State
    cmp #STATE_WALKING
    bne Move 

    dec PennyCrab + PennyCrabStruct::Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda
    
    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #WALK_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta PennyCrab + PennyCrabStruct::Anim_Timer
    
    ; 3. Alterna o Frame (Se era 0 vira 1, se era 1 vira 0)
    lda PennyCrab + PennyCrabStruct::Anim_Frame
    eor #$01 ; Logica XOR inverte o bit 0 perfeitamente (0 <-> 1)
    sta PennyCrab + PennyCrabStruct::Anim_Frame

;=== logica para mover
;=== logica para mover
Move:
    ; 1. Calcular a distância absoluta em X: |PennyCrab_X - BigHero_X|
    lda PennyCrab + PennyCrabStruct::X_Pos
    clc
    adc #16                          ; Ajusta o centro do PennyCrab em relação ao Hero. Hero 16, penny 32. Dist = Penny + 32 - Hero + 16 -> Dist = Penny + 16
    sec
    sbc BigHero + BigHeroStruct::X_Pos
    bcs CalculateAbsoluteDistance   ; Se PennyCrab_X >= BigHero_X, o resultado já é positivo

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
    lda PennyCrab + PennyCrabStruct::X_Pos
    cmp BigHero + BigHeroStruct::X_Pos
    bcc WalkRight           ; Se PennyCrab_X < BigHero_X, vai para a direita

WalkLeft:
    sec
    sbc #WALK_SPEED                 ; Move usando a constante de velocidade para a esquerda
    sta PennyCrab + PennyCrabStruct::X_Pos
    
    stz PennyCrab + PennyCrabStruct::Facing ;Olhando para a esquerda

    lda #STATE_WALKING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Preparing_Timer

    bra CheckVerticalMove
    
WalkRight:
    clc
    adc #WALK_SPEED                  ; Move usando a constante de velocidade para a direita
    sta PennyCrab + PennyCrabStruct::X_Pos
    
    lda #1
    sta PennyCrab + PennyCrabStruct::Facing ;Olhando para a direita
    
    lda #STATE_WALKING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Preparing_Timer

    bra CheckVerticalMove

StopHorizontalMove:
    lda #STATE_ATACKING
    cmp PennyCrab + PennyCrabStruct::State
    beq CheckVerticalMove
    
    lda #STATE_PREPARING
    sta PennyCrab + PennyCrabStruct::State

CheckVerticalMove:
    ; === Alinhamento no Eixo Y com tolerancia===
     ; === 1. Calcular a distância absoluta em Y: |PennyCrab_Y - BigHero_Y|
    lda PennyCrab + PennyCrabStruct::Y_Pos
    sec
    sbc BigHero + BigHeroStruct::Y_Pos
    bcs CalculateAbsoluteY          ; Se PennyCrab_Y >= BigHero_Y, o resultado já é positivo

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
    lda PennyCrab + PennyCrabStruct::Y_Pos
    cmp BigHero + BigHeroStruct::Y_Pos    
    bcc MoveDown                    ; Se PennyCrab_Y < BigHero_Y, ele está acima, então desce (+1)


    lda PennyCrab + PennyCrabStruct::Y_Pos
    cmp BigHero + BigHeroStruct::Y_Pos    
    beq ExitMovement        ; Se igual, mantém
    bcc MoveDown            ; Se PennyCrab_Y < BigHero_Y, ele está ACIMA, então deve DESCER (+1)

MoveUp:
    sec
    sbc #WALK_SPEED                  ; Está abaixo, então SOBE em direção ao herói
    sta PennyCrab + PennyCrabStruct::Y_Pos
    
    lda #STATE_WALKING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Preparing_Timer
    bra ExitMovement
    
MoveDown:
    clc
    adc #WALK_SPEED                  ; Está acima, então DESCE em direção ao herói
    sta PennyCrab + PennyCrabStruct::Y_Pos
    
    lda #STATE_WALKING
    sta PennyCrab + PennyCrabStruct::State
stz PennyCrab + PennyCrabStruct::Preparing_Timer
bra ExitMovement
StopVerticalMove:
; O Y está perfeitamente dentro da janela de ataque!
lda #STATE_ATACKING
cmp PennyCrab + PennyCrabStruct::State
beq Done
lda PennyCrab + PennyCrabStruct::State
cmp #STATE_WALKING
beq ExitMovement
lda #STATE_PREPARING
sta PennyCrab + PennyCrabStruct::State
ExitMovement:
lda PennyCrab + PennyCrabStruct::State
cmp #STATE_WALKING
bne Done
lda #WALK_ANIM_SPEED
sta PennyCrab + PennyCrabStruct::Walk_Anim_Speed
bra Done
Preparing:
stz PennyCrab + PennyCrabStruct::Walk_Anim_Speed
; =========================================================================
; 💤 BLOCO DE ATUALIZAÇÃO DO DESCANSO (IGUAL AO DO VADERCRAB)
; =========================================================================
RestFrameUpdate:
    lda #STATE_RESTING
    sta PennyCrab + PennyCrabStruct::State
    bra Done
Done:
rts
.endproc
;-------------------------------------------------------------------------------
; Formato por linha: Offset_X, Offset_Y, Tile_ID, Atributos(Paleta/Flip)
PennyCrab_Layout:
; === CABECA (4x2 de 16) ===
.byte 0,  0,  $24, $00     ; pedaco 1-1
.byte 16,  0,  $26, $00     ; pedaco 1-2
.byte 32,  0,  $28, $00     ; pedaco 1-3
.byte 48,  0,  $2A, $00     ; pedaco 1-4
.byte 0,  16,  $44, $00     ; pedaco 2-1
.byte 16,  16,  $46, $00     ; pedaco 2-2
.byte 32,  16,  $48, $00     ; pedaco 2-3
.byte 48,  16,  $4A, $00     ; pedaco 2-4
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
PennyCrab_Layout_Frame1:
; === CABECA (4x2 de 16) ===
.byte 0,  0,  $24, $00     ; pedaco 1-1
.byte 16,  0,  $26, $00     ; pedaco 1-2
.byte 32,  0,  $28, $00     ; pedaco 1-3
.byte 48,  0,  $2A, $00     ; pedaco 1-4
.byte 0,  16,  $44, $00     ; pedaco 2-1
.byte 16,  16,  $46, $00     ; pedaco 2-2
.byte 32,  16,  $48, $00     ; pedaco 2-3
.byte 48,  16,  $4A, $00     ; pedaco 2-4
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
PennyCrab_Layout_FramePreparing0:
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
PennyCrab_Layout_FramePreparing1:
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
PennyCrab_Layout_FramePreparing2:
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
PennyCrab_Layout_FramePreparing3:
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
PennyCrab_Layout_FrameAttacking0:
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
PennyCrab_Layout_FrameAttacking1:
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
;   DrawPennyCrab
;-------------------------------------------------------------------------------
.proc DrawPennyCrab
ldy #$0000              ; Indice Y vai caminhar pela tabela de Layout
DrawLoop:
; === 1. PROCESSAR POSIÇÃO X COM ESPELHAMENTO ===
lda PennyCrab + PennyCrabStruct::Facing
bne DrawXNormal         ; Se Facing != 0 (Direita/Padrão), pula para o cálculo normal
DrawXInverted:
lda #48
sec
sbc PennyCrab_Layout, Y
clc
adc PennyCrab + PennyCrabStruct::X_Pos
sta OAMMIRROR, X
bra ProcessY
DrawXNormal:
clc
lda PennyCrab + PennyCrabStruct::X_Pos
adc PennyCrab_Layout, Y
sta OAMMIRROR, X
ProcessY:
inx
iny
; === 2. PROCESSAR POSIÇÃO Y ===
clc
lda PennyCrab + PennyCrabStruct::Y_Pos
adc PennyCrab_Layout, Y
sta OAMMIRROR, X
inx
iny
; === 3. SELEÇÃO DINÂMICA DE TILE ID BASEADO NO FRAME ===
lda PennyCrab + PennyCrabStruct::State
cmp #STATE_PREPARING
beq DrawPreparing
cmp #STATE_ATACKING
beq DrawAttacking
bra DrawWalking
DrawPreparing:
lda PennyCrab + PennyCrabStruct::Preparing_Anim_Frame
cmp #1
beq JumpToFramePreparing1
cmp #2
beq JumpToFramePreparing2
cmp #3
beq JumpToFramePreparing3
FramePreparing0:
lda PennyCrab_Layout_FramePreparing0, Y
bra WriteTile
JumpToFramePreparing1:
lda PennyCrab_Layout_FramePreparing1, Y
bra WriteTile
JumpToFramePreparing2:
lda PennyCrab_Layout_FramePreparing2, Y
bra WriteTile
JumpToFramePreparing3:
lda PennyCrab_Layout_FramePreparing3, Y
bra WriteTile
DrawAttacking:
stz PennyCrab + PennyCrabStruct::Preparing_Anim_Frame
lda PennyCrab + PennyCrabStruct::Attacking_Anim_Frame
beq FrameAttacking0
FrameAttacking1:
lda PennyCrab_Layout_FrameAttacking1, Y
bra WriteTile
FrameAttacking0:
lda PennyCrab_Layout_FrameAttacking0, Y
bra WriteTile
DrawWalking:
stz PennyCrab + PennyCrabStruct::Preparing_Anim_Frame
stz PennyCrab + PennyCrabStruct::Attacking_Anim_Frame
lda PennyCrab + PennyCrabStruct::Anim_Frame
beq Frame0
Frame1:
lda PennyCrab_Layout_Frame1, Y
bra WriteTile
Frame0:
lda PennyCrab_Layout, Y
WriteTile:
sta OAMMIRROR, X
inx
iny
; === 4. PROCESSAR ATRIBUTOS E INJETAR H-FLIP HIERÁRQUICO ===
lda PennyCrab_Layout, Y
phy
lda PennyCrab + PennyCrabStruct::Facing
bne @NoFlip
@ApplyFlip:
lda PennyCrab_Layout, Y
ora #%01000000
bra @SaveAttributes
@NoFlip:
lda PennyCrab_Layout, Y
@SaveAttributes:
ply
sta OAMMIRROR, X
inx
iny
cpy #64
beq @Finish
brl DrawLoop
@Finish:
rts
.endproc