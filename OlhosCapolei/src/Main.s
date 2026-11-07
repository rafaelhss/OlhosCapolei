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
        jsr MoveVaderCrab


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
        jsr ApplyDamageToHero
        
        
        ; --- CHECA COLISÃO DA PEDRADA PARA CADA SLOT DE FORMA ISOLADA ---
        ldy #.loword(WeaponA)
        jsr ApplyWeaponCollisions       ; Testa se a arma do Slot A acertou o Vader
        ldy #.loword(WeaponB)
        jsr ApplyWeaponCollisions       ; Testa se a arma do Slot B acertou o Vader
        ldy #.loword(WeaponC)
        jsr ApplyWeaponCollisions       ; Testa se a arma do Slot C acertou o Vader
        ldy #.loword(WeaponD)
        jsr ApplyWeaponCollisions       ; Testa se a arma do Slot C acertou o Vader
        ldy #.loword(WeaponE)
        jsr ApplyWeaponCollisions       ; Testa se a arma do Slot C acertou o Vader
        
        
        ; CHECA COLISÃO CORPORAL (PORRETADA) PARA CADA SLOT
        ldy #.loword(WeaponA)
        jsr ApplyMeleeWeaponCollisions

        ldy #.loword(WeaponB)
        jsr ApplyMeleeWeaponCollisions

        ldy #.loword(WeaponC)
        jsr ApplyMeleeWeaponCollisions

        ldy #.loword(WeaponD)
        jsr ApplyMeleeWeaponCollisions

        ldy #.loword(WeaponE)
        jsr ApplyMeleeWeaponCollisions


        jsr ApplyBulletCollisions

        
        ; 4. SISTEMA DE RENDERIZAÇÃO FINAL
        ldx #$0000     
        
        ; --- RENDERIZAÇÃO DO VADERCRAB ---
        pea .loword(VaderCrab)          ; Empilha o endereço de 16-bit diretamente (Y fica livre!)
        jsr DrawVaderCrab
        pla                     ; Tentativa Param: reset stack pointer


        ; --- RENDERIZAÇÃO DO VADERCRAB ---
        pea .loword(RapaCrab)          ; Empilha o endereço de 16-bit diretamente (Y fica livre!)
        jsr DrawVaderCrab
        pla                     ; Tentativa Param: reset stack pointer


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



.proc ApplyBulletCollisions
        lda Bullet + BulletStruct::Active
        cmp #BULLET_STATE_ACTIVE
        beq @CheckVaderVulnerable
        rts

@CheckVaderVulnerable:
        ; 2. Se o VaderCrab já estiver em Hitstun/Dano, aborta para evitar múltiplos hits
        lda VaderCrab + VaderCrabStruct::HurtTimer
        beq @StartAABB
        rts

@StartAABB:
        ; --- TESTE DO EIXO X (Usando o slot parametrizado em Y) ---
        lda Bullet + BulletStruct::X_Pos
        clc
        adc #16                 ; Largura estimada da Bullet
        cmp VaderCrab + VaderCrabStruct::Hurtbox_X1
        bcc NoCollision
        beq NoCollision

        lda Bullet + BulletStruct::X_Pos
        cmp VaderCrab + VaderCrabStruct::Hurtbox_X2
        bcs NoCollision

        ; --- TESTE DO EIXO Y ---
        lda Bullet + BulletStruct::Y_Pos
        clc
        adc #16                 ; Altura estimada
        cmp VaderCrab + VaderCrabStruct::Hurtbox_Y1
        bcc NoCollision
        beq NoCollision

        lda Bullet + BulletStruct::Y_Pos
        cmp VaderCrab + VaderCrabStruct::Hurtbox_Y2
        bcs NoCollision

        ; =====================================================================
        ; IMPACTO CONFIRMADO: Bullet ACERTOU O VADER!
        ; =====================================================================
        

        lda #BULLET_STATE_INACTIVE
        sta Bullet + BulletStruct::Active

        ; 1. Força o VaderCrab a entrar em estado de Hitstun (30 frames)
        lda #30
        sta VaderCrab + VaderCrabStruct::HurtTimer

        ; =====================================================================
        ; 🦀 BOUNCE BACK / KNOCKBACK DO VADERCRAB
        ; =====================================================================

        ; Verifica a direção do projétil ativo para empurrar o Vader corretamente
        lda Bullet + BulletStruct::Speed_X
        bmi @BulletIndoParaEsquerda

