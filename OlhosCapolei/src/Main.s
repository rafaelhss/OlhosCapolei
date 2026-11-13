; -----------------------------------------------------------------------------
;   File: Main.s (Edicão Elegante & Otimizada - Pipeline de Auto-polling)
;   Description: Displays a sprite movable with the dpad
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     ResetHandler        
.export     NMIHandler
;-------------------------------------------------------------------------------

;----- Assembler Directives ----------------------------------------------------
.p816                           ; Habilita o conjunto de instrucões do 65816
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
.INCLUDE "BigHero.inc"
.include "MeleeCrab.inc"
.INCLUDE "Weapon2.inc"
.INCLUDE "Bullet.inc"
.include "Util.inc"

;-------------------------------------------------------------------------------

.segment "CODE"

VADER_KNOCKBACK = 12


;-------------------------------------------------------------------------------
;   PONTO DE ENTRADA DO SISTEMA (Boot seguro em Hardware Real)
;-------------------------------------------------------------------------------
.proc   ResetHandler
        sei                     ; Desabilita interrupcões de hardware
        cld                     ; Desativa modo decimal binário (Crítico para Everdrive)
        clc
        xce                     ; Transiciona o 65816 para Modo Nativo

        jmp   _ResetAlign       ; Sincroniza o Program Bank Register (K) para $00
        
_ResetAlign:
        rep #$10                ; Índices X/Y travados em 16-bit (.i16)
        sep #$20                ; Acumulador A travado em 8-bit (.a8)
        
        lda #$8f                ; Forca V-Blank imediato (Desliga a tela)
        sta INIDISP
        stz NMITIMEN            ; Garante NMI desligado durante limpezas
        
        ldx #$1fff              ; Aponta a Pilha para o topo da página espelho
        txs

        jsr ClearProjectilePool 
        jsr ClearRegisters
        jsr ClearVRAM
        jsr ClearCGRAM
        jsr ClearOAMRAM
        jsr InitDemo            ; Executa inicializacão customizada e ativa PPU

        
        ; --- ENTRADA EM AMBIENTE DE EXECUcÃO REAL ---
        lda #$81                ; ◄ AUTO-POLLING LIGADO: Habilita NMI ($80) + Auto-read ($01)
        sta NMITIMEN
        cli                     ; Corta a trava global de interrupcões da CPU

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
        JSR ReadJoypad1
        

;TODO melhorar a inteligencia de respawn
        LDA #00
        CMP FrameCounter
        bne NaoRespawn
        ;so teste 
        pea .loword(VaderCrab)
        jsr RespawnEnemy
        ply 
        pea .loword(DengueCrab)
        jsr RespawnEnemy
        ply 
        pea .loword(RapaNuiCrab)
        jsr RespawnEnemy
        ply 


NaoRespawn:
        ; 2. SESSÃO DE FÍSICA E MOVIMENTAcÃO

        JSR MoveBigHero
        ;Atualiza a posicao central do heroi para o sistema de colisões
        LDA BigHero + BigHeroStruct::X_Pos
        CLC
        ADC #16
        STA z:DP_HERO_CENTER_X
        LDA BigHero + BigHeroStruct::Y_Pos
        CLC
        ADC #32
        STA z:DP_HERO_CENTER_Y
        
        pea .loword(VaderCrab)
        jsr UpdateTargetSector
        ply 
         
        pea .loword(RapaNuiCrab)
        jsr UpdateTargetSector
        ply  

        pea .loword(DengueCrab)
        jsr UpdateTargetSector
        ply  
        




        ; ; --- MOVIMENTAcÃO DO VADERCRAB ---
        pea .loword(VaderCrab)
        jsr MoveMeleeCrab
        ply                             ; Limpa 2 bytes da pilha (.i16 ativo)

        ; --- MOVIMENTAcÃO DO DengueCRAB ---
        pea .loword(DengueCrab)
        jsr MoveMeleeCrab
        ply                             ; Limpa 2 bytes da pilha
       
        ; ; --- MOVIMENTAcÃO DO RapaNUiCRAB ---
        pea .loword(RapaNuiCrab)
        jsr MoveMeleeCrab
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
        jsr MoveBullet2


        ; 3. FILTRO DE COLISÕES & REGRAS DE GAMEPLAY
        jsr ApplyEdgeCollisions


        ; --- DETECcÃO DE DANO AO HERÓI PARAMETRIZADA VIA PILHA ---
        pea .loword(VaderCrab)
        jsr ApplyDamageToHero
        ply                             ; Limpa 2 bytes da pilha

        pea .loword(DengueCrab)
        jsr ApplyDamageToHero
        ply                             ; Limpa 2 bytes da pilha

        pea .loword(RapaNuiCrab)
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
        pea .loword(VaderCrab)
        jsr ApplyBullet2Collisions
        ply



        ; === TESTES CONTRA O DengueCRAB ===
        ldy #.loword(DengueCrab)
        sty z:DP_ENEMY_STRUCT_PTR       ; Muda o alvo atual na Direct Page!
        
        ; Checa colisões de pedradas (Slots A..E) contra o Dengue
        .repeat 5, I
            ldy #.loword(.ident(.sprintf("Weapon%c", $41 + I)))
            jsr ApplyWeaponCollisions
        .endrepeat
        
        ; Checa colisões de porretadas (Slots A..E) contra o Dengue
        .repeat 5, I
            ldy #.loword(.ident(.sprintf("Weapon%c", $41 + I)))
            jsr ApplyMeleeWeaponCollisions
        .endrepeat

        pea .loword(DengueCrab)
        jsr ApplyBulletCollisions
        ply
        pea .loword(DengueCrab)
        jsr ApplyBullet2Collisions
        ply
        

        ; === TESTES CONTRA O RapaNuiCrab ===
        LDY #.loword(RapaNuiCrab)
        sty z:DP_ENEMY_STRUCT_PTR       ; Muda o alvo atual na Direct Page!
        
        ; Checa colisões de pedradas (Slots A..E) contra o Dengue
        .repeat 5, I
            ldy #.loword(.ident(.sprintf("Weapon%c", $41 + I)))
            jsr ApplyWeaponCollisions
        .endrepeat
        
        ; Checa colisões de porretadas (Slots A..E) contra o Dengue
        .repeat 5, I
            ldy #.loword(.ident(.sprintf("Weapon%c", $41 + I)))
            jsr ApplyMeleeWeaponCollisions
        .endrepeat

        pea .loword(RapaNuiCrab)
        jsr ApplyBulletCollisions
        ply
        pea .loword(RapaNuiCrab)
        jsr ApplyBullet2Collisions
        ply
        


        ; 4. SISTEMA DE RENDERIZAcÃO FINAL
        ldx #$0000     

        
        ; ; JSR drawHeroCenterDebug
        ; ; JSR drawHeroHitBoxDebug
        ; ; ;JSR DrawDengueHitboxDebug
        ; ; jsr DrawHitboxDebug
        ;  JSR DrawtargetEnemyXYDebug
        ;  jsr drawDengueXYDebug
        ; ; jsr drawVaderXYDebug
        ; ; ;jsr DrawDengueAttackSectorDebug
        ; ; ;JSR DrawPow ; tem que estar em cima de td
        
        
   
        jsr DrawBullet
        jsr DrawBullet2


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
        
        ldy #.loword(WeaponB)     ; Passa o endereco de WRAM da WeaponB por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!

        ldy #.loword(WeaponC)     ; Passa o endereco de WRAM da WeaponC por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!

        ldy #.loword(WeaponD)     ; Passa o endereco de WRAM da WeaponC por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!


        ldy #.loword(WeaponE)     ; Passa o endereco de WRAM da WeaponC por parâmetro
        jsr DrawDroppedWeapon     ; Desenha reutilizando o mesmo código!
        ;lda z:$00
        ;eor #$40                        
        ;sta z:$00

        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq Finish

        jsr DrawBigHero          
        
