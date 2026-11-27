; -----------------------------------------------------------------------------
;   File: Init.s (Versão Corrigida com Forçamento de Índices 16-bit)
;   Description: Holds subroutines to initialize the demo
; -----------------------------------------------------------------------------


;----- Export ------------------------------------------------------------------
.export     InitDemo
.export SetupDefaultMeleeStats
.export SetupPreSpawnMeleeStats
.export SetupWeaponStats
;-------------------------------------------------------------------------------


;----- Assembler Directives ----------------------------------------------------
.p816                           
.a8                             ; Travado em 8-bit acumulador
.i16                            ; Travado em 16-bit indexes
;-------------------------------------------------------------------------------

;----- Includes ----------------------------------------------------------------
.include "Assets.inc"
.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "PPU.inc"
.INCLUDE "Registers.inc"
.include "Stage.inc"
;-------------------------------------------------------------------------------


.import  BigHero, PennyCrab, VaderCrab, WeaponA, WeaponB, WeaponC, WeaponD, WeaponE
.import DengueCrab, RapaNuiCrab
.import Bullet
.import Bullet2
.import InitRNG
.import Camera_X
.import Current_Stage
.import Stage_Scripts_Table
.import Stage2_Sky_Color
.import Stage_Script_Ptr

.import Weapon_Data_Table


.segment "RODATA"



.segment "CODE"


;-------------------------------------------------------------------------------
;   This initializes the demo
;-------------------------------------------------------------------------------
.proc   InitDemo
        ; --- GARANTIA DE HARDWARE REAL ---
        sep #$20                        ; Garante Acumulador em 8-bit (.a8)
        rep #$10                        ; FORÇA índices X e Y em 16-bit (.i16) para o loop de 512 bytes



        ; No InitDemo (Init.s):
        stz Camera_X
        stz Camera_X + 1


        ; --- 1. LIMPEZA ESTRITA DA OAMMIRROR EM HARDWARE REAL ---
        ; Joga todos os 128 sprites para fora da tela (Y = $E0) para evitar lixo visual
        ldx #0
:       lda #0                          ; X = 0
        sta OAMMIRROR, x
        inx
        lda #$E0                        ; Y = 224 (Escondido)
        sta OAMMIRROR, x
        inx
        lda #0                          ; Tile = 0, Atributos = 0
        sta OAMMIRROR, x
        inx
        inx                             
        cpx #512                        ; Se X for de 8-bit, isso trava para sempre. Com rep #$10 funciona.
        bcc :-

        ; Zera a High OAM Table (32 bytes finais de tamanho/9º bit do X)
        ldx #512
        lda #0
:       sta OAMMIRROR, x
        inx
        cpx #544
        bcc :-

        ; --- 2. CARGA DE GRÁFICOS PARA VRAM ---
        ; ◄ PLANILHA 1: HEROI + PENNYCRAB (Envia para o offset $0000)
        tsx                             
        pea $0000                       ; Endereço de destino na VRAM (Página 0)
        pea SpriteData                  ; Origem na ROM
        rep #$20                        
        lda #$2000                      ; Tamanho: 8 KB
        pha                             
        sep #$20                        
        jsr LoadVRAM                   
        txs                             

        ; ◄ PLANILHA 2: VADERCRAB (Envia para o offset $1000)
        tsx                             
        pea $1000                       ; Endereço de destino na VRAM (Página 1)
        pea VaderData                   ; Origem na ROM (Seu novo rótulo!)
        rep #$20                        
        lda #$2000                      ; Tamanho: 8 KB
        pha                             
        sep #$20                        
        jsr LoadVRAM                   
        txs                             ; Restaura o Stack perfeitamente

        ; --- 3. CARGA DE CORES PARA CGRAM ---
        ; Altera a Cor 00 diretamente via hardware para manter a TELA AZUL
        stz CGADD                       ; Seleciona o índice $00 da CGRAM (Cor de Fundo)
        lda #$90                        ; Byte Baixo do Azul Puro do SNES ($00)
        sta CGDATA                      ; Envia para a PPU
        lda #$F2                        ; Byte Alto do Azul Puro do SNES ($7C)
        sta CGDATA                      ; Envia para a PPU (Escrita dupla finalizada)
       

         ; --- CARGA DIRETA DA PALETA DOS SPRITES NO ÍNDICE $80 DA CGRAM ---
        lda #$80                        ; Paleta dos Sprites inicia no índice $80
        sta CGADD
        ldx #0
