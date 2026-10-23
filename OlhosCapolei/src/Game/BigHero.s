; -----------------------------------------------------------------------------
;   File: BigHero.s (Versão Corrigida - 4 Fileiras Reais para 64px de Altura)
; -----------------------------------------------------------------------------

.p816
.a8
.i16

.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Registers.inc"

.import BigHero
.export DrawBigHero, MoveBigHero

.segment "CODE"

.proc DrawBigHero
        lda #%00110000          ; Prioridade 3, Paleta 0
        sta $00                 ; Salva os atributos na Direct Page para reuso

        ; =====================================================================
        ; FILEIRA 1: CABEÇA E OMBROS (Y + 0)
        ; =====================================================================
        ; Bloco Superior Esquerdo
        lda BigHero + BigHeroStruct::X_Pos
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        lda #$20                ; Tile VRAM da Cabeça Esquerda
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx

        ; Bloco Superior Direito
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #16
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        lda #$22                ; Tile VRAM da Cabeça Direita
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx

        ; =====================================================================
        ; FILEIRA 2: PEITO E ABDÔMEN (Y + 16)
        ; =====================================================================
        ; Bloco do Meio-Superior Esquerdo
        lda BigHero + BigHeroStruct::X_Pos
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #16                 ; Desce 16 pixels na tela
        sta OAMMIRROR, x
        inx
        lda #$40                ; Avança uma linha de blocos na VRAM (+$20)
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx

        ; Bloco do Meio-Superior Direito
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #16
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #16
        sta OAMMIRROR, x
        inx
        lda #$42
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx

        ; =====================================================================
        ; FILEIRA 3: CINTURA E COXAS (Y + 32)
        ; =====================================================================
        ; Bloco do Meio-Inferior Esquerdo
        lda BigHero + BigHeroStruct::X_Pos
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #32                 ; Desce 32 pixels na tela
        sta OAMMIRROR, x
        inx
        lda #$60                ; Avança mais uma linha na VRAM (+$20)
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx

        ; Bloco do Meio-Inferior Direito
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #16
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #32
        sta OAMMIRROR, x
        inx
        lda #$62
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx

        ; =====================================================================
        ; FILEIRA 4: OS PÉS ANIMADOS (Y + 48) -> Aqui fechamos os 64 pixels!
        ; =====================================================================
        lda BigHero + BigHeroStruct::Anim_Frame
        cmp #1
        beq PassoAberto

        ; --- Frame 0: Pés Parados (Guarda Neutra)
        lda BigHero + BigHeroStruct::X_Pos
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #48                 ; Cravado na base de 48 pixels abaixo do topo
        sta OAMMIRROR, x
        inx
        lda #$80                ; Linha de tiles dos pés parados na VRAM
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx

        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #16
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #48
        sta OAMMIRROR, x
        inx
        lda #$82
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx
        bra DoneDrawing

PassoAberto:
        ; --- Frame 1: Pés em Movimento (Caminhando)
        lda BigHero + BigHeroStruct::X_Pos
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #48
        sta OAMMIRROR, x
        inx
        lda #$A0                ; Linha de tiles dos pés andando na VRAM
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx

        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #16
        sta OAMMIRROR, x
        inx
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #48
        sta OAMMIRROR, x
        inx
        lda #$A2
        sta OAMMIRROR, x
        inx
        lda $00
        sta OAMMIRROR, x
        inx




DoneDrawing:
        rts
.endproc

;-------------------------------------------------------------------------------
;   MoveBigHero (Atualiza Posição e Trata Animação)
;-------------------------------------------------------------------------------
.proc MoveBigHero
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
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc HOR_SPEED               ; Matematica limpa de 1 byte
        sta BigHero + BigHeroStruct::X_Pos ; Grava apenas 1 byte, protegendo o Y_Pos!

CheckLeft:
        rep #$20                    ; Abre 16-bit apenas para testar o botao
        .a16
        lda JOYHELD1
        and #LEFT_BUTTON
        beq CheckUp

        sep #$20                    ; === FECHA PARA 8-BIT ===
        .a8
MoveLeft:
        lda BigHero + BigHeroStruct::X_Pos
        sec
        sbc HOR_SPEED               ; CORRIGIDO: Era VER_SPEED no arquivo original!
        sta BigHero + BigHeroStruct::X_Pos

CheckUp:
        rep #$20                    ; Abre 16-bit apenas para testar o botao
        .a16
        lda JOYHELD1
        and #UP_BUTTON
        beq CheckDown

        sep #$20                    ; === FECHA PARA 8-BIT ===
        .a8
MoveUp:
        lda BigHero + BigHeroStruct::Y_Pos
        sec
        sbc VER_SPEED               ; CORRIGIDO: Movimento vertical usa VER_SPEED
        sta BigHero + BigHeroStruct::Y_Pos

CheckDown:
        rep #$20                    ; Abre 16-bit apenas para testar o botao
        .a16
        lda JOYHELD1
        and #DOWN_BUTTON
        beq MoveDone

        sep #$20                    ; === FECHA PARA 8-BIT ===
        .a8
MoveDown:
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc VER_SPEED                       
        sta BigHero + BigHeroStruct::Y_Pos

MoveDone:
        sep #$20                    ; Garante que a CPU saia da rotina em 8-bit
        .a8
        rts
.endproc
