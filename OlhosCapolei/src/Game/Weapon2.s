; -----------------------------------------------------------------------------
;   File: Weapon.s
;   Description: Centralized Weapon, Projectile, and Ground Pickup Subsystem
;   Project: OlhosCapolei
; -----------------------------------------------------------------------------

.p816
.a8
.i16

;----- Exports -----------------------------------------------------------------
.export     GetWeaponData
.export     ProcessWeaponAttack
.export     UpdateProjectiles
.export     DrawProjectiles
.export     SpawnWeaponOnGround
.export     DrawDroppedWeapon
.export     Weapon_Data_Table 
.export     ClearProjectilePool
.export LoadActiveWeaponToY

;----- Imports -----------------------------------------------------------------
.import     VaderCrab
.import     BigHero
.import     WeaponA
.import     WeaponB
.import     rand                ; Invocando o seu LFSR puro de src/common/Util.s

;----- Includes ----------------------------------------------------------------
.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Registers.inc"

;----- Constants ---------------------------------------------------------------
;MAX_PROJECTILES     = 4         
;WEAPON_ROW_SIZE     = 6        
 ;


; =============================================================================
; TABELA DE DEFINIÇÃO DE ARMAS (Injetada diretamente no segmento CODE para segurança)
; Formato: Tile_ID, Atributos, Tipo_Arma ($00=Branca, $01=Projétil), Dano, Alcance/ID_Proj, Balas
; =============================================================================
.segment "CODE"

Weapon_Data_Table:
    .byte $00, $00, $00, $00, $00, $00  ; ID 0: Desarmado
    ; --- Armas Brancas ---
    .byte $2C, $31, $00, $02, $08, $00  ; ID 1: Faca de Combate
    .byte $2E, $33, $00, $04, $16, $00  ; ID 2: Cano de Ferro
    .byte $4C, $35, $00, $05, $20, $00  ; ID 3: Pedaço de Pau
    ; --- Armas de Projétil ---
    .byte $26, $32, $01, $01, $A0, $05  ; ID 4: Pedra de Arremesso
    .byte $46, $34, $01, $03, $A2, $07  ; ID 5: Pistola 9mm
    .byte $A0, $36, $01, $09, $A4, $01  ; ID 6: Bazuca

;-------------------------------------------------------------------------------
;   ClearProjectilePool (Garante RAM limpa e força Y=$E0 contra Sprites Fantasmas)
;-------------------------------------------------------------------------------
.proc ClearProjectilePool
        rts
.endproc

;-------------------------------------------------------------------------------
;   GetWeaponData (Versão Blindada contra Lixo de 16-bit nos Índices)
;-------------------------------------------------------------------------------
.proc GetWeaponData
        rts
.endproc


;-------------------------------------------------------------------------------
;   ProcessWeaponAttack
;   Entrada: Y = Endereço absoluto do slot ativo (WeaponA ou WeaponB)
;-------------------------------------------------------------------------------
.proc ProcessWeaponAttack
        ; Testa o estado usando o slot parametrizado
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_EQUIPPED
        bne @Exit                       

        ; 1. Transiciona para o estado voando (THROWN)
        lda #WEAPON_STATE_THROWN
        sta a:WeaponStruct::Active, y

        ; 2. Calcula a linha de chão do solo
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #48                         
        sta a:WeaponStruct::Target_Y, y

        ; 3. Define trajetória horizontal com base no Facing
        lda BigHero + BigHeroStruct::Facing
        bne @ArremessoEsquerda

@ArremessoDireita:
        lda #$06                        
        sta a:WeaponStruct::Speed_X, y
        bra @AplicarImpulsoVertical

@ArremessoEsquerda:
        lda #$FA                        ; Força <-6 em byte assinado
        sta a:WeaponStruct::Speed_X, y

@AplicarImpulsoVertical:
        lda #$FA                        ; Força impulso vertical inicial para cima (-6)
        sta a:WeaponStruct::Speed_Y, y

@Exit:
        rts
.endproc

;-------------------------------------------------------------------------------
;   UpdateProjectiles
;   Entrada: Y = Endereço absoluto do slot a processar (WeaponA ou WeaponB)
;-------------------------------------------------------------------------------
.proc UpdateProjectiles
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_THROWN
        beq @StartFisica
        rts

@StartFisica:
        ; 1. Deslocamento Horizontal
        lda a:WeaponStruct::X_Pos, y
        clc
        adc a:WeaponStruct::Speed_X, y
        sta a:WeaponStruct::X_Pos, y

        ; --- CHECAGEM DE COLISÃO LATERAL ---
@CheckWallRight:
        lda a:WeaponStruct::X_Pos, y
        cmp #(SCREEN_RIGHT - 16)        
        bcc @CheckWallLeft               

        lda #(SCREEN_RIGHT - 17)        
        sta a:WeaponStruct::X_Pos, y
        bra @AplicarFisicaRicochete

@CheckWallLeft:
        lda a:WeaponStruct::X_Pos, y
        cmp #(SCREEN_LEFT + 4)
        bcs @ProcessVertical            

        lda #(SCREEN_LEFT + 5)          
        sta a:WeaponStruct::X_Pos, y