@LoadSpritePalLoop:
        lda f:ColorData, x              ; Lê com endereço completo de 24-bit (f:)
        sta CGDATA
        inx
        cpx #32                         ; 32 bytes (16 cores de 2 bytes)
        bcc @LoadSpritePalLoop




        ; --- 4. INICIALIZAÇÃO DAS ARMAS ---
        JSR InitAllWeapons

        



        ; 3. RESTAURAÇÃO DE MODO PARA O RESTANTE DO INIT.S
        sep #$20                        ; Retorna Acumulador para 8-bit (.a8)
        .a8
        ; Índices X/Y continuam em 16-bit (.i16) de forma segura.



        ; Aponta Stage_Script_Ptr conforme a fase escolhida (0 = Fase 1, 1 = Fase 2)
        rep #$20
        .a16
        lda Current_Stage
        and #$00FF
        asl                             ; Multiplica por 2 (cada ponteiro tem 2 bytes)
        tax
        lda f:Stage_Scripts_Table, x
        sta Stage_Script_Ptr
        sep #$20
        .a8



        ; --- INICIALIZAÇÃO DOS INIMIGOS MELEE ---
        jsr InitAllMeleeCrabs





; -----------------------------------------------------------------------------
; ----------- NOVO: INICIALIZAÇÃO DO BIGHERO (32x64)
; -----------------------------------------------------------------------------
 
        ; BigHero X_Pos = 20 (16-bit)
        rep #$20
        .a16
        lda #20
        STA BigHero + BigHeroStruct::X_Pos
        sep #$20
        .a8



        lda #100                        ; Nasce em uma altura boa de chão (eixo Z)
        sta BigHero + BigHeroStruct::Y_Pos

        lda #6                          ; Gasta 6 blocos na OAMMIRROR
        sta BigHero + BigHeroStruct::Tile_Count

        lda #8                          ; Velocidade do relógio de passos (8 frames por passada)
        sta BigHero + BigHeroStruct::Anim_Timer
        
        lda #0                          ; Começa com o frame de pé parado (guarda)
        sta BigHero + BigHeroStruct::Anim_Frame

        lda #00                          ; Começa com o sem arma
        sta BigHero + BigHeroStruct::Current_Weapon_ID

 ;       lda #STATE_HURT_NOT
 ;       sta BigHero + BigHeroStruct::HurtState
        
        lda #$01
        sta BigHero + BigHeroStruct::Hurtbox_Active

; =========== FIM BIGHERO

;------------- cria Bullet

        ; BigHero X_Pos = 20 (16-bit)
        rep #$20
        .a16
        lda #64
        sta Bullet + BulletStruct::X_Pos
        sep #$20
        .a8
        
        lda #100                        ; Nasce em uma altura boa de chão (eixo Z)
        sta Bullet + BulletStruct::Y_Pos

        lda #$01
        sta Bullet + BulletStruct::Active

        lda #$EE
        sta Bullet + BulletStruct::Tile_ID

        lda #$01 
        sta Bullet + BulletStruct::Speed_X
                 

; =========== FIM bullet

;------------- cria Bullet2

        rep #$20
        .a16
        lda #64
        sta Bullet2 + BulletStruct::X_Pos
        sep #$20
        .a8
        
        lda #100                        ; Nasce em uma altura boa de chão (eixo Z)
        sta Bullet2 + BulletStruct::Y_Pos

        lda #$01
        sta Bullet2 + BulletStruct::Active

        lda #$84
        sta Bullet2 + BulletStruct::Tile_ID

        lda #$01 
        sta Bullet2 + BulletStruct::Speed_X
                 

