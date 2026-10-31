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
.export     LoadActiveWeaponToY
.export     ProcessMeleeAttack

;----- Imports -----------------------------------------------------------------
.import     VaderCrab
.import     BigHero
.import     WeaponA
.import     WeaponB
.import     WeaponC
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



Weapon_Layout_Hammer:
    .byte 0, <(  0), $66, $30  
    .byte 0, <(-16), $46, $30
    .byte 0, <(-32), $26, $30  
    .byte 0, <(-48), $06, $30

Weapon_Layout_Hammer_Attack_Frame0:
    .byte 0, <(  0), $68, $30  
    .byte 8, <(-16), $48, $30
    .byte 16, <(-32), $28, $30  
    .byte 24, <(-48), $08, $30

Weapon_Layout_Hammer_Attack_Frame1:
    .byte 0, <(  0), $6A, $30  
    .byte 16, <(-8), $4A, $30
    .byte 32, <(-16), $2A, $30  
    .byte 48, <(-24), $0A, $30

Weapon_Layout_Hammer_Attack_Frame2:
    .byte 0, <(  0), $64, $30  
    .byte 16, <(  0), $44, $30
    .byte 32, <( 0), $24, $30  
    .byte 48, <( 0), $04, $30

    
    
;-------------------------------------------------------------------------------
;   ClearProjectilePool (Garante RAM limpa e força Y=$E0 contra Sprites Fantasmas)
;-------------------------------------------------------------------------------
.proc ClearProjectilePool
        ; === ZERAMENTO INICIAL DE SEGURANÇA DOS SLOTS (WRAM SANITIZATION) ===
        ; Garante que nenhuma arma inicie voando ou com lixo nas velocidades
        php                     ; Preserva o estado atual dos flags da CPU
        sep #$20                ; Garante que o Acumulador está em 8-bit (.a8)
        rep #$10                ; Garante que os Índices X/Y estão em 16-bit (.i16)

        lda #$00                ; Carrega zero em A para usar o modo de endereçamento válido sta ..., y

        ; --- SANITIZAÇÃO DA WEAPON A ---
        ldy #.loword(WeaponA)
        sta a:WeaponStruct::Active, y
        sta a:WeaponStruct::Weapon_ID, y
        sta a:WeaponStruct::Tile_ID, y
        sta a:WeaponStruct::X_Pos, y
        sta a:WeaponStruct::Y_Pos, y
        sta a:WeaponStruct::Speed_X, y
        sta a:WeaponStruct::Speed_Y, y
        sta a:WeaponStruct::Target_Y, y
        sta a:WeaponStruct::Melee_Timer, y
        sta a:WeaponStruct::Melee_Frame, y

        ; --- SANITIZAÇÃO DA WEAPON B ---
        ldy #.loword(WeaponB)
        sta a:WeaponStruct::Active, y
        sta a:WeaponStruct::Weapon_ID, y
        sta a:WeaponStruct::Tile_ID, y
        sta a:WeaponStruct::X_Pos, y
        sta a:WeaponStruct::Y_Pos, y
        sta a:WeaponStruct::Speed_X, y
        sta a:WeaponStruct::Speed_Y, y
        sta a:WeaponStruct::Target_Y, y
        sta a:WeaponStruct::Melee_Timer, y
        sta a:WeaponStruct::Melee_Frame, y

        ; --- SANITIZAÇÃO DA WEAPON C ---
        ldy #.loword(WeaponC)
        sta a:WeaponStruct::Active, y
        sta a:WeaponStruct::Weapon_ID, y
        sta a:WeaponStruct::Tile_ID, y
        sta a:WeaponStruct::X_Pos, y
        sta a:WeaponStruct::Y_Pos, y
        sta a:WeaponStruct::Speed_X, y
        sta a:WeaponStruct::Speed_Y, y
        sta a:WeaponStruct::Target_Y, y
        sta a:WeaponStruct::Melee_Timer, y
        sta a:WeaponStruct::Melee_Frame, y

        plp                     ; Restaura o estado anterior dos flags da CPU
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
;   Entrada: Y = Endereço absoluto do slot a processar
;-------------------------------------------------------------------------------
.proc UpdateProjectiles
        ; 1. Se estiver voando (THROWN), executa a física de parábola original
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_THROWN
        beq @StartFisica
        
        ; 2. Se estiver equipada, verifica o timer de ataque corpo a corpo
        cmp #WEAPON_STATE_EQUIPPED
        bne @Exit
        
        lda a:WeaponStruct::Melee_Timer, y
        beq @Exit                       ; Se for zero, não há porretada ativa

        ; --- PIPELINE DO MOTOR MELEE ---
        lda a:WeaponStruct::Melee_Timer, y
        dec
        sta a:WeaponStruct::Melee_Timer, y
        beq @MeleeFinished

        ; Define o frame baseado exclusivamente na variável Melee_Timer porretada
        lda a:WeaponStruct::Melee_Timer, y
        cmp #6
        bcs @SetFrame0
        cmp #3
        bcs @SetFrame1

