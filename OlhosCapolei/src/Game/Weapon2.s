; -----------------------------------------------------------------------------
;   File: Weapon.s
;   Description: Centralized Weapon, Projectile, and Ground Pickup Subsystem
;   Project: OlhosCapolei
; -----------------------------------------------------------------------------

.p816
.a8
.i16

;----- Exports -----------------------------------------------------------------
.export     ProcessWeaponAttack
.export     UpdateProjectiles
.export     DrawDroppedWeapon
.export     Weapon_Data_Table 
.export     ClearProjectilePool
.export     LoadActiveWeaponToY
.export     ProcessMeleeAttack
.export     ProcessFireAttack

;----- Imports -----------------------------------------------------------------
.import     VaderCrab
.import     BigHero
.import     WeaponA
.import     WeaponB
.import     WeaponC
.import     WeaponD
.import     WeaponE
.import     Bullet
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

;Ainda nao eh usado, mas eh uma ideia boa
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


Weapon_Layout_Wood:
    .byte 0, <(  0), $6A, $00  
    .byte 16, <(-8), $4A, $00
    .byte 32, <(-16), $2A, $00  
    .byte 48, <(-24), $0A, $00

Weapon_Layout_Wood_Picked:
    .byte 0, <(  0), $66, $00  
    .byte 0, <(-16), $46, $00
    .byte 0, <(-32), $26, $00  
    .byte 0, <(-48), $06, $00

Weapon_Layout_Wood_Attack_Frame00:
     .byte 0, <(  0), $6A, $F0  
    .byte <(-16), <(8), $4A, $F0
    .byte <(-32), <(16), $2A, $F0  
    .byte <(-48), <(24), $0A, $F0
    
Weapon_Layout_Wood_Attack_Frame01:
    .byte 0, <(  0), $64, $00  
    .byte 16, <(  0), $44, $00
    .byte 32, <( 0), $24, $00  
    .byte 48, <( 0), $04, $00

Weapon_Layout_Wood_Attack_Frame02:
     .byte 0, <(  -0), $6A, $00  
    .byte 16, <(-8), $4A, $00
    .byte 32, <(-16), $2A, $00  
    .byte 48, <(-24), $0A, $00

Weapon_Layout_Wood_Attack_Frame10:
    .byte 0, <(  0), $68, $00  
    .byte 8, <(-16), $48, $00
    .byte 16, <(-32), $28, $00  
    .byte 24, <(-48), $08, $00
    
Weapon_Layout_Wood_Attack_Frame11:
    .byte 0, <(  0), $6A, $00  
    .byte 16, <(-8), $4A, $00
    .byte 32, <(-16), $2A, $00  
    .byte 48, <(-24), $0A, $00

Weapon_Layout_Wood_Attack_Frame12:
    .byte 0, <(  0), $64, $00  
    .byte 16, <(  0), $44, $00
    .byte 32, <( 0), $24, $00  
    .byte 48, <( 0), $04, $00

Weapon_Layout_Wood_Attack_Frame20:
    .byte  <(-32), <(0), $64, $00  
    .byte <(-16), <(  0), $44, $00
    .byte <(0), <( 0), $24, $00  
    .byte <(16), <( 0), $04, $00
    
Weapon_Layout_Wood_Attack_Frame21:
    .byte 0, <(  0), $64, $00  
    .byte 16, <(  0), $44, $00
    .byte 32, <( 0), $24, $00  
    .byte 48, <( 0), $04, $00

Weapon_Layout_Wood_Attack_Frame22:
    .byte  <(-32), <(0), $64, $00  
    .byte <(-16), <(  0), $44, $00
    .byte <(0), <( 0), $24, $00  
    .byte <(16), <( 0), $04, $00   


    
Weapon_Layout_Fire:
    .byte 0, <( 0), $C0, $00, 16, <(0), $C2, $00
    .byte 0, <(16), $E0, $00, 16, <(16), $E2, $00