; =========== FIM bullet2
         JSR InitRNG    ; Define a semente inicial do gerador de números aleatórios


        ; --- 5. CONFIGURAÇÃO DE VELOCIDADE E REGISTRADORES PPU ---
        lda #SPRITE_SPEED
        sta HOR_SPEED
        sta VER_SPEED

        ; ARQUITETURA BEAT 'EM UP: Configura tamanho base de sprites
        ; %01100000 ($60) -> Bits 7-5 = 011 significa: 16x16 (Pequeno) e 32x32 (Grande)
        ; Name Selection continua em $0000 na VRAM
        lda #%01100000                  
        sta OBJSEL
        
        ; Ativa a camada de Sprites (Main Screen Objs)
        lda #$10
        STA TM
        

        JSR initBG
        
        sep #$20                ; Garante A em 8-bit!
        .a8


        ; Zera scroll inicial de BG1 e BG2 (write-twice)
        stz BG1HOFS
        stz BG1HOFS
        stz BG1VOFS
        stz BG1VOFS

        stz BG2HOFS
        stz BG2HOFS
        stz BG2VOFS
        stz BG2VOFS


        ; Libera o blackout, coloca o brilho no máximo
        lda #$0f
        sta INIDISP

        ; Habilita NMI e leitura automática de controles (Joypad Auto-polling)
        lda #$81
        sta NMITIMEN

        rts                    
.endproc

.proc   initBG
        php
        sep #$20
        rep #$10
        .a8
        .i16

        ; --- 1. CARGA DIRETA DAS PALETAS DE BG (ÍNDICE $00 DA CGRAM) ---
        stz CGADD                       ; Começa no índice 0 da CGRAM
        ldx #0
@LoadPalLoop:
        lda f:Test_BG_Palettes, x
        sta CGDATA
        inx
        cpx #64                         ; 64 bytes (Paleta 0 e Paleta 1)
        bcc @LoadPalLoop

        ; Se Current_Stage == 1 (Fase 2), pinta o céu (Cor $00) com cor de anoitecer
        lda Current_Stage
        cmp #1
        bne @SkipNightSky
        stz CGADD
        lda f:Stage2_Sky_Color
        sta CGDATA
        lda f:Stage2_Sky_Color + 1
        sta CGDATA
@SkipNightSky:



        ; --- 2. CARGA DIRETA DOS TILES DE BG PARA VRAM ($2000) ---
        lda #$80
        sta VMAINC                      ; Incrementa endereço VRAM após escrita no byte alto
        ldx #$2000
        stx VMADDL                      ; Endereço de destino: $2000

        ldx #0
@LoadTilesLoop:
        lda f:Test_BG_Tiles, x
        sta VMDATAL
        inx
        lda f:Test_BG_Tiles, x
        sta VMDATAH
        inx
        cpx #96                         ; 3 tiles x 32 bytes = 96 bytes
        bcc @LoadTilesLoop

        ; --- 3. GERA OS MAPAS DE TELA NA VRAM ---
        jsr BuildTestBackgrounds

        ; --- 4. CONFIGURAÇÃO DE MODO DE VÍDEO E CAMADAS ---
        lda #$01                        ; BG Mode 1
        sta BGMODE

        lda #$41                        ; Tilemap BG1 em $4000 (64x32)
        sta BG1SC

        lda #$49                        ; Tilemap BG2 em $4800 (64x32)
        sta BG2SC

        lda #$22                        ; Tilesets de BG1 e BG2 apontam para VRAM $2000
        sta BG12NBA

        ; Zera o scroll inicial das duas camadas
        stz BG1HOFS
        stz BG1HOFS
        stz BG1VOFS
        stz BG1VOFS

        stz BG2HOFS
        stz BG2HOFS
        stz BG2VOFS
        stz BG2VOFS

        ; --- 5. ATIVA SPRITES + BG1 + BG2 ---
        lda #$13                        ; OBJ ($10) + BG2 ($02) + BG1 ($01)
        sta TM

        plp
        rts
.endproc

.proc InitAllMeleeCrabs
        php
        sep #$20
        rep #$10
        .a8
        .i16

        ldx #.loword(VaderCrab)
        jsr SetupDefaultMeleeStats

        ldx #.loword(DengueCrab)
        jsr SetupDefaultMeleeStats

        ldx #.loword(RapaNuiCrab)
        jsr SetupDefaultMeleeStats

        plp
        rts
.endproc




