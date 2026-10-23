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
