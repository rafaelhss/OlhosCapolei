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
.include "Weapon.inc"

.import BigHero
.import GetWeaponData       
.import Weapon_Data_Table  


.export DrawBigHero, MoveBigHero
.export DrawBigHeroHurtboxDebug

; --- Alocação de Ponteiro na Direct Page ---
;DP_HERO_LAYOUT_PTR = $04 ;comentada pq foi para o gameconstants

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

; --- Tabela de Offsets Locais da Mão do BigHero por Frame ---
; Define onde a arma deve ser colada em relação ao X_Pos e Y_Pos globais
Hero_Hand_Offsets:
    .byte 24, 20    ; Frame 0 (Idle): Mão avança 24px em X, desce 20px em Y
    .byte 24, 18    ; Frame 1 (Walk): Mão avança 24px em X, desce 18px em Y
    .byte 12, 24    ; Frame 2 (Hurt): Mão recua para 12px em X devido ao hitstun

;-------------------------------------------------------------------------------
;   DrawBigHero
;-------------------------------------------------------------------------------
.proc DrawBigHero
        ; --- PIPELINE DE SELEÇÃO DE ANIMAÇÃO HIERÁRQUICA ---
        lda BigHero + BigHeroStruct::HurtTimer
        beq @CheckMovement

        ldy #.loword(BigHero_Layout_Hurt)
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
        ; =====================================================================
        ; CRÍTICO: ACOPLAMENTO FRONTAL DA ARMA EQUIPADA (ORDEM HIERÁRQUICA OAM)
        ; =====================================================================
        ; Desenhamos a arma PRIMEIRO. Assim ela pega um índice mais baixo na OAM
        ; e a PPU do SNES a renderiza na frente do peito do herói automaticamente!
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        beq @DrawHeroBody               ; Se ID for 0 (Desarmado), vai direto para o corpo

        sta z:DP_TEMP_00                       ; Guarda temporariamente o ID em $00 da DP

        ; Descobre qual índice de frame da mão ler (0=Idle, 1=Walk, 2=Hurt)
        lda BigHero + BigHeroStruct::HurtTimer
        beq @CheckHandWalk
        lda #2                          ; Força frame da mão em Hurt
        bra @CalcularOffsetsMao

@CheckHandWalk:
        lda BigHero + BigHeroStruct::Anim_Frame ; Pega 0 ou 1 da caminhada

@CalcularOffsetsMao:
        asl a                           ; Multiplica por 2 (cada entrada tem 2 bytes: X e Y)
        tay                             ; Transfere para Y para indexar a Hero_Hand_Offsets

        lda Hero_Hand_Offsets, y     
        sta z:DP_TEMP_02                       ; Guarda Offset X local da mão em $02 da DP
        lda Hero_Hand_Offsets + 1, y 
        sta z:DP_TEMP_03                       ; Guarda Offset Y local da mão em $03 da DP

        ; Preserva o offset OAM (X) antes de chamar a rotina de dados státicos da ROM
        stx z:DP_HERO_OAM_BACKUP

        lda z:DP_TEMP_00                       ; Recarrega o ID da arma
        jsr GetWeaponData               ; Retorna em Y o offset exato da arma na ROM
        
        ldx z:DP_HERO_OAM_BACKUP                       ; Recupera o offset OAM limpo

        ; Injeta o sprite da arma acoplada na OAMMIRROR
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc z:DP_TEMP_02                       ; Posição X Global da arma
        sta OAMMIRROR, x
        inx

        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc z:DP_TEMP_03                       ; Posição Y Global da arma
        sta OAMMIRROR, x
        inx

        lda Weapon_Data_Table, y        ; Carrega o Tile_ID correto da arma vindo da ROM
        sta OAMMIRROR, x
        inx

        lda Weapon_Data_Table + 1, y    ; Carrega os Atributos de paleta/prioridade da arma
        sta OAMMIRROR, x
        inx                             ; Avança OAM de forma cumulativa

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
        jsr CheckWeaponPickup       ; Dispara o motor tridimensional de coleta do chão

CheckAttackButton:                  
        rep #$20
        .a16
        lda JOYTRIGGER1             
        and #Y_BUTTON               ; ◄ ALTERADO: Agora intercepta o clique do botão Y!
        beq @PickupDone             

        sep #$20                    
        .a8
        jsr ProcessWeaponAttack     ; Invoca o motor de ataque (tiro ou arremesso de pedra)


@PickupDone:
        sep #$20                    
        .a8

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