Weapon_Layout_Fire_Picked:
    .byte <(-16), <( 11), $C0, $00, 0, <(11), $C2, $00
    .byte <(-16), <(27), $E0, $00, 0, <(27), $E2, $00

Weapon_Layout_Fire_Attack_Frame00:
    .byte 0, <( 0), $C0, $00, 16, <(0), $C2, $00
    .byte 0, <(16), $E0, $00, 16, <(16), $E2, $00

Weapon_Layout_Fire_Attack_Frame01:
    .byte <(-8), <( 0), $C0, $00, 8, <(0), $C2, $00
    .byte <(-8), <(16), $E0, $00, 8, <(16), $E2, $00

Weapon_Layout_Fire_Attack_Frame02:
    .byte 0, <( 0), $C0, $00, 16, <(0), $C2, $00
    .byte 0, <(16), $E0, $00, 16, <(16), $E2, $00

Weapon_Layout_Chain:
    .byte 0, <(  0), $E8, $00  
    .byte 16, <(0), $EA, $00
    .byte 32, <(0), $EA, $00  
    .byte 48, <(0), $EA, $00

Weapon_Layout_Chain_Picked:
    .byte 0, <(  16), $CC, $00  
    .byte 0, <(32), $EC, $00
    .byte <(-16), <(32), $EA, $00  
    .byte <(-32), <(32), $E8, $00

Weapon_Layout_Chain_Attack_Frame00:
    .byte <(-16), <(0), $EA, $00  
    .byte <(-32), <(0), $EC, $F0
    .byte <(-32), <(16), $CC, $00  
    .byte <(-32), <(32), $E8, $00

Weapon_Layout_Chain_Attack_Frame01:
    .byte 0, <(  0), $EA, $00  
    .byte 16, <(0), $EA, $00
    .byte 32, <(0), $EA, $00  
    .byte 48, <(0), $E8, $00

Weapon_Layout_Chain_Attack_Frame02:
    .byte 0, <(  16), $CC, $00  
    .byte 0, <(32), $EC, $70
    .byte <(16), <(32), $EA, $00  
    .byte <(32), <(32), $E8, $00


; =============================================================================
; TABELAS MESTRES PARA ARMAS EM REPOUSO (Melee_Timer == 0)
; =============================================================================
Weapon_Ground_Table:
    .addr $0000, $0000, $0000        ; IDs 0, 1, 2
    .addr Weapon_Layout_Wood         ; ID 3: Madeira no chão
    .addr $0000                      ; ID 4: Pedra
    .addr Weapon_Layout_Fire         ; ID 5: Pistola no chão
    .addr Weapon_Layout_Chain        ; ID 6: corrente no chão

Weapon_Picked_Table:
    .addr $0000, $0000, $0000        ; IDs 0, 1, 2
    .addr Weapon_Layout_Wood_Picked  ; ID 3: Madeira na mão
    .addr $0000                      ; ID 4: Pedra
    .addr Weapon_Layout_Fire_Picked  ; ID 5: Pistola na mão
    .addr Weapon_Layout_Chain_Picked  ; ID 6: corrente na mão

; =============================================================================
; TABELA MESTRE DE ARMAS (Weapon_Anims_Table)
; Indexado diretamente por Weapon_ID (Multiplicado por 2 em tempo de execução)
; =============================================================================
Weapon_Anims_Table:
    .addr $0000                      ; ID 0: Desarmado (Nulo)
    .addr $0000                      ; ID 1: Faca (Expansão)
    .addr $0000                      ; ID 2: Cano (Expansão)
    .addr Weapon_Wood_Anims_Table    ; ID 3: Pedaço de Pau (Madeira)
    .addr $0000                      ; ID 4: Pedra (Single-tile, não usa sub-tabela)
    .addr Weapon_Fire_Anims_Table    ; ID 5: Pistola / Fogo (Exemplo de expansão Multi-tile)
    .addr Weapon_Chain_Anims_Table    ; ID 6: Corrente)