@BulletIndoParaDireita:
        lda VaderCrab + VaderCrabStruct::X_Pos
        clc
        adc #VADER_KNOCKBACK
        sta VaderCrab + VaderCrabStruct::X_Pos
        bra Finish

@BulletIndoParaEsquerda:
        lda VaderCrab + VaderCrabStruct::X_Pos
        sec
        sbc #VADER_KNOCKBACK
        sta VaderCrab + VaderCrabStruct::X_Pos

NoCollision:
Finish:
        rts
.endproc

;-------------------------------------------------------------------------------
;   ApplyWeaponCollisions (AABB CENTRALIZADO E PARAMETRIZADO VIA Y)
;   Entrada: Y = Endereço absoluto do slot (WeaponA ou WeaponB)
;-------------------------------------------------------------------------------
.proc ApplyWeaponCollisions
        ; 1. Filtro preliminar: Só checa colisão se o slot enviado em Y estiver voando (THROWN = 2)
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_THROWN
        beq @CheckVaderVulnerable
        rts

@CheckVaderVulnerable:
        ; 2. Se o VaderCrab já estiver em Hitstun/Dano, aborta para evitar múltiplos hits
        lda VaderCrab + VaderCrabStruct::HurtTimer
        beq @StartAABB
        rts

@StartAABB:
        ; --- TESTE DO EIXO X (Usando o slot parametrizado em Y) ---
        lda a:WeaponStruct::X_Pos, y
        clc
        adc #16                 ; Largura estimada da pedra/martelo
        cmp VaderCrab + VaderCrabStruct::Hurtbox_X1
        bcc NoCollision
        beq NoCollision

        lda a:WeaponStruct::X_Pos, y
        cmp VaderCrab + VaderCrabStruct::Hurtbox_X2
        bcs NoCollision

        ; --- TESTE DO EIXO Y ---
        lda a:WeaponStruct::Y_Pos, y
        clc
        adc #16                 ; Altura estimada
        cmp VaderCrab + VaderCrabStruct::Hurtbox_Y1
        bcc NoCollision
        beq NoCollision

        lda a:WeaponStruct::Y_Pos, y
        cmp VaderCrab + VaderCrabStruct::Hurtbox_Y2
        bcs NoCollision

        ; =====================================================================
        ; IMPACTO CONFIRMADO: A ARMA DO SLOT Y ACERTOU O VADER!
        ; =====================================================================
        
        ; 1. Força o VaderCrab a entrar em estado de Hitstun (30 frames)
        lda #30
        sta VaderCrab + VaderCrabStruct::HurtTimer

        ; =====================================================================
        ; 🦀 BOUNCE BACK / KNOCKBACK DO VADERCRAB
        ; =====================================================================
        VADER_KNOCKBACK = 12

        ; Verifica a direção do projétil ativo para empurrar o Vader corretamente
        lda a:WeaponStruct::Speed_X, y
        bmi @PedraIndoParaEsquerda

@PedraIndoParaDireita:
        lda VaderCrab + VaderCrabStruct::X_Pos
        clc
        adc #VADER_KNOCKBACK
        sta VaderCrab + VaderCrabStruct::X_Pos

        cmp #(SCREEN_RIGHT - 48)
        bcc @ApplyRicochet
        lda #(SCREEN_RIGHT - 48)
        sta VaderCrab + VaderCrabStruct::X_Pos
        bra @ApplyRicochet

@PedraIndoParaEsquerda:
        lda VaderCrab + VaderCrabStruct::X_Pos
        sec
        sbc #VADER_KNOCKBACK
        sta VaderCrab + VaderCrabStruct::X_Pos

        cmp #SCREEN_LEFT
        bcs @ApplyRicochet
        lda #SCREEN_LEFT
        sta VaderCrab + VaderCrabStruct::X_Pos

