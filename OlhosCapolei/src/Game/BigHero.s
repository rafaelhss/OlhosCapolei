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

.import     WeaponA, WeaponB


.export DrawBigHero, MoveBigHero
.export DrawBigHeroHurtboxDebug

; --- Alocação de Ponteiro na Direct Page ---
;DP_HERO_LAYOUT_PTR = $04 ;comentada pq foi para o gameconstants


PICKUP_DISTANCE  = 48        ; Tolerância em pixels para conseguir pegar a arma

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

; FRAME 1: Caminhada (Passo Aberto)
BigHero_Layout_Walk:
    .byte 0, 0,$20,$30, 16, 0,$22,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$60,$30, 16,32,$62,$30
    .byte 0,48,$A0,$30, 16,48,$A2,$30

; FRAME 2: Estado de Dano / Hitstun (Cabeça muda para Tiles $A0/$A2)
BigHero_Layout_Hurt:
    .byte 0, 0,$A0,$30, 16, 0,$A2,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$60,$30, 16,32,$62,$30
    .byte 0,48,$80,$30, 16,48,$82,$30

BigHero_Layout_WeaponA:
    .byte 0, 0,$20,$30, 16, 0,$22,$30
    .byte 0,16,$40,$30, 16,16,$42,$30
    .byte 0,32,$A4,$30, 16,32,$A6,$30
    .byte 0,48,$80,$30, 16,48,$82,$30


;-------------------------------------------------------------------------------
;   DrawBigHero
;-------------------------------------------------------------------------------
.proc DrawBigHero
        ; --- PIPELINE DE SELEÇÃO DE ANIMAÇÃO HIERÁRQUICA ---
        lda BigHero + BigHeroStruct::HurtTimer
        beq @CheckWeapon

        ldy #.loword(BigHero_Layout_Hurt)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw

@CheckWeapon:
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq @CheckMovement

        ldy #.loword(BigHero_Layout_WeaponA)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw


@CheckMovement:
        lda BigHero + BigHeroStruct::Anim_Frame
        bne @WalkFrame
        
        ldy #.loword(BigHero_Layout_Idle)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw

@WalkFrame:
        ldy #.loword(BigHero_Layout_Walk)
        sty z:DP_HERO_LAYOUT_PTR

@StartDraw:
@DrawHeroBody:
        ldy #$0000              ; Reseta Y para indexar os 8 blocos do corpo do herói

DrawLoop:
        ; --- EIXO X (Com suporte a espelhamento) ---
        lda BigHero + BigHeroStruct::Facing
        beq @NoXFlip

        ; Se estiver olhando para a esquerda, nós invertemos o deslocamento X do bloco
        ; O herói tem 32px de largura, e cada bloco tem 16px. 
        ; Para espelhar a matriz de 2 colunas: Novo_Offset = 16 - Offset_Original
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

        ; --- ATRIBUTOS (Injeta o Flip se Facing = 1) ---
        lda (DP_HERO_LAYOUT_PTR),y
        sta z:$00                       ; Guarda o atributo original da ROM em $00
        
        lda BigHero + BigHeroStruct::Facing
        beq @WriteAttributes            ; Se for 0 (Direita), pula o flip
        
        lda z:$00
        eor #$40                        ; Aplica Flip Horizontal via Hardware (Bit 6)
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
        stz BigHero + BigHeroStruct::Facing     ; ◄ $00 = Olhando para a DIREITA
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc HOR_SPEED               
        sta BigHero + BigHeroStruct::X_Pos 

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
        sta BigHero + BigHeroStruct::Facing     ; ◄ $01 = Olhando para a ESQUERDA
        lda BigHero + BigHeroStruct::X_Pos
        sec
        sbc HOR_SPEED               
        sta BigHero + BigHeroStruct::X_Pos


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

CheckPickupButton:
        ; === CENTRALIZAÇÃO DE INPUT: BOTÃO X PARA COLETAR ARMA ===
        rep #$20                    
        .a16
        lda JOYTRIGGER1             ; Captura o clique atômico do frame
        and #X_BUTTON                  ; Máscara de hardware do botão X
        beq CheckAttackButton             

        sep #$20                    
        .a8

        ldy #.loword(WeaponA) 
        jsr CheckWeaponPickup       ; Dispara o motor tridimensional de coleta do chão
        ldy #.loword(WeaponB) 
        jsr CheckWeaponPickup       ; Dispara o motor tridimensional de coleta do chão


CheckAttackButton:                  
        rep #$20
        .a16
        lda JOYTRIGGER1             
        and #Y_BUTTON               
        beq @PickupDone             

        sep #$20                    
        .a8
        
        ; 1. Localiza o slot físico ANTES de zerar o inventário do herói
        jsr LoadActiveWeaponToY
        
        ; 2. Gerenciamento de Inventário Consumível
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_ROCK             
        beq @Arremessar        
        cmp #WEAPON_ID_HAMMER             
        beq @Arremessar        
        bra @DispararAtaqueComum

@Arremessar:
        lda #WEAPON_ID_UNARMED
        sta BigHero + BigHeroStruct::Current_Weapon_ID

@DispararAtaqueComum:
        ; Executa o arremesso passando o Y preservado com o endereço da arma ativa
        jsr ProcessWeaponAttack         


@PickupDone:
        sep #$20                    
        .a8
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq MoveDone
        
        ; Sincroniza o slot de arraste para a caminhada
        jsr LoadActiveWeaponToY
        ldy z:DP_HERO_OAM_BACKUP     ; Recupera o ponteiro salvo da DP para garantir

@ProcessarArraste:
        ; --- CALCULO DO ARRASTE GEOMÉTRICO USANDO O PONTEIRO Y ---
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
        rts

@Vulnerable:
        lda #$01 
        sta BigHero + BigHeroStruct::Hurtbox_Active
        rts
.endproc

;-------------------------------------------------------------------------------
;   CheckWeaponPickup
;   Calcula a proximidade entre BigHero e WeaponA. Se perto, equipa
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   CheckWeaponPickup / DropWeapon (Versão Corrigida Parametrizada)
;-------------------------------------------------------------------------------
.proc CheckWeaponPickup
        ; 1. Se a arma enviada por Y já estiver equipada por este herói, o botão X dropa ela
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_EQUIPPED
        beq @DropWeapon

        ; 2. Se a arma está no chão, checa proximidade para ver se o jogador está em cima dela
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_GROUND
        bne @Exit

        ; --- Cálculo de Distância Absoluta no Eixo X ---
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

        ; --- Cálculo de Distância Absoluta no Eixo Y ---
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

        ; --- SE PASSOU NOS TESTES: COLETA ESTA ARMA ESPECÍFICA ---
        lda a:WeaponStruct::Weapon_ID, y
        sta BigHero + BigHeroStruct::Current_Weapon_ID
        
        lda #WEAPON_STATE_EQUIPPED
        sta a:WeaponStruct::Active, y
        rts

@DropWeapon:
        ; Desequipa rigidamente a arma que estava na mão
        lda #WEAPON_ID_UNARMED
        sta BigHero + BigHeroStruct::Current_Weapon_ID

        lda #WEAPON_STATE_GROUND
        sta a:WeaponStruct::Active, y

        ; Alinha o repouso no chão com os pés atuais do herói
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #48                         
        sta a:WeaponStruct::Target_Y, y
        sta a:WeaponStruct::Y_Pos, y

        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #8                          
        sta a:WeaponStruct::X_Pos, y

        ;lda #$6D                        ; Restaura tile original de chão
        ;sta a:WeaponStruct::Tile_ID, y

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
