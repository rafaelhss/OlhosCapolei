; -----------------------------------------------------------------------------
;   File: Weapon.s
;   Description: Centralized Weapon, Projectile, and Ground Pickup Subsystem
; -----------------------------------------------------------------------------

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
;   GetWeaponData
;-------------------------------------------------------------------------------
.segment "CODE"

;-------------------------------------------------------------------------------
;   ClearProjectilePool (Garante RAM limpa no Boot contra sprites fantasmas)
;-------------------------------------------------------------------------------
.proc ClearProjectilePool
        ldx #$0000
@LoopLimpeza:
        stz Projectile_Pool + ProjectileEntity::Active, x
        stz Projectile_Pool + ProjectileEntity::X_Pos, x
        stz Projectile_Pool + ProjectileEntity::Y_Pos, x
        stz Projectile_Pool + ProjectileEntity::Tile_ID, x
        stz Projectile_Pool + ProjectileEntity::Attrs, x
        stz Projectile_Pool + ProjectileEntity::Speed_X, x
        stz Projectile_Pool + ProjectileEntity::Speed_Y, x
        
        txa
        clc
        adc #.sizeof(ProjectileEntity)
        tax
        cpx #(.sizeof(ProjectileEntity) * MAX_PROJECTILES)
        bcc @LoopLimpeza
        rts
.endproc

;-------------------------------------------------------------------------------
;   GetWeaponData (Versão Blindada contra Lixo de 16-bit nos Índices)
;   Entrada: Acumulador A = ID da Arma (8-bit)
;   Saída:   Registrador Y = Offset exato limpo em 16-bit
;-------------------------------------------------------------------------------
.proc GetWeaponData
        sta z:$00               ; Salva o ID de 8 bits temporariamente na DP
        
        ; Transiciona temporariamente para modo 16 bits no acumulador para limpar o lixo
        rep #$20
        .a16
        and #$00FF              ; Garante que a parte alta do acumulador seja ZERO absoluto
        
        ; Resgata o ID limpo e multiplica por 6: (ID * 4) + (ID * 2)
        lda z:$00
        and #$00FF              ; Isola estritamente o byte baixo
        asl a                   ; A = ID * 2
        sta z:$02               
        asl a                   ; A = ID * 4
        clc
        adc z:$02               ; A = ID * 6 (Matemática pura em 16 bits sem estouro)
        tay                     ; Y recebe o offset perfeito de 16 bits com a parte alta zerada!
        
        ; Restaura o Acumulador para o modo padrão de 8 bits do jogo
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
        
        ; (Se futuramente adicionar o Ovo, basta colocar a constante WEAPON_ID_EGG aqui)

@AtirarLinhaReta:
        lda Weapon_Data_Table + 4, y    ; Pega o Tile_ID da tabela (Pistola/Bazuca)
        sta z:$00                       
        lda Weapon_Data_Table + 1, y    ; Pega os Atributos
        sta z:$01                       
        jsr SpawnProjectile             
        rts

@ArremessarItem:
        lda Weapon_Data_Table + 4, y    ; Pega o Tile_ID dinâmico da tabela ($26)
        jsr SpawnThrowable              ; Chama o nosso motor parabólico genérico

        ; ◄ A SOLUÇÃO: Remove a pedra da mão do herói para que ela seja consumida!
        sep #$20                        ; Garante acumulador em 8-bit
        .a8
        lda #WEAPON_ID_UNARMED          ; Carrega 0 (Desarmado)
        sta BigHero + BigHeroStruct::Current_Weapon_ID ; Atualiza o inventário do herói

@Exit:
        rts
.endproc

;------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   SpawnThrowable (Versão Engenharia de Elite - Segura e Sem Uso de Pilha)
;   Entrada: Acumulador A = Tile_ID do arremessável
;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------
;   SpawnThrowable (Totalmente Higienizado via Constantes Centrais)
;-------------------------------------------------------------------------------
.proc SpawnThrowable
        sta z:DP_WEAPON_TILE_TMP        ; ◄ Salva no canal seguro de armas

        ldx #$0000              
@LoopPool:
        lda Projectile_Pool + ProjectileEntity::Active, x
        beq @EncontrouSlot      
        
        txa
        clc
        adc #.sizeof(ProjectileEntity)
        tax                     
        
        cpx #(.sizeof(ProjectileEntity) * MAX_PROJECTILES)
        bcc @LoopPool
        rts                     