@ApplyRicochet:
        ; =====================================================================
        ; 2. RICOCHETE PARAMETRIZADO DA ARMA QUE ESTAVA EM VOO
        ; =====================================================================
        lda a:WeaponStruct::Speed_X, y
        eor #$FF
        clc
        adc #1
        sta a:WeaponStruct::Speed_X, y

        ; 3. Impulso Vertical no quique da arma ativa
        lda #$FC                ; Força Speed_Y = -4
        sta a:WeaponStruct::Speed_Y, y

NoCollision:
        rts
.endproc



;-------------------------------------------------------------------------------
;   ApplyMeleeWeaponCollisions (Detecção de Dano Corporal por Proximidade)
;   Entrada: Y = Endereço absoluto do slot (WeaponA, WeaponB ou WeaponC)
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   ApplyMeleeWeaponCollisions (Conceito Puro: Hitbox da Arma vs Hurtbox do Inimigo)
;   Entrada: Y = Endereço absoluto do slot (WeaponA, WeaponB ou WeaponC)
;-------------------------------------------------------------------------------
.proc ApplyMeleeWeaponCollisions
MeleeStart:
        ; 1. Filtro preliminar rápido: A Hitbox da arma deve estar ligada. Se for 0, sai.
        lda a:WeaponStruct::Hitbox_Active, y
        bne :+                          ; Se NÃO for zero (está ativa), pula para o próximo teste
        jmp MeleeExit                   ; Se for zero, executa o Salto Longo Absoluto de saída

:       ; 2. Filtro de Segurança do Alvo: Se o VaderCrab já estiver em Hitstun, aborta
        lda VaderCrab + VaderCrabStruct::HurtTimer
        beq :+                          ; Se for igual a zero (vulnerável), pula para iniciar o AABB
        jmp MeleeExit                   ; Se já estiver em hitstun, executa o Salto Longo Absoluto

:       rep #$20                ; Transiciona acumulador para 16 bits para evitar sobramento
        .a16
        ; --- TESTE DE INTERSECÇÃO BLINDADO COM RÓTULOS NUMÉRICOS (HITBOX vs HURTBOX) ---
        
        ; Teste 1: Se Hitbox_X2 <= Hurtbox_X1 (Ataque totalmente à esquerda)
        lda a:WeaponStruct::Hitbox_X2, y
        and #$00FF              
        sta $00                 
        lda VaderCrab + VaderCrabStruct::Hurtbox_X1
        and #$00FF
        cmp $00
        bcc :+
        
        jmp MeleeNoCollision    ; Salto Longo Absoluto se não houver colisão

:       ; Teste 2: Se Hitbox_X1 >= Hurtbox_X2 (Ataque totalmente à direita)
        lda a:WeaponStruct::Hitbox_X1, y
        and #$00FF
        sta $00
        lda VaderCrab + VaderCrabStruct::Hurtbox_X2
        and #$00FF
        cmp $00
        bcs :+          
        
        jmp MeleeNoCollision        

:       ; Teste 3: Se Hitbox_Y2 <= Hurtbox_Y1 (Ataque totalmente acima)
        lda a:WeaponStruct::Hitbox_Y2, y
        and #$00FF
        sta $00
        lda VaderCrab + VaderCrabStruct::Hurtbox_Y1
        and #$00FF
        cmp $00
        bcc :+
        
        jmp MeleeNoCollision        

:       ; Teste 4: Se Hitbox_Y1 >= Hurtbox_Y2 (Ataque totalmente abaixo)
        lda a:WeaponStruct::Hitbox_Y1, y
        and #$00FF
        sta $00
        lda VaderCrab + VaderCrabStruct::Hurtbox_Y2
        and #$00FF
        cmp $00
        bcs MeleeConfirmouImpacto   ; Se for menor, passou em TODOS os testes! COLISÃO CONFIRMADA!
        
        jmp MeleeNoCollision        

