; -----------------------------------------------------------------------------
;   File: Init.s (Versão Corrigida com Forçamento de Índices 16-bit)
;   Description: Holds subroutines to initialize the demo
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     InitDemo
.export SetupDefaultMeleeStats
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
.include "Registers.inc"
;-------------------------------------------------------------------------------


.import  BigHero, PennyCrab, VaderCrab, WeaponA, WeaponB, WeaponC, WeaponD, WeaponE
.import DengueCrab, RapaNuiCrab
.import Bullet
.import Bullet2
.import InitRNG
.import Camera_X

.segment "RODATA"

; =============================================================================
; TABELA LINEAR DE BOOT DE ITENS (7 BYTES ÚTEIS POR ARMA)
; Formato: Active (1), Weapon_ID (1), Tile_ID (1), Tile_Size (1), X_Pos (2), Y_Pos (1)
; =============================================================================
Table_Init_Weapons:
    ; WeaponA (Pedra - ID 4)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_ROCK,   $6D, $01
    .word $00AA
    .byte (SCREEN_BOTTOM / 4)

    ; WeaponB (Martelo - ID 7)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_HAMMER, $0E, $01
    .word $0180                         ; Exemplo: já nasce lá na frente em X = 384!
    .byte (SCREEN_BOTTOM / 4)

    ; WeaponC (Madeira - ID 3)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_WOOD,   $06, $04
    .word $0030
    .byte (SCREEN_BOTTOM / 4)

    ; WeaponD (Pistola - ID 5)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_PISTOL, $06, $04
    .word $0290                         ; Exemplo: nasce em X = 656
    .byte (SCREEN_BOTTOM - 50)

    ; WeaponE (Corrente - ID 6)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_CHAIN,  $06, $04
    .word $0010
    .byte (SCREEN_BOTTOM / 2)

; =============================================================================
; TABELA DE BOOT DOS INIMIGOS MELEE (7 BYTES POR INIMIGO)
; Formato: Endereço WRAM (2), X_Pos (2), Y_Pos (1), Enemy_Type (1), Attack_Sector (1)
; =============================================================================
Table_Init_MeleeCrabs:
    ; VaderCrab
    .word .loword(VaderCrab)
    .word $00F0
    .byte (SCREEN_BOTTOM - 40 ), ENEMY_TYPE_VADER, $00

    ; DengueCrab
    .word .loword(DengueCrab)
    .word $01C8                         ; Exemplo: nasce em X = 456
    .byte (SCREEN_BOTTOM / 2), ENEMY_TYPE_DENGUE, $01

    ; RapaNuiCrab
    .word .loword(RapaNuiCrab)
    .word $0008
    .byte (SCREEN_BOTTOM - 20), ENEMY_TYPE_RAPA, $02

Table_Init_MeleeCrabs_End:


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


        ; --- 4. INICIALIZAÇÃO DAS STRUCTS (8-BIT PURO E SEGURO) ---
; =============================================================================
; INICIALIZAÇÃO DATA-DRIVEN BLINDADA (ÍNDICES INTEGRALMENTE EM 16-BIT)
; =============================================================================
        rep #$30                        ; .a16, .i16 (A/X/Y travados em 16-bit)
        .a16
        .i16

        ; 1. LIMPEZA INICIAL AUTOMATIZADA DA RAM DAS ARMAS
        lda #0
        ldx #.loword(WeaponA)
@ClearRAMLoop:
        sta a:0, x                      ; Zera de 2 em 2 bytes na WRAM
        inx
        inx
        cpx #(.loword(WeaponE) + .sizeof(WeaponStruct))
        bcc @ClearRAMLoop

        ; 2. LOOP DE CÓPIA DE ESTRUTURAS (ROM -> WRAM)
        ldy #0                          ; Y = Indexador de bytes lidos da ROM
        ldx #.loword(WeaponA)           ; X = Ponteiro de escrita na WRAM

