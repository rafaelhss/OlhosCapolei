; -----------------------------------------------------------------------------
;   File: Joypad.s (Corrigido - Variáveis do Controle 2 Removidas)
;   Description: Subroutines to read the current state of the joypads
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     ReadJoypad1
.export     ReadJoypad2
;-------------------------------------------------------------------------------

;----- Assembler Directives ----------------------------------------------------
.p816                           ; tell the assembler this is 65816 code
.a8                             ; Registrador A em 8-bit padrão
.i16                            ; Registradores X e Y fixos em 16-bit
;-------------------------------------------------------------------------------

;----- Includes ----------------------------------------------------------------
.include "MemoryMapWRAM.inc"
.include "Registers.inc"
;-------------------------------------------------------------------------------

.segment "CODE"
;-------------------------------------------------------------------------------
;   Read and update the state of joypad 1
;   Acessa diretamente as globais de WRAM sem poluir a pilha (Stack-less pipeline)
; -----------------------------------------------------------------------------
.proc   ReadJoypad1
        ; 1. Garante que o hardware do SNES terminou a leitura automática dos pinos
WaitForJoypad:
        lda HVBJOY                          ; get joypad status da PPU
        and #$01                            ; check whether joypad done reading...
        bne WaitForJoypad                   ; Se bit 0 for 1, o SNES ainda está varrendo elétricamente. Espera zerar.

        ; 2. Calcula as transições de estado usando registros de 16-bit
        rep #$20                            ; Abre o acumulador A para 16-bit completo
        
        lda JOYRAW1                         ; Pega os botões armazenados no FRAME ANTERIOR
        tay                                 ; Transfere temporariamente para Y para usarmos de máscara histórica
        
        lda JOY1L                           ; Pega a leitura elétrica atualizada (Bruta) que o SNES acabou de cuspir
        sta JOYRAW1                         ; Atualiza o buffer global RAW atual
        sta JOYHELD1                        ; O estado bruto atual É o estado de botões sendo segurados (Held)

        ; 3. EQUAÇÃO DE COMPUTAÇÃO DO TRIGGER (Botão clicado JUSTAMENTE neste frame)
        ; Fórmula estável: Trigger = Raw_Atual AND (NOT Held_Anterior)
        tya                                 ; Resgata o frame anterior (armazenado em Y)
        eor #$FFFF                          ; Aplica operador NOT em todos os 16-bits invertendo o estado anterior
        and JOYRAW1                         ; Compara com o Raw atual (AND)
        sta JOYTRIGGER1                     ; Salva o resultado no buffer global de clicks de botão

        sep #$20                            ; RETORNA OBRIGATORIAMENTE o acumulador para 8-bit (.a8)
        rts
.endproc
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;   Read and update the state of joypad 2 (Vazia/Segura para 1-Player)
; -----------------------------------------------------------------------------
.proc   ReadJoypad2
        ; Deixada vazia e segura por enquanto para evitar erros de símbolos indefindos 
        ; de variáveis do player 2 que não estão declaradas no seu MemoryMapWRAM.inc
        rts
.endproc
;-------------------------------------------------------------------------------
