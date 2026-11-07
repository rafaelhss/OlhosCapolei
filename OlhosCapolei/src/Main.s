; -----------------------------------------------------------------------------
;   File: Main.s (Edição Elegante & Otimizada - Pipeline de Auto-polling)
;   Description: Displays a sprite movable with the dpad
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     ResetHandler        
.export     NMIHandler
;-------------------------------------------------------------------------------

;----- Assembler Directives ----------------------------------------------------
.p816                           ; Habilita o conjunto de instruções do 65816
;-------------------------------------------------------------------------------

;----- Includes ----------------------------------------------------------------
.include "Assets.inc"
.include "GameConstants.inc"
.include "Init.inc"
.include "InitSNES.inc"
.include "Input.inc"
.include "Joypad.inc"
.include "MemoryMapWRAM.inc"
.include "PPU.inc"
.include "Registers.inc"
.include "BigHero.inc"
.include "PennyCrab.inc"
.include "VaderCrab.inc"
.include "Weapon2.inc"
.include "Bullet.inc"

;-------------------------------------------------------------------------------

.segment "CODE"

VADER_KNOCKBACK = 12


;-------------------------------------------------------------------------------
;   PONTO DE ENTRADA DO SISTEMA (Boot seguro em Hardware Real)
;-------------------------------------------------------------------------------
.proc   ResetHandler
        sei                     ; Desabilita interrupções de hardware
        cld                     ; Desativa modo decimal binário (Crítico para Everdrive)
        clc
        xce                     ; Transiciona o 65816 para Modo Nativo

        jmp   _ResetAlign       ; Sincroniza o Program Bank Register (K) para $00
        
_ResetAlign:
        rep #$10                ; Índices X/Y travados em 16-bit (.i16)
        sep #$20                ; Acumulador A travado em 8-bit (.a8)
        
        lda #$8f                ; Força V-Blank imediato (Desliga a tela)
        sta INIDISP
        stz NMITIMEN            ; Garante NMI desligado durante limpezas
        
        ldx #$1fff              ; Aponta a Pilha para o topo da página espelho
        txs

        jsr ClearProjectilePool 
        jsr ClearRegisters
        jsr ClearVRAM
        jsr ClearCGRAM
        jsr ClearOAMRAM
        jsr InitDemo            ; Executa inicialização customizada e ativa PPU

        
        ; --- ENTRADA EM AMBIENTE DE EXECUÇÃO REAL ---
        lda #$81                ; ◄ AUTO-POLLING LIGADO: Habilita NMI ($80) + Auto-read ($01)
        sta NMITIMEN
        cli                     ; Corta a trava global de interrupções da CPU

        jmp GameLoop            
.endproc
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;   ENGINE GAME LOOP (Pipeline Limpo de Alta Performance)
;-------------------------------------------------------------------------------
; (Mantenha o topo, ResetHandler e as primeiras linhas do GameLoop idênticas)