MeleeConfirmouImpacto:
        ; =====================================================================
        ; CONTACT CONFIRMED: COLISÃO GEOMÉTRICA DE CAIXAS TOTALMENTE REALIZADA!
        ; =====================================================================
        sep #$20                ; Retorna acumulador para 8 bits
        .a8

        ; 1. Aplica o estado de dano (Hitstun) ao caranguejo grande
        lda #10
        sta VaderCrab + VaderCrabStruct::HurtTimer

        ; 2. Desativa a Hitbox para este frame para garantir que dê apenas 1 hit por porretada
        lda #$00
        sta a:WeaponStruct::Hitbox_Active, y

        ; 3. Executa o Knockback baseado no Facing do herói
        VADER_MELEE_KNOCKBACK = 20

        lda BigHero + BigHeroStruct::Facing
        bne PushVaderLeft

PushVaderRight:
        lda VaderCrab + VaderCrabStruct::X_Pos
        clc
        adc #VADER_MELEE_KNOCKBACK
        sta VaderCrab + VaderCrabStruct::X_Pos
        
        cmp #(SCREEN_RIGHT - 48)
        bcc MeleeExit
        lda #(SCREEN_RIGHT - 48)
        sta VaderCrab + VaderCrabStruct::X_Pos
        bra MeleeExit

PushVaderLeft:
        lda VaderCrab + VaderCrabStruct::X_Pos
        sec
        sbc #VADER_MELEE_KNOCKBACK
        sta VaderCrab + VaderCrabStruct::X_Pos
        
        cmp #SCREEN_LEFT
        bcs MeleeExit
        lda #SCREEN_LEFT
        sta VaderCrab + VaderCrabStruct::X_Pos
        bra MeleeExit

MeleeNoCollision:
        sep #$20                ; Garante o retorno estável para 8-bit se falhar
        .a8
MeleeExit:
        rts
.endproc

;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;   ApplyDamageToHero (Versão Arcade Premium - Proteção Atômica de Hitstun)
;-------------------------------------------------------------------------------
.proc ApplyDamageToHero
        ; =====================================================================
        ; FILTROS PRELIMINARES DE HARDWARE (8-bit)
        ; =====================================================================
        ; 1. ⚡ ESCUDO DA REALEZA: Se o Herói está em Hitstun/Recuperação, aborta imediatamente!
        ; Isso impede fisicamente hits duplos/triplos mesmo se ele estiver dentro da garra.
        lda BigHero + BigHeroStruct::HurtTimer
        bne @AbortDamage

        ; 2. Se a hitbox do VaderCrab não está ativa neste frame, aborta
        lda VaderCrab + VaderCrabStruct::Hitbox_Active
        beq @AbortDamage

        ; 3. Se a hurtbox do herói foi explicitamente desligada, aborta
        lda BigHero + BigHeroStruct::Hurtbox_Active
        beq @AbortDamage

        ; =====================================================================
        ; MOTOR MATEMÁTICO POR EXCLUSÃO (Pipeline de Alta Performance 16-bit)
        ; =====================================================================
@StartAABB:
        rep #$20                ; Transiciona o Acumulador para 16 bits (.a16)
        .a16

        ; --- TESTE DO EIXO X ---
        ; Teste 1: Se Hitbox_X2 <= Hurtbox_X1 (Inimigo totalmente à esquerda) -> SAI
        lda VaderCrab + VaderCrabStruct::Hitbox_X2
        and #$00FF              
        sta $00                 
        lda BigHero + BigHeroStruct::Hurtbox_X1
        and #$00FF
        cmp $00
        bcs @NoCollision        

        ; Teste 2: Se Hitbox_X1 >= Hurtbox_X2 (Inimigo totalmente à direita) -> SAI
        lda VaderCrab + VaderCrabStruct::Hitbox_X1
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_X2
        and #$00FF
        cmp $00
        bcc @NoCollision        
        beq @NoCollision

        ; --- TESTE DO EIXO Y ---
        ; Teste 3: Se Hitbox_Y2 <= Hurtbox_Y1 (Inimigo totalmente acima) -> SAI
        lda VaderCrab + VaderCrabStruct::Hitbox_Y2
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_Y1
        and #$00FF
        cmp $00
        bcs @NoCollision        

        ; Teste 4: Se Hitbox_Y1 >= Hurtbox_Y2 (Inimigo totalmente abaixo) -> SAI
        lda VaderCrab + VaderCrabStruct::Hitbox_Y1
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_Y2
        and #$00FF
        cmp $00
        bcc @NoCollision        
        beq @NoCollision

        ; =====================================================================
        ; COLISÃO CONFIRMADA: O RETÂNGULO INTERSECTOU EM AMBOS OS EIXOS!
        ; =====================================================================
        sep #$20                ; Restaura o Acumulador para 8 bits (.a8)
        .a8

        ; Liga o Hitstun imediatamente no relógio do Herói (30 frames de invulnerabilidade)
        lda #30
        sta BigHero + BigHeroStruct::HurtTimer
        
        ; Desativa as flags para isolamento total do frame
        stz BigHero + BigHeroStruct::Hurtbox_Active
        stz VaderCrab + VaderCrabStruct::Hitbox_Active

        ; Executa os impactos cinéticos e visuais do golpe tomado
        jsr TriggerHeroDamageEffect
        rts

