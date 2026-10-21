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
.a8                             ; Fixado em 8-bit por padrao
.i16                            ; Indices em 16-bit
;-------------------------------------------------------------------------------

;----- Includes ----------------------------------------------------------------
.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
;-------------------------------------------------------------------------------

.import Hero

.segment "CODE"
;-------------------------------------------------------------------------------
;   This subroutines move hero
; -----------------------------------------------------------------------------
.proc MoveHero

        ; Inicializacao de velocidade sempre em 8-bit
        lda #SPRITE_SPEED
        sta HOR_SPEED
        sta VER_SPEED

        ; === LOGICA DE TURBO (A_BUTTON) ===
        rep #$20                    ; Abre 16-bit apenas para ler o controle
        .a16
        lda JOYHELD1
        and #A_BUTTON
        beq CheckRight
        
        sep #$20                    ; Fecha para 8-bit para aplicar a velocidade
        .a8
        lda #(SPRITE_SPEED + SPRITE_SPEED)
        sta HOR_SPEED
        sta VER_SPEED

CheckRight:
        rep #$20                    ; Abre 16-bit apenas para testar o botao
        .a16
        lda JOYHELD1
        and #RIGHT_BUTTON
        beq CheckLeft

        sep #$20                    ; === FECHA PARA 8-BIT ANTES DE MEXER NA RAM ===
        .a8
MoveRight:
        lda Hero + HeroStruct::X_Pos
        clc
        adc HOR_SPEED               ; Matematica limpa de 1 byte
        sta Hero + HeroStruct::X_Pos ; Grava apenas 1 byte, protegendo o Y_Pos!

CheckLeft:
        rep #$20                    ; Abre 16-bit apenas para testar o botao
        .a16
        lda JOYHELD1
        and #LEFT_BUTTON
        beq CheckUp

        sep #$20                    ; === FECHA PARA 8-BIT ===
        .a8
MoveLeft:
        lda Hero + HeroStruct::X_Pos
        sec
        sbc HOR_SPEED               ; CORRIGIDO: Era VER_SPEED no arquivo original!
        sta Hero + HeroStruct::X_Pos

CheckUp:
        rep #$20                    ; Abre 16-bit apenas para testar o botao
        .a16
        lda JOYHELD1
        and #UP_BUTTON
        beq CheckDown

        sep #$20                    ; === FECHA PARA 8-BIT ===
        .a8
MoveUp:
        lda Hero + HeroStruct::Y_Pos
        sec
        sbc VER_SPEED               ; CORRIGIDO: Movimento vertical usa VER_SPEED
        sta Hero + HeroStruct::Y_Pos

CheckDown:
        rep #$20                    ; Abre 16-bit apenas para testar o botao
        .a16
        lda JOYHELD1
        and #DOWN_BUTTON
        beq MoveDone

        sep #$20                    ; === FECHA PARA 8-BIT ===
        .a8
MoveDown:
        lda Hero + HeroStruct::Y_Pos
        clc
        adc VER_SPEED                       
        sta Hero + HeroStruct::Y_Pos

MoveDone:
        sep #$20                    ; Garante que a CPU saia da rotina em 8-bit
        .a8
        rts                            
.endproc

;-------------------------------------------------------------------------------
Hero_Layout:
    ; === CABECA (2x2) ===
    .byte 0,  0,  $00, $00     
    .byte 8,  0,  $01, $00     
    .byte 0,  8,  $10, $00     
    .byte 8,  8,  $11, $00     

    ; === CORPO LINHA 1 (2x2) ===
    .byte 0, 16, $02, $00    
    .byte 8, 16, $03, $00    
    .byte 0, 24, $12, $00    
    .byte 8, 24, $13, $00    

;-------------------------------------------------------------------------------
.proc DrawHero
        ldy #$0000              

DrawLoop:
        ; 1. Processar Posicao X (Posicao Central + Offset do Bloco)
        clc
        lda Hero + HeroStruct::X_Pos    
        adc Hero_Layout + 0, Y           
        sta OAMMIRROR, X                          
        inx                                       

        ; 2. Processar Posicao Y (Posicao Central + Offset do Bloco)
        clc
        lda Hero + HeroStruct::Y_Pos    
        adc Hero_Layout + 1, Y           
        sta OAMMIRROR, X                          
        inx

        ; 3. Copiar o Numero do Tile diretamente
        lda Hero_Layout + 2, Y
        sta OAMMIRROR, X
        inx

        ; 4. Copiar os Atributos (Paleta, Flip, Prioridade) diretamente
        lda Hero_Layout + 3, Y
        sta OAMMIRROR, X
        inx

        iny
        iny
        iny
        iny

        cpy #32                 ; 8 blocos * 4 bytes cada = 32 bytes
        bne DrawLoop

        rts
.endproc