Finish:



; TODO Decidir a ordem com base no Y para nao ficar estranho a nocao de 3d
     ; --- RENDERIZAcÃO DO VADERCRAB ---
        pea .loword(VaderCrab)          ; Empilha o endereco de 16-bit diretamente (Y fica livre!)
        jsr DrawMeleeCrab
        ply                     ; Tentativa Param: reset stack pointer


        ; --- RENDERIZAcÃO DO VADERCRAB ---
        pea .loword(DengueCrab)          ; Empilha o endereco de 16-bit diretamente (Y fica livre!)
        jsr DrawMeleeCrab
        ply                     ; Tentativa Param: reset stack pointer


        ; --- RENDERIZAcÃO DO VADERCRAB ---
        pea .loword(RapaNuiCrab)          ; Empilha o endereco de 16-bit diretamente (Y fica livre!)
        jsr DrawMeleeCrab
        ply                     ; Tentativa Param: reset stack pointer




        pea .loword(VaderCrab)          ; Empilha o endereco de 16-bit diretamente (Y fica livre!)
        jsr DrawMeleeCrabHP
        ply                     ; Tentativa Param: reset stack pointer


        pea .loword(DengueCrab)          ; Empilha o endereco de 16-bit diretamente (Y fica livre!)
        jsr DrawMeleeCrabHP
        ply                     ; Tentativa Param: reset stack pointer


        pea .loword(RapaNuiCrab)          ; Empilha o endereco de 16-bit diretamente (Y fica livre!)
        jsr DrawMeleeCrabHP
        ply                     ; Tentativa Param: reset stack pointer



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
        ldy z:DP_ENEMY_STRUCT_PTR       ; Y = Inimigo ativo (Vader ou Dengue)
        lda MeleeCrabStruct::HurtTimer, y
        beq @StartAABB
        rts

@StartAABB:
        ldy z:DP_ENEMY_STRUCT_PTR       
        lda Bullet + BulletStruct::X_Pos
        clc
        adc #16                 
        cmp MeleeCrabStruct::Hurtbox_X1, y
        bcc @NoCollision
        beq @NoCollision

        lda Bullet + BulletStruct::X_Pos
        cmp MeleeCrabStruct::Hurtbox_X2, y
        bcs @NoCollision

        lda Bullet + BulletStruct::Y_Pos
        clc
        adc #16                 
        cmp MeleeCrabStruct::Hurtbox_Y1, y
        bcc @NoCollision
        beq @NoCollision

        lda Bullet + BulletStruct::Y_Pos
        cmp MeleeCrabStruct::Hurtbox_Y2, y
        bcs @NoCollision

        ; =====================================================================
        ; IMPACTO CONFIRMADO
        ; =====================================================================
        ; =====================================================================
        ; IMPACTO CONFIRMADO (Bullet)
        ; =====================================================================
        lda #BULLET_STATE_INACTIVE
        sta Bullet + BulletStruct::Active

        lda #30
        sta z:DP_TEMP_00                ; HurtTimer = 30
        lda #1
        sta z:DP_TEMP_01                ; Dano = 1
        lda #VADER_KNOCKBACK
        sta z:DP_TEMP_02                ; Knockback = 12

        ; Speed_X já é positivo (Direita) ou negativo (Esquerda)!
        lda Bullet + BulletStruct::Speed_X
        sta z:DP_TEMP_03                ; Direção direta pelo sinal do Speed_X

        JSR ApplyEnemyHit
@NoCollision:
        rts
.endproc



;-------------------------------------------------------------------------------
;   ApplyBullet2Collisions (Física de Impacto para o Segundo Slot de Tiro)
;-------------------------------------------------------------------------------
.proc ApplyBullet2Collisions
        lda Bullet2 + BulletStruct::Active
        cmp #BULLET_STATE_ACTIVE
        beq @CheckVaderVulnerable
        rts

