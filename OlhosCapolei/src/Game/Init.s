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

.import Hero, InimigoGrande, InimigoGrande2

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
        lda #$0400                      ; Tamanho: 1024 bytes
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

;----------- HÉROI 
        lda #$40                        ; X = 64
        sta Hero + HeroStruct::X_Pos   
        
        lda #(SCREEN_BOTTOM / 4)        ; Y
        sta Hero + HeroStruct::Y_Pos   

        lda #8                         
        sta Hero + HeroStruct::Tile_Count
;=========== FIM HERÓI

;----------- INIMIGO GRANDE 1
        lda #90                         ; X = 90
        sta InimigoGrande + EnemyStruct::X_Pos
        
        lda #(SCREEN_BOTTOM / 3)        ; Y
        sta InimigoGrande + EnemyStruct::Y_Pos

        lda #12                        
        sta InimigoGrande + EnemyStruct::Tile_Count   

        lda #$08                       
        sta InimigoGrande + EnemyStruct::Anim_Timer
        lda #$00                       
        sta InimigoGrande + EnemyStruct::Anim_Frame   
;=========== FIM INIMIGO 1
 
;----------- INIMIGO GRANDE 2
        lda #90                         ; X = 90
        sta InimigoGrande2 + EnemyStruct::X_Pos
        
        lda #(SCREEN_BOTTOM / 2)        ; Y
        sta InimigoGrande2 + EnemyStruct::Y_Pos

        lda #12                        
        sta InimigoGrande2 + EnemyStruct::Tile_Count   

        lda #$04                       
        sta InimigoGrande2 + EnemyStruct::Anim_Timer
        lda #$00                       
        sta InimigoGrande2 + EnemyStruct::Anim_Frame   
;=========== FIM INIMIGO 2

        ; --- 5. CONFIGURAÇÃO DE VELOCIDADE E REGISTRADORES PPU ---
        lda #SPRITE_SPEED
        sta HOR_SPEED
        sta VER_SPEED

        ; Configura o tamanho e local dos Sprites na VRAM
        lda #%00000000                  
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
