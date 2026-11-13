; -----------------------------------------------------------------------------
;   File: Assets.s
;   Description: Creates a segment for all assets and exports symbols to make
;   them accessible to other parts of the project.
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     SpriteData
.export     VaderData
.export     ColorData
.export     BackgroundData
.export BuildTestBackgrounds
.export Test_BG_Palettes
.export Test_BG_Tiles
;-------------------------------------------------------------------------------

.INCLUDE "Registers.inc"
.include "PPU.inc"
;----- Assset Data -------------------------------------------------------------
.segment "SPRITEDATA"
SpriteData: .incbin "SpritesBig9.vra"
VaderData: .incbin "VaderSprites7.vra"
ColorData:  .incbin "SpritesBig8c.pal"
BackgroundData: .incbin "Background.pal"

;-------------------------------------------------------------------------------
; =============================================================================
; DADOS DE TESTE PARA BACKGROUND (4BPP = 32 BYTES POR TILE)
; =============================================================================
Test_BG_Palettes:
    ; Paleta 0 (BG1 - Rua)
    .word $6739     ; Cor 0: Céu (#CCCCCC)
    .word $19B3     ; Cor 1: Rua (#9E6831)
    .word $19B3     ; Cor 2: Entre tijolos da rua (#9E6831)
    .word $112D     ; Cor 3: Faixa da rua (#6E471F)
    .res 24, $00    ; Completa os 32 bytes da Paleta 0

    ; Paleta 1 (BG2 - Prédios)
    .word $0000     ; Cor 0: Transparente
    .word $0000     ; Cor 1: Prédio - tijolo (#666666)
    .word $318C     ; Cor 2: Prédio - entre tijolos (#000000)
    .word $7FFF     ; Cor 3: Branco (opcional/extra)
    .res 24, $00    ; Completa os 32 bytes da Paleta 1


Test_BG_Tiles:
    ; --- TILE 0: Vazio / Transparente (32 bytes zerados) ---
    .res 32, $00

    ; --- TILE 1: Bloco Sólido com Borda (Usa Cor 1 e Cor 2) ---
    ; Bitplanes 0 e 1 (Primeiros 16 bytes)
    .byte $FF, $00, $81, $7E, $81, $7E, $81, $7E
    .byte $81, $7E, $81, $7E, $81, $7E, $FF, $00
    ; Bitplanes 2 e 3 (Últimos 16 bytes - zerados pois usamos cores 1 a 3)
    .res 16, $00

    ; --- TILE 2: Faixa Central (Usa Cor 3) ---
    .byte $00, $00, $00, $00, $00, $00, $FF, $FF
    .byte $FF, $FF, $00, $00, $00, $00, $00, $00
    .res 16, $00

.proc BuildTestBackgrounds
        php
        sep #$20
        rep #$10
        .a8
        .i16

        lda #$80
        sta VMAINC

        ; =====================================================================
        ; 1. PREENCHER BG1 (CHÃO) NAS DUAS TELAS ($4000 E $4400)
        ; =====================================================================
        ldx #$4000
        jsr @FillBG1Screen
        ldx #$4400
        jsr @FillBG1Screen

        ; =====================================================================
        ; 2. PREENCHER BG2 (PRÉDIOS) NAS DUAS TELAS ($4800 E $4C00)
        ; =====================================================================
        ldx #$4800
        jsr @FillBG2Screen
        ldx #$4C00
        jsr @FillBG2Screen

        plp
        rts

; --- Sub-rotina interna para preencher uma tela 32x32 do BG1 ---
@FillBG1Screen:
        stx VMADDL
        ; Linhas 0 a 19: Céu transparente (Tile 0)
        ldx #0
:       stz VMDATAL
        stz VMDATAH
        inx
        cpx #(32 * 20)
        bcc :-

        ; Linhas 20 a 22: Asfalto superior (Tile 1)
        ldx #0
:       lda #$01
        sta VMDATAL
        stz VMDATAH
        inx
        cpx #(32 * 3)
        bcc :-

        ; Linha 23: Faixa amarela central (Tile 2)
        ldx #0
:       lda #$02
        sta VMDATAL
        stz VMDATAH
        inx
        cpx #32
        bcc :-

        ; Linhas 24 a 27: Asfalto inferior (Tile 1)
        ldx #0
:       lda #$01
        sta VMDATAL
        stz VMDATAH
        inx
        cpx #(32 * 4)
        bcc :-
        rts

; --- Sub-rotina interna para preencher uma tela 32x32 do BG2 (com colunas alternadas) ---
@FillBG2Screen:
        stx VMADDL
        ; Linhas 0 a 9: Céu vazio
        ldx #0
:       stz VMDATAL
        stz VMDATAH
        inx
        cpx #(32 * 10)
        bcc :-

        ; Linhas 10 a 19: Prédios alternando bloco sólido e espaço para ver o movimento
        ldx #0
@BG2_Loop:
        txa
        and #$03                        ; A cada 4 tiles, deixa 1 coluna vazia (céu)
        cmp #$03
        beq @BG2_Vazio

        lda #$01                        ; Tile 1 (Bloco azul)
        sta VMDATAL
        lda #$04                        ; Paleta 1
        sta VMDATAH
        bra @BG2_Next

@BG2_Vazio:
        stz VMDATAL
        stz VMDATAH

@BG2_Next:
        inx
        cpx #(32 * 10)
        bcc @BG2_Loop
        rts
.endproc
