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
.include "Weapon2.inc"
.include "Bullet.inc"

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
        jsr ReadJoypad1

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

        ; --- MOVIMENTAcÃO DO VADERCRAB ---
        pea .loword(VaderCrab)
        jsr MoveMeleeCrab
        ply                             ; Limpa 2 bytes da pilha (.i16 ativo)

        ; --- MOVIMENTAcÃO DO DengueCRAB ---
        pea .loword(DengueCrab)
        jsr MoveMeleeCrab
        ply                             ; Limpa 2 bytes da pilha
       
        ; --- MOVIMENTAcÃO DO RapaNUiCRAB ---
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

        
        JSR drawHeroCenterDebug
        ;JSR DrawDengueHitboxDebug
        jsr DrawHitboxDebug
        ;JSR DrawtargetEnemyXYDebug
        ;jsr DrawDengueAttackSectorDebug
        ;JSR DrawPow ; tem que estar em cima de td
        
        
   
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
        lda #BULLET_STATE_INACTIVE
        sta Bullet + BulletStruct::Active

        ldy z:DP_ENEMY_STRUCT_PTR       
        lda #30
        sta MeleeCrabStruct::HurtTimer, y


        ldy z:DP_ENEMY_STRUCT_PTR 
        jsr createEnemyPow
        


        lda Bullet + BulletStruct::Speed_X
        bmi @BulletIndoParaEsquerda

@BulletIndoParaDireita:
        lda MeleeCrabStruct::X_Pos, y
        clc
        adc #VADER_KNOCKBACK
        sta MeleeCrabStruct::X_Pos, y
        bra @Finish

@BulletIndoParaEsquerda:
        lda MeleeCrabStruct::X_Pos, y
        sec
        sbc #VADER_KNOCKBACK
        sta MeleeCrabStruct::X_Pos, y

@NoCollision:
@Finish:
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
        lda #BULLET_STATE_INACTIVE
        sta Bullet2 + BulletStruct::Active

        ldy z:DP_ENEMY_STRUCT_PTR       
        lda #30
        sta MeleeCrabStruct::HurtTimer, y

        ldy z:DP_ENEMY_STRUCT_PTR 
        jsr createEnemyPow
        
        ldy z:DP_ENEMY_STRUCT_PTR
        lda Bullet2 + BulletStruct::Speed_X
        bmi @BulletIndoParaEsquerda

@BulletIndoParaDireita:
        lda MeleeCrabStruct::X_Pos, y
        clc
        adc #VADER_KNOCKBACK
        sta MeleeCrabStruct::X_Pos, y
        bra @Finish

@BulletIndoParaEsquerda:
        lda MeleeCrabStruct::X_Pos, y
        sec
        sbc #VADER_KNOCKBACK
        sta MeleeCrabStruct::X_Pos, y

@NoCollision:
@Finish:
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
        lda MeleeCrabStruct::HurtTimer, y
        beq @StartAABB
        ldy z:DP_WEAPON_POOL_PTR        
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
        lda #30
        sta a:MeleeCrabStruct::HurtTimer, x

        ldy z:DP_ENEMY_STRUCT_PTR 
        jsr createEnemyPow

        ; Restaura os contextos limpos de índice após o retorno do POW
        ldy z:DP_WEAPON_POOL_PTR        
        ldx z:DP_ENEMY_STRUCT_PTR       

        ; Salva a direção horizontal da arma em um rascunho seguro
        lda a:WeaponStruct::Speed_X, y
        sta z:DP_TEMP_00                
        bmi @PedraIndoParaEsquerda

@PedraIndoParaDireita:
        lda a:MeleeCrabStruct::X_Pos, x
        clc
        adc #VADER_KNOCKBACK
        sta a:MeleeCrabStruct::X_Pos, x

        cmp #(SCREEN_RIGHT - 48)
        bcc @ForcaRicochete
        lda #(SCREEN_RIGHT - 48)
        sta a:MeleeCrabStruct::X_Pos, x
        bra @ForcaRicochete

