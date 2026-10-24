.p816
.a8

.segment "BSS"
rng_seed: .res 2    ; Apenas reserva os 2 bytes na RAM, sem inicializar dados aqui

.export rand
.export InitRNG     ; Exporta a nova rotina de inicialização

.code

; =========================================================================
; INICIALIZAR RNG
; Deve ser chamada uma única vez no boot do jogo (ex: no Init.s ou Main.s)
; =========================================================================
.proc InitRNG
    REP #$20        ; Acumulador de 16-bits
    .A16
    
    LDA #$ACE1      ; Carrega o valor inicial da semente
    STA a:rng_seed  ; Salva na memória RAM
    
    SEP #$20        ; Retorna Acumulador para 8-bits
    .A8
    RTS
.endproc

; =========================================================================
; GERAR RNG (LFSR de 16 bits)
; =========================================================================
.proc rand
GerarRNG:
    REP #$20            
    .A16                

    LDA a:rng_seed      
    LSR                 
    BCC @SemXOR         

    EOR #$B400          

@SemXOR:
    STA a:rng_seed      
    
    SEP #$20            
    .A8                 
    
    RTS                 
.endproc