@CheckVaderVulnerable:

        ldy z:DP_ENEMY_STRUCT_PTR       ; Y = Inimigo ativo
        
        ; --- FILTRO: Ignora se State >= STATE_DYING (6 ou 7) ---
        lda MeleeCrabStruct::State, y
        cmp #STATE_DYING
        bcs @NoCollision                ; Se estiver morrendo ou morto, sai!


        ldy z:DP_ENEMY_STRUCT_PTR       
        lda MeleeCrabStruct::HurtTimer, y
        beq @StartAABB
        rts

@StartAABB:
        ldy z:DP_ENEMY_STRUCT_PTR       
        lda Bullet2 + BulletStruct::X_Pos
        clc
        adc #16                 
        cmp MeleeCrabStruct::Hurtbox_X1, y
        bcc @NoCollision
        beq @NoCollision

        lda Bullet2 + BulletStruct::X_Pos
        cmp MeleeCrabStruct::Hurtbox_X2, y
        bcs @NoCollision

        lda Bullet2 + BulletStruct::Y_Pos
        clc
        adc #16                 
        cmp MeleeCrabStruct::Hurtbox_Y1, y
        bcc @NoCollision
        beq @NoCollision

        lda Bullet2 + BulletStruct::Y_Pos
        cmp MeleeCrabStruct::Hurtbox_Y2, y
        bcs @NoCollision

        ; =====================================================================
        ; IMPACTO CONFIRMADO (Bullet 2)
        ; =====================================================================
        ; =====================================================================
        ; IMPACTO CONFIRMADO (Bullet)
        ; =====================================================================
        lda #BULLET_STATE_INACTIVE
        sta Bullet2 + BulletStruct::Active

        lda #30
        sta z:DP_TEMP_00                ; HurtTimer = 30
        lda #1
        sta z:DP_TEMP_01                ; Dano = 1
        lda #VADER_KNOCKBACK
        sta z:DP_TEMP_02                ; Knockback = 12

        ; Speed_X já é positivo (Direita) ou negativo (Esquerda)!
        lda Bullet2 + BulletStruct::Speed_X
        sta z:DP_TEMP_03                ; Direção direta pelo sinal do Speed_X

          JSR ApplyEnemyHit
@NoCollision:
        rts
.endproc




;-------------------------------------------------------------------------------
;   ApplyWeaponCollisions (Leitura de Direct Page Direta)
;   Entrada: Y = Endereco absoluto do slot da Arma
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   ApplyWeaponCollisions (Física de Ricochete Corrigida e Blindada)
;-------------------------------------------------------------------------------
.proc ApplyWeaponCollisions
        lda a:WeaponStruct::Active, y
        cmp #WEAPON_STATE_THROWN
        beq @CheckVaderVulnerable
        rts

@CheckVaderVulnerable:
        sty z:DP_WEAPON_POOL_PTR        ; Preserva Y da arma
        ldy z:DP_ENEMY_STRUCT_PTR       ; Carrega o inimigo atual
        
        ; --- FILTRO: Ignora se State >= STATE_DYING ---
        lda MeleeCrabStruct::State, y
        cmp #STATE_DYING
        bcs @EnemyDeadOrDying

        lda MeleeCrabStruct::HurtTimer, y
        beq @StartAABB

@EnemyDeadOrDying:
        ldy z:DP_WEAPON_POOL_PTR        ; Restaura Y da arma
        rts

@StartAABB:
        ldy z:DP_WEAPON_POOL_PTR        ; Y = Arma ativa
        ldx z:DP_ENEMY_STRUCT_PTR       ; X = Inimigo ativo

        lda a:WeaponStruct::X_Pos, y
        clc
        adc #16                 
        cmp a:MeleeCrabStruct::Hurtbox_X1, x
        bcc @NoCollision
        beq @NoCollision

        lda a:WeaponStruct::X_Pos, y
        cmp a:MeleeCrabStruct::Hurtbox_X2, x
        bcs @NoCollision

        lda a:WeaponStruct::Y_Pos, y
        clc
        adc #16                 
        cmp a:MeleeCrabStruct::Hurtbox_Y1, x
        bcc @NoCollision
        beq @NoCollision

        lda a:WeaponStruct::Y_Pos, y
        cmp a:MeleeCrabStruct::Hurtbox_Y2, x
        bcs @NoCollision

        ; =====================================================================
        ; IMPACTO CONFIRMADO
        ; =====================================================================
        ; =====================================================================
        ; IMPACTO CONFIRMADO (Arma Arremessada)
        ; =====================================================================
        lda #30
        sta z:DP_TEMP_00                ; HurtTimer = 30
        LDA #1
        sta z:DP_TEMP_01                ; Dano = 2
        lda #VADER_KNOCKBACK
        sta z:DP_TEMP_02                ; Knockback = 12

        ; Speed_X já tem o sinal da direção do arremesso!
        lda a:WeaponStruct::Speed_X, y
        sta z:DP_TEMP_03                ; Salva direção antes do ricochete

        jsr ApplyEnemyHit

        ; Restaura Y da arma e aplica o ricochete usando z:DP_TEMP_03 (Speed_X original)
        ldy z:DP_WEAPON_POOL_PTR
        lda z:DP_TEMP_03
        eor #$FF
        clc
        adc #1
        sta a:WeaponStruct::Speed_X, y  ; Inverte o vetor horizontal

        LDA #$FC                        ; Quique para cima (-4)
        sta a:WeaponStruct::Speed_Y, y
        rts

@NoCollision:
        ldy z:DP_WEAPON_POOL_PTR
        rts
.endproc


