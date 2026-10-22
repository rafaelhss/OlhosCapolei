; -----------------------------------------------------------------------------
;   File: InitSNES.s (Corrigido para Hardware Real / Everdrive)
;   Description: Reset the SNES to a known state safely
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     ClearRegisters      
.export     ClearVRAM           
.export     ClearCGRAM          
.export     ClearOAMRAM         
;-------------------------------------------------------------------------------

;----- Assembler Directives ----------------------------------------------------
.p816                           
.a8
.i16
;-------------------------------------------------------------------------------

;----- Includes ----------------------------------------------------------------
.include "Registers.inc"
;-------------------------------------------------------------------------------

.segment "CODE"

; --- CONSTANTES DE PREENCHIMENTO NA ROM ---
; Colocar os bytes aqui garante que o DMA leia da ROM de forma estável,
; eliminando o conflito de ler da Página Zero de WRAM.
ByteZero: .byte $00
ByteFF:   .byte $ff

;-------------------------------------------------------------------------------
;   Clear all PPU and CPU registers to standard values
;-------------------------------------------------------------------------------
.proc   ClearRegisters
        ; Registradores da PPU ($2101 até $210C)
        ldx #$2101                      
loop1:  stz $00, X
        inx
        cpx #$210d
        bne loop1

        ; Registradores de escrita dupla de Scroll ($210D até $2114)
        ; Corrigido: Escreve duas vezes em cada registrador individualmente
loop2:  stz $00, X                      
        stz $00, X
        inx
        cpx #$2115
        bne loop2

        lda #$80                        ; Incremento de VRAM para VMDATAH
        sta VMAINC

        inx                             ; Registradores $2116 até $211A
loop3:  stz $00, X
        inx
        cpx #$211b
        bne loop3

        ; Registradores de matriz/tamanho de BG ($211B até $2120)
loop4:  lda #$01                        
        sta $00, X                      ; $211B exige escrita dupla com valores específicos
        stz $00, X
        inx                             ; Avança para $211C
        stz $00, X                      
        stz $00, X
        inx                             ; Avança para $211D
        stz $00, X
        stz $00, X
        inx                             ; Avança para $211E
        stz $00, X
        stz $00, X
        inx                             ; Avança para $211F
        stz $00, X
        stz $00, X
        inx                             ; Avança para $2120
        stz $00, X
        stz $00, X
        inx
        cpx #$2121
        bne loop4

        ; Janelas e efeitos ($2121 até $2133)
loop5:  stz $00, X                      
        inx
        cpx #$2134
        bne loop5

        ; Valores especiais de controle de cor e tela
        lda #$30
        sta CGSWSEL
        lda #$e0
        sta COLDATA

        ; Registradores da CPU
        stz NMITIMEN
        lda #$ff
        sta WRIO

        ldx #$4202                      ; Registradores multiplicadores/divisores ($4202 até $420D)
loop6:  stz $00, X
        inx
        cpx #$420e
        bne loop6

        rts
.endproc

;-------------------------------------------------------------------------------
;   Clear the complete VRAM to $00
;-------------------------------------------------------------------------------
.proc   ClearVRAM
        lda #$80                        
        sta VMAINC
        ldx #$0000                      
        stx VMADDL
        
        ; DMA Canal 0: Preenchimento fixo usando ByteZero localizado na ROM
        lda #$09                        ; Escrita de 2 bytes, endereço fixo
        sta DMAP0
        lda #$18                        ; Destino: VMDATAL ($2118)
        sta BBAD0
        
        ; Aponta a origem do DMA para a constante estável na ROM
        ldx #.loword(ByteZero)
        stx A1T0L
        lda #.bankbyte(ByteZero)
        sta A1T0B
        
        stz DAS0L                       ; Tamanho do bloco: $010000 (64 KBytes)
        stz DAS0H
        lda #$01
        sta DAS0B
        
        sta MDMAEN                      ; Dispara o DMA
        rts
.endproc

;-------------------------------------------------------------------------------
;   Clear the complete CG-RAM to $00
;-------------------------------------------------------------------------------
.proc   ClearCGRAM
        stz CGADD                       
        
        ; DMA Canal 0: Limpa a paleta de cores
        lda #$0a                        ; Escrita de 2 bytes (passo duplo), endereço fixo
        sta DMAP0
        lda #$22                        ; Destino: CGDATA ($2122)
        sta BBAD0
        
        ; Aponta a origem para o ByteZero na ROM
        ldx #.loword(ByteZero)
        stx A1T0L
        lda #.bankbyte(ByteZero)
        sta A1T0B
        
        stz DAS0L                       ; Tamanho do bloco: 512 bytes ($0200)
        lda #$02
        sta DAS0H
        stz DAS0B
        
        lda #$01                        
        sta MDMAEN
        rts
.endproc

;-------------------------------------------------------------------------------
;   Clear the complete OAM-RAM to $ff (Move os sprites para fora da tela)
;-------------------------------------------------------------------------------
.proc   ClearOAMRAM
        stz OAMADDL                     
        stz OAMADDH
        
        ; DMA Canal 0: Preenche a OAM com $FF para desativar posições espúrias
        lda #$0a                        
        sta DMAP0
        lda #$04                        ; Destino: OAMDATA ($2104)
        sta BBAD0
        
        ; Aponta a origem para a constante ByteFF na ROM (Segurança Máxima)
        ldx #.loword(ByteFF)
        stx A1T0L
        lda #.bankbyte(ByteFF)
        sta A1T0B
        
        lda #$20                        ; Tamanho do bloco: 544 bytes ($0220)
        sta DAS0L
        lda #$02
        sta DAS0H
        stz DAS0B
        
        lda #$01                        
        sta MDMAEN
        rts
.endproc
