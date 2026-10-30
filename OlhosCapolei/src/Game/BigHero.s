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
.include "Weapon2.inc"

.import BigHero
.import WeaponA, WeaponB
.import FrameCounter
.import LoadActiveWeaponToY
.import ProcessWeaponAttack

.export DrawBigHero, MoveBigHero
.export DrawBigHeroHurtboxDebug

PICKUP_DISTANCE  = 48        ; Tolerância em pixels para conseguir pegar a arma
WALK_ANIM_SPEED  = 8         ; Frequência de troca de pernas (a cada 8 frames da PPU)

.segment "CODE"

; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO (Layouts de 8 blocos x 4 bytes = 32 bytes)
; Formato: Offset_X, Offset_Y, Tile_ID, Atributos
; =============================================================================

; FRAME 0: Guarda Neutra (Pés Parados)
BigHero_Layout_Idle:
    .byte 0, 0,$20,$30, 16, 0,$22,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$60,$30, 16,32,$62,$30
    .byte 0,48,$80,$30, 16,48,$82,$30

; FRAME 1: Caminhada (Passo Aberto A)
BigHero_Layout_Walk:
    .byte 0, 0,$20,$30, 16, 0,$22,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$A8,$30, 16,32,$AA,$30
    .byte 0,48,$C8,$30, 16,48,$CA,$30

; FRAME 2: Caminhada (Passo Aberto B)
BigHero_Layout_Walk2:
    .byte 0, 0,$20,$30, 16, 0,$22,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$2C,$30, 16,32,$2E,$30
    .byte 0,48,$4C,$30, 16,48,$4E,$30

; FRAME 3: Estado de Dano / Hitstun
BigHero_Layout_Hurt:
    .byte 0, 0,$A0,$30, 16, 0,$A2,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$60,$30, 16,32,$62,$30
    .byte 0,48,$80,$30, 16,48,$82,$30

BigHero_Layout_Weapon0:
    .byte 0, 0,$20,$30, 16, 0,$22,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$A4,$30, 16,32,$A6,$30
    .byte 0,48,$80,$30, 16,48,$82,$30

BigHero_Layout_Weapon1:
    .byte 0, 0,$20,$30, 16, 0,$22,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$A4,$30, 16,32,$A6,$30
    .byte 0,48,$C8,$30, 16,48,$CA,$30

BigHero_Layout_Weapon2:
    .byte 0, 0,$20,$30, 16, 0,$22,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$A4,$30, 16,32,$A6,$30
     .byte 0,48,$4C,$30, 16,48,$4E,$30

;-------------------------------------------------------------------------------
;   DrawBigHero
;-------------------------------------------------------------------------------
.proc DrawBigHero
        ; --- PIPELINE DE SELEÇÃO DE ANIMAÇÃO HIERÁRQUICA ---
        ; 1. Prioridade Máxima: Estado de Dano / Hitstun
        lda BigHero + BigHeroStruct::HurtTimer
        beq @CheckWeapon

        ldy #.loword(BigHero_Layout_Hurt)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw

@CheckWeapon:
        ; 2. Verifica se o herói está armado para selecionar a sub-árvore de animações
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq @CheckMovementNormal

        ; --- ÁRVORE DE ANIMAÇÃO COM ARMA ---
        lda BigHero + BigHeroStruct::Anim_Frame
        cmp #0
        beq @WeaponIdle
        cmp #1
        beq @WeaponWalk1
        cmp #2
        beq @WeaponWalk2

@WeaponIdle:
        ldy #.loword(BigHero_Layout_Weapon0)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw
@WeaponWalk1:
        ldy #.loword(BigHero_Layout_Weapon1)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw
@WeaponWalk2:
        ldy #.loword(BigHero_Layout_Weapon2)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw

@CheckMovementNormal:
        ; --- ÁRVORE DE ANIMAÇÃO DESARMADO ---
        lda BigHero + BigHeroStruct::Anim_Frame
        cmp #0
        beq @Idle
        cmp #1
        beq @Walk1
        cmp #2
        beq @Walk2

@Idle: 
        ldy #.loword(BigHero_Layout_Idle)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw
@Walk1: 
        ldy #.loword(BigHero_Layout_Walk)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw
@Walk2: 
        ldy #.loword(BigHero_Layout_Walk2)
        sty z:DP_HERO_LAYOUT_PTR
@StartDraw:
@DrawHeroBody:
        ldy #$0000              

DrawLoop:
        ; --- EIXO X (Com suporte a espelhamento) ---
        lda BigHero + BigHeroStruct::Facing
        beq @NoXFlip

        lda #16
        sec
        sbc (DP_HERO_LAYOUT_PTR),y
        bra @ApplyXPos

@NoXFlip:
        lda (DP_HERO_LAYOUT_PTR),y