;-------------------------------------------------------------------------------
;   ApplyMeleeWeaponCollisions (Leitura de Direct Page Direta)
;   Entrada: Y = Endereco absoluto do slot da Arma
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   ApplyMeleeWeaponCollisions (Correção de Knockback com Restauro de Contexto)
;-------------------------------------------------------------------------------
.proc ApplyMeleeWeaponCollisions
MeleeStart:
        lda a:WeaponStruct::Hitbox_Active, y
        bne @CheckVaderVulnerable                
        rts

@CheckVaderVulnerable:
        sty z:DP_WEAPON_POOL_PTR        ; Preserva Y da arma
        ldy z:DP_ENEMY_STRUCT_PTR       ; Carrega o inimigo atual
        
        ; --- FILTRO: Ignora se State >= STATE_DYING ---
        lda MeleeCrabStruct::State, y
        cmp #STATE_DYING
        bcs @EnemyDeadOrDying

        lda MeleeCrabStruct::HurtTimer, y
        beq @StartAABB                  

@EnemyDeadOrDying:
        ldy z:DP_WEAPON_POOL_PTR        ; Restaura Y da arma
        rts

@StartAABB:
        ldy z:DP_WEAPON_POOL_PTR        ; Y = Arma ativa
        ldx z:DP_ENEMY_STRUCT_PTR       ; X = Inimigo ativo

        rep #$20                
        .a16
        
        lda a:WeaponStruct::Hitbox_X2, y
        and #$00FF              
        sta $00                 
        lda a:MeleeCrabStruct::Hurtbox_X1, x
        and #$00FF
        cmp $00
        bcc :+
        jmp MeleeNoCollision    

:       lda a:WeaponStruct::Hitbox_X1, y
        and #$00FF
        sta $00
        lda a:MeleeCrabStruct::Hurtbox_X2, x
        and #$00FF
        cmp $00
        bcs :+          
        jmp MeleeNoCollision        

:       lda a:WeaponStruct::Hitbox_Y2, y
        and #$00FF
        sta $00
        lda a:MeleeCrabStruct::Hurtbox_Y1, x
        and #$00FF
        cmp $00
        bcc :+
        jmp MeleeNoCollision        

:       lda a:WeaponStruct::Hitbox_Y1, y
        and #$00FF
        sta $00
        lda a:MeleeCrabStruct::Hurtbox_Y2, x
        and #$00FF
        cmp $00
        bcs @MeleeConfirmouImpacto   
        jmp MeleeNoCollision        

@MeleeConfirmouImpacto:
        sep #$20
        .a8

        ; Desativa hitbox da arma imediatamente
        ldy z:DP_WEAPON_POOL_PTR
        lda #$00
        sta a:WeaponStruct::Hitbox_Active, y

        lda #10
        sta z:DP_TEMP_00                ; HurtTimer = 10
        lda #1
        sta z:DP_TEMP_01                ; Dano = 2
        lda #16
        sta z:DP_TEMP_02                ; Knockback Melee = 16

        ; Converte Facing (0 = Direita, 1 = Esquerda) para sinal (0 ou $80)
        stz z:DP_TEMP_03                ; Assume 0 (Direita)
        lda BigHero + BigHeroStruct::Facing
        beq @DisparaHit
        lda #$80                        ; Se Facing != 0, liga bit 7 (Esquerda)
        sta z:DP_TEMP_03

@DisparaHit:
        jsr ApplyEnemyHit

        ldy z:DP_WEAPON_POOL_PTR        ; Restaura Y para o loop .repeat
        rts

MeleeNoCollision:
        sep #$20                
        .a8
MeleeExit:
        ldy z:DP_WEAPON_POOL_PTR        ; Restaura Y da arma para o macro do loop funcionar
        rts
.endproc

;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;   ApplyDamageToHero (Versão Arcade Premium - Protecão Atômica de Hitstun)
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   ApplyDamageToHero (Versão Arcade Premium Parametrizada via Pilha)
;-------------------------------------------------------------------------------
.proc ApplyDamageToHero
        ; 1. Recupera o endereco de 16-bit da Struct do inimigo enviado via pilha
        rep #$20
        .a16
        lda 3,s
        tay                             ; Y agora aponta para o inimigo atual (Vader ou Dengue)
        sep #$20
        .a8

        ; =====================================================================
        ; FILTROS PRELIMINARES DE HARDWARE (8-bit)
        ; =====================================================================
        ; 1. Se o Herói está em Hitstun/Recuperacão, aborta imediatamente!
        lda BigHero + BigHeroStruct::HurtTimer
        beq CheckEnemyHitbox
        jmp AbortDamage

CheckEnemyHitbox:
        ; 2. Se a hitbox deste caranguejo específico não está ativa, aborta
        lda MeleeCrabStruct::Hitbox_Active, y
        bne CheckHeroHurtbox
        jmp AbortDamage

CheckHeroHurtbox:
        ; 3. Se a hurtbox do herói foi desligada, aborta
        lda BigHero + BigHeroStruct::Hurtbox_Active
        bne @StartAABB
        jmp AbortDamage

        ; =====================================================================
        ; MOTOR MATEMÁTICO POR EXCLUSÃO (AABB Dinâmico 16-bit)
        ; =====================================================================
