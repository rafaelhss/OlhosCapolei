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
.import WeaponA, WeaponB, WeaponC, WeaponD, WeaponE
.import FrameCounter
.import LoadActiveWeaponToY
.import ProcessWeaponAttack
.import ProcessMeleeAttack
.import ProcessFireAttack
.import rand

.export DrawBigHero, MoveBigHero
.export DrawBigHeroHurtboxDebug

PICKUP_DISTANCE  = 32        ; Tolerância em pixels para conseguir pegar a arma
WALK_ANIM_SPEED  = 8         ; Frequência de troca de pernas (a cada 8 frames da PPU)

.segment "CODE"

; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO (Layouts de 8 blocos x 4 bytes = 32 bytes)
; Formato: Offset_X, Offset_Y, Tile_ID, Atributos
; =============================================================================

; FRAME 0: Guarda Neutra (Pés Parados)
BigHero_Layout_Idle:
    .byte 0, 0,$00,$00, 16, 0,$02,$00
    .byte 0,16,$20,$00, 16,16,$22,$00
    .byte 0,32,$40,$00, 16,32,$42,$00
    .byte 0,48,$60,$00, 16,48,$62,$00

; FRAME 1: Caminhada (Passo Aberto A)
BigHero_Layout_Walk:
    .byte 0, 0,$00,$00, 16, 0,$02,$00
    .byte 0,16,$20,$00, 16,16,$22,$00
    .byte 0,32,$A8,$00, 16,32,$AA,$00
    .byte 0,48,$C8,$00, 16,48,$CA,$00

; FRAME 2: Caminhada (Passo Aberto B)
BigHero_Layout_Walk2:
    .byte 0, 0,$00,$00, 16, 0,$02,$00
    .byte 0,16,$20,$00, 16,16,$22,$00
    .byte 0,32,$2C,$00, 16,32,$2E,$00
    .byte 0,48,$4C,$00, 16,48,$4E,$00

; FRAME 3: Estado de Dano / Hitstun
BigHero_Layout_Hurt:
    .byte 0, 0,$80,$00, 16, 0,$82,$00
    .byte 0,16,$20,$00, 16,16,$22,$00
    .byte 0,32,$40,$00, 16,32,$42,$00
    .byte 0,48,$60,$00, 16,48,$62,$00

BigHero_Layout_Weapon0:
    .byte 0, 0,$00,$00, 16, 0,$02,$00
    .byte 0,16,$20,$00, 16,16,$22,$00
    .byte 0,32,$A4,$00, 16,32,$A6,$00
    .byte 0,48,$60,$00, 16,48,$62,$00


BigHero_Layout_Weapon1:
    .byte 0, 0,$00,$00, 16, 0,$02,$00
    .byte 0,16,$20,$00, 16,16,$22,$00
    .byte 0,32,$A4,$00, 16,32,$A6,$00
    .byte 0,48,$C8,$00, 16,48,$CA,$00

BigHero_Layout_Weapon2:
    .byte 0, 0,$00,$00, 16, 0,$02,$00
    .byte 0,16,$20,$00, 16,16,$22,$00
    .byte 0,32,$A4,$00, 16,32,$A6,$00
    .byte 0,48,$4C,$00, 16,48,$4E,$00



; FRAME: Herói Atacando - Preparação (Weapon Melee_Frame = 0)
BigHero_Layout_Attack_Frame0:
    .byte <(-2), 0,$00,$00, 14, 0,$02,$00
    .byte <(-2),16,$20,$00, 14,16,$22,$00
    .byte 0,32,$8C,$00, 16,32,$8E,$00
    .byte 0,48,$60,$00, 16,48,$62,$00

; FRAME: Herói Atacando - Janela de Impacto / Dano (Weapon Melee_Frame = 1)
BigHero_Layout_Attack_Frame1:
    .byte 3, 0,$00,$30, 19, 0,$02,$30
    .byte 3,16,$20,$30, 19,16,$22,$30
    .byte 0,32,$AC,$30, 16,32,$AE,$30
    .byte 0,48,$60,$00, 16,48,$62,$00

