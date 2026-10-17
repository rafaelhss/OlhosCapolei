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
        ; upper-left sprite
        lda #(SCREEN_RIGHT/2 - SPRITE_SIZE) ; sprite 1, horizontal position
        sta OAMMIRROR, X
        inx                                 ; increment index
        lda #(SCREEN_BOTTOM/2 - SPRITE_SIZE); sprite 1, vertical position
        sta OAMMIRROR, X
        inx
        lda #$00                            ; sprite 1, name
        sta OAMMIRROR, X
        inx
        lda #$00                            ; no flip, palette 0
        sta OAMMIRROR, X
        inx
        ; upper-right sprite
        lda #(SCREEN_RIGHT/2)               ; sprite 3, horizontal position
        sta OAMMIRROR, X
        inx                                 ; increment index
        lda #(SCREEN_BOTTOM/2 - SPRITE_SIZE); sprite 3, vertical position
        sta OAMMIRROR, X
        inx
        lda #$01                            ; sprite 3, name
        sta OAMMIRROR, X
        inx
        lda #$00                            ; no flip, palette 0
        sta OAMMIRROR, X
        inx
        ; lower-left sprite
        lda #(SCREEN_RIGHT/2 - SPRITE_SIZE) ; sprite 2, horizontal position
        sta OAMMIRROR, X
        inx                                 ; increment index
        lda #(SCREEN_BOTTOM/2)              ; sprite 2, vertical position
        sta OAMMIRROR, X
        inx
        lda #$10                            ; sprite 2, name
        sta OAMMIRROR, X
        inx
        lda #$00                            ; no flip, palette 0
        sta OAMMIRROR, X
        inx
        ; lower-right sprite
        lda #(SCREEN_RIGHT/2)                ; sprite 4, horizontal position
        sta OAMMIRROR, X
        inx                                 ; increment index
        lda #(SCREEN_BOTTOM/2)              ; sprite 4, vertical position
        sta OAMMIRROR, X
        inx
        lda #$11                            ; sprite 4, name
        sta OAMMIRROR, X
        inx
        lda #$00                            ; no flip, palette 0
        sta OAMMIRROR, X
        inx


        

; === CONFIGURAÇÃO DO corpo ===
        ; Novo Sprite Superior Esquerdo
        lda #(SCREEN_RIGHT/2 - SPRITE_SIZE)                             ; Uma coordenada X qualquer para ele aparecer do lado
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/2 + SPRITE_SIZE)                            ; Uma coordenada Y qualquer
        sta OAMMIRROR, X
        inx
        lda #$02                            ; ◄ O SEU NOVO TILE 4 DO YY-CHR!
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx
                lda #(SCREEN_RIGHT/2)                            ; Uma coordenada X qualquer para ele aparecer do lado
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/2 + SPRITE_SIZE)                            ; Uma coordenada Y qualquer
        sta OAMMIRROR, X
        inx
        lda #$03                            ; ◄ O SEU NOVO TILE 4 DO YY-CHR!
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx
                lda #(SCREEN_RIGHT/2 - SPRITE_SIZE)                            ; Uma coordenada X qualquer para ele aparecer do lado
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/2 + SPRITE_SIZE + SPRITE_SIZE)                            ; Uma coordenada Y qualquer
        sta OAMMIRROR, X
        inx
        lda #$12                            ; ◄ O SEU NOVO TILE 4 DO YY-CHR!
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx
                lda #$80                            ; Uma coordenada X qualquer para ele aparecer do lado
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/2 + SPRITE_SIZE + SPRITE_SIZE)                            ; Uma coordenada Y qualquer
        sta OAMMIRROR, X
        inx
        lda #$13                           ; ◄ O SEU NOVO TILE 4 DO YY-CHR!
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx


;============= inimigo 1