@AplicarFisicaRicochete:
        lda a:WeaponStruct::Speed_X, y
        eor #$FF
        clc
        adc #1
        sta a:WeaponStruct::Speed_X, y

        lda #$FC                        ; Impulso para cima (-4)
        sta a:WeaponStruct::Speed_Y, y

@ProcessVertical:
        ; 2. Deslocamento Vertical + Gravidade
        lda a:WeaponStruct::Y_Pos, y
        clc
        adc a:WeaponStruct::Speed_Y, y
        sta a:WeaponStruct::Y_Pos, y

        ; Gravidade incrementa +1 frame a frame
        lda a:WeaponStruct::Speed_Y, y
        clc
        adc #$01
        sta a:WeaponStruct::Speed_Y, y

        ; 3. Checagem de Solo
        lda a:WeaponStruct::Speed_Y, y
         StructuralBMI:
        bmi @Exit                       ; Se for negativo (subindo), pula teste de chão

        lda a:WeaponStruct::Y_Pos, y
        cmp a:WeaponStruct::Target_Y, y                      
        bcc @Exit                       

@TocouOChao:
        lda a:WeaponStruct::Target_Y, y
        sta a:WeaponStruct::Y_Pos, y

        lda #WEAPON_STATE_GROUND
        sta a:WeaponStruct::Active, y

@Exit:
        rts
.endproc

;-------------------------------------------------------------------------------
;   DrawProjectiles (Versão Pura - Sem nenhuma correção ou blindagem)
;-------------------------------------------------------------------------------
.proc DrawProjectiles
        rts                             ; Retorna deixando o X onde parou para a Main.s
.endproc







;-------------------------------------------------------------------------------
;   DrawDroppedWeapon
;   Responsabilidade: Renderizar o item e aplicar H-Flip baseado no herói se equipado
;-------------------------------------------------------------------------------
; =============================================================================
; SUBSISTEMA DE RENDERIZAÇÃO DE ARMAS PARAMETRIZADO VIA REGISTRADOR Y (16-bit)
; =============================================================================

;-------------------------------------------------------------------------------
;   DrawDroppedWeapon (Versão Universal Reutilizável)
;   Entrada: Y = Endereço absoluto de 16-bit da WeaponStruct (WeaponA ou WeaponB)
;   Saída:   X = Incrementado automaticamente na OAMMIRROR
;-------------------------------------------------------------------------------
.proc DrawDroppedWeapon
        ; --- POSIÇÃO X ---
        lda a:WeaponStruct::X_Pos, y
        sta OAMMIRROR, x
        inx
        
        ; --- POSIÇÃO Y ---
        lda a:WeaponStruct::Y_Pos, y
        sta OAMMIRROR, x
        inx
        
        ; --- TILE ID ---
        lda a:WeaponStruct::Tile_ID, y
        sta OAMMIRROR, x
        inx
        
        ; --- ATRIBUTOS COM SISTEMA DE FLIP DINÂMICO ---
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_EQUIPPED
        bne @UseDefaultAttributes        ; Se estiver no chão ou voando, usa o atributo padrão ($01)

        ; Se estiver na mão, checa a direção do herói para espelhar
        lda BigHero + BigHeroStruct::Facing
        beq @UseDefaultAttributes        ; Se Facing = 0 (Olhando para a Direita), mantém padrão

@ApplyHeroFlip:
        lda #$00                         ; Atributo original (Página 1 da VRAM)
        eor #$40                         ; Aplica Flip Horizontal via Hardware (Bit 6)
        sta OAMMIRROR, x
        inx
        rts

@UseDefaultAttributes:
        lda #$00                         ; Atributo padrão apontando para a Página 1 da VRAM
        sta OAMMIRROR, x
        inx
        rts
.endproc

;-------------------------------------------------------------------------------
;   SpawnWeaponOnGround
;   Mantida apenas por compatibilidade com sua Main.s anterior, redirecionando o fluxo
;-------------------------------------------------------------------------------
.proc SpawnWeaponOnGround
        ldy #.loword(WeaponA)            ; Garante que aponta para a WeaponA padrão
        jsr DrawDroppedWeapon
        rts      
.endproc





.proc LoadActiveWeaponToY
 ; === VARREDURA DINÂMICA DE SLOTS POR ESTADO VISUAL ===
        ; Em vez de adivinhar pelo ID, checa qual slot físico está com o estado EQUIPPED (0)
        
@ChecarSlotA:
        lda WeaponA + WeaponStruct::Active
        cmp #WEAPON_STATE_EQUIPPED
        bne @ChecarSlotB                 ; Se não está equipada, tenta o próximo slot

        ldy #.loword(WeaponA)            ; Sucesso: O slot ativo é a WeaponA
        sty z:DP_HERO_OAM_BACKUP
        bra Done

@ChecarSlotB:
        lda WeaponB + WeaponStruct::Active
        cmp #WEAPON_STATE_EQUIPPED
        bne Done                     ; Se nenhum slot está equipado, pula o arraste

        ldy #.loword(WeaponB)            ; Sucesso: O slot ativo é a WeaponB
        sty z:DP_HERO_OAM_BACKUP
Done:
rts
.endproc