@PedraIndoParaEsquerda:
        lda a:MeleeCrabStruct::X_Pos, x
        sec
        sbc #VADER_KNOCKBACK
        sta a:MeleeCrabStruct::X_Pos, x

        cmp #SCREEN_LEFT
        bcs @ForcaRicochete
        lda #SCREEN_LEFT
        sta a:MeleeCrabStruct::X_Pos, x

@ForcaRicochete:
        ; --- INVERSÃO MATEMÁTICA OBRIGATÓRIA DO VETOR ---
        lda z:DP_TEMP_00                ; Recupera a velocidade original do rascunho
        eor #$FF
        clc
        adc #1
        sta a:WeaponStruct::Speed_X, y  ; Inverte o sinal (complemento de dois)

        ; Injeta o impulso vertical de quique para cima (-4)
        lda #$FC                
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
        lda MeleeCrabStruct::HurtTimer, y
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

        ; Dispara o POW na tela
        ldy z:DP_ENEMY_STRUCT_PTR 
        jsr createEnemyPow

        ; --- RECUPERAÇÃO DE CONTEXTO CRÍTICA ---
        ; Como jsr createEnemyPow alterou registradores, re-sincronizamos X e Y!
        ldy z:DP_WEAPON_POOL_PTR        ; Y volta a apontar para a Arma
        ldx z:DP_ENEMY_STRUCT_PTR       ; X volta a apontar para o Inimigo

        ; Aplica o hitstun de 10 frames no caranguejo indexado em X
        lda #10
        sta a:MeleeCrabStruct::HurtTimer, x

        ; Desativa a hitbox da arma para evitar múltiplos hits no mesmo frame
        lda #$00
        sta a:WeaponStruct::Hitbox_Active, y

        VADER_MELEE_KNOCKBACK = 16

        ; --- MATEMÁTICA DE EMPURRÃO INDEXADA EM X ---
        lda BigHero + BigHeroStruct::Facing
        bne @PushVaderLeft

@PushVaderRight:
        lda a:MeleeCrabStruct::X_Pos, x
        clc
        adc #VADER_MELEE_KNOCKBACK
        sta a:MeleeCrabStruct::X_Pos, x
        
        cmp #(SCREEN_RIGHT - 48)
        bcc MeleeExit
        lda #(SCREEN_RIGHT - 48)
        sta a:MeleeCrabStruct::X_Pos, x
        bra MeleeExit

@PushVaderLeft:
        lda a:MeleeCrabStruct::X_Pos, x
        sec
        sbc #VADER_MELEE_KNOCKBACK
        sta a:MeleeCrabStruct::X_Pos, x
        
        cmp #SCREEN_LEFT
        bcs MeleeExit
        lda #SCREEN_LEFT
        sta a:MeleeCrabStruct::X_Pos, x
        bra MeleeExit

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
        
        KNOCKBACK_FORCE = 32


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
        sta Pow + PowStruct::Y_Pos
.endproc


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



.proc drawHeroCenterDebug
        
        lda DP_HERO_CENTER_X
        sta OAMMIRROR, x
        inx
        
        lda DP_HERO_CENTER_Y
        sta OAMMIRROR, x
        inx
        
        lda #$86
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
        lda #$86
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
        lda #$86
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
        lda #$86
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
        lda #$86
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
        INX
        
        LDA RapaNuiCrab + MeleeCrabStruct::Hitbox_X1
        sta a:OAMMIRROR, X
        inx
        lda RapaNuiCrab + MeleeCrabStruct::Hitbox_Y1
        sta a:OAMMIRROR, X
        inx
        lda #$86
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
        lda #$86
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


;-------------------------------------------------------------------------------
;   EXECUcÃO AUTOMÁTICA EM V-BLANK (Hardware real manipula OAM aqui)
;-------------------------------------------------------------------------------
.proc   NMIHandler
        lda RDNMI               ; Lê e limpa o flag indicador de interrupcão de NMI
.import Hero, InimigoGrande, InimigoGrande2

       
        tsx                     ; Preserva o ponteiro de pilha atual
        pea OAMMIRROR           ; Injeta o endereco do espelho da RAM
        jsr UpdateOAMRAM        ; Envia os dados para a OAM real via DMA
        txs                     ; Restaura a pilha instantaneamente

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
PennyCrab:       .tag PennyCrabStruct
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
