; -----------------------------------------------------------------------------
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
;   This subroutines meve enemy
;-------------------------------------------------------------------------------
.proc   MoveEnemy1





; --- LÓGICA DE MOVIMENTAÇÃO PURA ---
    ; Exemplo: Mover para a esquerda continuamente
   ;rep #$20        ; Abre o Acumulador para 16 bits temporariamente
   ; .a16

    ; 1. Reduz o timer de animação
    DEC InimigoGrande + EnemyStruct::Anim_Timer
    BNE Move ; Se não chegou a zero, não faz nada ainda
    
    ; 2. O timer zerou! Reseta o timer para o valor padrão
    LDA #$08 ; Ajuste este valor para mais rápido ou mais lento
    STA InimigoGrande + EnemyStruct::Anim_Timer
    
    ; 3. Alterna o Frame (Se era 0 vira 1, se era 1 vira 0)
    LDA InimigoGrande + EnemyStruct::Anim_Frame
    EOR #$01 ; Lógica XOR inverte o bit 0 perfeitamente (0 <-> 1)
    STA InimigoGrande + EnemyStruct::Anim_Frame


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
    ;sep #$20        ; Volta o Acumulador para 8 bits para não bugar o resto do jogo
    ;.a8
    ; Se quiser fazer ele quicar nas bordas, você testa o X_Pos aqui
    rts
                               
.endproc
;-------------------------------------------------------------------------------

; Formato por linha: Offset_X, Offset_Y, Tile_ID, Atributos(Paleta/Flip)
InimigoGrande_Layout:
    ; === CABEÇA (2x2) ===
    .byte 0,  0,  $06, $00     ; pedaco 1-1
    .byte 8,  0,  $07, $00     ; pedaco 1-2
    .byte 0,  8,  $16, $00     ; pedaco 2-1
    .byte 8,  8,  $17, $00     ; pedaco 2-2

    ; === CORPO LINHA 1 (4x1) ===
    .byte 248, 16, $08, $00    ; pedaco 1-1 (-8 virou 248)
    .byte 0,   16, $09, $00    ; pedaco 1-2
    .byte 8,   16, $0a, $00    ; pedaco 1-3
    .byte 16,  16, $0b, $00    ; pedaco 1-4

    ; === CORPO LINHA 2 (4x1) ===
    .byte 248, 24, $18, $00    ; pedaco 2-1 (-8 virou 248)
    .byte 0,   24, $19, $00    ; pedaco 2-2
    .byte 8,   24, $1a, $00    ; pedaco 2-3
    .byte 16,  24, $1b, $00    ; pedaco 2-4





.proc DrawEnemy1
        ; ATENÇÃO: Essa rotina assume que o registrador X já aponta para a posição
        ; livre atual da OAMMIRROR (você gerencia o índice X globalmente para os sprites)
        
        ldy #$0000              ; Índice Y vai caminhar pela tabela de Layout (4 bytes por bloco)

DrawLoop:
        ; 1. Processar Posição X (Posição Central + Offset do Bloco)
        clc
        lda InimigoGrande + EnemyStruct::X_Pos    ; Pega o X real (8 bits inferiores)
        adc InimigoGrande_Layout + 0, Y           ; Soma o Offset X do layout
        sta OAMMIRROR, X                          ; Grava na OAMMIRROR
        inx                                       ; Próximo byte da OAM

        ; 2. Processar Posição Y (Posição Central + Offset do Bloco)
        clc
        lda InimigoGrande + EnemyStruct::Y_Pos    ; Pega o Y real
        adc InimigoGrande_Layout + 1, Y           ; Soma o Offset Y do layout
        sta OAMMIRROR, X                          ; Grava na OAMMIRROR
        inx


        ; --- CÁLCULO DINÂMICO DO TILE BASEADO NO FRAME --- Isso ainda nao funciona
        LDA InimigoGrande + EnemyStruct::Anim_Frame
        BEQ Frame0
    
        Frame1:
            lda InimigoGrande_Layout + 2, Y ; ID do Tile do Frame de Caminhada B
            BRA WriteTile

        Frame0:
            lda InimigoGrande_Layout + 2, Y ; ID do Tile do Frame de Caminhada A

        WriteTile:
            sta OAMMIRROR, X

        ; 3. Copiar o Número do Tile diretamente
        ;lda InimigoGrande_Layout + 2, Y
        ;sta OAMMIRROR, X
        
        inx

        ; 4. Copiar os Atributos (Paleta, Flip, Prioridade) diretamente
        lda InimigoGrande_Layout + 3, Y
        sta OAMMIRROR, X
        inx

        ; Avança 4 bytes na tabela de Layout para ir para o próximo bloco
        iny
        iny
        iny
        iny

        ; Checa se já desenhou todos os blocos do inimigo
        cpy #48                 ; 12 blocos * 4 bytes cada = 48 bytes lidos no total
        bne DrawLoop

        rts
.endproc
