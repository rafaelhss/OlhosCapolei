; ---------------- -------------------------------------------------------------
;   File: Enemy.s
;   Description: Subroutines to move enemy
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     MoveEnemy1
.export     DrawEnemy1
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

.import InimigoGrande
.import Hero

.segment "CODE"
;-------------------------------------------------------------------------------
;   This subroutines move enemy
;-------------------------------------------------------------------------------
.proc   MoveEnemy1

    ; 1. Reduz o timer de animacao
    dec InimigoGrande + EnemyStruct::Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda
    
    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #$08 ; Ajuste este valor para mais rapido ou mais lento
    sta InimigoGrande + EnemyStruct::Anim_Timer
    
    ; 3. Alterna o Frame (Se era 0 vira 1, se era 1 vira 0)
    lda InimigoGrande + EnemyStruct::Anim_Frame
    eor #$01 ; Logica XOR inverte o bit 0 perfeitamente (0 <-> 1)
    sta InimigoGrande + EnemyStruct::Anim_Frame

;=== logica para mover
Move:
    lda InimigoGrande + EnemyStruct::X_Pos
    cmp Hero + HeroStruct::X_Pos    ;== compara com o hero
    beq NoEnemyHMove_CheckV ; mantem
    bcc MoveEnemyRight
MoveEnemyLeft:
    sec
    sbc #1          ; Move 1 pixel por frame
    sta InimigoGrande + EnemyStruct::X_Pos
    bra NoEnemyHMove_CheckV
    
MoveEnemyRight:
    clc
    adc #1                  ; Move 1 pixel para a direita
    sta InimigoGrande + EnemyStruct::X_Pos
    bra NoEnemyHMove_CheckV ;nao precisava, mas eh bom
    
NoEnemyHMove_CheckV:
    lda InimigoGrande + EnemyStruct::Y_Pos
    cmp Hero + HeroStruct::Y_Pos    ;== compara com o hero
    beq NoEnemyYMove ; mantem
    bcc MoveEnemyUp
MoveEnemyDown:
    sec
    sbc #1          ; Move 1 pixel por frame
    sta InimigoGrande + EnemyStruct::Y_Pos
    bra NoEnemyYMove
    
MoveEnemyUp:
    clc
    adc #1                  ; Move 1 pixel para a direita
    sta InimigoGrande + EnemyStruct::Y_Pos
    bra NoEnemyYMove ;nao precisava, mas eh bom
    
NoEnemyYMove:
    rts
                               
.endproc
;-------------------------------------------------------------------------------

; Formato por linha: Offset_X, Offset_Y, Tile_ID, Atributos(Paleta/Flip)
InimigoGrande_Layout:
    ; === CABECA (2x2) ===
    .byte 0,  0,  $06, $00     ; pedaco 1-1
    .byte 8,  0,  $07, $00     ; pedaco 1-2
    .byte 0,  8,  $16, $00     ; pedaco 2-1
    .byte 8,  8,  $17, $00     ; pedaco 2-2

    ; === CORPO LINHA 1 (4x1) ===
    .byte 248, 16, $08, $00    ; pedaco 1-1
    .byte 0,   16, $09, $00    ; pedaco 1-2
    .byte 8,   16, $0a, $00    ; pedaco 1-3
    .byte 16,  16, $0b, $00    ; pedaco 1-4

    ; === CORPO LINHA 2 (4x1) ===
    .byte 248, 24, $18, $00    ; pedaco 2-1
    .byte 0,   24, $19, $00    ; pedaco 2-2
    .byte 8,   24, $1a, $00    ; pedaco 2-3
    .byte 16,  24, $1b, $00    ; pedaco 2-4

; =============================================================================
; FRAME 1: INIMIGO ANDANDO (Proximas posicoes livres de Tile)
; =============================================================================
InimigoGrande_Layout_Frame1:
    ; === CABECA (2x2) ===
    .byte 0,  0,  $06, $00     ; pedaco 1-1
    .byte 8,  0,  $07, $00     ; pedaco 1-2
    .byte 0,  8,  $16, $00     ; pedaco 2-1
    .byte 8,  8,  $17, $00     ; pedaco 2-2

    ; === CORPO LINHA 1 (4x1) ===
    .byte 248, 16, $0C, $00    ; pedaco 1-1
    .byte 0,   16, $0D, $00    ; pedaco 1-2
    .byte 8,   16, $0E, $00    ; pedaco 1-3
    .byte 16,  16, $0F, $00    ; pedaco 1-4

    ; === CORPO LINHA 2 (4x1) ===
    .byte 248, 24, $1C, $00    ; pedaco 2-1
    .byte 0,   24, $1D, $00    ; pedaco 2-2
    .byte 8,   24, $1E, $00    ; pedaco 2-3
    .byte 16,  24, $1F, $00    ; pedaco 2-4


.proc DrawEnemy1
        ldy #$0000              ; Indice Y vai caminhar pela tabela de Layout

DrawLoop:
        ; 1. Processar Posicao X (Posicao Central + Offset do Bloco)
        clc
        lda InimigoGrande + EnemyStruct::X_Pos    
        adc InimigoGrande_Layout, Y               ; Le o Offset X (Y + 0)
        sta OAMMIRROR, X                          
        inx                                       
        iny                                       ; Aponta para o Offset Y

        ; 2. Processar Posicao Y (Posicao Central + Offset do Bloco)
        clc
        lda InimigoGrande + EnemyStruct::Y_Pos    
        adc InimigoGrande_Layout, Y               ; Le o Offset Y (Y + 1)
        sta OAMMIRROR, X                          
        inx
        iny                                       ; Aponta para o Tile ID

        ; --- CALCULO DINAMICO DO TILE BASEADO NO FRAME ---
        lda InimigoGrande + EnemyStruct::Anim_Frame
        beq Frame0
    
Frame1:
        lda InimigoGrande_Layout_Frame1, Y        ; Le o Tile ID do Layout 1 (Y + 2)
        bra WriteTile

Frame0:
        lda InimigoGrande_Layout, Y               ; Le o Tile ID do Layout 0 (Y + 2)

WriteTile:
        sta OAMMIRROR, X
        inx
        iny                                       ; Aponta para os Atributos

        ; 4. Copiar os Atributos (Paleta, Flip, Prioridade) diretamente
        lda InimigoGrande_Layout, Y               ; Le o Atributo (Y + 3)
        sta OAMMIRROR, X
        inx
        iny                                       ; Avanca para o proximo bloco (X do proximo sprite)

        ; Checa se ja desenhou todos os 12 blocos do inimigo (12 * 4 = 48 bytes lidos)
        cpy #48                 
        bne DrawLoop

        rts
.endproc
