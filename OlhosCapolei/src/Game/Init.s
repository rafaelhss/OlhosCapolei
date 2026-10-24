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

.import Hero, InimigoGrande, InimigoGrande2, BigHero, PennyCrab

.segment "CODE"
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
        tsx                             ; Salva o Stack Pointer
        pea $0000                       ; Endereço de destino na VRAM
        pea SpriteData                  ; Endereço de origem na ROM
        
        
        rep #$20                        ; Abre 16-bit APENAS para empilhar o tamanho do DMA
        lda #$2000                      ; Tamanho: 1024 bytes
        pha                             
        sep #$20                        ; Volta IMEDIATAMENTE para 8-bit
        
        jsr LoadVRAM                   
        txs                             ; Restaura o Stack

        ; --- 3. CARGA DE CORES PARA CGRAM ---
        ; Altera a Cor 00 diretamente via hardware para manter a TELA AZUL
        stz CGADD                       ; Seleciona o índice $00 da CGRAM (Cor de Fundo)
        lda #$00                        ; Byte Baixo do Azul Puro do SNES ($00)
        sta CGDATA                      ; Envia para a PPU
        lda #$7C                        ; Byte Alto do Azul Puro do SNES ($7C)
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
; =========== FIM BIGHERO


       

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