@StartAABB:
        rep #$20                        ; Transiciona o Acumulador para 16 bits
        .a16

        ; --- TESTE DO EIXO X ---
        lda MeleeCrabStruct::Hitbox_X2, y
        and #$00FF              
        sta $00                 
        lda BigHero + BigHeroStruct::Hurtbox_X1
        and #$00FF
        cmp $00
        bcs @NoCollision        

        lda MeleeCrabStruct::Hitbox_X1, y
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_X2
        and #$00FF
        cmp $00
        bcc @NoCollision        
        beq @NoCollision

        ; --- TESTE DO EIXO Y ---
        lda MeleeCrabStruct::Hitbox_Y2, y
        and #$00FF
        sta $00
        lda BigHero + BigHeroStruct::Hurtbox_Y1
        and #$00FF
        cmp $00
        bcs @NoCollision        

        lda MeleeCrabStruct::Hitbox_Y1, y
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


        ;jsr createHeroPow
        
        ; Liga o Hitstun imediatamente no Herói (30 frames)
        lda #30
        sta BigHero + BigHeroStruct::HurtTimer
        
        ; Desativa as flags para isolamento total do frame
        stz BigHero + BigHeroStruct::Hurtbox_Active
        
        lda #0
        sta MeleeCrabStruct::Hitbox_Active, y

        ; Empilha o ponteiro do caranguejo agressor para empurrar o herói certo
        phy
        jsr TriggerHeroDamageEffect
        ply
        rts

@NoCollision:
        sep #$20                        ; Restaura o Acumulador para 8 bits
        .a8
AbortDamage:
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
        ; 1. Recupera o endereco do caranguejo enviado da pilha para o registrador Y
        rep #$20
        .a16
        lda 3,s                         
        tay
        sep #$20
        .a8

        HURT_TIME = 30 
        lda #HURT_TIME
        sta BigHero + BigHeroStruct::HurtTimer

       ; LDA z:$00
        ;eor #$40                        
        ;sta z:$00
        
        KNOCKBACK_FORCE = 8


        ; 2. Verifica a direcão do caranguejo atual parametrizado em Y
        lda MeleeCrabStruct::Facing, y
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
        bcc CheckHeroRight          ; Se X < 240, está em uma posicão normal da tela. Checa a direita.
        
        ; Se caiu aqui, houve underflow (X >= 240 vindo do zero). Forca na borda esquerda!
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
        
        ; Se caiu aqui, houve underflow no teto. Forca na borda superior!
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
;   ApplyEnemyHit (Centraliza Dano, HurtTimer, Pow, Knockback e Bordas)
;   Entrada via Direct Page:
;     z:DP_ENEMY_STRUCT_PTR = Ponteiro para o Inimigo atingido
;     z:DP_TEMP_00          = Duração do HurtTimer (frames)
;     z:DP_TEMP_01          = Dano a ser descontado do HP
;     z:DP_TEMP_02          = Força do Knockback (pixels)
;     z:DP_TEMP_03          = Direção (0 = Direita, Negativo/$80 = Esquerda)
;-------------------------------------------------------------------------------
.proc ApplyEnemyHit
        ldy z:DP_ENEMY_STRUCT_PTR       ; Y = Inimigo atingido

        ; 1. Aplica o HurtTimer parametrizado
        lda z:DP_TEMP_00
        sta a:MeleeCrabStruct::HurtTimer, y

        ; 2. Dispara partícula POW (preserva Y)
        jsr createEnemyPow

        ; 3. Aplica Dano com Subtração Saturada (Anti-Underflow)
        lda a:MeleeCrabStruct::HP, y
        sec
        sbc z:DP_TEMP_01
        bcs @SalvaHP                    ; Se Carry = 1, HP >= 0
        lda #0                          ; Satura em 0 se houve underflow
@SalvaHP:
        sta a:MeleeCrabStruct::HP, y
        bne @AplicaKnockback          ; <-- Quando criar a morte, descomente aqui!
        jmp IniciaMorte

@AplicaKnockback:
        lda z:DP_TEMP_03                ; Lê a direção salva na DP
        bmi @EmpurraParaEsquerda        ; Se bit 7 = 1 (negativo), vai para a esquerda

@EmpurraParaDireita:
        lda a:MeleeCrabStruct::X_Pos, y
        clc
        adc z:DP_TEMP_02                ; Soma força do Knockback
        sta a:MeleeCrabStruct::X_Pos, y

        ; Blindagem Borda Direita
        cmp #(SCREEN_RIGHT - 48)
        bcc Finish
        lda #(SCREEN_RIGHT - 48)
        sta a:MeleeCrabStruct::X_Pos, y
        bra Finish

@EmpurraParaEsquerda:
        lda a:MeleeCrabStruct::X_Pos, y
        sec
        sbc z:DP_TEMP_02                ; Subtrai força do Knockback
        sta a:MeleeCrabStruct::X_Pos, y

        ; Blindagem Borda Esquerda
        cmp #SCREEN_LEFT
        bcs Finish
        lda #SCREEN_LEFT
        STA a:MeleeCrabStruct::X_Pos, y
        JMP Finish

IniciaMorte:
        lda #STATE_DYING
        sta a:MeleeCrabStruct::State, y

        lda #00
        sta a:MeleeCrabStruct::Hitbox_Active, y  ; Garante que não dê dano póstumo
        sta a:MeleeCrabStruct::HurtTimer, y      ; Zera HurtTimer (ou use para piscar)
        sta a:MeleeCrabStruct::Dying_Timer, y
        sta a:MeleeCrabStruct::Dying_Anim_Frame, y

        lda #15                                  ; Velocidade de troca dos frames de morte
        sta a:MeleeCrabStruct::Dying_Anim_Timer, y

Finish:
        rts
.endproc



;-------------------------------------------------------------------------------
;   createHeroPow (Versão Blindada com Isolamento de Registradores)
;-------------------------------------------------------------------------------
.proc createHeroPow


        ; Salva os registradores de índice atuais para proteger a OAM e o loop global
        phx
        phy

        lda #08
        sta Pow + PowStruct::Active_timer

        ; --- CÁLCULO DO CENTRO X DO HERÓI ---
        lda BigHero + BigHeroStruct::Hurtbox_X1
        clc
        adc BigHero + BigHeroStruct::Hurtbox_X2
        ror a 
        sta Pow + PowStruct::X_Pos
        
        ; --- CÁLCULO DO CENTRO Y DO HERÓI (Com blindagem ROR contra estouros) ---
        lda BigHero + BigHeroStruct::Hurtbox_Y1
        clc
        adc BigHero + BigHeroStruct::Hurtbox_Y2
        ror a 
        sta Pow + PowStruct::Y_Pos

        ; Restaura os contextos intactos antes de voltar para o fluxo de dano
        ply
        plx
        rts
