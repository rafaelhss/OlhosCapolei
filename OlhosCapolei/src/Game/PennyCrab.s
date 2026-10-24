; ---------------- -------------------------------------------------------------
;   File: PennyCrab.s
;   Description: Subroutines to move PennyCrab
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
;-------------------------------------------------------------------------------

.import PennyCrab
.import BigHero



WALK_ANIM_SPEED = $08 ; quanto menor mais rapido
PREPARING_ANIM_SPEED = $08
PREPARING_DURATION_FRAMES = 120

;attackin speed e frames. Se for iguais o ataque tem 1 frame. Se forem um metade do outro, dois frames. e assim vai
ATTACKING_ANIM_SPEED = 7   
ATTACKING_DURATION_FRAMES = 60


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
    
    ; 3. Alterna o Frame (Se era 0 vira 1, se era 1 vira 0)
    lda PennyCrab + PennyCrabStruct::Attacking_Anim_Frame
    eor #$01 ; Logica XOR inverte o bit 0 perfeitamente (0 <-> 1)
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
    
    ; 3. Alterna o Frame (Se era 0 vira 1, se era 1 vira 0)
    lda PennyCrab + PennyCrabStruct::Preparing_Anim_Frame
    eor #$01 ; Logica XOR inverte o bit 0 perfeitamente (0 <-> 1)
    sta PennyCrab + PennyCrabStruct::Preparing_Anim_Frame


 WalkFrameUpdate:
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
    sbc #1                  ; Move 1 pixel por frame para a esquerda
    sta PennyCrab + PennyCrabStruct::X_Pos
    
    ;lda #WALK_ANIM_SPEED
    ;sta PennyCrab + PennyCrabStruct::Walk_Anim_Speed
    stz PennyCrab + PennyCrabStruct::Facing ;Olhando para a esquerda

    lda #STATE_WALKING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Preparing_Timer

    bra CheckVerticalMove
    
WalkRight:
    clc
    adc #1                  ; Move 1 pixel por frame para a direita
    sta PennyCrab + PennyCrabStruct::X_Pos
    
    ;lda #WALK_ANIM_SPEED
    ;sta PennyCrab + PennyCrabStruct::Walk_Anim_Speed
    lda #1
    sta PennyCrab + PennyCrabStruct::Facing ;Olhando para a direita
    
    lda #STATE_WALKING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Preparing_Timer

    bra CheckVerticalMove

StopHorizontalMove:
    ; Espaço reservado: Aqui você poderá setar o State de ataque no futuro
    ;stz PennyCrab + PennyCrabStruct::Walk_Anim_Speed
    
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
    sbc #1                  ; Está abaixo, então SOBE (-1) em direção ao herói
    sta PennyCrab + PennyCrabStruct::Y_Pos
    
    lda #STATE_WALKING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Preparing_Timer
    bra ExitMovement
    
MoveDown:
    clc
    adc #1                  ; Está acima, então DESCE (+1) em direção ao herói
    sta PennyCrab + PennyCrabStruct::Y_Pos
    
    lda #STATE_WALKING
    sta PennyCrab + PennyCrabStruct::State
    stz PennyCrab + PennyCrabStruct::Preparing_Timer
    bra ExitMovement
    
StopVerticalMove:
    ; O Y está perfeitamente dentro da janela de ataque! 
    ; Não altera a posição Y neste frame, mantendo o inimigo estável na linha.
    


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
    bne Preparing
    lda #WALK_ANIM_SPEED
    sta PennyCrab + PennyCrabStruct::Walk_Anim_Speed
    bra Done

