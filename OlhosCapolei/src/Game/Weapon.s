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
.export     CheckWeaponPickup
.export     DrawDroppedWeapon
.export     Weapon_Data_Table 
.export     SpawnThrowable 
.export     ClearProjectilePool

;----- Imports -----------------------------------------------------------------
.import     VaderCrab
.import     BigHero
.import     rand                ; Invocando o seu LFSR puro de src/common/Util.s

;----- Includes ----------------------------------------------------------------
.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Registers.inc"

;----- Constants ---------------------------------------------------------------
MAX_PROJECTILES     = 4         
WEAPON_ROW_SIZE     = 6         
PICKUP_DISTANCE     = 32        ; Tolerância em pixels para conseguir pegar a arma

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
        phb                             ; Salva Data Bank atual
        lda #.bankbyte(Projectile_Pool)
        pha
        plb                             ; Configura Data Bank para o banco da WRAM

        ldx #$0000
@LoopLimpeza:
        lda #0
        sta Projectile_Pool + ProjectileEntity::Active, x
        sta Projectile_Pool + ProjectileEntity::X_Pos, x
        sta Projectile_Pool + ProjectileEntity::Tile_ID, x
        sta Projectile_Pool + ProjectileEntity::Attrs, x
        sta Projectile_Pool + ProjectileEntity::Speed_X, x
        sta Projectile_Pool + ProjectileEntity::Speed_Y, x
        
        ; Força Y=$E0 (Totalmente fora da tela visível do SNES)
        lda #$E0                
        sta Projectile_Pool + ProjectileEntity::Y_Pos, x
        
        txa
        clc
        adc #.sizeof(ProjectileEntity)  
        tax
        cpx #(.sizeof(ProjectileEntity) * 4) 
        bcc @LoopLimpeza

        plb                             ; Restaura Data Bank
        rts
.endproc

;-------------------------------------------------------------------------------
;   GetWeaponData (Versão Blindada contra Lixo de 16-bit nos Índices)
;-------------------------------------------------------------------------------
.proc GetWeaponData
        sta z:DP_TEMP_00        ; Salva o ID temporariamente na Direct Page
        
        rep #$20
        .a16
        lda z:DP_TEMP_00
        and #$00FF              ; Garante que a parte alta do acumulador seja ZERO absoluto
        
        asl a                   ; A = ID * 2
        sta z:DP_TEMP_02               
        asl a                   ; A = ID * 4
        clc
        adc z:DP_TEMP_02        ; A = ID * 6 (Matemática estável em 16-bit)
        tay                     ; Y recebe o offset perfeito de 16 bits
        
        sep #$20
        .a8
        rts
.endproc

;-------------------------------------------------------------------------------
;   ProcessWeaponAttack (Refatorado com Constantes de Escopo)
;-------------------------------------------------------------------------------
.proc ProcessWeaponAttack
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_UNARMED
        beq @Exit               
        
        jsr GetWeaponData       
        
        ; Verifica a categoria da arma (Offset +2 da Weapon_Data_Table)
        lda Weapon_Data_Table + 2, y
        cmp #WEAPON_TYPE_PROJECTILE
        beq @WeaponFire        

@WeaponMelee:
        lda Weapon_Data_Table + 4, y
        rts

@WeaponFire:
        ; DIFERENCIAÇÃO: Se a arma de projétil equipada for a Pedra de Arremesso
        lda BigHero + BigHeroStruct::Current_Weapon_ID
        cmp #WEAPON_ID_ROCK
        beq @ArremessarItem

@AtirarLinhaReta:
        lda Weapon_Data_Table + 4, y    ; Pega o Tile_ID da tabela (Pistola/Bazuca)
        sta z:DP_TEMP_00                       
        lda Weapon_Data_Table + 1, y    ; Pega os Atributos
        sta z:DP_TEMP_01                       
        jsr SpawnProjectile             
        rts

@ArremessarItem:
        lda Weapon_Data_Table + 4, y    ; Pega o Tile_ID dinâmico da tabela ($26)
        jsr SpawnThrowable              ; Chama o nosso motor arremessável genérico

        ; Remove a pedra da mão do herói para que ela seja consumida visualmente
        sep #$20
        .a8
        lda #WEAPON_ID_UNARMED          
        sta BigHero + BigHeroStruct::Current_Weapon_ID 