.endproc

.proc createEnemyPow
        lda #08
        sta Pow + PowStruct::Active_timer
        
        lda a:MeleeCrabStruct::Hurtbox_X1, y
        clc
        adc a:MeleeCrabStruct::Hurtbox_X2, y
        ror a 
        sta Pow + PowStruct::X_Pos
        lda a:MeleeCrabStruct::Hurtbox_Y2, y
        clc
        adc a:MeleeCrabStruct::Hurtbox_Y1, y
        ror a 
        STA Pow + PowStruct::Y_Pos
        rts
.endproc


.proc DrawMeleeCrabHP
        ; 1. Recupera o endereco do caranguejo enviado da pilha para o registrador Y
        rep #$20
        .a16
        lda 3,s                         
        tay
        sep #$20
        .a8
        

        LDA a:MeleeCrabStruct::State, y
        cmp #STATE_DEAD
        bne Draw
        rts

Draw:


        

        lda a:MeleeCrabStruct::HP, y
        CMP #0
        BEQ @ZeroHp
        CMP #1
        BEQ @OneHp
        CMP #2
        BEQ @TwoHp
        CMP #3
        BEQ @ThreeHp
        CMP #4
        BEQ @FourHp

@ZeroHp:
        rts
        lda #$E0                         ; Tile ID do HP
        sta OAMMIRROR, x
        inx
        JMP Finish
@OneHp:
         LDA a:MeleeCrabStruct::X_Pos, y
        sta OAMMIRROR, x
        inx
        
        lda a:MeleeCrabStruct::Y_Pos, y
        sta OAMMIRROR, x
        inx
        lda #$8A                         ; Tile ID do HP
        sta OAMMIRROR, x
        inx
        JMP Finish
@TwoHp:
         LDA a:MeleeCrabStruct::X_Pos, y
        sta OAMMIRROR, x
        inx
        
        lda a:MeleeCrabStruct::Y_Pos, y
        sta OAMMIRROR, x
        inx
        LDA #$20                         ; Tile ID do HP
        STA OAMMIRROR, x
        inx
        JMP Finish
@ThreeHp:
         LDA a:MeleeCrabStruct::X_Pos, y
        sta OAMMIRROR, x
        inx
        
        lda a:MeleeCrabStruct::Y_Pos, y
        sta OAMMIRROR, x
        inx
        LDA #$2E                         ; Tile ID do HP
        sta OAMMIRROR, x
        inx
        JMP Finish
@FourHp:
         LDA a:MeleeCrabStruct::X_Pos, y
        sta OAMMIRROR, x
        inx
        
        lda a:MeleeCrabStruct::Y_Pos, y
        sta OAMMIRROR, x
        inx
        LDA #$0E                         ; Tile ID do HP
        sta OAMMIRROR, x
        inx
        JMP Finish

Finish:
        lda #$31                         
        sta OAMMIRROR, x
        INX
        
        RTS
.endproc



;-------------------------------------------------------------------------------
;   RespawnEnemy
;   Entrada via Pilha (3,s): Endereço 16-bit da struct do inimigo
;   Comportamento:
;     - Verifica se o inimigo morreu (HP == 0)
;     - Usa a sua rotina 'rand' para sortear o lado (esquerda/direita) e altura Y
;     - Reseta todos os status via SetupDefaultMeleeStats
;-------------------------------------------------------------------------------
.proc   RespawnEnemy
        ; 1. Pega o endereço do inimigo seguindo o seu padrão exato (3,s)
        rep #$20
        .a16
        lda 3, s                        ; Lê ponteiro da struct do inimigo
        tay                             ; Guarda em Y
        sep #$20
        .a8

        ; 2. Só faz respawn se o inimigo estiver morto (HP == 0)
        lda a:MeleeCrabStruct::HP, y
        bne @Fim

        ; --- 3. SORTEIA O LADO DO EIXO X (ESQUERDA OU DIREITA) ---
        jsr rand                        ; Retorna byte aleatório em A (.a8)
        and #$01                        ; Isola apenas o bit 0 (0 ou 1)
        beq @NasceEsquerda

@NasceDireita:
        lda #$F0                        ; X = 240 (Borda direita)
        bra @SalvaX

@NasceEsquerda:
        lda #$08                        ; X = 8 (Borda esquerda)

@SalvaX:
        sta a:MeleeCrabStruct::X_Pos, y

        ; --- 4. SORTEIA A ALTURA DO CHÃO (EIXO Y) ---
        jsr rand                        ; Pega um novo byte aleatório em A
        and #$3F                        ; Limita o valor entre 0 e 63 ($00 a $3F)
        clc
        adc #(SCREEN_BOTTOM - 64)       ; Soma com o teto do chão (Ex: 224 - 64 = 160)
        sta a:MeleeCrabStruct::Y_Pos, y

        ; --- 5. RESETA OS STATUS PADRÃO ---
        tyx                             ; Transfere ponteiro Y -> X
        jsr SetupDefaultMeleeStats

@Fim:
        rts
.endproc