Preparing:
    stz PennyCrab + PennyCrabStruct::Walk_Anim_Speed
    

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
    .byte 16,  0,  $28, $00     ; pedaco 1-2
    .byte 32,  0,  $26, $00     ; pedaco 1-3
    .byte 48,  0,  $2A, $00     ; pedaco 1-4
    
    .byte 0,  16,  $44, $00     ; pedaco 2-1
    .byte 16,  16,  $48, $00     ; pedaco 2-2
    .byte 32,  16,  $46, $00     ; pedaco 2-3
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
    .byte 0,  0,  $2A, $00     ; pedaco 1-1
    .byte 16,  0,  $28, $00     ; pedaco 1-2
    .byte 32,  0,  $26, $00     ; pedaco 1-3
    .byte 48,  0,  $24, $00     ; pedaco 1-4
    
    .byte 0,  16,  $4A, $00     ; pedaco 2-1
    .byte 16,  16,  $48, $00     ; pedaco 2-2
    .byte 32,  16,  $46, $00     ; pedaco 2-3
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
        ; Se estiver olhando para a esquerda, aplica a inversão de colunas:
        ; X_Global + (Largura_Total - 16) - Offset_X_Do_Bloco
        ; Para 64px de largura, (Largura_Total - 16) = 48
        lda #48
        sec
        sbc PennyCrab_Layout, Y ; Subtrai o Offset X atual (0, 16, 32 ou 48)
        clc
        adc PennyCrab + PennyCrabStruct::X_Pos ; Soma a ancoragem global
        sta OAMMIRROR, X
        bra ProcessY

DrawXNormal:
        clc
        lda PennyCrab + PennyCrabStruct::X_Pos    
        adc PennyCrab_Layout, Y ; Le o Offset X padrão (Y + 0)
        sta OAMMIRROR, X                          

ProcessY:
        inx                                       
        iny                     ; Aponta para o Offset Y (Y + 1)

; === 2. PROCESSAR POSIÇÃO Y ===
        clc
        lda PennyCrab + PennyCrabStruct::Y_Pos    
        adc PennyCrab_Layout, Y ; Le o Offset Y (Y + 1)
        sta OAMMIRROR, X                          
        inx
        iny                     ; Aponta para o Tile ID (Y + 2)

; === 3. SELEÇÃO DINÂMICA DE TILE ID BASEADO NO FRAME ===

        lda PennyCrab + PennyCrabStruct::State
        cmp #STATE_PREPARING
        beq DrawPreparing
        cmp #STATE_ATACKING
        beq DrawAttacking
        bra DrawWalking

DrawPreparing:        
        lda PennyCrab + PennyCrabStruct::Preparing_Anim_Frame
        beq FramePreparing0


FramePreparing1:
        lda PennyCrab_Layout_FramePreparing1, Y        ; Le o Tile ID do Layout 1 (Y + 2)
        bra WriteTile

FramePreparing0:
        lda PennyCrab_Layout_FramePreparing0, Y               ; Le o Tile ID do Layout 0 (Y + 2)
        bra WriteTile

DrawAttacking:

        lda PennyCrab + PennyCrabStruct::Attacking_Anim_Frame
        beq FrameAttacking0

FrameAttacking1:
        lda PennyCrab_Layout_FrameAttacking1, Y        ; Le o Tile ID do Layout 1 (Y + 2)
        bra WriteTile

FrameAttacking0:
        lda PennyCrab_Layout_FrameAttacking0, Y               ; Le o Tile ID do Layout 0 (Y + 2)
        bra WriteTile

DrawWalking:
        lda PennyCrab + PennyCrabStruct::Anim_Frame
        beq Frame0
    
Frame1:
        lda PennyCrab_Layout_Frame1, Y        ; Le o Tile ID do Layout 1 (Y + 2)
        bra WriteTile

Frame0:
        lda PennyCrab_Layout, Y               ; Le o Tile ID do Layout 0 (Y + 2)

WriteTile:
        sta OAMMIRROR, X
        inx
        iny                     ; Aponta para os Atributos (Y + 3)

        ; === 4. PROCESSAR ATRIBUTOS E INJETAR H-FLIP HIERÁRQUICO ===
        lda PennyCrab_Layout, Y ; Le o Atributo original (Y + 3)
        
        ; Protege o registrador Y empilhando-o para não quebrar o loop de leitura
        phy                     
        
        lda PennyCrab + PennyCrabStruct::Facing
        bne @NoFlip             ; Se Facing != 0 (Direita), mantém a paleta padrão intacta

@ApplyFlip:
        lda PennyCrab_Layout, Y ; Recarrega o atributo original no acumulador
        ora #%01000000          ; Injeta o Bit 6 (Horizontal Flip) via hardware da PPU
        bra @SaveAttributes

@NoFlip:
        lda PennyCrab_Layout, Y ; Garante o atributo limpo original se estiver para a direita

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