; === CONFIGURAÇÃO DO corpo ===
        ; Novo Sprite Superior Esquerdo
        lda #(SCREEN_RIGHT/2 - (SPRITE_SIZE  * 5))                            ; Uma coordenada X qualquer para ele aparecer do lado
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/2 + SPRITE_SIZE)                            ; Uma coordenada Y qualquer
        sta OAMMIRROR, X
        inx
        lda #$04                            ; ◄ O SEU NOVO TILE 4 DO YY-CHR!
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx
                lda #(SCREEN_RIGHT/2 - (SPRITE_SIZE  * 4))                            ; Uma coordenada X qualquer para ele aparecer do lado
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/2 + SPRITE_SIZE)                            ; Uma coordenada Y qualquer
        sta OAMMIRROR, X
        inx
        lda #$05                            ; ◄ O SEU NOVO TILE 4 DO YY-CHR!
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx
                lda #(SCREEN_RIGHT/2 - (SPRITE_SIZE  * 5))                            ; Uma coordenada X qualquer para ele aparecer do lado
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/2 + SPRITE_SIZE + SPRITE_SIZE)                            ; Uma coordenada Y qualquer
        sta OAMMIRROR, X
        inx
        lda #$14                            ; ◄ O SEU NOVO TILE 4 DO YY-CHR!
        sta OAMMIRROR, X
        inx
        lda #$15                            ; Paleta 0
        sta OAMMIRROR, X
        inx
                lda #(SCREEN_RIGHT/2 - (SPRITE_SIZE  * 4))                            ; Uma coordenada X qualquer para ele aparecer do lado
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/2 + SPRITE_SIZE + SPRITE_SIZE)                            ; Uma coordenada Y qualquer
        sta OAMMIRROR, X
        inx
        lda #$0b                            ; ◄ O SEU NOVO TILE 4 DO YY-CHR!
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx


;--===========fim inimogo 1

;---- inimogo grande 1
;==== cabeca 
;==== pedaco 1-1
        lda #(SCREEN_RIGHT/4)                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4)               
        sta OAMMIRROR, X
        inx
        lda #$06                           
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx

;==== pedaco 1-2
        lda #(SCREEN_RIGHT/4 + SPRITE_SIZE)                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4)               
        sta OAMMIRROR, X
        inx
        lda #$07                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx   
;==== pedaco 2-1
        lda #(SCREEN_RIGHT/4 )                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$16                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx  
;==== pedaco 2-2
        lda #(SCREEN_RIGHT/4 + SPRITE_SIZE )                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$17                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx   

;=== corpo

;==== pedaco 1-1
        lda #(SCREEN_RIGHT/4 - SPRITE_SIZE )                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE+ SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$08                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx 
;==== pedaco 1-2
        lda #(SCREEN_RIGHT/4)                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE+ SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$09                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx 
;==== pedaco 1-3
        lda #(SCREEN_RIGHT/4 + SPRITE_SIZE )                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE+ SPRITE_SIZE)              
        sta OAMMIRROR, X
        inx
        lda #$0a                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx 
;==== pedaco 1-4
        lda #(SCREEN_RIGHT/4 + SPRITE_SIZE+ SPRITE_SIZE )                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE+ SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$0b                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx 
        
;==== pedaco 2-1
        lda #(SCREEN_RIGHT/4 - SPRITE_SIZE )                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE+ SPRITE_SIZE+ SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$18                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx 
;==== pedaco 2-2
        lda #(SCREEN_RIGHT/4)                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE+ SPRITE_SIZE+ SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$19                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx 
;==== pedaco 2-3
        lda #(SCREEN_RIGHT/4 + SPRITE_SIZE )                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE+ SPRITE_SIZE+ SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$1a                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx 
;==== pedaco 2-4
        lda #(SCREEN_RIGHT/4 + SPRITE_SIZE+ SPRITE_SIZE )                
        sta OAMMIRROR, X
        inx
        lda #(SCREEN_BOTTOM/4 + SPRITE_SIZE+ SPRITE_SIZE+ SPRITE_SIZE)               
        sta OAMMIRROR, X
        inx
        lda #$1b                            
        sta OAMMIRROR, X
        inx
        lda #$00                            ; Paleta 0
        sta OAMMIRROR, X
        inx 
          




;---- fim inimogo grande 1


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