; =============================================================================
; ScrollWorldLeft
; Entrada: A (.a8) = Quantidade de pixels que a câmera avançou para a direita
; Efeito:  Soma A em Camera_X (16-bit) e subtrai A do X_Pos de todas as entidades
; =============================================================================
.proc ScrollWorldLeft
        php
        sep #$20
        .a8
        sta z:DP_TEMP_00                ; Salva o deslocamento (speed) em DP_TEMP_00

        ; 1. Avança Camera_X (16-bit)
        rep #$20
        .a16
        lda z:DP_TEMP_00
        and #$00FF                      ; Isola apenas o byte baixo
        clc
        adc Camera_X
        sta Camera_X
        sep #$20
        .a8

        ; 2. Puxa os Inimigos para a esquerda (X_Pos -= speed)
        lda VaderCrab + MeleeCrabStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta VaderCrab + MeleeCrabStruct::X_Pos

        lda DengueCrab + MeleeCrabStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta DengueCrab + MeleeCrabStruct::X_Pos

        lda RapaNuiCrab + MeleeCrabStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta RapaNuiCrab + MeleeCrabStruct::X_Pos

        ; 3. Puxa as Armas no chão / arremessadas para a esquerda
        lda WeaponA + WeaponStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta WeaponA + WeaponStruct::X_Pos

        lda WeaponB + WeaponStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta WeaponB + WeaponStruct::X_Pos

        lda WeaponC + WeaponStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta WeaponC + WeaponStruct::X_Pos

        lda WeaponD + WeaponStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta WeaponD + WeaponStruct::X_Pos

        lda WeaponE + WeaponStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta WeaponE + WeaponStruct::X_Pos

        ; 4. Puxa Projéteis e Partículas
        lda Bullet + BulletStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta Bullet + BulletStruct::X_Pos

        lda Bullet2 + BulletStruct::X_Pos
        sec
        sbc z:DP_TEMP_00
        sta Bullet2 + BulletStruct::X_Pos

        plp
        rts
.endproc
.export ScrollWorldLeft

.proc DrawPow

rts; ;Desativando pow, pq nao ficou legal

        lda Pow + PowStruct::Active_timer
        beq Finish
        dec Pow + PowStruct::Active_timer

        lda Pow + PowStruct::X_Pos
        sta OAMMIRROR, x
        inx
        
        lda Pow + PowStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        
        lda Pow + PowStruct::Tile_ID
        sta OAMMIRROR, x
        inx

        lda #$00                         
        sta OAMMIRROR, x
        inx

Finish:
        rts    
    
.endproc

.proc drawVaderXYDebug
        
        lda VaderCrab + MeleeCrabStruct::X_Pos
        sta OAMMIRROR, x
        inx
        
        lda VaderCrab + MeleeCrabStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        
        lda #$CE
        sta OAMMIRROR, x
        inx

        lda #$30                         
        sta OAMMIRROR, x
        INX
        RTS
        
.endproc

.proc drawDengueXYDebug
        
        lda DengueCrab + MeleeCrabStruct::X_Pos
        sta OAMMIRROR, x
        inx
        
        lda DengueCrab + MeleeCrabStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        
        lda #$CE
        sta OAMMIRROR, x
        inx

        lda #$30                         
        sta OAMMIRROR, x
        INX
        RTS
.endproc

.proc drawHeroCenterDebug
        
        lda DP_HERO_CENTER_X
        sta OAMMIRROR, x
        inx
        
        lda DP_HERO_CENTER_Y
        sta OAMMIRROR, x
        inx
        
        lda #$88
        sta OAMMIRROR, x
        inx

        lda #$30                         
        sta OAMMIRROR, x
        inx

Finish:
        rts    
    
.endproc


.proc DrawDengueHitboxDebug
        lda DengueCrab + MeleeCrabStruct::Hitbox_X1
        sta a:OAMMIRROR, X
        inx
        lda DengueCrab + MeleeCrabStruct::Hitbox_Y1
        sta a:OAMMIRROR, X
        inx
        lda #$88
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta a:OAMMIRROR, X
        inx
        lda DengueCrab + MeleeCrabStruct::Hitbox_X2
        sta a:OAMMIRROR, X
        inx
        lda DengueCrab + MeleeCrabStruct::Hitbox_Y2
        sta a:OAMMIRROR, X
        inx
        lda #$86
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta OAMMIRROR, X
        inx
        rts
.endproc

.proc DrawHitboxDebug
        LDA VaderCrab + MeleeCrabStruct::Hitbox_X1
        sta a:OAMMIRROR, X
        inx
        lda VaderCrab + MeleeCrabStruct::Hitbox_Y1
        sta a:OAMMIRROR, X
        inx
        lda #$88
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta a:OAMMIRROR, X
        inx
        lda VaderCrab + MeleeCrabStruct::Hitbox_X2
        sta a:OAMMIRROR, X
        inx
        lda VaderCrab + MeleeCrabStruct::Hitbox_Y2
        sta a:OAMMIRROR, X
        inx
        lda #$88
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta OAMMIRROR, X
        INX
        
        LDA DengueCrab + MeleeCrabStruct::Hitbox_X1
        sta a:OAMMIRROR, X
        inx
        lda DengueCrab + MeleeCrabStruct::Hitbox_Y1
        sta a:OAMMIRROR, X
        inx
        lda #$88
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta a:OAMMIRROR, X
        inx
        lda DengueCrab + MeleeCrabStruct::Hitbox_X2
        sta a:OAMMIRROR, X
        inx
        lda DengueCrab + MeleeCrabStruct::Hitbox_Y2
        sta a:OAMMIRROR, X
        inx
        lda #$88
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta OAMMIRROR, X
        INX
        
        LDA RapaNuiCrab + MeleeCrabStruct::Hitbox_X1
        sta a:OAMMIRROR, X
        inx
        lda RapaNuiCrab + MeleeCrabStruct::Hitbox_Y1
        sta a:OAMMIRROR, X
        inx
        lda #$88
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta a:OAMMIRROR, X
        inx
        lda RapaNuiCrab + MeleeCrabStruct::Hitbox_X2
        sta a:OAMMIRROR, X
        inx
        lda RapaNuiCrab + MeleeCrabStruct::Hitbox_Y2
        sta a:OAMMIRROR, X
        inx
        lda #$88
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta OAMMIRROR, X
        inx
        rts