; =============================================================================
; TABELA DE VETORES DE ANIMAÇÃO (PONTEIROS DE 16-BIT PARA CADA FRAME)
; Organizada linearmente: Var0 (Fr0, Fr1, Var2), Var1 (Fr0, Fr1, Fr2), Var2 (Fr0, Fr1, Fr2)
; =============================================================================
; =============================================================================
; TABELAS DE VETORES DE ANIMAÇÃO ESPECÍFICAS POR ARMA (Matrizes Lineares 3x3)
; =============================================================================
Weapon_Wood_Anims_Table:
    ; --- Variação 0 (Jab 1) ---
    .addr Weapon_Layout_Wood_Attack_Frame00
    .addr Weapon_Layout_Wood_Attack_Frame01
    .addr Weapon_Layout_Wood_Attack_Frame02
    ; --- Variação 1 (Jab 2) ---
    .addr Weapon_Layout_Wood_Attack_Frame10
    .addr Weapon_Layout_Wood_Attack_Frame11
    .addr Weapon_Layout_Wood_Attack_Frame12
    ; --- Variação 2 (Finalizador) ---
    .addr Weapon_Layout_Wood_Attack_Frame20
    .addr Weapon_Layout_Wood_Attack_Frame21
    .addr Weapon_Layout_Wood_Attack_Frame22

Weapon_Fire_Anims_Table:
    ; --- Variação 0 ---
    .addr Weapon_Layout_Fire_Attack_Frame00
    .addr Weapon_Layout_Fire_Attack_Frame01
    .addr Weapon_Layout_Fire_Attack_Frame02
    ; --- Variação 1 ---
    .addr Weapon_Layout_Fire_Attack_Frame00
    .addr Weapon_Layout_Fire_Attack_Frame01
    .addr Weapon_Layout_Fire_Attack_Frame02
    ; --- Variação 2 ---
    .addr Weapon_Layout_Fire_Attack_Frame00
    .addr Weapon_Layout_Fire_Attack_Frame01
    .addr Weapon_Layout_Fire_Attack_Frame02


Weapon_Chain_Anims_Table:
    ; --- Variação 0 ---
    .addr Weapon_Layout_Chain_Attack_Frame00
    .addr Weapon_Layout_Chain_Attack_Frame01
    .addr Weapon_Layout_Chain_Attack_Frame02
    ; --- Variação 1 ---
    .addr Weapon_Layout_Chain_Attack_Frame00
    .addr Weapon_Layout_Chain_Attack_Frame01
    .addr Weapon_Layout_Chain_Attack_Frame02
    ; --- Variação 2 ---
    .addr Weapon_Layout_Chain_Attack_Frame00
    .addr Weapon_Layout_Chain_Attack_Frame01
    .addr Weapon_Layout_Chain_Attack_Frame02


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
        sta a:WeaponStruct::Hitbox_Active, y
        sta a:WeaponStruct::Hitbox_X1, y
        sta a:WeaponStruct::Hitbox_X2, y
        sta a:WeaponStruct::Hitbox_Y1, y
        sta a:WeaponStruct::Hitbox_Y2, y

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
        sta a:WeaponStruct::Hitbox_Active, y
        sta a:WeaponStruct::Hitbox_X1, y
        sta a:WeaponStruct::Hitbox_X2, y
        sta a:WeaponStruct::Hitbox_Y1, y
        sta a:WeaponStruct::Hitbox_Y2, y

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
        sta a:WeaponStruct::Hitbox_Active, y
        sta a:WeaponStruct::Hitbox_X1, y
        sta a:WeaponStruct::Hitbox_X2, y
        sta a:WeaponStruct::Hitbox_Y1, y
        sta a:WeaponStruct::Hitbox_Y2, y


        ldy #.loword(WeaponD)
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
        sta a:WeaponStruct::Hitbox_Active, y
        sta a:WeaponStruct::Hitbox_X1, y
        sta a:WeaponStruct::Hitbox_X2, y
        sta a:WeaponStruct::Hitbox_Y1, y
        sta a:WeaponStruct::Hitbox_Y2, y

        plp                     ; Restaura o estado anterior dos flags da CPU
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
        cmp #11
        bcs @SetFrame0
        cmp #6
        bcs @SetFrame1