@Exit:
        rts
.endproc

;-------------------------------------------------------------------------------
;   SpawnThrowable (Versão Engenharia de Elite - Sem Uso de Pilha Perigosa)
;-------------------------------------------------------------------------------
.proc SpawnThrowable
        phb                             ; Preserva Data Bank
        lda #.bankbyte(Projectile_Pool)
        pha
        plb                             ; Alinha Banco para WRAM

        sta z:DP_WEAPON_TILE_TMP        ; Salva o Tile_ID com segurança na Direct Page

        ldx #$0000                      ; Reseta X para varrer o Pool
@LoopPool:
        lda Projectile_Pool + ProjectileEntity::Active, x
        beq @EncontrouSlot      
        
        txa
        clc
        adc #7                          ; Caminha 7 bytes rígidos
        tax                     
        
        cpx #28                         ; Limite de segurança física
        bcc @LoopPool
        plb                             ; Restaura banco antes de dar rts
        rts                             ; Pool cheio, ignora o disparo de forma segura

@EncontrouSlot:
        lda #1
        sta Projectile_Pool + ProjectileEntity::Active, x
        
        lda z:DP_WEAPON_TILE_TMP        
        sta Projectile_Pool + ProjectileEntity::Tile_ID, x
        
        stx z:DP_WEAPON_OAM_BACKUP      ; Protege o offset do Projétil contra chamadas à ROM

        lda BigHero + BigHeroStruct::Current_Weapon_ID
        jsr GetWeaponData       
        
        lda Weapon_Data_Table + 1, y    ; Lê os atributos da ROM (Paleta/Prioridade)
        sta z:DP_TEMP_02               

        ldx z:DP_WEAPON_OAM_BACKUP      ; Resgata o X do projétil intacto
        
        lda z:DP_TEMP_02               
        sta Projectile_Pool + ProjectileEntity::Attrs, x 
        
        ; Configura posição de spawn inicial (altura do peito do BigHero)
        lda BigHero + BigHeroStruct::X_Pos
        sta Projectile_Pool + ProjectileEntity::X_Pos, x
        
        lda BigHero + BigHeroStruct::Y_Pos
        sec
        sbc #16                 
        sta Projectile_Pool + ProjectileEntity::Y_Pos, x
        
        ; ---- APLICAÇÃO DO FACING DO HERÓI NA FÍSICA ----
        lda BigHero + BigHeroStruct::Facing
        bne @ArremessoEsquerda

@ArremessoDireita:
        lda #$03                        ; Velocidade horizontal estável para a direita
        sta Projectile_Pool + ProjectileEntity::Speed_X, x
        bra @ConfigurarGravidade

@ArremessoEsquerda:
        lda #<-3                        ; Velocidade horizontal para a esquerda (assinado)
        sta Projectile_Pool + ProjectileEntity::Speed_X, x
        
        lda Projectile_Pool + ProjectileEntity::Attrs, x
        eor #$40                        ; Injeta Flip Horizontal via hardware da PPU
        sta Projectile_Pool + ProjectileEntity::Attrs, x

@ConfigurarGravidade:
        lda #<-4                        ; Impulso parabólico inicial para CIMA ($FC)
        sta Projectile_Pool + ProjectileEntity::Speed_Y, x
        
        plb                             ; Restaura Data Bank
        rts                     
.endproc

;-------------------------------------------------------------------------------
;   SpawnProjectile (Mantido para tiros retilíneos da Pistola/Bazuca)
;-------------------------------------------------------------------------------
.proc SpawnProjectile
        phb
        lda #.bankbyte(Projectile_Pool)
        pha
        plb

        ldx #$0000              

@LoopPool:
        lda Projectile_Pool + ProjectileEntity::Active, x
        beq @EncontrouSlot      
        
        txa
        clc
        adc #7
        tax                     
        
        cpx #28
        bcc @LoopPool
        plb
        rts                     