; -------------------------------------------------------------------------------
;   ENGINE GAME LOOP (Pipeline Limpo de Alta Performance)
; -------------------------------------------------------------------------------
.proc   GameLoop
        wai                     

 ; === INCREMENTA O CONTADOR GLOBAL DE FRAMES ===
        inc FrameCounter


        ; 1. INPUT PIPELINE
        jsr ReadJoypad1

        ; 2. SESSÃO DE FÍSICA E MOVIMENTAÇÃO

        jsr MoveBigHero
        jsr MovePennyCrab

        ; --- MOVIMENTAÇÃO DO VADERCRAB ---
        pea .loword(VaderCrab)
        jsr MoveVaderCrab
        ply                             ; Limpa 2 bytes da pilha (.i16 ativo)

        ; --- MOVIMENTAÇÃO DO RAPACRAB ---
        pea .loword(RapaCrab)
        jsr MoveVaderCrab
        ply                             ; Limpa 2 bytes da pilha


        ldy #.loword(WeaponA)
        jsr UpdateProjectiles
        
        ldy #.loword(WeaponB)
        jsr UpdateProjectiles

        ldy #.loword(WeaponC)
        jsr UpdateProjectiles

        ldy #.loword(WeaponD)
        jsr UpdateProjectiles
 
        ldy #.loword(WeaponE)
        jsr UpdateProjectiles

        jsr MoveBullet


        ; 3. FILTRO DE COLISÕES & REGRAS DE GAMEPLAY
        jsr ApplyEdgeCollisions


        ; --- DETECÇÃO DE DANO AO HERÓI PARAMETRIZADA VIA PILHA ---
        pea .loword(VaderCrab)
        jsr ApplyDamageToHero
        ply                             ; Limpa 2 bytes da pilha

        pea .loword(RapaCrab)
        jsr ApplyDamageToHero
        ply                             ; Limpa 2 bytes da pilha



        
        ; === TESTES CONTRA O VADERCRAB ===
        ldy #.loword(VaderCrab)
        sty z:DP_ENEMY_STRUCT_PTR       ; Salva o alvo atual na Direct Page!
        
        ; Checa colisões de pedradas (Slots A..E) contra o Vader
        .repeat 5, I
            ldy #.loword(.ident(.sprintf("Weapon%c", $41 + I)))
            jsr ApplyWeaponCollisions
        .endrepeat
        
        ; Checa colisões de porretadas (Slots A..E) contra o Vader
        .repeat 5, I
            ldy #.loword(.ident(.sprintf("Weapon%c", $41 + I)))
            jsr ApplyMeleeWeaponCollisions
        .endrepeat

        ; --- CHECA COLISÃO DE BALAS/TIROS ---
        pea .loword(VaderCrab)
        jsr ApplyBulletCollisions
        ply



        ; === TESTES CONTRA O RAPACRAB ===
        ldy #.loword(RapaCrab)
        sty z:DP_ENEMY_STRUCT_PTR       ; Muda o alvo atual na Direct Page!
        
        ; Checa colisões de pedradas (Slots A..E) contra o Rapa
        .repeat 5, I
            ldy #.loword(.ident(.sprintf("Weapon%c", $41 + I)))
            jsr ApplyWeaponCollisions
        .endrepeat
        
        ; Checa colisões de porretadas (Slots A..E) contra o Rapa
        .repeat 5, I
            ldy #.loword(.ident(.sprintf("Weapon%c", $41 + I)))
            jsr ApplyMeleeWeaponCollisions
        .endrepeat

        pea .loword(RapaCrab)
        jsr ApplyBulletCollisions
        ply
        
        ; 4. SISTEMA DE RENDERIZAÇÃO FINAL
        ldx #$0000     
        
        ; --- RENDERIZAÇÃO DO VADERCRAB ---
        pea .loword(VaderCrab)          ; Empilha o endereço de 16-bit diretamente (Y fica livre!)
        jsr DrawVaderCrab
        ply                     ; Tentativa Param: reset stack pointer


        ; --- RENDERIZAÇÃO DO VADERCRAB ---
        pea .loword(RapaCrab)          ; Empilha o endereço de 16-bit diretamente (Y fica livre!)
        jsr DrawVaderCrab
        ply                     ; Tentativa Param: reset stack pointer


        jsr DrawBullet


        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq DrawHeroOverWeapons

        
        bra Draweapons

 DrawHeroOverWeapons:  
        jsr DrawBigHero          
        bra Draweapons

Draweapons:

        ldy #.loword(WeaponA)            ; Garante que aponta para a WeaponA padrão
        jsr DrawDroppedWeapon     
        
        ldy #.loword(WeaponB)     ; Passa o endereço de WRAM da WeaponB por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!

        ldy #.loword(WeaponC)     ; Passa o endereço de WRAM da WeaponC por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!

        ldy #.loword(WeaponD)     ; Passa o endereço de WRAM da WeaponC por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!


        ldy #.loword(WeaponE)     ; Passa o endereço de WRAM da WeaponC por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!
        ;lda z:$00
        ;eor #$40                        
        ;sta z:$00

        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq Finish

        jsr DrawBigHero          
        
Finish:

@LimpezaFantasmas:
        cpx #512                        ; Chegou no fim da tabela de 128 sprites?
        bcs @TerminouLimpeza
        
        inx                             ; Pula o X (Byte 0)
        lda #$E0                        ; Coordenada Y inválida (Esconde o sprite fora da tela)
        sta OAMMIRROR, x
        inx                             ; Pula o Y (Byte 1)
        inx                             ; Pula o Tile ID (Byte 2)
        inx                             ; Pula os Atributos (Byte 3)
        bra @LimpezaFantasmas

@TerminouLimpeza:

        jmp GameLoop
.endproc

;-------------------------------------------------------------------------------
;   ApplyBulletCollisions (Leitura de Direct Page Direta)
;-------------------------------------------------------------------------------
.proc ApplyBulletCollisions
        lda Bullet + BulletStruct::Active
        cmp #BULLET_STATE_ACTIVE
        beq @CheckVaderVulnerable
        rts