@SetFrame2:
        lda #2
        sta a:WeaponStruct::Melee_Frame, y
        lda #$00
        sta a:WeaponStruct::Hitbox_Active, y    ; Desliga hitbox na recuperação
        rts
        
@SetFrame0:
        lda #$00
        sta a:WeaponStruct::Melee_Frame, y      
        sta a:WeaponStruct::Hitbox_Active, y    ; Desliga hitbox na preparação
        rts



@SetFrame1:
        lda #1
        sta a:WeaponStruct::Melee_Frame, y  ; Frame 1 (Janela de Dano)
        
        ; --- LIGA E GERA A HITBOX DA PORRETADA ---
        lda #1
        sta a:WeaponStruct::Hitbox_Active, y

        ; --- LIMITES VERTICAIS (EIXO Y tridimensional) ---
        ; Alinha a área de dano na altura da cintura/mão do herói
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #16                                 ; Margem superior da colisão
        sta a:WeaponStruct::Hitbox_Y1, y
        clc
        adc #32                                 ; Caixa com 32px de altura vertical
        sta a:WeaponStruct::Hitbox_Y2, y

        ; --- LIMITES HORIZONTAIS (EIXO X baseado no Facing) ---
        lda BigHero + BigHeroStruct::Facing
        bne @HitboxEsquerda

@HitboxDireita:
        ; Ataque para a direita: Projeta a caixa à frente do corpo do Herói (32px de largura)
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #24                                 ; Começa perto do fim do corpo
        sta a:WeaponStruct::Hitbox_X1, y
        clc
        adc #32                                 ; Alcance horizontal do ataque (32 pixels)
        sta a:WeaponStruct::Hitbox_X2, y
        rts

@HitboxEsquerda:
        ; Ataque para a esquerda: Projeta a caixa recuada à esquerda do herói
        lda BigHero + BigHeroStruct::X_Pos
        sec
        sbc #24                                 ; Estica o alcance para trás do X_Pos
        sta a:WeaponStruct::Hitbox_X1, y
        clc
        adc #32                                 ; Encerra colisão rente ao corpo
        sta a:WeaponStruct::Hitbox_X2, y
        rts

@MeleeFinished:
        lda #$00
        sta a:WeaponStruct::Melee_Frame, y
        sta a:WeaponStruct::Hitbox_Active, y    ; Garante hitbox desligada no fim do golpe
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
        sty z:DP_WEAPON_POOL_PTR        ; Salva o ponteiro do slot atual (ex: WeaponC)

        ; --- PROTEÇÃO CRÍTICA CONTRA BOOT FANTASMA ---
        lda a:WeaponStruct::Melee_Timer, y
        bne @CalculateDynamicTable
        jmp @LoadDefaultLayout          ; Se o timer for 0, força o layout estático de chão/mão