@NoCollision:
        sep #$20                ; Restaura o Acumulador para 8 bits antes de sair (.a8)
        .a8
@AbortDamage:
        rts
.endproc

; --- Sub-rotina de suporte para aplicar os efeitos do golpe tomado ---

;-------------------------------------------------------------------------------
;   TriggerHeroDamageEffect
;   Aplica Knockback no BigHero baseado no Facing do Inimigo e trata as bordas
;-------------------------------------------------------------------------------
.proc TriggerHeroDamageEffect
        HURT_TIME = 30 ;quantodade de frames que fica de cara amassada
        lda #HURT_TIME
        sta BigHero + BigHeroStruct::HurtTimer

        lda z:$00
        eor #$40                        
        sta z:$00
        ; Constante local para a força do empurrão em pixels
        KNOCKBACK_FORCE = 16

        ; 1. Verifica a direção do VaderCrab para determinar o vetor do Knockback
        lda VaderCrab + VaderCrabStruct::Facing
        bne @PushToRight        ; Se Facing != 0 (Olhando para a Direita), empurra para a DIREITA

@PushToLeft:
        ; Inimigo olhando para a esquerda -> Empurra o herói para a ESQUERDA
        lda BigHero + BigHeroStruct::X_Pos
        sec
        sbc #KNOCKBACK_FORCE
        sta BigHero + BigHeroStruct::X_Pos

        ; --- Proteção de Borda Esquerda (Underflow) ---
        ; Se o resultado for menor que SCREEN_LEFT (ou se capotou a matemática devido ao SBC)
        lda BigHero + BigHeroStruct::X_Pos
        cmp #SCREEN_LEFT
        bcs @DoneKnockback      ; Se X >= SCREEN_LEFT, está seguro. Pula.
        
        lda #SCREEN_LEFT        ; Se estourou a borda esquerda, trava o herói nela
        sta BigHero + BigHeroStruct::X_Pos
        bra @DoneKnockback

@PushToRight:
        ; Inimigo olhando para a direita -> Empurra o herói para a DIREITA
        lda BigHero + BigHeroStruct::X_Pos
        clc
        adc #KNOCKBACK_FORCE
        sta BigHero + BigHeroStruct::X_Pos

        ; --- Proteção de Borda Direita (Overflow) ---
        ; O BigHero ocupa 32px de largura. Limite máximo é SCREEN_RIGHT - 32
        lda BigHero + BigHeroStruct::X_Pos
        cmp #(SCREEN_RIGHT - 32)
        bcc @DoneKnockback      ; Se X < limite direito, está seguro. Pula.
        
        lda #(SCREEN_RIGHT - 32) ; Se estourou a borda direita, trava o herói nela
        sta BigHero + BigHeroStruct::X_Pos

@DoneKnockback:
        ; 2. [Opcional] Inicializa um Timer de Invencibilidade na struct do Herói
        ; lda #60
        ; sta BigHero + BigHeroStruct::Invincibility_Timer ; (Adicionar campo na struct se desejar)

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
