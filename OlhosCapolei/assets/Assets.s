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
    ; Paleta 0 (BG1 - Chão / Asfalto)
    .word $7C00     ; Cor 0: Fundo/Transparente (Azul)
    .word $2108     ; Cor 1: Cinza Escuro (Asfalto)
    .word $4210     ; Cor 2: Cinza Médio (Detalhes)
    .word $03FF     ; Cor 3: Amarelo (Faixa da rua)
    .res 24, $00    ; Completa os 32 bytes (16 cores) da Paleta 0

    ; Paleta 1 (BG2 - Fundo / Prédios)
    .word $0000     ; Cor 0: Transparente (Ignorado pelo hardware no BG2)
    .word $3C00     ; Cor 1: Azul Escuro (Silhueta dos prédios)
    .word $5C00     ; Cor 2: Azul Médio (Janelas)
    .word $7FFF     ; Cor 3: Branco (Nuvens)
    .res 24, $00    ; Completa os 32 bytes (16 cores) da Paleta 1

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

        ; --- CONFIGURA INCREMENTO DA VRAM (+1 palavra após escrita no byte alto) ---
        lda #$80
        sta VMAINC

        ; =====================================================================
        ; 1. PREENCHER TILEMAP DO BG1 (CHÃO - VRAM $4000)
        ; =====================================================================
        ldx #$4000
        stx VMADDL

        ; Linhas 0 a 19 (160 pixels superiores): Céu transparente (Tile 0)
        ldx #0
@BG1_Ceu:
        stz VMDATAL
        stz VMDATAH
        inx
        cpx #(32 * 20)                  ; 20 linhas de 32 tiles
        bcc @BG1_Ceu

        ; Linhas 20 a 27 (64 pixels inferiores): Asfalto (Tile 1, Paleta 0 = $0001)
        ldx #0
@BG1_Chao:
        lda #$01                        ; Tile 1
        sta VMDATAL
        lda #$00                        ; Paleta 0
        sta VMDATAH
        inx
        cpx #(32 * 8)                   ; 8 linhas de 32 tiles
        bcc @BG1_Chao

        ; =====================================================================
        ; 2. PREENCHER TILEMAP DO BG2 (PRÉDIOS AO FUNDO - VRAM $4800)
        ; =====================================================================
        ldx #$4800
        stx VMADDL

        ; Linhas 0 a 9: Céu vazio
        ldx #0
@BG2_Ceu:
        stz VMDATAL
        stz VMDATAH
        inx
        cpx #(32 * 10)
        bcc @BG2_Ceu

        ; Linhas 10 a 19: Prédios ao fundo (Tile 1, Paleta 1 = $0401)
        ldx #0
@BG2_Predios:
        lda #$01                        ; Tile 1
        sta VMDATAL
        lda #$04                        ; Bit 2 do byte alto = Paleta 1!
        sta VMDATAH
        inx
        cpx #(32 * 10)
        bcc @BG2_Predios

        plp
        rts
.endproc
