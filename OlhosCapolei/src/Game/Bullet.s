; -----------------------------------------------------------------------------
;   File: BigHero.s (Konami/Capcom Architecture Style - Refactored)
;   Description: High-performance dynamic table-driven renderer for BigHero
; -----------------------------------------------------------------------------

.p816
.a8
.i16

.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Registers.inc"

.import BigHero, Bullet
.import Bullet2
.import Camera_X


.export DrawBullet, MoveBullet
.export DrawBullet2, MoveBullet2 



.segment "CODE"


;-------------------------------------------------------------------------------

.proc DrawBullet
        lda Bullet + BulletStruct::Active
        cmp #BULLET_STATE_INACTIVE
        beq Finish

        rep #$20
        .a16
        lda Bullet + BulletStruct::X_Pos
        SEC
        sbc Camera_X
        STA z:DP_TEMP_00
        ; Clipping: se Screen_X < 0 ($FFxx) ou >= 256 ($01xx), não desenha
        and #$FF00
        beq @InScreen
        sep #$20
        .a8
        rts

@InScreen:
        sep #$20
        .a8
        lda z:DP_TEMP_00
        sta OAMMIRROR, x
        inx

        
        lda Bullet + BulletStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        
        lda Bullet + BulletStruct::Tile_ID
        sta OAMMIRROR, x
        inx
        
        lda Bullet + BulletStruct::Speed_X  ; Lê a velocidade horizontal da RAM
        bmi @SingleDefaultAttributes

@SingleApplyFlip:
        lda #$30                         
        sta OAMMIRROR, x
        inx
        rts

@SingleDefaultAttributes:
        lda #$30                         ; Atributo padrão, Página 1 da VRAM
        eor #$40                         ; Injeta H-Flip via Hardware (Bit 6)
        sta OAMMIRROR, x
        inx
        rts
Finish:
        rts    
    
.endproc

.proc DrawBullet2
        lda Bullet2 + BulletStruct::Active
        cmp #BULLET_STATE_INACTIVE
        beq Finish

        rep #$20
        .a16
        lda Bullet2 + BulletStruct::X_Pos
        SEC
        sbc Camera_X
        STA z:DP_TEMP_00
        ; Clipping: se Screen_X < 0 ($FFxx) ou >= 256 ($01xx), não desenha
        and #$FF00
        beq @InScreen
        sep #$20
        .a8
        rts

@InScreen:
        sep #$20
        .a8
        lda z:DP_TEMP_00
        sta OAMMIRROR, x
        inx

        
        lda Bullet2 + BulletStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        
        lda Bullet2 + BulletStruct::Tile_ID
        sta OAMMIRROR, x
        inx
        
        lda Bullet2 + BulletStruct::Speed_X  ; Lê a velocidade horizontal da RAM
        bmi @SingleDefaultAttributes

@SingleApplyFlip:
        lda #$30                         
        sta OAMMIRROR, x
        inx
        rts

@SingleDefaultAttributes:
        lda #$30                         ; Atributo padrão, Página 1 da VRAM
        eor #$40                         ; Injeta H-Flip via Hardware (Bit 6)
        sta OAMMIRROR, x
        inx
        rts
Finish:
        rts    
    
.endproc

;-------------------------------------------------------------------------------
.proc MoveBullet
        lda Bullet + BulletStruct::Active
        cmp #BULLET_STATE_ACTIVE
        bne @Exit
        
@StartFisica:
        ; 1. Estende o sinal de Speed_X (8-bit com sinal) para 16-bit em DP_TEMP_00
        lda Bullet + BulletStruct::Speed_X
        sta z:DP_TEMP_00
        bmi @SpeedXNegativa
        stz z:DP_TEMP_00 + 1            ; Tiro para frente (+): byte alto = $00
        bra @AplicarDeslocamentoX

@SpeedXNegativa:
        lda #$FF
        sta z:DP_TEMP_00 + 1            ; Tiro para trás (-): byte alto = $FF

@AplicarDeslocamentoX:
        rep #$20
        .a16
        lda Bullet + BulletStruct::X_Pos
        clc
        adc z:DP_TEMP_00
        sta Bullet + BulletStruct::X_Pos

        ; 2. Desativa o tiro se sair da área visível da câmera (< 0 ou >= 256)
        sec
        sbc Camera_X
        and #$FF00
        beq @DentroDaTela

        sep #$20
        .a8
        lda #BULLET_STATE_INACTIVE
        sta Bullet + BulletStruct::Active
        rts

@DentroDaTela:
        sep #$20
        .a8
@Exit:
        rts
.endproc

;-------------------------------------------------------------------------------
.proc MoveBullet2
        lda Bullet2 + BulletStruct::Active
        cmp #BULLET_STATE_ACTIVE
        bne @Exit
        
@StartFisica:
        ; 1. Estende o sinal de Speed_X (8-bit com sinal) para 16-bit em DP_TEMP_00
        lda Bullet2 + BulletStruct::Speed_X
        sta z:DP_TEMP_00
        bmi @SpeedXNegativa
        stz z:DP_TEMP_00 + 1            ; Tiro para frente (+): byte alto = $00
        bra @AplicarDeslocamentoX

@SpeedXNegativa:
        lda #$FF
        sta z:DP_TEMP_00 + 1            ; Tiro para trás (-): byte alto = $FF

@AplicarDeslocamentoX:
        rep #$20
        .a16
        lda Bullet2 + BulletStruct::X_Pos
        clc
        adc z:DP_TEMP_00
        sta Bullet2 + BulletStruct::X_Pos

        ; 2. Desativa o tiro se sair da área visível da câmera (< 0 ou >= 256)
        sec
        sbc Camera_X
        and #$FF00
        beq @DentroDaTela

        sep #$20
        .a8
        lda #BULLET_STATE_INACTIVE
        sta Bullet2 + BulletStruct::Active
        rts

@DentroDaTela:
        sep #$20
        .a8
@Exit:
        rts
.endproc
