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

.segment "CODE"
;-------------------------------------------------------------------------------
;   This subroutines move enemy
;-------------------------------------------------------------------------------
.proc   MovePennyCrab
 ; 1. Reduz o timer de animacao
    dec PennyCrab + PennyCrabStruct::Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda
    
    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #$08 ; Ajuste este valor para mais rapido ou mais lento
    sta PennyCrab + PennyCrabStruct::Anim_Timer
    
    ; 3. Alterna o Frame (Se era 0 vira 1, se era 1 vira 0)
    lda PennyCrab + PennyCrabStruct::Anim_Frame
    eor #$01 ; Logica XOR inverte o bit 0 perfeitamente (0 <-> 1)
    sta PennyCrab + PennyCrabStruct::Anim_Frame

;=== logica para mover
Move:
    lda PennyCrab + PennyCrabStruct::X_Pos
    cmp BigHero + BigHeroStruct::X_Pos    ;== compara com o hero
    beq NoEnemyHMove_CheckV ; mantem
    bcc MoveEnemyRight
MoveEnemyLeft:
    sec
    sbc #1          ; Move 1 pixel por frame
    sta PennyCrab + PennyCrabStruct::X_Pos
    bra NoEnemyHMove_CheckV
    
MoveEnemyRight:
    clc
    adc #1                  ; Move 1 pixel para a direita
    sta PennyCrab + PennyCrabStruct::X_Pos
    bra NoEnemyHMove_CheckV ;nao precisava, mas eh bom
    
NoEnemyHMove_CheckV:
    lda PennyCrab + PennyCrabStruct::Y_Pos
    cmp BigHero + BigHeroStruct::Y_Pos    ;== compara com o hero
    beq NoEnemyYMove ; mantem
    bcc MoveEnemyUp
MoveEnemyDown:
    sec
    sbc #1          ; Move 1 pixel por frame
    sta PennyCrab + PennyCrabStruct::Y_Pos
    bra NoEnemyYMove
    
MoveEnemyUp:
    clc
    adc #1                  ; Move 1 pixel para a direita
    sta PennyCrab + PennyCrabStruct::Y_Pos
    bra NoEnemyYMove ;nao precisava, mas eh bom
    
NoEnemyYMove:
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


.proc DrawPennyCrab

       ldy #$0000              ; Indice Y vai caminhar pela tabela de Layout

DrawLoop:
        ; 1. Processar Posicao X (Posicao Central + Offset do Bloco)
        clc
        lda PennyCrab + PennyCrabStruct::X_Pos    
        adc PennyCrab_Layout, Y               ; Le o Offset X (Y + 0)
        sta OAMMIRROR, X                          
        inx                                       
        iny                                       ; Aponta para o Offset Y

        ; 2. Processar Posicao Y (Posicao Central + Offset do Bloco)
        clc
        lda PennyCrab + PennyCrabStruct::Y_Pos    
        adc PennyCrab_Layout, Y               ; Le o Offset Y (Y + 1)
        sta OAMMIRROR, X                          
        inx
        iny                                       ; Aponta para o Tile ID

        ; --- CALCULO DINAMICO DO TILE BASEADO NO FRAME ---
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
        iny                                       ; Aponta para os Atributos

        ; 4. Copiar os Atributos (Paleta, Flip, Prioridade) diretamente
        lda PennyCrab_Layout, Y               ; Le o Atributo (Y + 3)
        sta OAMMIRROR, X
        inx
        iny                                       ; Avanca para o proximo bloco (X do proximo sprite)

        ; Checa se ja desenhou todos os 16 blocos do inimigo (16 * 4 = 64 bytes lidos)
        cpy #64                 
        bne DrawLoop

        
        rts
.endproc