; FRAME: Herói Atacando - Recuperação / Cooldown (Weapon Melee_Frame = 2)
BigHero_Layout_Attack_Frame2:
    .byte <(-2), 0,$00,$30, 14, 0,$02,$30
    .byte <(-2),16,$20,$30, 14,16,$22,$30
    .byte 0,32,$8C,$30, 16,32,$8E,$30
    .byte 0,48,$60,$00, 16,48,$62,$00


;-------------------------------------------------------------------------------
;   DrawBigHero
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   DrawBigHero (Versão Atualizada com Sincronismo de Ataque)
;-------------------------------------------------------------------------------
.proc DrawBigHero
        ; --- PIPELINE DE SELEÇÃO DE ANIMAÇÃO HIERÁRQUICA ---
        ; 1. Prioridade Máxima: Estado de Dano / Hitstun
        lda BigHero + BigHeroStruct::HurtTimer
        beq @CheckAttackState

        ldy #.loword(BigHero_Layout_Hurt)
        sty z:DP_HERO_LAYOUT_PTR
        jmp @StartDraw

@CheckAttackState:
        ; 2. Nova Sub-árvore: O Herói está executando um golpe corporal?
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq @CheckMovementNormal        ; Se desarmado, não há porretada possível

        ; Preserva X da OAM para não chipar o preenchimento gráfico principal
        phx
        jsr LoadActiveWeaponToY         ; Devolve o slot ativo em Y
        cpy #0
        bne @ValidateWeaponTimer
        plx
        bra @CheckMovementNormal        ; Falha de segurança: vai pro normal se Y for nulo

@ValidateWeaponTimer:
        lda a:WeaponStruct::Melee_Timer, y
        beq @NoAttackActive             ; Timer zerado -> não está atacando, usa pose armada padrão

        ; --- SINCRONISMO ATÔMICO DE ANIMAÇÃO: Herói casado com a Arma ---
        lda a:WeaponStruct::Melee_Frame, y ; Lê frame 0, 1 ou 2 diretamente da struct da arma
        plx                             ; Restaura X OAM antes do desvio gráfico
        
        cmp #0
        beq @HeroAttack0
        cmp #1
        beq @HeroAttack1
        
@HeroAttack2:
        ldy #.loword(BigHero_Layout_Attack_Frame2)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw
@HeroAttack0:
        ldy #.loword(BigHero_Layout_Attack_Frame0)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw
@HeroAttack1:
        ldy #.loword(BigHero_Layout_Attack_Frame1)
        sty z:DP_HERO_LAYOUT_PTR
        bra @StartDraw

@NoAttackActive:
        plx                             ; Restaura X OAM limpo
        
        ; 3. ÁRVORE DE ANIMAÇÃO ARADO / REPOUSO COM ARMA
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
        ; --- 4. ÁRVORE DE ANIMAÇÃO DESARMADO ---
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
        ora #$10
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
;-------------------------------------------------------------------------------
;   MoveBigHero (Versão Arcade Premium - Filtro Atômico de Trava de Ataque)
;-------------------------------------------------------------------------------
.proc MoveBigHero
        stz z:$02               ; Rascunho na DP ($02): 0 = Parado, 1 = Em movimento

        ; =====================================================================
        ; ⚔️ FILTRO DE SEGURANÇA: SE ESTIVER BATENDO, BLOQUEIA ENTRADA DO D-PAD
        ; =====================================================================
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq @StartMovementPhysics       ; Se estiver desarmado, pula direto para a física normal

        ; Salva registradores para não corromper a Main.s
        phx
        phy
        jsr LoadActiveWeaponToY         ; Busca o slot da arma atual em Y
        cpy #0
        beq @RestoreAndMove             ; Proteção se o ponteiro falhar

        lda a:WeaponStruct::Melee_Timer, y
        beq @RestoreAndMove             ; Se o timer for 0 (não está batendo), libera movimento

        ; --- IMPACTO CINÉTICO: Está batendo! Ignora o D-Pad e vai direto pro fim ---
        ply                             ; Limpa a pilha antes de saltar
        plx
        stz BigHero + BigHeroStruct::Anim_Frame ; Força pés estáticos no chão ao golpear
        jmp ProcessarArrastePipeline   ; Salta direto para manter o arraste da arma ativo

