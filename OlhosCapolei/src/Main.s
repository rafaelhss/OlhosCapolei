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

        ;jsr ClearProjectilePool 
        
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

        ; 1. INPUT PIPELINE
        jsr ReadJoypad1

        ; 2. SESSÃO DE FÍSICA E MOVIMENTAÇÃO
        jsr MoveHero
        jsr MoveEnemy1
        jsr MoveBigHero
        jsr MovePennyCrab
        jsr MoveVaderCrab
        jsr UpdateProjectiles

        ; 3. FILTRO DE COLISÕES & REGRAS DE GAMEPLAY
        jsr ApplyEdgeCollisions
        jsr ApplyDamageToHero
        jsr ApplyWeaponCollisions       ; ◄ ADICIONADO: O gerenciador central testa a pedrada aqui!

        ; 4. SISTEMA DE RENDERIZAÇÃO FINAL
        ldx #$0000                
        jsr DrawDroppedWeapon     
        jsr DrawBigHero          
        jsr DrawVaderCrab

        jmp GameLoop
.endproc

;-------------------------------------------------------------------------------
;   ApplyWeaponCollisions (AABB CENTRALIZADO: WeaponA vs VaderCrab)
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   ApplyWeaponCollisions (AABB CENTRALIZADO: WeaponA vs VaderCrab)
;   Processado puramente em 8-bit com aplicação imediata de Bounce Back
;-------------------------------------------------------------------------------
.proc ApplyWeaponCollisions
        ; 1. Filtro preliminar: Só checa colisão se a pedra estiver voando (STATE_THROWN = 2)
        lda WeaponA + WeaponStruct::Active
        cmp #WEAPON_STATE_THROWN
        beq @CheckVaderVulnerable
        rts

@CheckVaderVulnerable:
        ; 2. Se o VaderCrab já estiver em Hitstun/Dano, aborta para evitar múltiplos hits
        lda VaderCrab + VaderCrabStruct::HurtTimer
        beq @StartAABB
        rts

@StartAABB:
        ; --- TESTE DO EIXO X ---
        lda WeaponA + WeaponStruct::X_Pos
        clc
        adc #16                 ; Largura estimada da pedra
        cmp VaderCrab + VaderCrabStruct::Hurtbox_X1
        bcc NoCollision
        beq NoCollision

        lda WeaponA + WeaponStruct::X_Pos
        cmp VaderCrab + VaderCrabStruct::Hurtbox_X2
        bcs NoCollision

        ; --- TESTE DO EIXO Y ---
        lda WeaponA + WeaponStruct::Y_Pos
        clc
        adc #16                 ; Altura estimada da pedra
        cmp VaderCrab + VaderCrabStruct::Hurtbox_Y1
        bcc NoCollision
        beq NoCollision

        lda WeaponA + WeaponStruct::Y_Pos
        cmp VaderCrab + VaderCrabStruct::Hurtbox_Y2
        bcs NoCollision

        ; =====================================================================
        ; IMPACTO CONFIRMADO: A PEDRA ACERTOU O VADER!
        ; =====================================================================
        
        ; 1. Força o VaderCrab a entrar em estado de Hitstun (30 frames)
        lda #30
        sta VaderCrab + VaderCrabStruct::HurtTimer

        ; =====================================================================
        ; 🦀 BOUNCE BACK / KNOCKBACK DO VADERCRAB
        ; =====================================================================
        ; Força do empurrão em pixels
        VADER_KNOCKBACK = 12

        ; Verifica para qual lado a pedra estava viajando para empurrar o Vader na direção correta
        lda WeaponA + WeaponStruct::Speed_X
        bmi @PedraIndoParaEsquerda

@PedraIndoParaDireita:
        ; Se a pedra viajava para a direita, o Vader é empurrado para a DIREITA
        lda VaderCrab + VaderCrabStruct::X_Pos
        clc
        adc #VADER_KNOCKBACK
        sta VaderCrab + VaderCrabStruct::X_Pos

        ; Proteção contra estouro da borda direita da tela (Largura do Vader: 48px)
        cmp #(SCREEN_RIGHT - 48)
        bcc @ApplyRicochet
        lda #(SCREEN_RIGHT - 48)
        sta VaderCrab + VaderCrabStruct::X_Pos
        bra @ApplyRicochet

@PedraIndoParaEsquerda:
        ; Se a pedra viajava para a esquerda (Sinal negativo), o Vader é empurrado para a ESQUERDA
        lda VaderCrab + VaderCrabStruct::X_Pos
        sec
        sbc #VADER_KNOCKBACK
        sta VaderCrab + VaderCrabStruct::X_Pos

        ; Proteção contra underflow na borda esquerda da tela
        cmp #SCREEN_LEFT
        bcs @ApplyRicochet
        lda #SCREEN_LEFT
        sta VaderCrab + VaderCrabStruct::X_Pos

@ApplyRicochet:
        ; =====================================================================
        ; 2. RICOCHETE DA PEDRA
        ; =====================================================================
        ; Inversão matemática do vetor horizontal (Soma <-> Subtração)
        lda WeaponA + WeaponStruct::Speed_X
        eor #$FF
        clc
        adc #1
        sta WeaponA + WeaponStruct::Speed_X

        ; 3. Impulso Vertical: Faz a pedra "quicar" para cima mudando a velocidade Y
        lda #$FC                ; Equivale a <-4 em byte assinado de 8 bits
        sta WeaponA + WeaponStruct::Speed_Y

NoCollision:
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
.proc ApplyEdgeCollisions
        ; === TRAVAS DO HEROI ===
CheckHeroLeft:
        lda BigHero + BigHeroStruct::X_Pos
        cmp #HERO_SCREEN_SAFE_LIMIT                    
        bcc CheckHeroRight          
        
        lda #SCREEN_LEFT            
        sta BigHero + BigHeroStruct::X_Pos
        bra CheckHeroTop            

CheckHeroRight:
        lda BigHero + BigHeroStruct::X_Pos
        cmp #(SCREEN_RIGHT - 16)
        bcc CheckHeroTop            
        
        lda #(SCREEN_RIGHT - 16)    
        sta BigHero + BigHeroStruct::X_Pos

CheckHeroTop:
        lda BigHero + BigHeroStruct::Y_Pos
        cmp #HERO_SCREEN_SAFE_LIMIT                    
        bcc CheckHeroBottom         
        
        lda #SCREEN_TOP             
        sta BigHero + BigHeroStruct::Y_Pos
        bra CollisionDone          

CheckHeroBottom:
        lda BigHero + BigHeroStruct::Y_Pos
        cmp #(SCREEN_BOTTOM - 32)
        bcc CollisionDone          
        
        lda #(SCREEN_BOTTOM - 32)    
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

Hero:            .tag HeroStruct
InimigoGrande:   .tag EnemyStruct
InimigoGrande2:  .tag EnemyStruct
BigHero:         .tag BigHeroStruct
PennyCrab:       .tag PennyCrabStruct
VaderCrab:       .tag VaderCrabStruct
WeaponA:         .tag WeaponStruct
