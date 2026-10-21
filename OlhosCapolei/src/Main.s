; -----------------------------------------------------------------------------
;   File: Main.s
;   Description: Displays a sprite movable with the dpad
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     ResetHandler        ; export the entry point of the demo
.export     NMIHandler
;-------------------------------------------------------------------------------

;----- Assembler Directives ----------------------------------------------------
.p816                           ; tell the assembler this is 65816 code
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
;   This is the entry point of the demo
;-------------------------------------------------------------------------------
.proc   ResetHandler
        sei                     ; disable interrupts
        clc                     ; clear the carry flag
        xce                     ; switch the 65816 to native (16-bit mode)
        rep #$10                ; set X and Y to 16-bit
        sep #$20                ; set A to 8-bit
        lda #$8f                ; force v-blanking
        sta INIDISP
        stz NMITIMEN            ; disable NMI
        ; set the stack pointer to $1fff
        ldx #$1fff              ; load X with $1fff
        txs                     ; copy X to stack pointer

        ; initialize SNES
        jsr ClearRegisters
        jsr ClearVRAM
        jsr ClearCGRAM
        jsr ClearOAMRAM

        jsr InitDemo            ; initialize the demo
        jmp GameLoop            ; enter main game loop
.endproc
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;   Executed during V-Blank
;-------------------------------------------------------------------------------
.proc   GameLoop
        wai                                 ; wait for NMI / V-Blank


        ; 1. INPUTS (Puxando dados do Joypad)
        ldx #JOYHELD1
        phx
        ldx #JOYTRIGGER1
        phx
        ldx #JOYRAW1
        phx
        jsr ReadJoypad1
        plx
        plx
        plx

        ; 2. MOVIMENTACAO BRUTA (Apenas altera posicoes na RAM)
        ldx #JOYHELD1
        phx
        ldx #JOYTRIGGER1
        phx
        ldx #JOYRAW1
        phx
        jsr MoveHero
        plx
        plx
        plx

        jsr MoveEnemy1

        ; 3. FILTRO DE COLISAO (Mantem todo mundo dentro da tela antes de desenhar)
        jsr ApplyEdgeCollisions
        jsr ApplyDamageToHero

        ; 4. RENDERIZACAO FINAL (Le a RAM tratada e joga na OAM)
        ldx #$00 
        jsr DrawHero
        jsr DrawEnemy1
        jsr DrawEnemy2

        jmp GameLoop
.endproc
;-------------------------------------------------------------------------------



.proc ApplyDamageToHero

        ; fazer depois de colocar mais um inimigo

        rts
.endproc



;-------------------------------------------------------------------------------
;   Rotina de Colisao com as Bordas da Tela (Constantes de Tela Limpas)
;-------------------------------------------------------------------------------
.proc ApplyEdgeCollisions
        ; === TRAVAS DO HEROI ===
        
CheckHeroLeft:
        ; Se X_Pos passou do limite seguro automatizado, houve underflow
        lda Hero + HeroStruct::X_Pos
        cmp #HERO_SCREEN_SAFE_LIMIT                    
        bcc CheckHeroRight          ; Se X for menor, nao eh underflow, pula pro proximo
        
        lda #SCREEN_LEFT            ; Se deu underflow, trava no zero
        sta Hero + HeroStruct::X_Pos
        bra CheckHeroTop            ; Evita o teste conflitante da direita

CheckHeroRight:
        ; Limite Direito: Tela (255) menos a largura fisica do heroi (16 pixels)
        lda Hero + HeroStruct::X_Pos
        cmp #(SCREEN_RIGHT - 16)
        bcc CheckHeroTop            
        
        lda #(SCREEN_RIGHT - 16)    
        sta Hero + HeroStruct::X_Pos

CheckHeroTop:
        ; Usa a mesma constante de tela para pegar o underflow do eixo Y
        lda Hero + HeroStruct::Y_Pos
        cmp #HERO_SCREEN_SAFE_LIMIT                    
        bcc CheckHeroBottom         
        
        lda #SCREEN_TOP             
        sta Hero + HeroStruct::Y_Pos
        bra CheckEnemyLeft          ; Evita o teste conflitante de baixo

CheckHeroBottom:
        ; Limite Inferior: Fundo do cenario (223) menos a altura fisica do heroi (32 pixels)
        lda Hero + HeroStruct::Y_Pos
        cmp #(SCREEN_BOTTOM - 32)
        bcc CheckEnemyLeft          
        
        lda #(SCREEN_BOTTOM - 32)    
        sta Hero + HeroStruct::Y_Pos


        ; === TRAVAS DO INIMIGO GRANDE ===
        
CheckEnemyLeft:
        ; Aplica o limite seguro de tela calculado para o inimigo
        lda InimigoGrande + EnemyStruct::X_Pos
        cmp #ENEMY_SCREEN_SAFE_LIMIT                    
        bcc CheckEnemyRight         
        
        lda #SCREEN_LEFT            
        sta InimigoGrande + EnemyStruct::X_Pos
        bra CheckEnemyTop

CheckEnemyRight:
        ; Limite Direito do Inimigo: Tela (255) menos a largura fisica dele (32 pixels)
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
        ; Limite Inferior do Inimigo: Fundo (223) menos a altura fisica dele (32 pixels)
        lda InimigoGrande + EnemyStruct::Y_Pos
        cmp #(SCREEN_BOTTOM - 32)
        bcc CollisionDone
        
        lda #(SCREEN_BOTTOM - 32)
        sta InimigoGrande + EnemyStruct::Y_Pos

CollisionDone:
        rts
.endproc
;-------------------------------------------------------------------------------


;-------------------------------------------------------------------------------
;   Will be called during V-Blank every frame
;-------------------------------------------------------------------------------
.proc   NMIHandler
        lda RDNMI               ; read NMI status, acknowledge NMI

        tsx                     ; save old stack pointer
        pea OAMMIRROR           ; push mirror address to stack
        jsr UpdateOAMRAM        ; update OAMRAM
        txs                     ; restore old stack pointer

        rti
.endproc
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;   Is not used in this program
;-------------------------------------------------------------------------------
.proc   IRQHandler
        ; code
        rti
.endproc
;-------------------------------------------------------------------------------


.segment "BSS"
.export Hero, InimigoGrande, InimigoGrande2

Hero:          .tag HeroStruct
InimigoGrande: .tag EnemyStruct

InimigoGrande2: .tag EnemyStruct