@CheckVaderVulnerable:
        ldy z:DP_ENEMY_STRUCT_PTR       ; Y = Inimigo ativo (Vader ou Rapa)
        lda VaderCrabStruct::HurtTimer, y
        beq @StartAABB
        rts

@StartAABB:
        ldy z:DP_ENEMY_STRUCT_PTR       
        lda Bullet + BulletStruct::X_Pos
        clc
        adc #16                 
        cmp VaderCrabStruct::Hurtbox_X1, y
        bcc @NoCollision
        beq @NoCollision

        lda Bullet + BulletStruct::X_Pos
        cmp VaderCrabStruct::Hurtbox_X2, y
        bcs @NoCollision

        lda Bullet + BulletStruct::Y_Pos
        clc
        adc #16                 
        cmp VaderCrabStruct::Hurtbox_Y1, y
        bcc @NoCollision
        beq @NoCollision

        lda Bullet + BulletStruct::Y_Pos
        cmp VaderCrabStruct::Hurtbox_Y2, y
        bcs @NoCollision

        ; =====================================================================
        ; IMPACTO CONFIRMADO
        ; =====================================================================
        lda #BULLET_STATE_INACTIVE
        sta Bullet + BulletStruct::Active

        ldy z:DP_ENEMY_STRUCT_PTR       
        lda #30
        sta VaderCrabStruct::HurtTimer, y

        lda Bullet + BulletStruct::Speed_X
        bmi @BulletIndoParaEsquerda

@BulletIndoParaDireita:
        lda VaderCrabStruct::X_Pos, y
        clc
        adc #VADER_KNOCKBACK
        sta VaderCrabStruct::X_Pos, y
        bra @Finish

@BulletIndoParaEsquerda:
        lda VaderCrabStruct::X_Pos, y
        sec
        sbc #VADER_KNOCKBACK
        sta VaderCrabStruct::X_Pos, y

@NoCollision:
@Finish:
        rts
.endproc

;-------------------------------------------------------------------------------
;   ApplyWeaponCollisions (Leitura de Direct Page Direta)
;   Entrada: Y = Endereço absoluto do slot da Arma
;-------------------------------------------------------------------------------
.proc ApplyWeaponCollisions
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_THROWN
        beq @CheckVaderVulnerable
        rts

@CheckVaderVulnerable:
        sty z:DP_WEAPON_POOL_PTR        ; Preserva Y da arma
        ldy z:DP_ENEMY_STRUCT_PTR       ; Carrega o inimigo atual
        lda VaderCrabStruct::HurtTimer, y
        beq @StartAABB
        ldy z:DP_WEAPON_POOL_PTR        
        rts

@StartAABB:
        ldy z:DP_WEAPON_POOL_PTR        ; Y = Arma ativa
        ldx z:DP_ENEMY_STRUCT_PTR       ; X = Inimigo ativo

        lda a:WeaponStruct::X_Pos, y
        clc
        adc #16                 
        cmp a:VaderCrabStruct::Hurtbox_X1, x
        bcc @NoCollision
        beq @NoCollision

        lda a:WeaponStruct::X_Pos, y
        cmp a:VaderCrabStruct::Hurtbox_X2, x
        bcs @NoCollision

        lda a:WeaponStruct::Y_Pos, y
        clc
        adc #16                 
        cmp a:VaderCrabStruct::Hurtbox_Y1, x
        bcc @NoCollision
        beq @NoCollision

        lda a:WeaponStruct::Y_Pos, y
        cmp a:VaderCrabStruct::Hurtbox_Y2, x
        bcs @NoCollision

        ; =====================================================================
        ; IMPACTO CONFIRMADO
        ; =====================================================================
        lda #30
        sta a:VaderCrabStruct::HurtTimer, x

        lda a:WeaponStruct::Speed_X, y
        bmi @PedraIndoParaEsquerda

@PedraIndoParaDireita:
        lda a:VaderCrabStruct::X_Pos, x
        clc
        adc #VADER_KNOCKBACK
        sta a:VaderCrabStruct::X_Pos, x

        cmp #(SCREEN_RIGHT - 48)
        bcc @ApplyRicochet
        lda #(SCREEN_RIGHT - 48)
        sta a:VaderCrabStruct::X_Pos, x
        bra @ApplyRicochet

@PedraIndoParaEsquerda:
        lda a:VaderCrabStruct::X_Pos, x
        sec
        sbc #VADER_KNOCKBACK
        sta a:VaderCrabStruct::X_Pos, x

        cmp #SCREEN_LEFT
        bcs @ApplyRicochet
        lda #SCREEN_LEFT
        sta a:VaderCrabStruct::X_Pos, x

