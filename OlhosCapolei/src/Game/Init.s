; -----------------------------------------------------------------------------
;   File: Init.s (Versão Corrigida com Forçamento de Índices 16-bit)
;   Description: Holds subroutines to initialize the demo
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     InitDemo
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
.import Bullet
.import InitRNG

.segment "CODE"

; =============================================================================
; TABELA LINEAR DE BOOT DE ITENS (6 BYTES ÚTEIS POR ARMA)
; Formato: Active, Weapon_ID, Tile_ID, Tile_Size, X_Pos, Y_Pos
; =============================================================================
Table_Init_Weapons:
    ; WeaponA (Pedra - ID 4)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_ROCK,   $6D, $01, $AA, (SCREEN_BOTTOM / 4)
    ; WeaponB (Martelo - ID 7)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_HAMMER, $0E, $01, $80, (SCREEN_BOTTOM / 4)
    ; WeaponC (Madeira - ID 3)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_WOOD,   $06, $04, $30, (SCREEN_BOTTOM / 4)
    ; WeaponD (Pistola - ID 5)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_PISTOL, $06, $04, $10, (SCREEN_BOTTOM / 4)
    ; WeaponE (Corrente - ID 6)
    .byte WEAPON_STATE_GROUND, WEAPON_ID_CHAIN,  $06, $04, $10, (SCREEN_BOTTOM / 2)


;-------------------------------------------------------------------------------
;   This initializes the demo
;-------------------------------------------------------------------------------
.proc   InitDemo
        ; --- GARANTIA DE HARDWARE REAL ---
        sep #$20                        ; Garante Acumulador em 8-bit (.a8)
        rep #$10                        ; FORÇA índices X e Y em 16-bit (.i16) para o loop de 512 bytes

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
       

        ; Agora carrega normalmente a paleta dos sprites no índice $80
        tsx                            
        lda #$80                        ; Paleta dos Sprites inicia em $80
        pha
        pea ColorData                  
        lda #$20                        ; 32 bytes (16 cores de 2 bytes)
        pha
        
        jsr LoadCGRAM                  
        txs                             ; Restaura o Stack perfeitamente

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

        lda a:Table_Init_Weapons + 4, y  ; Lê X_Pos (Byte) e Y_Pos (Byte)
        sta a:WeaponStruct::X_Pos, x

        ; Avança Y em 6 bytes (tamanho exato dos dados úteis de cada arma na tabela da ROM)
        tya
        clc
        adc #6
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




;----------- PennyCrab
        lda #$AA                         ; 
        sta PennyCrab + PennyCrabStruct::X_Pos
        
        lda #(SCREEN_BOTTOM / 2)        ; Y
        sta PennyCrab + PennyCrabStruct::Y_Pos

        lda #12                        
        sta PennyCrab + PennyCrabStruct::Tile_Count  

        lda #$09
        sta PennyCrab + PennyCrabStruct::Walk_Anim_Speed 

        lda #$04                       
        sta PennyCrab + PennyCrabStruct::Anim_Timer
        lda #$00                       
        sta PennyCrab + PennyCrabStruct::Anim_Frame   

        ; ◄ CRÍTICO: INICIALIZAÇÃO CONTRA O BUG DOS 5 SEGUNDOS
        lda #$08                       
        sta PennyCrab + PennyCrabStruct::Preparing_Anim_Timer
        stz PennyCrab + PennyCrabStruct::Preparing_Anim_Frame
        sta PennyCrab + PennyCrabStruct::Attacking_Anim_Timer
        sta PennyCrab + PennyCrabStruct::Attacking_Timer
        stz PennyCrab + PennyCrabStruct::Attacking_Anim_Frame
        
        lda #STATE_WALKING
        sta PennyCrab + PennyCrabStruct::State
;=========== FIM Penny



;----------- VaderCrab
        lda #$CC                        ; 
        sta VaderCrab + VaderCrabStruct::X_Pos
        
        lda #(SCREEN_BOTTOM / 2)        ; Y
        sta VaderCrab + VaderCrabStruct::Y_Pos

        lda #12                        
        sta VaderCrab + VaderCrabStruct::Tile_Count  

        lda #$09
        sta VaderCrab + VaderCrabStruct::Walk_Anim_Speed 

        lda #$04                       
        sta VaderCrab + VaderCrabStruct::Anim_Timer
        lda #$00                       
        sta VaderCrab + VaderCrabStruct::Anim_Frame   

        ; ◄ CRÍTICO: INICIALIZAÇÃO CONTRA O BUG DOS 5 SEGUNDOS
        lda #$08                       
        sta VaderCrab + VaderCrabStruct::Preparing_Anim_Timer
        stz VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
        sta VaderCrab + VaderCrabStruct::Attacking_Anim_Timer
        sta VaderCrab + VaderCrabStruct::Attacking_Timer
        stz VaderCrab + VaderCrabStruct::Attacking_Anim_Frame
        
        lda #STATE_WALKING
        sta VaderCrab + VaderCrabStruct::State
;=========== FIM Vader



; -----------------------------------------------------------------------------
; ----------- NOVO: INICIALIZAÇÃO DO BIGHERO (32x64)
; -----------------------------------------------------------------------------
        lda #20                        ; Nasce perto do meio horizontal da tela
        sta BigHero + BigHeroStruct::X_Pos
        
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

;------------- cria BiigHero

        lda #100                        ; Nasce perto do meio horizontal da tela
        sta Bullet + BulletStruct::X_Pos
        
        lda #100                        ; Nasce em uma altura boa de chão (eixo Z)
        sta Bullet + BulletStruct::Y_Pos

        lda #$01
        sta Bullet + BulletStruct::Active

        lda #$EE
        sta Bullet + BulletStruct::Tile_ID

        lda #$01 
        sta Bullet + BulletStruct::Speed_X
                 

; =========== FIM BiigHero



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
        sta TM

        ; Libera o blackout, coloca o brilho no máximo
        lda #$0f
        sta INIDISP

        ; Habilita NMI e leitura automática de controles (Joypad Auto-polling)
        lda #$81
        sta NMITIMEN

        rts                    
.endproc