.endproc


.proc DrawtargetEnemyXYDebug
        LDA VaderCrab + MeleeCrabStruct::Target_Attack_X
        sta a:OAMMIRROR, X
        inx
        lda VaderCrab + MeleeCrabStruct::Target_Attack_Y
        sta a:OAMMIRROR, X
        inx
        lda #$86
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta a:OAMMIRROR, X
        INX
        
        LDA RapaNuiCrab + MeleeCrabStruct::Target_Attack_X
        sta a:OAMMIRROR, X
        inx
        lda RapaNuiCrab + MeleeCrabStruct::Target_Attack_Y
        sta a:OAMMIRROR, X
        inx
        lda #$86
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta a:OAMMIRROR, X
        INX
        
        LDA DengueCrab + MeleeCrabStruct::Target_Attack_X
        sta a:OAMMIRROR, X
        inx
        lda DengueCrab + MeleeCrabStruct::Target_Attack_Y
        sta a:OAMMIRROR, X
        inx
        lda #$86
        sta a:OAMMIRROR, X
        inx
        lda #$30
        sta a:OAMMIRROR, X
        inx
        rts
.endproc


.proc DrawDengueAttackSectorDebug
        
        LDA DengueCrab + MeleeCrabStruct::X_Pos
        sta a:OAMMIRROR, X
        inx
        lda DengueCrab + MeleeCrabStruct::Y_Pos
        sta a:OAMMIRROR, X
        inx
        lda #$88
        sta a:OAMMIRROR, X
        INX
        
        LDA DengueCrab + MeleeCrabStruct::Attack_Sector
        CMP #0                          
        beq @SetorSupDireito
        cmp #1                          
        beq @SetorSupEsquerdo
        cmp #2                          
        beq @SetorInfDireito

@SetorInfEsquerdo:
        lda #$30

@SetorSupDireito:
        lda #$70

@SetorSupEsquerdo:
        lda #$B0

@SetorInfDireito:
        lda #$F0
        
@Continue:
        sta a:OAMMIRROR, X
        inx
        RTS
.endproc


.proc drawHeroHitBoxDebug
        LDA BigHero + BigHeroStruct::Hurtbox_X1
        sta OAMMIRROR, x
        inx
        
        lda BigHero + BigHeroStruct::Hurtbox_Y1
        sta OAMMIRROR, x
        inx
        
        lda #$8A
        sta OAMMIRROR, x
        inx

        lda #$30                         
        sta OAMMIRROR, x
        inx

        lda BigHero + BigHeroStruct::Hurtbox_X2
        sta OAMMIRROR, x
        inx
        
        lda BigHero + BigHeroStruct::Hurtbox_Y2
        sta OAMMIRROR, x
        inx
        
        lda #$8A
        sta OAMMIRROR, x
        inx

        lda #$30                         
        sta OAMMIRROR, x
        INX
        rts
.endproc




;-------------------------------------------------------------------------------
;   EXECUcÃO AUTOMÁTICA EM V-BLANK (Hardware real manipula OAM aqui)
;-------------------------------------------------------------------------------
.proc   NMIHandler
        php
        sep #$20
        .a8

        lda RDNMI               ; Lê e limpa o flag indicador de interrupção de NMI

        ; 1. Envia OAMMIRROR via DMA
        tsx
        pea OAMMIRROR
        jsr UpdateOAMRAM
        txs

        ; 2. Atualiza o Scroll do BG1 (Chão - Velocidade 1x)
        sep #$20
        .a8
        lda Camera_X            ; Byte baixo
        sta BG1HOFS
        lda Camera_X + 1        ; Byte alto
        sta BG1HOFS

        ; 3. Atualiza o Scroll do BG2 (Prédios - Velocidade 0.5x / Parallax)
        rep #$20                ; A em 16-bit para dividir Camera_X por 2
        .a16
        lda Camera_X
        lsr                     ; Divide por 2
        sep #$20                ; Volta A para 8-bit
        .a8
        sta BG2HOFS             ; Byte baixo
        xba                     ; Passa byte alto para a parte baixa de A
        sta BG2HOFS             ; Byte alto

        plp
        rti
.endproc


;-------------------------------------------------------------------------------
;   VETOR DE PROSPECcÃO DE HARDWARE
;-------------------------------------------------------------------------------
.proc   IRQHandler
        rti
.endproc

;-------------------------------------------------------------------------------
;   ALOCAcÃO DE VARIÁVEIS NA WRAM 
;-------------------------------------------------------------------------------
.segment "BSS"
.export BigHero 
.export PennyCrab
.export VaderCrab
.export DengueCrab
.export RapaNuiCrab
.export WeaponA
.export WeaponB
.export WeaponC
.export WeaponD
.export WeaponE
.export Bullet
.export Pow
.export Bullet2


BigHero:         .tag BigHeroStruct
PennyCrab:       .tag MeleeCrabStruct
VaderCrab:       .tag MeleeCrabStruct
DengueCrab:       .tag MeleeCrabStruct
RapaNuiCrab:       .tag MeleeCrabStruct


WeaponA:         .tag WeaponStruct
WeaponB:         .tag WeaponStruct
WeaponC:         .tag WeaponStruct
WeaponD:         .tag WeaponStruct
WeaponE:         .tag WeaponStruct
Bullet:          .tag BulletStruct
Bullet2:          .tag BulletStruct

Pow:             .tag PowStruct

FrameCounter:    .res 1    ; Contador global de frames (0 a 255)
.export FrameCounter

Camera_X: .res 2        ; Posição horizontal da câmera (16-bit: 0 a 65535)
.export Camera_X