@EncontrouSlot:
        lda #1
        sta Projectile_Pool + ProjectileEntity::Active, x
        
        lda z:DP_TEMP_00
        sta Projectile_Pool + ProjectileEntity::Tile_ID, x
        lda z:DP_TEMP_01
        sta Projectile_Pool + ProjectileEntity::Attrs, x
        
        lda BigHero + BigHeroStruct::X_Pos
        clc
        
adc #16
sta Projectile_Pool + ProjectileEntity::X_Pos, x
lda BigHero + BigHeroStruct::Y_Pos
clc
adc #24
sta Projectile_Pool + ProjectileEntity::Y_Pos, x
lda #$04
sta Projectile_Pool + ProjectileEntity::Speed_X, x
plb
rts
.endproc
;-------------------------------------------------------------------------------
;   UpdateProjectiles (Física Híbrida Corrigida com Limpador Automático de Chão)
;-------------------------------------------------------------------------------
.proc UpdateProjectiles
phb
lda #.bankbyte(Projectile_Pool)
pha
plb
ldx #$0000
@UpdateLoop:
lda Projectile_Pool + ProjectileEntity::Active, x
beq @NextSlot
; 1. Movimentação Horizontal (X)
lda Projectile_Pool + ProjectileEntity::X_Pos, x
clc
adc Projectile_Pool + ProjectileEntity::Speed_X, x
sta Projectile_Pool + ProjectileEntity::X_Pos, x
cmp #SCREEN_RIGHT - 8
bcs @DesativarProjetil
cmp #SCREEN_LEFT + 4
bcc @DesativarProjetil
; 2. Movimentação Vertical (Y) + Gravidade Parabólica
lda Projectile_Pool + ProjectileEntity::Y_Pos, x
clc
adc Projectile_Pool + ProjectileEntity::Speed_Y, x
sta Projectile_Pool + ProjectileEntity::Y_Pos, x
lda Projectile_Pool + ProjectileEntity::Speed_Y, x
clc
adc #$01                ; Gravidade +1 por frame puxando para baixo
sta Projectile_Pool + ProjectileEntity::Speed_Y, x
; 3. Validação do Chão Técnico Real (Trava em SCREEN_BOTTOM)
lda Projectile_Pool + ProjectileEntity::Y_Pos, x
cmp #$DF                ; Limite real da tela ($DF)
bcc @NextSlot           ; Se Y < $DF, a pedra continua voando
@DesativarProjetil:
lda #0
sta Projectile_Pool + ProjectileEntity::Active, x
lda #$E0
sta Projectile_Pool + ProjectileEntity::Y_Pos, x ; Expulsa da tela ao morrer
@NextSlot:
txa
clc
adc #.sizeof(ProjectileEntity)
tax
cpx #(.sizeof(ProjectileEntity) * 4)
bcc @UpdateLoop
plb
rts
.endproc
;-------------------------------------------------------------------------------
;   DrawProjectiles (Versão Síncrona - Com Correção de Indexação ca65)
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   DrawProjectiles (Versão Pura - Sem nenhuma correção ou blindagem)
;-------------------------------------------------------------------------------
.proc DrawProjectiles
        ldy #$0000                      ; Inicializa o índice do Pool de Projéteis em 0

@DrawLoop:
        ; Verifica se o projétil está ativo de forma direta
        lda Projectile_Pool + ProjectileEntity::Active, y
        beq @NextSlot                   ; Se for 0, ignora e pula para o próximo

        ; Descarrega os 4 bytes sequenciais direto na OAMMIRROR usando o X atual
        lda Projectile_Pool + ProjectileEntity::X_Pos, y
        sta OAMMIRROR, x
        inx
        
        lda Projectile_Pool + ProjectileEntity::Y_Pos, y
        sta OAMMIRROR, x
        inx
        
        lda Projectile_Pool + ProjectileEntity::Tile_ID, y
        sta OAMMIRROR, x
        inx
        
        lda Projectile_Pool + ProjectileEntity::Attrs, y
        sta OAMMIRROR, x
        inx                             ; Avança o ponteiro OAM para o próximo slot

