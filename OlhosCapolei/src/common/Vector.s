; -----------------------------------------------------------------------------
;   File: Vector.s (Corrigido - Erro de sintaxe resolvido)
;   Description: SNES ROM Header e Vetores Alinhados por Hardware
; -----------------------------------------------------------------------------

.p816                           ; Habilita instrucoes de 65816

;----- Imports -----------------------------------------------------------------
.import     ResetHandler        
.import     NMIHandler          
;-------------------------------------------------------------------------------

;----- Exports -----------------------------------------------------------------
.export     IRQHandler          
;-------------------------------------------------------------------------------

.segment "CODE"
; Rotina de IRQ padrao segura para preenchimento de vetores
.proc   IRQHandler
        rti                     
.endproc

; =============================================================================
;   SNES ROM HEADER - Localizado estritamente em $00FFC0
; =============================================================================
.segment "HEADER"

; $FFC0 - Nome do Jogo (21 bytes exatos)
.byte     "OLHOS CAPOLEI        "

; $FFD5 - Layout do Cartucho: $20 = LoROM, SlowROM
.byte     $20

; $FFD6 - Tipo de Cartucho: $00 = Apenas ROM
.byte     $00

; $FFD7 - Tamanho da ROM: $09 = 512KB (Corresponde a tela do Everdrive)
.byte     $09

; $FFD8 - Tamanho da RAM Extra (SRAM): $00 = Nenhuma
.byte     $00

; $FFD9 - Codigo do Pais: $01 = USA (NTSC)
.byte     $01

; $FFDA - Developer ID fixo em $33
.byte     $33

; $FFDB - Versao do Jogo: $00 (v1.0)
.byte     $00

; --- CHECKSUM VALIDO PARA HARDWARE REAL ---
; $FFDC: Complemento ($5A5A) e Checksum ($A5A5). A soma resulta em $FFFF.
.word     $5A5A, $A5A5            

; =============================================================================
;   VETORES DE INTERRUPCAO DO SNES - Inicia exatamente em $00FFE4
; =============================================================================
.segment "VECTOR"

; --- MODO NATIVO (65816 Native Mode - $FFE4 a $FFEF) ---
.addr     IRQHandler            ; $FFE4: COP
.addr     IRQHandler            ; $FFE6: BRK
.addr     IRQHandler            ; $FFE8: ABORT
.addr     NMIHandler            ; $FFEA: NMI (Sua rotina de V-Blank)
.addr     $0000                 ; $FFEC: RESET
.addr     IRQHandler            ; $FFEE: IRQ

; --- BYTES RESERVADOS DO HARDWARE ($FFF0 a $FFF3) ---
.word     $0000, $0000          

; --- MODO EMULACAO (6502 Emulation Mode - $FFF4 a $FFFF) ---
.addr     IRQHandler            ; $FFF4: COP
.addr     $0000                 ; $FFF6: Reservado
.addr     IRQHandler            ; $FFF8: ABORT
.addr     IRQHandler            ; $FFFA: NMI
.addr     ResetHandler          ; $FFFC: RESET (Onde o console inicia no Everdrive)
.addr     IRQHandler            ; $FFFE: IRQ/BRK