@RestoreAndMove:
        ply                             ; Restaura o contexto antes de rodar o D-Pad
        plx

@StartMovementPhysics:
        ; --- CONFIGURAÇÃO PADRÃO DE VELOCIDADE ---
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
        
        ; --- 1. GUARDA O ID ANTERIOR PARA TESTAR SE HOUVE AÇÃO ---
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        sta z:DP_TEMP_01                ; Usa DP_TEMP_01 para backup rápido

        ; --- 2. TESTA SLOT A ---
        ldy #.loword(WeaponA) 
        jsr CheckWeaponPickup       
        
        ; Se o ID mudou (coletou ou dropou), encerra o frame imediatamente!
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp z:DP_TEMP_01
        bne CheckAttackButton

        ; --- 3. TESTA SLOT B ---
        ldy #.loword(WeaponB) 
        jsr CheckWeaponPickup  
        
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp z:DP_TEMP_01
        bne CheckAttackButton

        ; --- 4. TESTA SLOT C ---
        ldy #.loword(WeaponC) 
        jsr CheckWeaponPickup     
        
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp z:DP_TEMP_01
        bne CheckAttackButton  

        ; --- 4. TESTA SLOT D ---
        ldy #.loword(WeaponD) 
        jsr CheckWeaponPickup  
        
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp z:DP_TEMP_01
        bne CheckAttackButton

        ; --- 4. TESTA SLOT E ---
        ldy #.loword(WeaponE) 
        jsr CheckWeaponPickup  
        
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp z:DP_TEMP_01
        bne CheckAttackButton

CheckAttackButton:                  
        rep #$20
        .a16
        lda JOYTRIGGER1             
        and #Y_BUTTON               
        beq @PickupDone             

        sep #$20                    
        .a8
        
        ; === FILTRO DE SEGURANÇA CONTRA ATAQUE FANTASMA ===
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq @PickupDone

        ; Localiza com segurança qual slot físico de arma está na mão do herói em Y
        jsr LoadActiveWeaponToY
        
        ; === ◄ NOVO FILTRO DE COMPORTAMENTO MELEE vs THROW ===
        ; Se o herói estiver segurando a madeira (WEAPON_ID_WOOD = 3), pula o arremesso!
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_WOOD             
        beq @DispararAtaqueMelee 
        cmp #WEAPON_ID_PISTOL             
        beq @DispararAtaqueFire 
        cmp #WEAPON_ID_CHAIN             
        beq @DispararAtaqueMelee        

@Arremessar:
        ; Se for Pedra ou Martelo, segue o fluxo de esvaziar inventário e arremessar
        lda #WEAPON_ID_UNARMED
        sta BigHero + BigHeroStruct::Current_Weapon_ID
        jsr ProcessWeaponAttack     
        bra @PickupDone

@DispararAtaqueMelee:
        ; Se for madeira, NÃO limpa o inventário (ela fica na mão) e chama o ataque físico
@RolarDado:
        jsr rand            ; Retorna valor em A (8-bits)
        and #$03            ; Isola os dois primeiros bits (Gera valores: 0, 1, 2 ou 3)
        cmp #3              ; O resultado deu 3?
        beq @RolarDado      ; Se for IGUAL a 3, rejeita e rola de novo imediatamente!

        sta a:WeaponStruct::Anim_Variation, y 
        
        jsr ProcessMeleeAttack
        bra @PickupDone


@DispararAtaqueFire:
        jsr ProcessFireAttack
        bra @PickupDone


@PickupDone:
        sep #$20                    
        .a8

        ; === ENGINE DE ATUALIZAÇÃO DO ANIM_FRAME DO PROTAGONISTA ===
        lda z:$02               ; Carrega o estado de movimento lido do D-Pad
        bne @UpdateWalkAnimation

        ; Se não está se movendo, força o frame de Idle (0) imediatamente
        stz BigHero + BigHeroStruct::Anim_Frame
        bra ProcessarArrastePipeline