@NextSlot:
        ; Avança para o próximo projétil no buffer de RAM (avanço rígido de 7 bytes)
        tya
        clc
        adc #7
        tay
        
        cpy #28                         ; Verifica se varreu os 4 slots (4 * 7 = 28)
        bcc @DrawLoop

        rts                             ; Retorna deixando o X onde parou para a Main.s
.endproc

; =============================================================================
; SUBSISTEMA DE COLETA DE ARMAS NO CHÃO (PICKUP SYSTEM)
; =============================================================================
.proc SpawnWeaponOnGround
jsr rand
and #$07
beq SpawnWeaponOnGround
cmp #7
beq SpawnWeaponOnGround
sta Ground_Weapon + DroppedWeaponEntity::Weapon_ID
jsr rand
sta Ground_Weapon + DroppedWeaponEntity::X_Pos
lda Ground_Weapon + DroppedWeaponEntity::X_Pos
cmp #32
bcc @FixXLow
cmp #220
bcs @FixXHigh
bra @SpawnY
@FixXLow:
lda #40
sta Ground_Weapon + DroppedWeaponEntity::X_Pos
bra @SpawnY
@FixXHigh:
lda #200
sta Ground_Weapon + DroppedWeaponEntity::X_Pos
@SpawnY:
jsr rand
and #$7F
clc
adc #100
sta Ground_Weapon + DroppedWeaponEntity::Y_Pos
lda Ground_Weapon + DroppedWeaponEntity::Y_Pos
cmp #180
bcc @DoneSpawn
lda #150
sta Ground_Weapon + DroppedWeaponEntity::Y_Pos
@DoneSpawn:
lda #1
sta Ground_Weapon + DroppedWeaponEntity::Active
rts
.endproc
.proc CheckWeaponPickup
lda Ground_Weapon + DroppedWeaponEntity::Active
bne @CalcularEixoX
rts
@CalcularEixoX:
lda BigHero + BigHeroStruct::X_Pos
clc
adc #8
sec
sbc Ground_Weapon + DroppedWeaponEntity::X_Pos
bcs @TesteX
eor #$FF
clc
adc #1
@TesteX:
cmp #PICKUP_DISTANCE
bcs @NoPickup
@CalcularEixoY:
lda BigHero + BigHeroStruct::Y_Pos
clc
adc #56
sec
sbc Ground_Weapon + DroppedWeaponEntity::Y_Pos
bcs @TesteY
eor #$FF
clc
adc #1
@TesteY:
cmp #PICKUP_DISTANCE
bcs @NoPickup
lda Ground_Weapon + DroppedWeaponEntity::Weapon_ID
sta BigHero + BigHeroStruct::Current_Weapon_ID
stz Ground_Weapon + DroppedWeaponEntity::Active
@NoPickup:
rts
.endproc
.proc DrawDroppedWeapon
lda Ground_Weapon + DroppedWeaponEntity::Active
bne @Desenhar
rts
@Desenhar:
stx z:DP_TEMP_00
lda Ground_Weapon + DroppedWeaponEntity::Weapon_ID
jsr GetWeaponData
ldx z:DP_TEMP_00
lda Ground_Weapon + DroppedWeaponEntity::X_Pos
sta OAMMIRROR, x
inx
lda Ground_Weapon + DroppedWeaponEntity::Y_Pos
sta OAMMIRROR, x
inx
lda Weapon_Data_Table, y
sta OAMMIRROR, x
inx
lda #%00100000
sta OAMMIRROR, x
inx
rts
.endproc

; =============================================================================
; SEÇÃO DE ALOCAÇÃO NA MEMÓRIA RAM (BSS) - PROTEÇÃO CONTRA SOBREPOSIÇÃO
; =============================================================================
.segment "BSS"
.export Ground_Weapon
.export Projectile_Pool

; Aloca exatamente os bytes necessários baseados na Struct (4 slots * 7 bytes = 28)
Projectile_Pool:  .tag ProjectileEntity, 4
; Força um alinhamento rígido para que nenhuma variável morda a outra
.align 2
Ground_Weapon:    .tag DroppedWeaponEntity