@EncontrouSlot:
        lda #1
        sta Projectile_Pool + ProjectileEntity::Active, x
        
        lda z:DP_WEAPON_TILE_TMP        ; ◄ Resgata do canal de armas
        sta Projectile_Pool + ProjectileEntity::Tile_ID, x
        
        stx z:DP_WEAPON_OAM_BACKUP      ; ◄ Guarda o X OAM no slot de armas

        lda BigHero + BigHeroStruct::Current_Weapon_ID
        jsr GetWeaponData       
        
        lda Weapon_Data_Table + 1, y 
        sta z:DP_TEMP_02                ; Usa rascunho temporário legítimo

        ldx z:DP_WEAPON_OAM_BACKUP      ; ◄ Recupera do slot seguro de armas
        
        lda z:DP_TEMP_02               
        sta Projectile_Pool + ProjectileEntity::Attrs, x 
        
        lda BigHero + BigHeroStruct::X_Pos
        sta Projectile_Pool + ProjectileEntity::X_Pos, x
        
        lda BigHero + BigHeroStruct::Y_Pos
        sec
        sbc #16                 
        sta Projectile_Pool + ProjectileEntity::Y_Pos, x
        
        lda BigHero + BigHeroStruct::Facing
        bne @ArremessoEsquerda

@ArremessoDireita:
        lda #$03                
        sta Projectile_Pool + ProjectileEntity::Speed_X, x
        bra @ConfigurarGravidade

@ArremessoEsquerda:
        lda #<-3                
        sta Projectile_Pool + ProjectileEntity::Speed_X, x
        
        lda Projectile_Pool + ProjectileEntity::Attrs, x
        eor #$40
        sta Projectile_Pool + ProjectileEntity::Attrs, x

@ConfigurarGravidade:
        lda #<-4                
        sta Projectile_Pool + ProjectileEntity::Speed_Y, x
        rts                     
.endproc

;-------------------------------------------------------------------------------
;   DrawProjectiles (Totalmente Higienizado via Constantes Centrais)
;-------------------------------------------------------------------------------
;   DrawProjectiles (Versão Ultra-Blindada contra Desalinhamento da OAM)
;   Entrada: Registrador X = Offset atual vindo da Main.s
;   Saída:   Registrador X = Offset OAM perfeitamente atualizado para os outros draws
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
.proc DrawProjectiles
        stx z:DP_WEAPON_OAM_BACKUP      ; ◄ Preserva o X que veio da Main no canal de armas
        stz z:DP_WEAPON_POOL_PTR        ; ◄ Reseta o ponteiro do loop no canal de armas

@DrawLoop:
        ldy z:DP_WEAPON_POOL_PTR        ; ◄ Indexa a leitura da RAM usando o canal de armas
        lda Projectile_Pool + ProjectileEntity::Active, y
        beq @NextSlot           

        ldx z:DP_WEAPON_OAM_BACKUP      ; ◄ Resgata o X do canal de armas

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
        inx                     

        stx z:DP_WEAPON_OAM_BACKUP      ; ◄ Atualiza o progresso no canal de armas

@NextSlot:
        lda z:DP_WEAPON_POOL_PTR
        clc
        adc #.sizeof(ProjectileEntity)
        sta z:DP_WEAPON_POOL_PTR        ; ◄ Avança no canal de armas
        
        cmp #(.sizeof(ProjectileEntity) * MAX_PROJECTILES)
        bcc @DrawLoop

        ldx z:DP_WEAPON_OAM_BACKUP      ; ◄ Entrega o X perfeitamente estável para a Main.s
        rts                     
.endproc



;-------------------------------------------------------------------------------
;   SpawnProjectile
;-------------------------------------------------------------------------------
.proc SpawnProjectile
        ldx #$0000              

@LoopPool:
        lda Projectile_Pool + ProjectileEntity::Active, x
        beq @EncontrouSlot      
        
        txa
        clc
        adc #.sizeof(ProjectileEntity)
        tax                     
        
        cpx #(.sizeof(ProjectileEntity) * MAX_PROJECTILES)
        bcc @LoopPool
        rts                     

@EncontrouSlot:
        lda #1
        sta Projectile_Pool + ProjectileEntity::Active, x
        
        lda z:$00
        sta Projectile_Pool + ProjectileEntity::Tile_ID, x
        lda z:$01
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

        rts
.endproc