@ApplyRicochet:
        lda a:WeaponStruct::Speed_X, y
        eor #$FF
        clc
        adc #1
        sta a:WeaponStruct::Speed_X, y

        lda #$FC                
        sta a:WeaponStruct::Speed_Y, y

@NoCollision:
        ldy z:DP_WEAPON_POOL_PTR        
        rts
.endproc

;-------------------------------------------------------------------------------
;   ApplyMeleeWeaponCollisions (Leitura de Direct Page Direta)
;   Entrada: Y = Endereço absoluto do slot da Arma
;-------------------------------------------------------------------------------
.proc ApplyMeleeWeaponCollisions
MeleeStart:
        lda a:WeaponStruct::Hitbox_Active, y
        bne @CheckVaderVulnerable                
        rts

@CheckVaderVulnerable:
        sty z:DP_WEAPON_POOL_PTR        ; Preserva Y da arma
        ldy z:DP_ENEMY_STRUCT_PTR       ; Carrega o inimigo atual
        lda VaderCrabStruct::HurtTimer, y
        beq @StartAABB                  
        ldy z:DP_WEAPON_POOL_PTR        
        rts

@StartAABB:
        ldy z:DP_WEAPON_POOL_PTR        ; Y = Arma ativa
        ldx z:DP_ENEMY_STRUCT_PTR       ; X = Inimigo ativo

        rep #$20                
        .a16
        
        lda a:WeaponStruct::Hitbox_X2, y
        and #$00FF              
        sta $00                 
        lda a:VaderCrabStruct::Hurtbox_X1, x
        and #$00FF
        cmp $00
        bcc :+
        jmp MeleeNoCollision    

:       lda a:WeaponStruct::Hitbox_X1, y
        and #$00FF
        sta $00
        lda a:VaderCrabStruct::Hurtbox_X2, x
        and #$00FF
        cmp $00
        bcs :+          
        jmp MeleeNoCollision        

:       lda a:WeaponStruct::Hitbox_Y2, y
        and #$00FF
        sta $00
        lda a:VaderCrabStruct::Hurtbox_Y1, x
        and #$00FF
        cmp $00
        bcc :+
        jmp MeleeNoCollision        

:       lda a:WeaponStruct::Hitbox_Y1, y
        and #$00FF
        sta $00
        lda a:VaderCrabStruct::Hurtbox_Y2, x
        and #$00FF
        cmp $00
        bcs @MeleeConfirmouImpacto   
        jmp MeleeNoCollision        

@MeleeConfirmouImpacto:
        sep #$20                
        .a8

        lda #10
        sta a:VaderCrabStruct::HurtTimer, x

        lda #$00
        sta a:WeaponStruct::Hitbox_Active, y

        VADER_MELEE_KNOCKBACK = 20
        lda BigHero + BigHeroStruct::Facing
        bne @PushVaderLeft

@PushVaderRight:
        lda a:VaderCrabStruct::X_Pos, x
        clc
        adc #VADER_MELEE_KNOCKBACK
        sta a:VaderCrabStruct::X_Pos, x
        
        cmp #(SCREEN_RIGHT - 48)
        bcc MeleeExit
        lda #(SCREEN_RIGHT - 48)
        sta a:VaderCrabStruct::X_Pos, x
        bra MeleeExit

@PushVaderLeft:
        lda a:VaderCrabStruct::X_Pos, x
        sec
        sbc #VADER_MELEE_KNOCKBACK
        sta a:VaderCrabStruct::X_Pos, x
        
        cmp #SCREEN_LEFT
        bcs MeleeExit
        lda #SCREEN_LEFT
        sta a:VaderCrabStruct::X_Pos, x
        bra MeleeExit

MeleeNoCollision:
        sep #$20                
        .a8
MeleeExit:
        ldy z:DP_WEAPON_POOL_PTR        
        rts