@ApplyXPos:
        clc
        adc BigHero + BigHeroStruct::X_Pos
        sta OAMMIRROR, x
        inx
        iny                     

        ; --- EIXO Y ---
        clc
        lda BigHero + BigHeroStruct::Y_Pos
        adc (DP_HERO_LAYOUT_PTR),y
        sta OAMMIRROR, x
        inx
        iny                     

        ; --- TILE ID ---
        lda (DP_HERO_LAYOUT_PTR),y
        sta OAMMIRROR, x
        inx
        iny                     

        ; --- ATRIBUTOS ---
        lda (DP_HERO_LAYOUT_PTR),y
        sta z:$00                       
        
        lda BigHero + BigHeroStruct::Facing
        beq @WriteAttributes            
        
        lda z:$00
        eor #$40                        
        sta z:$00

@WriteAttributes:
        lda z:$00
        sta OAMMIRROR, x
        inx
        iny                     

        cpy #32
        bne DrawLoop
        rts
.endproc

;-------------------------------------------------------------------------------
;   MoveBigHero
;-------------------------------------------------------------------------------
.proc MoveBigHero
        stz z:$02               ; Rascunho na DP ($02): 0 = Parado, 1 = Em movimento
        
        lda #SPRITE_SPEED
        sta HOR_SPEED
        sta VER_SPEED

        rep #$20                
        .a16
        lda JOYHELD1
        and #A_BUTTON
        beq CheckRight
        
        sep #$20                
        .a8
        lda #(SPRITE_SPEED + SPRITE_SPEED)
        sta HOR_SPEED
        sta VER_SPEED

CheckRight:
        rep #$20                
        .a16
        lda JOYHELD1
        and #RIGHT_BUTTON
        beq CheckLeft

        sep #$20                
        .a8
MoveRight:
        stz BigHero + BigHeroStruct::Facing     
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc HOR_SPEED               
        sta BigHero + BigHeroStruct::X_Pos 
        lda #1
        sta z:$02               ; Ativa flag de movimento

CheckLeft:
        rep #$20                
        .a16
        lda JOYHELD1
        and #LEFT_BUTTON
        beq CheckUp

        sep #$20                
        .a8
MoveLeft:
        lda #$01
        sta BigHero + BigHeroStruct::Facing     
        lda BigHero + BigHeroStruct::X_Pos
        sec
        sbc HOR_SPEED               
        sta BigHero + BigHeroStruct::X_Pos
        lda #1
        sta z:$02               ; Ativa flag de movimento

CheckUp:
        rep #$20                
        .a16
        lda JOYHELD1
        and #UP_BUTTON
        beq CheckDown

        sep #$20                
        .a8
MoveUp:
        lda BigHero + BigHeroStruct::Y_Pos
        sec
        sbc VER_SPEED               
        sta BigHero + BigHeroStruct::Y_Pos
        lda #1
        sta z:$02               ; Ativa flag de movimento

CheckDown:
        rep #$20                
        .a16
        lda JOYHELD1
        and #DOWN_BUTTON
        beq CheckPickupButton

        sep #$20                
        .a8
MoveDown:
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc VER_SPEED                       
        sta BigHero + BigHeroStruct::Y_Pos
        lda #1
        sta z:$02               ; Ativa flag de movimento

CheckPickupButton:
        rep #$20                    
        .a16
        lda JOYTRIGGER1             
        and #X_BUTTON                  
        beq CheckAttackButton             

        sep #$20                    
        .a8
        ldy #.loword(WeaponA) 
        jsr CheckWeaponPickup       
        ldy #.loword(WeaponB) 
        jsr CheckWeaponPickup       

CheckAttackButton:                  
        rep #$20
        .a16
        lda JOYTRIGGER1             
        and #Y_BUTTON               
        beq @PickupDone             

        sep #$20                    
        .a8
        
        ; === FILTRO DE SEGURANÇA CONTRA ATAQUE FANTASMA ===
        ; Se o herói estiver desarmado, ignora o botão Y completamente e aborta
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq @PickupDone

        ; Localiza com segurança qual slot físico está na mão do herói
        jsr LoadActiveWeaponToY
        
        ; Gerenciamento de Inventário Consumível (Mapeia se a arma vai sumir da mão)
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_ROCK             
        beq @Arremessar        
        cmp #WEAPON_ID_HAMMER             
        beq @Arremessar        
        bra @DispararAtaqueComum

@Arremessar:
        ; Como a pedra/martelo são consumíveis, limpa o inventário do herói antes do voo
        lda #WEAPON_ID_UNARMED
        sta BigHero + BigHeroStruct::Current_Weapon_ID

@DispararAtaqueComum:
        ; Executa o arremesso passando o Y validado com o endereço da arma ativa
        jsr ProcessWeaponAttack     

@PickupDone:
        sep #$20                    
        .a8

        ; === ENGINE DE ATUALIZAÇÃO DO ANIM_FRAME DO PROTAGONISTA ===
        lda z:$02               ; Carrega o estado de movimento lido do D-Pad
        bne @UpdateWalkAnimation

        ; Se não está se movendo, força o frame de Idle (0) imediatamente
        stz BigHero + BigHeroStruct::Anim_Frame
        bra @ProcessarArrastePipeline

