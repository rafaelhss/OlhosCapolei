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

;----- Imports -----------------------------------------------------------------
.import     VaderCrab
.import     BigHero
.import     WeaponA
.import     rand                ; Invocando o seu LFSR puro de src/common/Util.s

;----- Includes ----------------------------------------------------------------
.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Registers.inc"

;----- Constants ---------------------------------------------------------------
;MAX_PROJECTILES     = 4         
;WEAPON_ROW_SIZE     = 6        
 ;
WEAPON_STATE_EQUIPPED = 0  ; Coletada, colada na mão do herói
WEAPON_STATE_GROUND   = 1  ; Esperando no chão para ser coletada
WEAPON_STATE_THROWN   = 2  ; Voando pelo ar em parábola

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

;-------------------------------------------------------------------------------
;   ClearProjectilePool (Garante RAM limpa e força Y=$E0 contra Sprites Fantasmas)
;-------------------------------------------------------------------------------
.proc ClearProjectilePool
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
;   Responsabilidade: Modificar o estado físico da arma no cenário.
;-------------------------------------------------------------------------------
.proc ProcessWeaponAttack
        ; Só inicia o arremesso se a WeaponA estiver de fato na mão (WEAPON_STATE_EQUIPPED)
        lda WeaponA + WeaponStruct::Active
        cmp #WEAPON_STATE_EQUIPPED
        bne @Exit                       

        ; 1. Transiciona o estado físico da pedra para voando (THROWN)
        lda #WEAPON_STATE_THROWN
        sta WeaponA + WeaponStruct::Active

        ; === CAPTURA DO CHÃO TÉCNICO DO HERÓI ===
        ; O pé do BigHero (sombra) fica na base dele (Y_Pos + altura do sprite).
        ; Como seu sprite tem 64px de altura, o pé real está em Y_Pos + 64.
        ; Se o seu offset gráfico de arraste já joga a pedra para a mão na linha do pé,
        ; use diretamente o Y atual da arma ou calcule o pé do herói:
        lda BigHero + BigHeroStruct::Y_Pos
        clc
        adc #48                         ; 64 do hero - 16 de mim Alinha a linha de repouso com o pé/sombra do herói
        sta WeaponA + WeaponStruct::Target_Y

        ; 2. Define a trajetória horizontal baseada no Facing atual do herói
        lda BigHero + BigHeroStruct::Facing
        bne @ArremessoEsquerda

@ArremessoDireita:
        lda #$06                        ; Avança para a direita
        sta WeaponA + WeaponStruct::Speed_X
        bra @AplicarImpulsoVertical

@ArremessoEsquerda:
        lda #<-6                        ; Recua para a esquerda ($FA)
        sta WeaponA + WeaponStruct::Speed_X

@AplicarImpulsoVertical:
        ; 3. Dá o impulso vertical inicial para CIMA ($FA) criando a parábola
        lda #<-6                        
        sta WeaponA + WeaponStruct::Speed_Y

@Exit:
        rts
.endproc

;-------------------------------------------------------------------------------
;   UpdateProjectiles
;   Responsabilidade: Processar a física da parábola e gravidade da pedra no ar
;-------------------------------------------------------------------------------
.proc UpdateProjectiles
        ; Só processa se a WeaponA estiver no estado de voo (WEAPON_STATE_THROWN)
        lda WeaponA + WeaponStruct::Active
        cmp #WEAPON_STATE_THROWN
        bne @Exit

        ; 1. Movimentação Horizontal (Eixo X)
        lda WeaponA + WeaponStruct::X_Pos
        clc
        adc WeaponA + WeaponStruct::Speed_X
        sta WeaponA + WeaponStruct::X_Pos

        ; Proteção de bordas laterais da tela
        cmp #SCREEN_RIGHT - 8
        bcs @TocouOChao
        cmp #SCREEN_LEFT + 4
        bcc @TocouOChao

        ; 2. Movimentação Vertical (Eixo Y) + Gravidade
        lda WeaponA + WeaponStruct::Y_Pos
        clc
        adc WeaponA + WeaponStruct::Speed_Y
        sta WeaponA + WeaponStruct::Y_Pos

        ; Gravidade puxa +1 pixel para baixo a cada frame
        lda WeaponA + WeaponStruct::Speed_Y
        clc
        adc #$01
        sta WeaponA + WeaponStruct::Speed_Y

        ; 3. Verificação Dinâmica de Queda (Compara com a Target_Y salva no início)
        ; Se a velocidade vertical for para baixo (positiva) e Y passou ou igualou o chão:
        lda WeaponA + WeaponStruct::Speed_Y
        bmi @Exit                       ; Se Speed_Y for negativa, a pedra ainda está subindo. Pula checagem.

        lda WeaponA + WeaponStruct::Y_Pos
        cmp WeaponA + WeaponStruct::Target_Y                       
        bcc @Exit                       ; Se Y < Target_Y, ainda está caindo no ar. Continua.

@TocouOChao:
        ; Trava a pedra exatamente na linha do pé calculada no início do tiro
        lda WeaponA + WeaponStruct::Target_Y
        sta WeaponA + WeaponStruct::Y_Pos

        ; Reseta o estado físico para "No Chão" (WEAPON_STATE_GROUND)
        lda #WEAPON_STATE_GROUND
        sta WeaponA + WeaponStruct::Active

        lda #$6D
        sta WeaponA + WeaponStruct::Tile_ID

@Exit:
        rts
.endproc


;-------------------------------------------------------------------------------
;   DrawProjectiles (Versão Pura - Sem nenhuma correção ou blindagem)
;-------------------------------------------------------------------------------
.proc DrawProjectiles
        rts                             ; Retorna deixando o X onde parou para a Main.s
.endproc


; =============================================================================
; SUBSISTEMA DE COLETA DE ARMAS NO CHÃO (PICKUP SYSTEM)
; =============================================================================
.proc SpawnWeaponOnGround
        lda WeaponA + WeaponStruct::X_Pos
        sta OAMMIRROR, x
        inx
        lda WeaponA + WeaponStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        lda WeaponA + WeaponStruct::Tile_ID ;tile
        sta OAMMIRROR, x
        inx
        lda $01 ; atributos
        sta OAMMIRROR, x
        inx

        rts      

.endproc





.proc DrawDroppedWeapon
        lda WeaponA + WeaponStruct::X_Pos
        sta OAMMIRROR, x
        inx
        lda WeaponA + WeaponStruct::Y_Pos
        sta OAMMIRROR, x
        inx
        lda WeaponA + WeaponStruct::Tile_ID ;tile
        sta OAMMIRROR, x
        inx
        lda $01 ; atributos
        sta OAMMIRROR, x
        inx

        rts  
rts
.endproc