@CalculateDynamicTable:
        ; =====================================================================
        ; PIPELINE DATA-DRIVEN: BUSCA INDIRETA BASEADA NO WEAPON_ID
        ; =====================================================================
        phy                             ; Preserva ponteiro da estrutura da arma
        phx                             ; Preserva ponteiro do preenchimento da OAM

        rep #$20                        ; Aberto em 16-bit puro para evitar quebra de banco
        .a16
        
        ldx z:DP_WEAPON_POOL_PTR        ; X mapeia a WeaponStruct na RAM

        ; 1. Buscar a Sub-Tabela correta através do Weapon_ID
        lda a:WeaponStruct::Weapon_ID, x
        and #$00FF                      ; Isola byte baixo limpo
        asl                             ; Multiplica ID por 2 (tamanho de .addr)
        tay                             ; Y = Índice da tabela mestre
        
        lda Weapon_Anims_Table, y       ; Lê o endereço base da animação desta arma específica
        sta z:DP_VADER_LAYOUT_PTR       ; Salva no canal limpo de indicação da Direct Page

        ; 2. Calcular índice interno da sub-tabela: (Anim_Variation * 3) + Melee_Frame
        lda a:WeaponStruct::Anim_Variation, x
        and #$00FF                      
        sta z:DP_TEMP_CALC              ; Rascunho temporário de 16-bit
        asl                             ; Variation * 2
        clc
        adc z:DP_TEMP_CALC              ; (Variation * 2) + Variation = Variation * 3
        sta z:DP_TEMP_CALC              

        lda a:WeaponStruct::Melee_Frame, x
        and #$00FF                      
        clc
        adc z:DP_TEMP_CALC              ; Índice linear final em número de frames
        asl                             ; Multiplica por 2 para casar com o tamanho em bytes (.addr)
        tay                             ; Y = Deslocamento final em bytes dentro da sub-tabela

        ; 3. Resgatar o Frame de Animação Real via Ponteiro Indireto da Direct Page
        lda (DP_VADER_LAYOUT_PTR), y    
        sta z:DP_HERO_LAYOUT_PTR        ; Injeta o frame final calculado no motor de desenho padrão

        ; Restaura os registradores e flags originais com segurança
        sep #$20                        ; Retorna acumulador estável para 8-bit
        .a8
        plx                             ; Recupera X OAM original
        ply                             ; Recupera Y Struct original
        
        jmp @StartLoop                  ; Desvia diretamente para o laço gráfico original

@LoadDefaultLayout:
        ; =====================================================================
        ; CARGA DE LAYOUT ESTÁTICO (MÃO / CHÃO) - ISOLAMENTO DE ÍNDICE DE 16-BIT
        ; =====================================================================
        phx                             ; Preserva ponteiro da OAM global (Main.s)
        phy                             ; Preserva ponteiro da WRAM da arma atual

        ; 1. Abre o Acumulador para 16-bit estritamente para limpar e calcular o Offset
        rep #$20
        .a16
        
        ; Lê o Weapon_ID limpando qualquer resíduo do byte alto
        lda a:WeaponStruct::Weapon_ID, y
        and #$00FF                      ; Força o byte alto a ser estritamente $00
        asl                             ; Multiplica ID por 2 (Tamanho de cada .addr)
        tay                             ; Y de 16 bits agora recebe o índice perfeito ($0000, $0002...)

        ; 2. Retorna o Acumulador para 8-bit para fazer a checagem de estado segura
        sep #$20
        .a8

        ldx z:DP_WEAPON_POOL_PTR        ; Mapeia a WeaponStruct corrente na RAM
        lda a:WeaponStruct::Active, x   ; Lê o estado em 8-bit puro
        cmp #WEAPON_STATE_EQUIPPED
        beq @SelectPickedTable

@SelectGroundTable:
        rep #$20                        ; Abre em 16-bit para carregar o endereço do layout da ROM
        .a16
        lda a:Weapon_Ground_Table, y    ; Busca ponteiro correto (Sem lixo no Y)
        sta z:DP_HERO_LAYOUT_PTR        
        sep #$20                        ; Retorna para 8-bit
        .a8
        bra @RestoreContext

@SelectPickedTable:
        rep #$20                        ; Abre em 16-bit para carregar o endereço do layout da ROM
        .a16
        lda a:Weapon_Picked_Table, y    ; Busca ponteiro correto (Sem lixo no Y)
        sta z:DP_HERO_LAYOUT_PTR        
        sep #$20                        ; Retorna para 8-bit
        .a8

@RestoreContext:
        ply                             ; Restaura o Y original (Ponteiro WRAM da arma)
        plx                             ; Restaura o X original (Ponteiro OAMMIRROR da Main.s)
        
        ldy #$0000                      ; Inicializa o indexador do laço multi-tile