.endproc
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;   ApplyDamageToHero (Versão Arcade Premium - Proteção Atômica de Hitstun)
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   ApplyDamageToHero (Versão Arcade Premium Parametrizada via Pilha)
;-------------------------------------------------------------------------------
.proc ApplyDamageToHero
        ; 1. Recupera o endereço de 16-bit da Struct do inimigo enviado via pilha
        rep #$20
        .a16
        lda 3,s
        tay                             ; Y agora aponta para o inimigo atual (Vader ou Rapa)
        sep #$20
        .a8

        ; =====================================================================
        ; FILTROS PRELIMINARES DE HARDWARE (8-bit)
        ; =====================================================================
        ; 1. Se o Herói está em Hitstun/Recuperação, aborta imediatamente!
        lda BigHero + BigHeroStruct::HurtTimer
        bne @AbortDamage

        ; 2. Se a hitbox deste caranguejo específico não está ativa, aborta
        lda VaderCrabStruct::Hitbox_Active, y
        beq @AbortDamage

        ; 3. Se a hurtbox do herói foi desligada, aborta
        lda BigHero + BigHeroStruct::Hurtbox_Active
        beq @AbortDamage

        ; =====================================================================
        ; MOTOR MATEMÁTICO POR EXCLUSÃO (AABB Dinâmico 16-bit)
        ; =====================================================================
@StartAABB:
        rep #$20                        ; Transiciona o Acumulador para 16 bits
        .a16

        ; --- TESTE DO EIXO X ---
        lda VaderCrabStruct::Hitbox_X2, y
        and #$00FF              
        sta $00                 
        lda BigHero + BigHeroStruct::Hurtbox_X1
        and #$00FF
        cmp $00
        bcs @NoCollision        

        lda VaderCrabStruct::Hitbox_X1, y
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_X2
        and #$00FF
        cmp $00
        bcc @NoCollision        
        beq @NoCollision

        ; --- TESTE DO EIXO Y ---
        lda VaderCrabStruct::Hitbox_Y2, y
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_Y1
        and #$00FF
        cmp $00
        bcs @NoCollision        

        lda VaderCrabStruct::Hitbox_Y1, y
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_Y2
        and #$00FF
        cmp $00
        bcc @NoCollision        
        beq @NoCollision

        ; =====================================================================
        ; COLISÃO CONFIRMADA: IMPACTO REALIZADO!
        ; =====================================================================
        sep #$20                        ; Restaura o Acumulador para 8 bits
        .a8

        ; Liga o Hitstun imediatamente no Herói (30 frames)
        lda #30
        sta BigHero + BigHeroStruct::HurtTimer
        
        ; Desativa as flags para isolamento total do frame
        stz BigHero + BigHeroStruct::Hurtbox_Active
        
        lda #0
        sta VaderCrabStruct::Hitbox_Active, y

        ; Empilha o ponteiro do caranguejo agressor para empurrar o herói certo
        phy
        jsr TriggerHeroDamageEffect
        ply
        rts

@NoCollision:
        sep #$20                        ; Restaura o Acumulador para 8 bits
        .a8
@AbortDamage:
        rts
.endproc


;-------------------------------------------------------------------------------
;   TriggerHeroDamageEffect
;   Aplica Knockback no BigHero baseado no Facing do Inimigo e trata as bordas
;-------------------------------------------------------------------------------
; -----------------------------------------------------------------------------
;   File: Main.s (PARTE 2 DE 2 - KNOCKBACK DINÂMICO) - Substitua a antiga
; -----------------------------------------------------------------------------
.proc TriggerHeroDamageEffect
        ; 1. Recupera o endereço do caranguejo enviado da pilha para o registrador Y
        rep #$20
        .a16
        lda 3,s                         
        tay
        sep #$20
        .a8

        HURT_TIME = 30 
        lda #HURT_TIME
        sta BigHero + BigHeroStruct::HurtTimer

        lda z:$00
        eor #$40                        
        sta z:$00
        
        KNOCKBACK_FORCE = 16

        ; 2. Verifica a direção do caranguejo atual parametrizado em Y
        lda VaderCrabStruct::Facing, y
        bne @PushToRight        

@PushToLeft:
        lda BigHero + BigHeroStruct::X_Pos
        sec
        sbc #KNOCKBACK_FORCE
        sta BigHero + BigHeroStruct::X_Pos

        lda BigHero + BigHeroStruct::X_Pos
        cmp #SCREEN_LEFT
        bcs @DoneKnockback      
        
        lda #SCREEN_LEFT        
        sta BigHero + BigHeroStruct::X_Pos
        bra @DoneKnockback

@PushToRight:
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #KNOCKBACK_FORCE
        sta BigHero + BigHeroStruct::X_Pos

        lda BigHero + BigHeroStruct::X_Pos
        cmp #(SCREEN_RIGHT - 32)
        bcc @DoneKnockback      
        
        lda #(SCREEN_RIGHT - 32) 
        sta BigHero + BigHeroStruct::X_Pos