@SetFrame2:
        lda #2
        sta a:WeaponStruct::Melee_Frame, y
        rts

@SetFrame0:
        lda #$00
        sta a:WeaponStruct::Melee_Frame, y      
        rts

@SetFrame1:
        lda #1
        sta a:WeaponStruct::Melee_Frame, y  ; Frame 1 (Janela de Dano)
        rts

@MeleeFinished:
        lda #$00
        sta a:WeaponStruct::Melee_Frame, y
@Exit:
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
;   DrawDroppedWeapon (Versão Multi-Tile Estável - 8-bit Safe)
;   Entrada: Y = Endereço absoluto de 16-bit da WeaponStruct (WeaponA, WeaponB ou WeaponC)
;   Saída:   X = Incrementado automaticamente na OAMMIRROR
;-------------------------------------------------------------------------------
.proc DrawDroppedWeapon
        ; --- 1. SELEÇÃO RÁPIDA: SE FOR SINGLE-TILE (1), ENTRA NO FAST PATH ---
        lda a:WeaponStruct::Tile_Size, y
        cmp #1
        bne @ProcessMultiTile

        ; =====================================================================
        ; FAST PATH - RENDERIZAÇÃO DE ARMA SIMPLES (1 BLOCO 16x16)
        ; =====================================================================
        lda a:WeaponStruct::X_Pos, y
        sta OAMMIRROR, x
        inx
        
        lda a:WeaponStruct::Y_Pos, y
        sta OAMMIRROR, x
        inx
        
        lda a:WeaponStruct::Tile_ID, y   
        clc
        adc a:WeaponStruct::Melee_Frame, y   ; ◄ Usando a variável exclusiva de animação
        sta OAMMIRROR, x
        inx     
        
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_EQUIPPED
        bne @SingleDefaultAttributes

        lda BigHero + BigHeroStruct::Facing
        beq @SingleDefaultAttributes

@SingleApplyFlip:
        lda #$00                         ; Página 1 da VRAM
        eor #$40                         ; Injeta H-Flip via Hardware (Bit 6)
        sta OAMMIRROR, x
        inx
        rts

@SingleDefaultAttributes:
        lda #$00                         ; Atributo padrão, Página 1 da VRAM
        sta OAMMIRROR, x
        inx
        rts

 @ProcessMultiTile:
        sty z:DP_WEAPON_POOL_PTR        ; Salva o ponteiro do slot atual (WeaponC)

        ; --- ◄ PROTEÇÃO CRÍTICA CONTRA BOOT FANTASMA ---
        ; Verifica se o cronômetro do golpe está rodando.
        lda a:WeaponStruct::Melee_Timer, y
        beq @LoadDefaultLayout          ; Se o timer for 0, a arma NÃO está atacando. Força o layout neutro!

        ; --- SE O TIMER ESTIVER ATIVO, SELECIONA O FRAME DE ATAQUE ---
        lda a:WeaponStruct::Melee_Frame, y   ; Pega o frame atual do ataque (0, 1 ou 2)
        cmp #1
        beq @LoadAttackFrame1
        cmp #2
        beq @LoadAttackFrame2
        
@LoadAttackFrame0:
        rep #$20                        ; Abre A para 16-bit
        .a16
        lda #.loword(Weapon_Layout_Hammer_Attack_Frame0)
        sta z:DP_HERO_LAYOUT_PTR        
        sep #$20                        ; Retorna acumulador para 8-bit
        .a8
        bra @StartLoop

@LoadAttackFrame1:
        rep #$20
        .a16
        lda #.loword(Weapon_Layout_Hammer_Attack_Frame1)
        sta z:DP_HERO_LAYOUT_PTR
        sep #$20
        .a8
        bra @StartLoop

@LoadAttackFrame2:
        rep #$20
        .a16
        lda #.loword(Weapon_Layout_Hammer_Attack_Frame2)
        sta z:DP_HERO_LAYOUT_PTR
        sep #$20
        .a8
        bra @StartLoop

@LoadDefaultLayout:
        rep #$20
        .a16
        lda #.loword(Weapon_Layout_Hammer)
        sta z:DP_HERO_LAYOUT_PTR
        sep #$20
        .a8

@StartLoop:
        ldy #$0000                      ; Inicializa o indexador da tabela em Y

@MultiTileLoop:
        ; --- CÁLCULO DO EIXO X COM SUPORTE A H-FLIP ---
        phx                             
        ldx z:DP_WEAPON_POOL_PTR
        lda a:WeaponStruct::Active, x
        cmp #WEAPON_STATE_EQUIPPED
        bne @MultiNoXFlip

        lda BigHero + BigHeroStruct::Facing
        beq @MultiNoXFlip

