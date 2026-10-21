; -----------------------------------------------------------------------------
;   File: Init.s
;   Description: Holds subroutines to initialize the demo
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     InitDemo
;-------------------------------------------------------------------------------

;----- Assembler Directives ----------------------------------------------------
.p816                           ; tell the assembler this is 65816 code
.a8
.i16
;-------------------------------------------------------------------------------

;----- Includes ----------------------------------------------------------------
.include "Assets.inc"
.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "PPU.inc"
.include "Registers.inc"
;-------------------------------------------------------------------------------

.import Hero, InimigoGrande

.segment "CODE"
;-------------------------------------------------------------------------------
;   This initializes the demo
;-------------------------------------------------------------------------------
.proc   InitDemo
        ; load sprites into VRAM
        tsx                             ; save current stack pointer
        pea $0000                       ; push VRAM destination address to stack
        pea SpriteData                  ; push sprite data source address to stack
        ;lda #$80                        ; number of bytes (128/$80) to transfer
        
        rep #$20                        ; 1. Força o Acumulador A a entrar em modo de 16-bit
        lda #$0400                      ; 2. Agora sim! Carrega o número 512 ($0200) sem erro
        pha                             ; 3. Empilha os 2 bytes do tamanho na Stack
        sep #$20                        ; 4. Volta o Acumulador para 8-bit para o resto do código
        
        jsr LoadVRAM                    ; transfer sprite data to VRAM
        txs                             ; restore old stack pointer

        ; load color data into CGRAM
        tsx                             ; save current stack pointer
        lda #$80                        ; destination address in CGRAM
        pha
        pea ColorData                   ; color data source address
        lda #$20                        ; number of bytes (32/$20) to transfer
        pha
        jsr LoadCGRAM                   ; transfer color data into CGRAM
        txs                             ; restore old stack pointer



        ; initialize OAMRAM mirror
        ldx #$00
;----------- HÉROI (Alinhamento perfeito entre Montador e CPU)
        rep #$20                        ; CPU em modo 16-bits
        .a16                            ; ◄ AVISO AO CA65: Monte os números em 16-bits agora!
        
        lda #$40         ; Agora o ca65 gera os bytes $80 e $00 na ROM!
        sta Hero + HeroStruct::X_Pos    ; Grava os 16-bits perfeitamente na RAM
        
        sep #$20                        ; CPU volta para 8-bits
        .a8                             ; ◄ AVISO AO CA65: Volte a montar em 8-bits!
        
        lda #(SCREEN_BOTTOM / 4)        
        sta Hero + HeroStruct::Y_Pos

        lda #8                          
        sta Hero + HeroStruct::Tile_Count ; (ou HeroStruct::Tile_Count dependendo do nome da sua variável)
;=========== FIM HERÓI



    

;----------- INIMIGO GRANDE 1
        rep #$20                        ; CPU em modo 16-bits
        .a16                            ; ◄ AVISO AO CA65!
        
        lda #90                         ; Carrega 40 completo ($0028)
        sta InimigoGrande + EnemyStruct::X_Pos 
        
        sep #$20                        ; CPU volta para 8-bits
        .a8                             ; ◄ AVISO AO CA65!
        
        lda #(SCREEN_BOTTOM / 3)        
        sta InimigoGrande + EnemyStruct::Y_Pos

        lda #12                         
        sta InimigoGrande + EnemyStruct::Tile_Count    


        LDA #$08                        ;atualiza a cada 8 frames na tela
        STA InimigoGrande + EnemyStruct::Anim_Timer
        LDA #$00                        ; comeca do tile 0
        STA InimigoGrande + EnemyStruct::Anim_Frame    



;----------- FIM INIMIGO





        ; move the other sprites off screen
       ; rep #$20                            ; set A to 16-bit
       ; lda #$f180                          ; Y = 241, X = -128
OAMLoop: 
        ; joga 241 128 em todos os objetos da OAM principal
    ;    sta OAMMIRROR, X
      ;  inx
      ;  inx
       ; cpx #(OAMMIRROR_SIZE - $20)  ;O autor escreveu em forma de equação (OAMMIRROR_SIZE - $20) apenas para o código ficar mais legível para humanos, deixando claro que ele quer ir até o final da tabela, subtraindo o bloco extra.
       ; bne OAMLoop
        ; correct bit 9 of horizontal/X position, set size to 8x8
        ;lda #$5555
       ; lda #$0000
       ; sep #$20                            ; ◄ ENTROU: Força o Acumulador a voltar para 8-bit ANTES do loop
       ; lda #$00
OBJLoop:
        ; seta 5555 (sinal negativo) para todos na tabela extra
        ;sta OAMMIRROR, X
       ; inx
       ; inx
        ;cpx #OAMMIRROR_SIZE
        ;bne OBJLoop

        sep #$20                            ; set A to 8-bit
        ; correct extra OAM byte for first four sprites
        ;ldx #(OAMMIRROR_SIZE - $20) ; inicio da tabela extra
        ;lda #$00
        ;sta OAMMIRROR, X ;corrige o sinal para os 4 primeiros tiles
        ;inx
        ;sta OAMMIRROR, X ;corrige o sinal para os 4 seguintes
        ;inx
        ;sta OAMMIRROR, X ;corrige o sinal para os 4 seguintes

        ; set initial horizontal and vertical speed
        lda #SPRITE_SPEED
        sta HOR_SPEED
        sta VER_SPEED

        ; make Objects visible
        lda #$10
        sta TM
        ; release forced blanking, set screen to full brightness
        lda #$0f
        sta INIDISP
        ; enable NMI, turn on automatic joypad polling
        lda #$81
        sta NMITIMEN

        ; jmp GameLoop            ; all initialization is done
        rts                     ; all initialization is done
.endproc
;-------------------------------------------------------------------------------
