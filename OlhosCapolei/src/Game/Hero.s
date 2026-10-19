; -----------------------------------------------------------------------------
;   File: Hero.s
;   Description: Subroutines to move Hero
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     MoveHero
.export     DrawHero
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

.import Hero

.segment "CODE"
;-------------------------------------------------------------------------------
;   This subroutines meve hero
;-------------------------------------------------------------------------------
.proc   MoveHero
        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
                .byte $42, $00          ; debugger breakpoint
                .byte $42, $00          ; debugger breakpoint 
                        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
                .byte $42, $00          ; debugger breakpoint
                .byte $42, $00          ; debugger breakpoint 
                        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
        .byte $42, $00          ; debugger breakpoint
                .byte $42, $00          ; debugger breakpoint
                .byte $42, $00          ; debugger breakpoint 

; --- LÓGICA DE MOVIMENTAÇÃO PURA ---
    ; Exemplo: Mover para a esquerda continuamente
    rep #$20        ; Abre o Acumulador para 16 bits temporariamente
  
    lda Hero + HeroStruct::X_Pos
    sec
    sbc #1          ; Move 1 pixel por frame
    sta Hero + HeroStruct::X_Pos
    sep #$20        ; Volta o Acumulador para 8 bits para não bugar o resto do jogo

    ; Se quiser fazer ele quicar nas bordas, você testa o X_Pos aqui
    rts                            
.endproc
;-------------------------------------------------------------------------------

; Formato por linha: Offset_X, Offset_Y, Tile_ID, Atributos(Paleta/Flip)
Hero_Layout:
    ; === CABEÇA (2x2) ===
    .byte 0,  0,  $00, $00     ; pedaco 1-1
    .byte 8,  0,  $01, $00     ; pedaco 1-2
    .byte 0,  8,  $10, $00     ; pedaco 2-1
    .byte 8,  8,  $11, $00     ; pedaco 2-2

    ; === CORPO LINHA 1 (2x2) ===
    .byte 0, 16, $02, $00    ; pedaco 1-1 
    .byte 8, 16, $03, $00    ; pedaco 1-2
    .byte 0, 24, $12, $00    ; pedaco 1-3
    .byte 8, 24, $13, $00    ; pedaco 1-4






.proc DrawHero
        ; ATENÇÃO: Essa rotina assume que o registrador X já aponta para a posição
        ; livre atual da OAMMIRROR (você gerencia o índice X globalmente para os sprites)
        
        ldy #$0000              ; Índice Y vai caminhar pela tabela de Layout (4 bytes por bloco)

DrawLoop:
        ; 1. Processar Posição X (Posição Central + Offset do Bloco)
        clc
        lda Hero + HeroStruct::X_Pos    ; Pega o X real (8 bits inferiores)
        adc Hero_Layout + 0, Y           ; Soma o Offset X do layout
        sta OAMMIRROR, X                          ; Grava na OAMMIRROR
        inx                                       ; Próximo byte da OAM

        ; 2. Processar Posição Y (Posição Central + Offset do Bloco)
        clc
        lda Hero + HeroStruct::Y_Pos    ; Pega o Y real
        adc Hero_Layout + 1, Y           ; Soma o Offset Y do layout
        sta OAMMIRROR, X                          ; Grava na OAMMIRROR
        inx

        ; 3. Copiar o Número do Tile diretamente
        lda Hero_Layout + 2, Y
        sta OAMMIRROR, X
        inx

        ; 4. Copiar os Atributos (Paleta, Flip, Prioridade) diretamente
        lda Hero_Layout + 3, Y
        sta OAMMIRROR, X
        inx

        ; Avança 4 bytes na tabela de Layout para ir para o próximo bloco
        iny
        iny
        iny
        iny

        ; Checa se já desenhou todos os blocos do inimigo
        cpy #32                 ; 8 blocos * 4 bytes cada = 48 bytes lidos no total
        bne DrawLoop

        rts
.endproc