@UpdateWalkAnimation:
        ; Taxa de amostragem: Só alterna o passo a cada N frames globais do clock da PPU
        lda FrameCounter
        and #(WALK_ANIM_SPEED - 1) ; Filtra o bit operacional (Módulo 8)
        bne ProcessarArrastePipeline

        ; Avança dinamicamente entre Passo 1 e Passo 2
        lda BigHero + BigHeroStruct::Anim_Frame
        cmp #1
        beq @SetPasso2

@SetPasso1:
        lda #1
        sta BigHero + BigHeroStruct::Anim_Frame
        bra ProcessarArrastePipeline

@SetPasso2:
        lda #2
        sta BigHero + BigHeroStruct::Anim_Frame

ProcessarArrastePipeline:
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
        beq @Vulnerable                 ; Se o timer for 0, ele está normal. Vai para vulnerável.

        ; Se o timer for maior que zero, ele tomou dano! Decrementa o relógio
        dec BigHero + BigHeroStruct::HurtTimer
        
        ; BLINDAGEM: Garante que ele continue INVULNERÁVEL (0) durante todo o Hitstun!
        stz BigHero + BigHeroStruct::Hurtbox_Active
        stz BigHero + BigHeroStruct::Anim_Frame ; Trava pernas estáticas se atingido
        rts
@Vulnerable:
        lda #$01
        sta BigHero + BigHeroStruct::Hurtbox_Active
        rts
.endproc

;-------------------------------------------------------------------------------
;   CheckWeaponPickup / DropWeapon (Versão Sênior - Troca de Inventário Blindada)
;   Entrada: Y = Endereço absoluto do slot a ser testado (WeaponA..WeaponE)
;-------------------------------------------------------------------------------
.proc CheckWeaponPickup
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_EQUIPPED
        beq @DropWeapon
        
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_GROUND
        beq @TestDist
        jmp @Exit


; --- TESTE DE DISTÂNCIA HIERÁRQUICO (AABB) ---
@TestDist:
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
        clc
        adc #48                         ; ◄ INJETADO: Move a âncora de teste da cabeça para a base/pés
        sec
        sbc a:WeaponStruct::Y_Pos, y    ; Compara os pés do Herói com o chão da arma
        bcs @DiffYPositive

        eor #$FF
        clc
        adc #1
@DiffYPositive:
        cmp #PICKUP_DISTANCE
        bcs @Exit

        ; =====================================================================
        ; SE O HERÓI JÁ ESTIVER SEGURANDO OUTRA ARMA, FORÇA O DROP DELA PRIMEIRO
        ; =====================================================================
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq @ApplyNewPickup             ; Se estava desarmado, pula direto para a coleta

        ; Preserva o Y da nova arma que estamos prestes a coletar
        phy                             
        
        ; Localiza qual slot antigo está na mão e força o desequipamento físico dele
        jsr LoadActiveWeaponToY         ; Retorna o slot antigo em Y
        cpy #0
        beq @PopAndPickup               ; Proteção contra ponteiro nulo

        ; Força a arma antiga a ir para o chão de forma limpa
        lda #WEAPON_STATE_GROUND
        sta a:WeaponStruct::Active, y

        ; Configura a posição de soltura da arma antiga rente ao corpo do herói
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #48
        sta a:WeaponStruct::Target_Y, y
        sta a:WeaponStruct::Y_Pos, y
        
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #8                          
        sta a:WeaponStruct::X_Pos, y

@PopAndPickup:
        ply                             ; Recupera o Y da nova arma que o herói está em cima

@ApplyNewPickup:
        ; Executa a coleta da nova arma estritamente
        lda a:WeaponStruct::Weapon_ID, y
        sta BigHero + BigHeroStruct::Current_Weapon_ID
        
        lda #WEAPON_STATE_EQUIPPED
        sta a:WeaponStruct::Active, y
        rts

@DropWeapon:
        ; --- COMPORTAMENTO PADRÃO DE DROP VOLUNTÁRIO (BOTÃO X) ---
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_EQUIPPED
        bne @Exit

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