@UpdateWalkAnimation:
        ; Taxa de amostragem: Só alterna o passo a cada N frames globais do clock da PPU
        lda FrameCounter
        and #(WALK_ANIM_SPEED - 1) ; Filtra o bit operacional (Módulo 8)
        bne @ProcessarArrastePipeline

        ; Avança dinamicamente entre Passo 1 e Passo 2
        lda BigHero + BigHeroStruct::Anim_Frame
        cmp #1
        beq @SetPasso2

@SetPasso1:
        lda #1
        sta BigHero + BigHeroStruct::Anim_Frame
        bra @ProcessarArrastePipeline

@SetPasso2:
        lda #2
        sta BigHero + BigHeroStruct::Anim_Frame

@ProcessarArrastePipeline:
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq MoveDone
        
        jsr LoadActiveWeaponToY
        ldy z:DP_HERO_OAM_BACKUP     

@ProcessarArraste:
        lda BigHero + BigHeroStruct::Facing
        bne @ArrasteEsquerda

@ArrasteDireita:
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #16                      
        sta a:WeaponStruct::X_Pos, y 
        bra @AjustarY

@ArrasteEsquerda:
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #01                      
        sta a:WeaponStruct::X_Pos, y 

@AjustarY:
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #24                      
        sta a:WeaponStruct::Y_Pos, y 

MoveDone:
        ; --- SISTEMA DE MANUTENÇÃO DE GEOMETRIA & INVENCIBILIDADE ---
        lda BigHero + BigHeroStruct::X_Pos
        sta BigHero + BigHeroStruct::Hurtbox_X1
        clc
        adc #32                             
        sta BigHero + BigHeroStruct::Hurtbox_X2

lda BigHero + BigHeroStruct::Y_Pos
sta BigHero + BigHeroStruct::Hurtbox_Y1
clc
adc #64
sta BigHero + BigHeroStruct::Hurtbox_Y2
lda BigHero + BigHeroStruct::HurtTimer
beq @Vulnerable
dec BigHero + BigHeroStruct::HurtTimer
stz BigHero + BigHeroStruct::Hurtbox_Active
stz BigHero + BigHeroStruct::Anim_Frame ; Trava pernas estáticas se atingido
rts
@Vulnerable:
lda #$01
sta BigHero + BigHeroStruct::Hurtbox_Active
rts
.endproc
;-------------------------------------------------------------------------------
;   CheckWeaponPickup / DropWeapon (Versão Corrigida Parametrizada)
;-------------------------------------------------------------------------------
.proc CheckWeaponPickup
lda a:WeaponStruct::Active, y
cmp #WEAPON_STATE_EQUIPPED
beq @DropWeapon
lda a:WeaponStruct::Active, y
cmp #WEAPON_STATE_GROUND
bne @Exit
lda BigHero + BigHeroStruct::X_Pos
sec
sbc a:WeaponStruct::X_Pos, y
bcs @DiffXPositive
eor #$FF
clc
adc #1
@DiffXPositive:
cmp #PICKUP_DISTANCE
bcs @Exit
lda BigHero + BigHeroStruct::Y_Pos
sec
sbc a:WeaponStruct::Y_Pos, y
bcs @DiffYPositive
eor #$FF
clc
adc #1
@DiffYPositive:
cmp #PICKUP_DISTANCE
bcs @Exit
lda a:WeaponStruct::Weapon_ID, y
sta BigHero + BigHeroStruct::Current_Weapon_ID
lda #WEAPON_STATE_EQUIPPED
sta a:WeaponStruct::Active, y
rts
@DropWeapon:
lda #WEAPON_ID_UNARMED
sta BigHero + BigHeroStruct::Current_Weapon_ID
lda #WEAPON_STATE_GROUND
sta a:WeaponStruct::Active, y
lda BigHero + BigHeroStruct::Y_Pos
clc
adc #48
sta a:WeaponStruct::Target_Y, y
sta a:WeaponStruct::Y_Pos, y
lda BigHero + BigHeroStruct::X_Pos
clc
adc #8
sta a:WeaponStruct::X_Pos, y
@Exit:
rts
.endproc
;-------------------------------------------------------------------------------
;   DrawBigHeroHurtboxDebug
;-------------------------------------------------------------------------------
.proc DrawBigHeroHurtboxDebug
lda BigHero + BigHeroStruct::Hurtbox_X1
sta a:OAMMIRROR, X
inx
lda BigHero + BigHeroStruct::Hurtbox_Y1
sta a:OAMMIRROR, X
inx
lda #$A0
sta a:OAMMIRROR, X
inx
lda #$31
sta a:OAMMIRROR, X
inx
lda BigHero + BigHeroStruct::Hurtbox_X2
sta a:OAMMIRROR, X
inx
lda BigHero + BigHeroStruct::Hurtbox_Y2
sta a:OAMMIRROR, X
inx
lda #$A2
sta a:OAMMIRROR, X
inx
lda #$31
sta OAMMIRROR, X
inx
rts
.endproc