@DoneKnockback:
        rts
.endproc



;-------------------------------------------------------------------------------
;   ROTINA CENTRALIZADA DE COLISÃO COM AS BORDAS (Aritmética de Underflow)
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   ROTINA CENTRALIZADA DE COLISÃO COM AS BORDAS (Blindagem Absoluta Anti-Underflow)
;-------------------------------------------------------------------------------
.proc ApplyEdgeCollisions
        ; === BLINDAGEM DO EIXO X (ESQUERDA / DIREITA) ===
CheckHeroLeft:
        lda BigHero + BigHeroStruct::X_Pos
        ; Se o herói passou da esquerda (underflow), o valor capotou para perto de $FF (ex: $FD, $FE, $FF)
        ; Se o valor for maior que 240 e ele estava perto do zero, ele cruzou a borda esquerda.
        cmp #240
        bcc CheckHeroRight          ; Se X < 240, está em uma posição normal da tela. Checa a direita.
        
        ; Se caiu aqui, houve underflow (X >= 240 vindo do zero). Força na borda esquerda!
        lda #SCREEN_LEFT            
        sta BigHero + BigHeroStruct::X_Pos
        bra CheckHeroTop            

CheckHeroRight:
        ; Limite físico da direita: SCREEN_RIGHT (255) - largura do sprite (32px) = 223
        lda BigHero + BigHeroStruct::X_Pos
        cmp #223
        bcc CheckHeroTop            ; Se X < 223, está seguro dentro da tela. Vai pro teto.
        
        lda #223                    ; Se X >= 223, satura na borda direita
        sta BigHero + BigHeroStruct::X_Pos

        ; === BLINDAGEM DO EIXO Y (TETO / BASE) ===
CheckHeroTop:
        lda BigHero + BigHeroStruct::Y_Pos
        ; Se o herói passou do teto (underflow), o valor capotou para perto de $FF
        cmp #240
        bcc CheckHeroBottom         ; Se Y < 240, altura está normal. Checa a base.
        
        ; Se caiu aqui, houve underflow no teto. Força na borda superior!
        lda #SCREEN_TOP             
        sta BigHero + BigHeroStruct::Y_Pos
        bra CollisionDone          

CheckHeroBottom:
        ; Limite físico da base: SCREEN_BOTTOM (223) - altura do sprite (64px) = 159
        lda BigHero + BigHeroStruct::Y_Pos
        cmp #159
        bcc CollisionDone          ; Se Y < 159, está seguro dentro do cenário.
        
        lda #159                    ; Se Y >= 159, satura no limite inferior do cenário
        sta BigHero + BigHeroStruct::Y_Pos

CollisionDone:
        rts
.endproc

;-------------------------------------------------------------------------------
;   EXECUÇÃO AUTOMÁTICA EM V-BLANK (Hardware real manipula OAM aqui)
;-------------------------------------------------------------------------------
.proc   NMIHandler
        lda RDNMI               ; Lê e limpa o flag indicador de interrupção de NMI
.import Hero, InimigoGrande, InimigoGrande2

       
        tsx                     ; Preserva o ponteiro de pilha atual
        pea OAMMIRROR           ; Injeta o endereço do espelho da RAM
        jsr UpdateOAMRAM        ; Envia os dados para a OAM real via DMA
        txs                     ; Restaura a pilha instantaneamente

        rti
.endproc

;-------------------------------------------------------------------------------
;   VETOR DE PROSPECÇÃO DE HARDWARE
;-------------------------------------------------------------------------------
.proc   IRQHandler
        rti
.endproc

;-------------------------------------------------------------------------------
;   ALOCAÇÃO DE VARIÁVEIS NA WRAM 
;-------------------------------------------------------------------------------
.segment "BSS"
.export BigHero 
.export PennyCrab
.export VaderCrab
.export RapaCrab
.export WeaponA
.export WeaponB
.export WeaponC
.export WeaponD
.export WeaponE
.export Bullet


BigHero:         .tag BigHeroStruct
PennyCrab:       .tag PennyCrabStruct
VaderCrab:       .tag VaderCrabStruct
RapaCrab:       .tag VaderCrabStruct

WeaponA:         .tag WeaponStruct
WeaponB:         .tag WeaponStruct
WeaponC:         .tag WeaponStruct
WeaponD:         .tag WeaponStruct
WeaponE:         .tag WeaponStruct
Bullet:          .tag BulletStruct

FrameCounter:    .res 1    ; Contador global de frames (0 a 255)
.export FrameCounter