;-------------------------------------------------------------------------------
;   UpdateProjectiles (Versão Atualizada com Suporte a Gravidade/Parábola)
;-------------------------------------------------------------------------------
.proc UpdateProjectiles
        ldx #$0000              

@UpdateLoop:
        lda Projectile_Pool + ProjectileEntity::Active, x
        beq @NextSlot           

        ; 1. Atualiza Posição Horizontal (X)
        lda Projectile_Pool + ProjectileEntity::X_Pos, x
        clc
        adc Projectile_Pool + ProjectileEntity::Speed_X, x
        sta Projectile_Pool + ProjectileEntity::X_Pos, x

        ; Checa se saiu das bordas laterais da tela
        cmp #SCREEN_RIGHT - 8
        bcs @DesativarProjetil  
        cmp #SCREEN_LEFT + 4
        bcc @DesativarProjetil

        ; 2. Atualiza Posição Vertical (Y) com Gravidade
        ; (Nota: Se for um projétil retilíneo comum, o Speed_Y estará zerado e não afetará)
        lda Projectile_Pool + ProjectileEntity::Y_Pos, x
        clc
        adc Projectile_Pool + ProjectileEntity::Speed_Y, x
        sta Projectile_Pool + ProjectileEntity::Y_Pos, x

        ; Aplica aceleração constante da gravidade se o item estiver no ar
        lda Projectile_Pool + ProjectileEntity::Speed_Y, x
        clc
        adc #$01                ; Soma +1 puxando o Y para baixo a cada frame
        sta Projectile_Pool + ProjectileEntity::Speed_Y, x

   ;    ;3. Checa colisão com o chão horizontal fixo da tela (Ajustado para o limite inferior real)
        lda Projectile_Pool + ProjectileEntity::Y_Pos, x
        cmp #$DF                ; Alterado de $A0 para $DF (SCREEN_BOTTOM)
        bcs @DesativarProjetil  ; Se passar da base da tela, ela some

        bra @NextSlot

@DesativarProjetil:
        lda #0
        sta Projectile_Pool + ProjectileEntity::Active, x 

@NextSlot:
        txa
        clc
        adc #.sizeof(ProjectileEntity)
        tax
        cpx #(.sizeof(ProjectileEntity) * MAX_PROJECTILES)
        bcc @UpdateLoop

        rts
.endproc

; =============================================================================
; SUBSISTEMA DE COLETA DE ARMAS NO CHÃO (PICKUP SYSTEM)
; =============================================================================

;-------------------------------------------------------------------------------
;   SpawnWeaponOnGround
;-------------------------------------------------------------------------------
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

;-------------------------------------------------------------------------------
;   CheckWeaponPickup
;-------------------------------------------------------------------------------
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


;-------------------------------------------------------------------------------
;   DrawDroppedWeapon (Versão Corrigida)
;-------------------------------------------------------------------------------
.proc DrawDroppedWeapon
        lda Ground_Weapon + DroppedWeaponEntity::Active
        bne @Desenhar
        rts

@Desenhar:
        ; Salva o X da OAM para não perder a referência durante a chamada
        stx z:$06

        lda Ground_Weapon + DroppedWeaponEntity::Weapon_ID
        jsr GetWeaponData       ; Retorna o offset exato e limpo no registrador Y

        ; Recupera o offset OAM original guardado em $06
        ldx z:$06

        ; Escreve a Posição X da RAM na OAMMIRROR
        lda Ground_Weapon + DroppedWeaponEntity::X_Pos
        sta OAMMIRROR, x
        inx

        ; Escreve a Posição Y da RAM na OAMMIRROR
        lda Ground_Weapon + DroppedWeaponEntity::Y_Pos
        sta OAMMIRROR, x
        inx

        ; Escreve o Tile_ID estático correto lido da ROM0 (Weapon_Data_Table)
        lda Weapon_Data_Table, y
        sta OAMMIRROR, x
        inx

        ; Escreve os Atributos padrão (Paleta 0, Prioridade 2 para ficar atrás dos personagens)
        lda #%00100000          
        sta OAMMIRROR, x
        inx                     ; Devolve X avançado com sucesso para o GameLoop

        rts
.endproc


; =============================================================================
; SEÇÃO DE ALOCAÇÃO NA MEMÓRIA RAM (BSS)
; =============================================================================
.segment "BSS"
.export Ground_Weapon
Projectile_Pool:  .res ( .sizeof(ProjectileEntity) * MAX_PROJECTILES )
Ground_Weapon:    .tag DroppedWeaponEntity