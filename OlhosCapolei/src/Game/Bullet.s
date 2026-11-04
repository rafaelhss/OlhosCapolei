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


.export DrawBullet, MoveBullet



.segment "CODE"


;-------------------------------------------------------------------------------

.proc DrawBullet
        lda Bullet + BulletStruct::Active
        cmp #BULLET_STATE_INACTIVE
        beq Finish

        lda Bullet + BulletStruct::X_Pos
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
        lda #$00                         
        sta OAMMIRROR, x
        inx
        rts

@SingleDefaultAttributes:
        lda #$00                         ; Atributo padrão, Página 1 da VRAM
        eor #$40                         ; Injeta H-Flip via Hardware (Bit 6)
        sta OAMMIRROR, x
        inx
        rts
Finish:
        rts    
    
.endproc

;-------------------------------------------------------------------------------
.proc MoveBullet


       ; 1. Se estiver voando (THROWN), executa a física de parábola original
        lda Bullet + BulletStruct::Active
        cmp #BULLET_STATE_ACTIVE
        bne @Exit
        
@StartFisica:
        ; 1. Deslocamento Horizontal
        lda Bullet + BulletStruct::X_Pos
        clc
        adc Bullet + BulletStruct::Speed_X
        sta Bullet + BulletStruct::X_Pos

        ; --- CHECAGEM DE COLISÃO LATERAL ---
@CheckWallRight:
        lda Bullet + BulletStruct::X_Pos
        cmp #(SCREEN_RIGHT - 16)        
        bcc @CheckWallLeft               

        lda #(SCREEN_RIGHT - 17)        
        sta Bullet + BulletStruct::X_Pos
        bra @WallHit

@CheckWallLeft:
        lda Bullet + BulletStruct::X_Pos
        cmp #(SCREEN_LEFT + 4)
        bcs @Exit            

@WallHit:
        lda #BULLET_STATE_INACTIVE
        sta Bullet + BulletStruct::Active
@Exit:
        rts
.endproc