@CopyWeaponsLoop:
        ; Como estamos em 16-bit, lemos e escrevemos de 2 em 2 bytes respeitando os offsets
        lda a:Table_Init_Weapons + 0, y  ; Lê Active (Byte) e Weapon_ID (Byte)
        sta a:WeaponStruct::Active, x

        lda a:Table_Init_Weapons + 2, y  ; Lê Tile_ID (Byte) e Tile_Size (Byte)
        sta a:WeaponStruct::Tile_ID, x

        ; Lê X_Pos (Word completo de 16-bit!)
        lda a:Table_Init_Weapons + 4, y
        sta a:WeaponStruct::X_Pos, x

        ; Lê Y_Pos (Byte único - voltamos A para 8-bit rapidinho)
        sep #$20
        .a8
        lda a:Table_Init_Weapons + 6, y
        sta a:WeaponStruct::Y_Pos, x
        rep #$20
        .a16

        ; Avança Y em 7 bytes (tamanho exato dos dados úteis de cada arma na tabela da ROM)
        tya
        clc
        adc #7
        tay

        ; Avança X para a próxima estrutura WeaponStruct inteira na WRAM
        txa
        clc
        adc #.sizeof(WeaponStruct)
        tax

        ; Checa se já inicializou todas as 5 armas do pool
        cpx #(.loword(WeaponE) + .sizeof(WeaponStruct))
        bcc @CopyWeaponsLoop

        ; 3. RESTAURAÇÃO DE MODO PARA O RESTANTE DO INIT.S
        sep #$20                        ; Retorna Acumulador para 8-bit (.a8)
        .a8
        ; Índices X/Y continuam em 16-bit (.i16) de forma segura.



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
;-------------------------------------------------------------------------------
;   InitAllMeleeCrabs
;   Lê a Table_Init_MeleeCrabs e configura todos os inimigos automaticamente
;-------------------------------------------------------------------------------
.proc   InitAllMeleeCrabs
        php                             ; Salva flags atuais do processador
        sep #$20                        ; Garante Acumulador 8-bit (.a8)
        rep #$10                        ; Garante Índices 16-bit (.i16)
        .a8
        .i16

        ldy #0                          ; Y = Offset de leitura na tabeInitAllMeleeCrabsla da ROM

@Loop:
        ; 1. Carrega o endereço WRAM do inimigo para o registrador X (16-bit)
        rep #$20                        ; Muda A para 16-bit temporariamente
        .a16
        lda a:Table_Init_MeleeCrabs + 0, y
        tax                             ; X agora aponta para a struct (ex: VaderCrab)
        LDA a:Table_Init_MeleeCrabs + 2, y
        sta a:MeleeCrabStruct::X_Pos, x ; Grava X_Pos de 16-bit!
        sep #$20
        .a8

        ; 2. Lê os dados exclusivos da tabela
        lda a:Table_Init_MeleeCrabs + 4, y
        sta a:MeleeCrabStruct::Y_Pos, x

        lda a:Table_Init_MeleeCrabs + 5, y
        sta a:MeleeCrabStruct::Enemy_Type, x

        lda a:Table_Init_MeleeCrabs + 6, y
        sta a:MeleeCrabStruct::Attack_Sector, x

        ; 3. Preenche os valores padrão compartilhados por todos os MeleeCrabs
        jsr SetupDefaultMeleeStats

        ; 4. Avança Y em 7 bytes e verifica se chegou ao fim da tabela
        rep #$20
        .a16
        tya
        clc
        adc #7
        tay
        sep #$20
        .a8

        cpy #(Table_Init_MeleeCrabs_End - Table_Init_MeleeCrabs)
        bcc @Loop

        plp                             ; Restaura estado original do processador
        rts
.endproc

;-------------------------------------------------------------------------------
;   SetupDefaultMeleeStats (Rotina Reutilizável de Spawn!)
;   Entrada: X = Ponteiro 16-bit para a MeleeCrabStruct na WRAM
;-------------------------------------------------------------------------------
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

        ; Prevenção do bug dos 5 segundos
        lda #$08
        sta a:MeleeCrabStruct::Preparing_Anim_Timer, x
        stz a:MeleeCrabStruct::Preparing_Anim_Frame, x
        sta a:MeleeCrabStruct::Attacking_Anim_Timer, x
        sta a:MeleeCrabStruct::Attacking_Timer, x
        stz a:MeleeCrabStruct::Attacking_Anim_Frame, x

        lda #STATE_WALKING
        sta a:MeleeCrabStruct::State, x

        stz a:MeleeCrabStruct::Hitbox_Active, x

        lda #04
        sta a:MeleeCrabStruct::HP, x

        rts
.endproc
