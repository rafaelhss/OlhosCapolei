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
.include "Enemy.inc"
.include "Hero.inc"
.include "BigHero.inc"
.include "PennyCrab.inc"
.include "VaderCrab.inc"
.include "Weapon2.inc"

;-------------------------------------------------------------------------------

.segment "CODE"
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

        jsr SpawnWeaponOnGround ;

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
        jsr MoveHero
        jsr MoveEnemy1


        jsr MoveBigHero
        jsr MovePennyCrab
        jsr MoveVaderCrab


        ldy #.loword(WeaponA)
        jsr UpdateProjectiles
        
        ldy #.loword(WeaponB)
        jsr UpdateProjectiles

        ldy #.loword(WeaponC)
        jsr UpdateProjectiles

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
        
        ; CHECA COLISÃO CORPORAL (PORRETADA) PARA CADA SLOT
        ldy #.loword(WeaponA)
        jsr ApplyMeleeWeaponCollisions

        ldy #.loword(WeaponB)
        jsr ApplyMeleeWeaponCollisions

        ldy #.loword(WeaponC)
        jsr ApplyMeleeWeaponCollisions



        
        ; 4. SISTEMA DE RENDERIZAÇÃO FINAL
        ldx #$0000     
        
        
        ldy #.loword(WeaponA)            ; Garante que aponta para a WeaponA padrão
        jsr DrawDroppedWeapon     
        
        ldy #.loword(WeaponB)     ; Passa o endereço de WRAM da WeaponB por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!

        ldy #.loword(WeaponC)     ; Passa o endereço de WRAM da WeaponC por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!



        jsr DrawBigHero          
        jsr DrawVaderCrab

        jmp GameLoop
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
        lda #30
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

.proc ApplyDamageToHero


        ; =====================================================================
        ; FILTROS PRELIMINARES RÁPIDOS (8-bit)
        ; =====================================================================
        ; 1. Se a hitbox do VaderCrab não está ativa, aborta imediatamente
        lda VaderCrab + VaderCrabStruct::Hitbox_Active
        bne @CheckHurtbox
        rts

@CheckHurtbox:
        ; 2. Se o BigHero não está vulnerável (frames de dano/invencibilidade), aborta
        lda BigHero + BigHeroStruct::Hurtbox_Active
        bne @StartAABB
        rts

        ; =====================================================================
        ; MOTOR MATEMÁTICO POR EXCLUSÃO (Pipeline de Alta Performance 16-bit)
        ; =====================================================================
@StartAABB:
        rep #$20                ; Transiciona o Acumulador para 16 bits (.a16)
        .a16

        ; --- TESTE DO EIXO X ---
        
        ; Teste 1: Se Hitbox_X2 <= Hurtbox_X1 (Inimigo totalmente à esquerda) -> SAI
        lda VaderCrab + VaderCrabStruct::Hitbox_X2
        and #$00FF              ; Isola o byte baixo (limpa lixo do registrador)
        sta $00                 ; Guarda temporariamente na Direct Page ($00) para comparar
        lda BigHero + BigHeroStruct::Hurtbox_X1
        and #$00FF
        cmp $00
        bcs NoCollision        ; Se Hurtbox_X1 >= Hitbox_X2, não há colisão!

        ; Teste 2: Se Hitbox_X1 >= Hurtbox_X2 (Inimigo totalmente à direita) -> SAI
        lda VaderCrab + VaderCrabStruct::Hitbox_X1
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_X2
        and #$00FF
        cmp $00
        bcc NoCollision        ; Se Hurtbox_X2 <= Hitbox_X1, não há colisão! Se for igual, apenas raspou
        beq NoCollision

        ; --- TESTE DO EIXO Y ---
        
        ; Teste 3: Se Hitbox_Y2 <= Hurtbox_Y1 (Inimigo totalmente acima) -> SAI
        lda VaderCrab + VaderCrabStruct::Hitbox_Y2
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_Y1
        and #$00FF
        cmp $00
        bcs NoCollision        ; Se Hurtbox_Y1 >= Hitbox_Y2, não há colisão!

        ; Teste 4: Se Hitbox_Y1 >= Hurtbox_Y2 (Inimigo totalmente abaixo) -> SAI
        lda VaderCrab + VaderCrabStruct::Hitbox_Y1
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_Y2
        and #$00FF
        cmp $00
        bcc NoCollision        ; Se Hurtbox_Y2 <= Hitbox_Y1, não há colisão!
        beq NoCollision

        ; =====================================================================
        ; COLISÃO DETECTADA: O RETÂNGULO INTERSECTOU EM AMBOS OS EIXOS!
        ; =====================================================================
        sep #$20                ; Restaura o Acumulador para 8 bits (.a8)
        .a8

        ; Desativa a vulnerabilidade do herói imediatamente para não tomar dano infinito
        stz BigHero + BigHeroStruct::Hurtbox_Active
        ;lda #STATE_HURT
        ;sta BigHero + BigHeroStruct::HurtState

        ; Executa os gatilhos físicos e visuais do combate
        jsr TriggerHeroDamageEffect
        rts

NoCollision:
        sep #$20                ; Restaura o Acumulador para 8 bits antes de sair (.a8)
        .a8
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
.export Hero, InimigoGrande, InimigoGrande2
.export BigHero 
.export PennyCrab
.export VaderCrab
.export WeaponA
.export WeaponB
.export WeaponC

Hero:            .tag HeroStruct
InimigoGrande:   .tag EnemyStruct
InimigoGrande2:  .tag EnemyStruct
BigHero:         .tag BigHeroStruct
PennyCrab:       .tag PennyCrabStruct
VaderCrab:       .tag VaderCrabStruct
WeaponA:         .tag WeaponStruct
WeaponB:         .tag WeaponStruct
WeaponC:         .tag WeaponStruct

FrameCounter:    .res 1    ; Contador global de frames (0 a 255)
.export FrameCounter