.proc   SetupDefaultMeleeStats
        .a8
        .i16

        lda #12
        sta a:MeleeCrabStruct::Tile_Count, x

        lda #$09
        sta a:MeleeCrabStruct::Walk_Anim_Speed, x

        lda #$04
        sta a:MeleeCrabStruct::Anim_Timer, x
        stz a:MeleeCrabStruct::Anim_Frame, x

        lda #$08
        sta a:MeleeCrabStruct::Preparing_Anim_Timer, x
        stz a:MeleeCrabStruct::Preparing_Anim_Frame, x
        sta a:MeleeCrabStruct::Attacking_Anim_Timer, x
        sta a:MeleeCrabStruct::Attacking_Timer, x
        stz a:MeleeCrabStruct::Attacking_Anim_Frame, x

        stz a:MeleeCrabStruct::HurtTimer, x
        stz a:MeleeCrabStruct::Resting_Timer, x
        stz a:MeleeCrabStruct::Dying_Timer, x
        stz a:MeleeCrabStruct::Hitbox_Active, x

        lda #STATE_DEAD
        sta a:MeleeCrabStruct::State, x

        lda #04
        sta a:MeleeCrabStruct::HP, x

        rts
.endproc


.proc   SetupPreSpawnMeleeStats
        .a8
        .i16

        lda #12
        sta a:MeleeCrabStruct::Tile_Count, x

        lda #$09
        sta a:MeleeCrabStruct::Walk_Anim_Speed, x

        lda #08
        sta a:MeleeCrabStruct::Anim_Timer, x
        stz a:MeleeCrabStruct::Anim_Frame, x

        lda #$08
        sta a:MeleeCrabStruct::Preparing_Anim_Timer, x
        stz a:MeleeCrabStruct::Preparing_Anim_Frame, x
        sta a:MeleeCrabStruct::Attacking_Anim_Timer, x
        sta a:MeleeCrabStruct::Attacking_Timer, x
        stz a:MeleeCrabStruct::Attacking_Anim_Frame, x

        stz a:MeleeCrabStruct::HurtTimer, x
        stz a:MeleeCrabStruct::Resting_Timer, x
        stz a:MeleeCrabStruct::Dying_Timer, x
        stz a:MeleeCrabStruct::Spawn_Vel_Y, x
        stz a:MeleeCrabStruct::Spawn_Anim_Timer, x
        stz a:MeleeCrabStruct::Hitbox_Active, x

        lda #STATE_PRE_SPAWN
        sta a:MeleeCrabStruct::State, x

        lda #04
        sta a:MeleeCrabStruct::HP, x

        rts
.endproc
.proc InitAllWeapons
        php
        rep #$30                        ; .a16, .i16
        .a16
        .i16

        ; 1. Zera toda a WRAM dos 5 slots (WeaponA até WeaponE)
        lda #0
        ldx #.loword(WeaponA)
@ClearLoop:
        sta a:0, x
        inx
        inx
        cpx #(.loword(WeaponE) + .sizeof(WeaponStruct))
        bcc @ClearLoop

        ; 2. Marca todos os slots como INACTIVE (3), e NÃO 0 (EQUIPPED)!
        sep #$20
        .a8
        lda #WEAPON_STATE_INACTIVE
        sta WeaponA + WeaponStruct::Active
        sta WeaponB + WeaponStruct::Active
        sta WeaponC + WeaponStruct::Active
        sta WeaponD + WeaponStruct::Active
        sta WeaponE + WeaponStruct::Active

        plp
        rts
.endproc

; -----------------------------------------------------------------------------
; SetupWeaponStats
; Entrada: Y = Ponteiro 16-bit do slot (WeaponA..WeaponD) já com ID, Tile_ID e Tile_Size
; -----------------------------------------------------------------------------
.proc SetupWeaponStats
        .a8
        .i16

        lda #0
        sta a:WeaponStruct::Speed_X, y
        sta a:WeaponStruct::Speed_Y, y
        sta a:WeaponStruct::Target_Y, y
        sta a:WeaponStruct::Melee_Timer, y
        sta a:WeaponStruct::Melee_Frame, y
        sta a:WeaponStruct::Anim_Variation, y
        sta a:WeaponStruct::Hitbox_Active, y

        lda #WEAPON_STATE_GROUND
        sta a:WeaponStruct::Active, y

        rts
.endproc