@StartLoop:
        ; (O código do loop multi-tile segue idêntico aqui abaixo)
        ldy #$0000                      ; Inicializa o indexador do laço de blocos

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
        cmp #WEAPON_STATE_EQUIPPED    ;----  0 significa equipado. é, eu sei.,..
        bne @MultiWriteAttributes     ;---  se nao estiver equipado vai pra isso. se estiver, avança aqui sem branch
        phx
        ldx z:DP_WEAPON_POOL_PTR
        lda a:WeaponStruct::Active, x   ; Lê o estado real da RAM (0 = EQUIPPED)
        plx
        
        cmp #WEAPON_STATE_EQUIPPED
        beq @SkipGroundPriority         ; Se estiver na mão, CURTO CIRCUITO: não mexe em nada, mantém a ROM!

@ApplyGroundBack:
        ; Se estiver no chão, limpa cirurgicamente o bit 4 (e o 5 se quiser Prioridade 0 como a corrente)
        lda z:DP_TEMP_00
        and #$CF                         ; Máscara atômica: limpa bits 4 e 5. Preserva VRAM (bit 0), paletas e Flips!
        sta z:DP_TEMP_00

@SkipGroundPriority:
        ; Agora o fluxo segue direto e limpo para checar a direção do Herói
        lda BigHero + BigHeroStruct::Facing
        beq @MultiWriteAttributes

@MultiApplyHardwareFlip:
        lda z:DP_TEMP_00
        eor #$40                         ; Inverte estritamente o Bit 6 (H-Flip)
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
        bne @ChecarSlotD                     ; Se nenhum slot está equipado, limpa

        ldy #.loword(WeaponC)            ; Sucesso: O slot ativo é a WeaponC
        sty z:DP_HERO_OAM_BACKUP
        rts

@ChecarSlotD:
        lda WeaponD + WeaponStruct::Active
        cmp #WEAPON_STATE_EQUIPPED
        bne @ChecarSlotE                     ; Se nenhum slot está equipado, limpa

        ldy #.loword(WeaponD)            ; Sucesso: O slot ativo é a WeaponC
        sty z:DP_HERO_OAM_BACKUP
        rts

@ChecarSlotE:
        lda WeaponE + WeaponStruct::Active
        cmp #WEAPON_STATE_EQUIPPED
        bne @NenhumEquipado                     ; Se nenhum slot está equipado, limpa

        ldy #.loword(WeaponE)            ; Sucesso: O slot ativo é a WeaponC
        sty z:DP_HERO_OAM_BACKUP
        rts

@NenhumEquipado:
        ldy #$0000                       ; Força Y = 0 se o herói estiver desarmado
        sty z:DP_HERO_OAM_BACKUP
        rts
.endproc



.proc ProcessFireAttack
        ; Só inicia se o temporizador do golpe estiver zerado (evita spam)
        lda a:WeaponStruct::Melee_Timer, y
        bne @Exit

        ; Configura o tiro com 10 frames de duração total
        lda #10
        sta a:WeaponStruct::Melee_Timer, y
        
        ; Inicia no frame de animação 0
        lda #$00
        sta a:WeaponStruct::Melee_Frame, y

        
        lda  a:WeaponStruct::X_Pos, y
        sta Bullet + BulletStruct::X_Pos
        
        lda  a:WeaponStruct::Y_Pos, y
        sta Bullet + BulletStruct::Y_Pos
        
        lda #$01
        sta Bullet + BulletStruct::Active

        lda #$EE
        sta Bullet + BulletStruct::Tile_ID

        lda BigHero + BigHeroStruct::Facing
        bne @BulletEsquerda
        lda #BULLET_SPEED
        bra @SetSpeed

@BulletEsquerda:
        lda #<(-BULLET_SPEED) 
@SetSpeed:

        sta Bullet + BulletStruct::Speed_X
        


@Exit:
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
        lda #15
        sta a:WeaponStruct::Melee_Timer, y
        
        ; Inicia no frame de animação 0
        lda #$00
        sta a:WeaponStruct::Melee_Frame, y


@Exit:
        rts
.endproc