@MultiXFlip:
        lda #0
        sec
        sbc (DP_HERO_LAYOUT_PTR), y     ; ◄ CORREÇÃO: Lê da tabela dinâmica apontada na DP
        bra @MultiApplyXPos

@MultiNoXFlip:
        lda (DP_HERO_LAYOUT_PTR), y     ; ◄ CORREÇÃO: Lê da tabela dinâmica apontada na DP

@MultiApplyXPos:
        ldx z:DP_WEAPON_POOL_PTR
        clc
        adc a:WeaponStruct::X_Pos, x     
        plx                             
        sta OAMMIRROR, x                
        inx
        iny                              

        ; --- CÁLCULO DO EIXO Y ---
        phx
        lda (DP_HERO_LAYOUT_PTR), y     ; ◄ CORREÇÃO
        ldx z:DP_WEAPON_POOL_PTR
        clc
        adc a:WeaponStruct::Y_Pos, x     
        plx
        sta OAMMIRROR, x                
        inx
        iny                              

        ; --- PROCESSAMENTO DO TILE ID ---
        lda (DP_HERO_LAYOUT_PTR), y     ; ◄ CORREÇÃO: Pega o ID estrito definido em cada struct de frame!
        sta OAMMIRROR, x
        inx
        iny                              

        ; --- PROCESSAMENTO DOS ATRIBUTOS + H-FLIP ---
        lda (DP_HERO_LAYOUT_PTR), y     ; ◄ CORREÇÃO
        sta z:DP_TEMP_00                 
        
        phx
        ldx z:DP_WEAPON_POOL_PTR
        lda a:WeaponStruct::Active, x
        cmp #WEAPON_STATE_EQUIPPED
        bne @MultiWriteAttributes

        lda BigHero + BigHeroStruct::Facing
        beq @MultiWriteAttributes

@MultiApplyHardwareFlip:
        lda z:DP_TEMP_00
        eor #$40                         
        sta z:DP_TEMP_00

@MultiWriteAttributes:
        plx
        lda z:DP_TEMP_00
        sta OAMMIRROR, x                
        inx
        iny                              

        cpy #16
        bne @MultiTileLoop

        ldy z:DP_WEAPON_POOL_PTR
        rts
.endproc


;-------------------------------------------------------------------------------
;   SpawnWeaponOnGround
;   Mantida apenas por compatibilidade com sua Main.s anterior, redirecionando o fluxo
;-------------------------------------------------------------------------------
.proc SpawnWeaponOnGround
       ; ldy #.loword(WeaponA)            ; Garante que aponta para a WeaponA padrão
       ; jsr DrawDroppedWeapon
        rts      
.endproc





.proc LoadActiveWeaponToY
        ; === VARREDURA DINÂMICA DE SLOTS POR ESTADO VISUAL ===
@ChecarSlotA:
        lda WeaponA + WeaponStruct::Active
        cmp #WEAPON_STATE_EQUIPPED
        bne @ChecarSlotB                 ; Se não está equipada, tenta o próximo slot

        ldy #.loword(WeaponA)            ; Sucesso: O slot ativo é a WeaponA
        sty z:DP_HERO_OAM_BACKUP
        rts                              ; Aborta imediatamente com Y preenchido

@ChecarSlotB:
        lda WeaponB + WeaponStruct::Active
        cmp #WEAPON_STATE_EQUIPPED
        bne @ChecarSlotC                     ; Se nenhum slot está equipado, pula o arraste

        ldy #.loword(WeaponB)            ; Sucesso: O slot ativo é a WeaponB
        sty z:DP_HERO_OAM_BACKUP
        rts                              ; Aborta imediatamente com Y preenchido

@ChecarSlotC:
        lda WeaponC + WeaponStruct::Active
        cmp #WEAPON_STATE_EQUIPPED
        bne @NenhumEquipado                     ; Se nenhum slot está equipado, limpa

        ldy #.loword(WeaponC)            ; Sucesso: O slot ativo é a WeaponC
        sty z:DP_HERO_OAM_BACKUP
        rts

@NenhumEquipado:
        ldy #$0000                       ; Força Y = 0 se o herói estiver desarmado
        sty z:DP_HERO_OAM_BACKUP
        rts
.endproc


;-------------------------------------------------------------------------------
;   ProcessMeleeAttack (Isolamento Absoluto de Variáveis)
;   Entrada: Y = Endereço absoluto do slot ativo (WeaponC)
;-------------------------------------------------------------------------------
.proc ProcessMeleeAttack
        ; Só inicia se o temporizador do golpe estiver zerado (evita spam)
        lda a:WeaponStruct::Melee_Timer, y
        bne @Exit

        ; Configura a porretada com 15 frames de duração total
        lda #10
        sta a:WeaponStruct::Melee_Timer, y
        
        ; Inicia no frame de animação 0
        lda #$00
        sta a:WeaponStruct::Melee_Frame, y

@Exit:
        rts
.endproc