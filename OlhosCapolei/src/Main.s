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
.proc   GameLoop
        wai                     ; Dorme eficientemente até o próximo V-Blank / NMI

        ; 1. INPUT PIPELINE (Direto via Registradores de Hardware - Sem sujeira na Pilha)
        jsr ReadJoypad1

        ; 2. SESSÃO DE FÍSICA E MOVIMENTAÇÃO (Leitura direta dos buffers de RAM)
        jsr MoveHero
        jsr MoveEnemy1

        ; 3. FILTRO DE COLISÕES & REGRAS DE GAMEPLAY
        jsr ApplyEdgeCollisions
        jsr ApplyDamageToHero

        ; 4. SISTEMA DE RENDERIZAÇÃO FINAL (Injeção na OAMMIRROR)
        ldx #$00                ; X inicia em 0 como offset do primeiro Sprite na OAM
        jsr DrawHero            ; Desenha o Heroi e devolve o X avançado
        jsr DrawEnemy1          ; Desenha o Inimigo 1 a partir do ponto que o Heroi parou
        jsr DrawEnemy2          ; Desenha o Inimigo 2 dinamicamente

        jmp GameLoop
.endproc
;-------------------------------------------------------------------------------

.proc ApplyDamageToHero
        ; Implementar lógica de colisão por bounding-box entre Hero e Enemy posteriormente
        rts
.endproc

;-------------------------------------------------------------------------------
;   ROTINA CENTRALIZADA DE COLISÃO COM AS BORDAS (Aritmética de Underflow)
;-------------------------------------------------------------------------------
.proc ApplyEdgeCollisions
        ; === TRAVAS DO HEROI ===
CheckHeroLeft:
        lda Hero + HeroStruct::X_Pos
        cmp #HERO_SCREEN_SAFE_LIMIT                    
        bcc CheckHeroRight          
        
        lda #SCREEN_LEFT            
        sta Hero + HeroStruct::X_Pos
        bra CheckHeroTop            

CheckHeroRight:
        lda Hero + HeroStruct::X_Pos
        cmp #(SCREEN_RIGHT - 16)
        bcc CheckHeroTop            
        
        lda #(SCREEN_RIGHT - 16)    
        sta Hero + HeroStruct::X_Pos

CheckHeroTop:
        lda Hero + HeroStruct::Y_Pos
        cmp #HERO_SCREEN_SAFE_LIMIT                    
        bcc CheckHeroBottom         
        
        lda #SCREEN_TOP             
        sta Hero + HeroStruct::Y_Pos
        bra CheckEnemyLeft          

CheckHeroBottom:
        lda Hero + HeroStruct::Y_Pos
        cmp #(SCREEN_BOTTOM - 32)
        bcc CheckEnemyLeft          
        
        lda #(SCREEN_BOTTOM - 32)    
        sta Hero + HeroStruct::Y_Pos

        ; === TRAVAS DO INIMIGO GRANDE ===
CheckEnemyLeft:
        lda InimigoGrande + EnemyStruct::X_Pos
        cmp #ENEMY_SCREEN_SAFE_LIMIT                    
        bcc CheckEnemyRight         
        
        lda #SCREEN_LEFT            
        sta InimigoGrande + EnemyStruct::X_Pos
        bra CheckEnemyTop

CheckEnemyRight:
        lda InimigoGrande + EnemyStruct::X_Pos
        cmp #(SCREEN_RIGHT - 32)
        bcc CheckEnemyTop
        
        lda #(SCREEN_RIGHT - 32)    
        sta InimigoGrande + EnemyStruct::X_Pos

CheckEnemyTop:
        lda InimigoGrande + EnemyStruct::Y_Pos
        cmp #ENEMY_SCREEN_SAFE_LIMIT                    
        bcc CheckEnemyBottom        
        
        lda #SCREEN_TOP             
        sta InimigoGrande + EnemyStruct::Y_Pos
        bra CollisionDone

CheckEnemyBottom:
        lda InimigoGrande + EnemyStruct::Y_Pos
        cmp #(SCREEN_BOTTOM - 32)
        bcc CollisionDone
        
        lda #(SCREEN_BOTTOM - 32)
        sta InimigoGrande + EnemyStruct::Y_Pos

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

Hero:          .tag HeroStruct
InimigoGrande: .tag EnemyStruct
InimigoGrande2: .tag EnemyStruct
