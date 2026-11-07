; ---------------- -------------------------------------------------------------
;   File: VaderCrab.s
;   Description: Subroutines to move VaderCrab
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     MoveVaderCrab
.export     DrawVaderCrab
.export     DrawVaderHitboxDebug

;-------------------------------------------------------------------------------

;----- Assembler Directives ----------------------------------------------------
.p816                           ; tell the assembler this is 65816 code
.a8
.i16
;-------------------------------------------------------------------------------

;----- Includes ----------------------------------------------------------------
.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.include "Util.inc"
;-------------------------------------------------------------------------------

.import VaderCrab
.import BigHero
.import FrameCounter


WALK_SPEED = $01
WALK_ANIM_SPEED = $08 ; quanto menor mais rapido

PREPARING_ANIM_SPEED = 30
PREPARING_DURATION_FRAMES = 89
PREPARING_MAX_FRAMES = 3

;attackin speed e frames. Se for iguais o ataque tem 1 frame. Se forem um metade do outro, dois frames. e assim vai
ATTACKING_ANIM_SPEED = 15   
ATTACKING_DURATION_FRAMES = 45
ATTACK_MAX_FRAMES = 2  ; Altere este número para quantos frames a arte tiver! (3, 4, 5...)

REST_TIME = 30 ;  

.segment "CODE"
;-------------------------------------------------------------------------------
;   This subroutines move enemy
;-------------------------------------------------------------------------------
.proc   MoveVaderCrab
    ; 1. Reduz o timer de animacao
 
    lda VaderCrab + VaderCrabStruct::HurtTimer
    beq @ProcessIA                  ; Se for 0, o Vader está livre para agir e pensar
    
    dec VaderCrab + VaderCrabStruct::HurtTimer ; Decrementa o tempo travado de dano
    brl Done   


@CheckFrameFilter:
    ; Filtro de velocidade: Só se move a cada 2 frames (Velocidade 0.5px)
    lda FrameCounter
    and #%00000001          ; Testa o bit 0 do contador de frames
    beq @ProcessIA          ; Se for frame par (0), vai processar a IA normalmente
    brl Done                ; Se for frame ímpar (1), dá um salto longo seguro até o fim da rotina!



@ProcessIA:
AttackFrameUpdate:
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_ATACKING
    beq @ProcessandoAtaque
    brl PreparingFrameUpdate ; se nao esta atacando, vai ver a animacao de prepare

@ProcessandoAtaque:  
    inc VaderCrab + VaderCrabStruct::Attacking_Timer
    lda VaderCrab + VaderCrabStruct::Attacking_Timer
    cmp #ATTACKING_DURATION_FRAMES
    bne AttackingAnim

    ; --- ACABOU O ATAQUE: Desativa a Hitbox de Dano ---
    lda #$00
    sta VaderCrab + VaderCrabStruct::Hitbox_Active  

    ; --- TRANSIÇÃO PARA COOLDOWN (EVITA SPAM DE GOLPE) ---
    ; Em vez de voltar direto pro prepare, força o estado WALKING 
    ; para ele se reajustar no cenário antes de tentar focar o herói de novo!
    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    
    ; Carrega o timer de descanso para ele ficar "pensando" por 60 frames antes de agir
    lda #60
    sta VaderCrab + VaderCrabStruct::Resting_Timer

    ; Sanitização de contadores antigos
    stz VaderCrab + VaderCrabStruct::Attacking_Timer
    stz VaderCrab + VaderCrabStruct::Attacking_Anim_Frame
    stz VaderCrab + VaderCrabStruct::Attacking_Anim_Timer
    stz VaderCrab + VaderCrabStruct::Preparing_Timer
    stz VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
    stz VaderCrab + VaderCrabStruct::Preparing_Anim_Timer

    brl Move 



AttackingAnim:
    dec VaderCrab + VaderCrabStruct::Attacking_Anim_Timer
    beq ContinueAttackAnim ;gambiarra para erro de range
    brl Move ; Se nao chegou a zero, nao faz nada ainda.
ContinueAttackAnim:
    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #ATTACKING_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta VaderCrab + VaderCrabStruct::Attacking_Anim_Timer
    
   ; 2. Avança de forma linear para o próximo frame
    lda VaderCrab + VaderCrabStruct::Attacking_Anim_Frame
    clc
    adc #1                          ; Incrementa o ID do frame (+1)
    
    ; 3. COMPARAÇÃO COM O TETO (Módulo Dinâmico)
    cmp #ATTACK_MAX_FRAMES          ; Checa se atingiu o limite de N frames da arte
    bcc @SaveFrame                  ; Se for MENOR, pula o reset e salva direto
    
    lda #0                          ; Se for IGUAL, estourou a animação! Reseta para o frame 0

@SaveFrame:
    sta VaderCrab + VaderCrabStruct::Attacking_Anim_Frame

@AtualizarHitbox:
    ; =========================================================================
    ; 🦀 GERADOR DINÂMICO DE HITBOX (CONCEITO DE CAIXA DE COLISÃO)
    ; =========================================================================
    ; Só queremos ativar o rastro de dano no Frame 1 (quando ele realmente estica a garra)
    lda VaderCrab + VaderCrabStruct::Attacking_Anim_Frame
    cmp #1
    beq @AtivarHitbox
    
    ; Se for Frame 0 (recolhendo a garra), desativa a hitbox temporariamente
    stz VaderCrab + VaderCrabStruct::Hitbox_Active
    brl Move


    ;brl Move ;Ataquei Pulo o prepare e vejo se o hero fugiu

@AtivarHitbox:
    lda #1
    sta VaderCrab + VaderCrabStruct::Hitbox_Active

    ; --- 1. Definir os limites Verticais (Eixo Y) ---
    ; A garra atinge a altura do corpo dele. Vamos pegar o Y dele e dar uma altura de 16 pixels
    lda VaderCrab + VaderCrabStruct::Y_Pos
    clc
    adc #16                             ; Margem superior da garra
    sta VaderCrab + VaderCrabStruct::Hitbox_Y1
    clc
    adc #16                             ; Caixa com 16 pixels de altura vertical
    sta VaderCrab + VaderCrabStruct::Hitbox_Y2

    ; --- 2. Definir os limites Horizontais (Eixo X) com base no Lado (Facing) ---
    lda VaderCrab + VaderCrabStruct::Facing
    bne @HitboxDireita                  ; Se Facing != 0 (Olhando para a Direita)

@HitboxEsquerda:
    ; Se está olhando para a esquerda, a garra projeta-se à esquerda do X_Pos dele
    lda VaderCrab + VaderCrabStruct::X_Pos
    sec
    sbc #32                            ; A garra estica 16 pixels para fora do corpo dele
    sta VaderCrab + VaderCrabStruct::Hitbox_X1
    
    lda VaderCrab + VaderCrabStruct::X_Pos ; O limite direito da garra morre no próprio corpo
    sta VaderCrab + VaderCrabStruct::Hitbox_X2
    brl Move

@HitboxDireita:
    ; Se está olhando para a direita, a garra projeta-se à direita do corpo de 64px de largura
    lda VaderCrab + VaderCrabStruct::X_Pos
    clc
    adc #64                             ; Começa perto do fim do corpo
    sta VaderCrab + VaderCrabStruct::Hitbox_X1
    clc
    adc #32                             ; Estica mais 24 pixels para a direita
    sta VaderCrab + VaderCrabStruct::Hitbox_X2
    brl Move

PreparingFrameUpdate:
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_PREPARING
    bne WalkFrameUpdate ; se nao esta Preparando, vai ver a animacao de andar
    ;aqui vou colocar o codigo para PreparingFrameUpdate
    
    inc VaderCrab + VaderCrabStruct::Preparing_Timer
    lda VaderCrab + VaderCrabStruct::Preparing_Timer
    cmp #PREPARING_DURATION_FRAMES
    bne PreparingAnim
 
    lda #STATE_ATACKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer
    stz VaderCrab + VaderCrabStruct::Attacking_Anim_Frame ; Começa estritamente no frame 0
    
    stz VaderCrab + VaderCrabStruct::Attacking_Timer
    lda #ATTACKING_ANIM_SPEED
    sta VaderCrab + VaderCrabStruct::Attacking_Anim_Timer

    brl Done

PreparingAnim:
    dec VaderCrab + VaderCrabStruct::Preparing_Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda

    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #PREPARING_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta VaderCrab + VaderCrabStruct::Preparing_Anim_Timer
    
   ; 2. Avança de forma linear para o próximo frame
    lda VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
    clc
    adc #1                          ; Incrementa o ID do frame (+1)
    
    ; 3. COMPARAÇÃO COM O TETO (Módulo Dinâmico)
    cmp #PREPARING_MAX_FRAMES          ; Checa se atingiu o limite de N frames da arte
    bcc @SaveFramePrep                  ; Se for MENOR, pula o reset e salva direto
    
    lda #0                          ; Se for IGUAL, estourou a animação! Reseta para o frame 0

@SaveFramePrep:
    sta VaderCrab + VaderCrabStruct::Preparing_Anim_Frame




 WalkFrameUpdate:
    ; 1. Decrementa o timer do descanso direto na memória RAM
    DEC VaderCrab + VaderCrabStruct::Resting_Timer
    ; 2. Checa o resultado usando a Negative Flag (N) que o DEC acabou de afetar
    BMI ContinueWalkFrameUpdate
    BRL RestFrameUpdate    ; Se N=0 (Valores de 127 a 0), pula para a rotina de descanso
    
   
 ContinueWalkFrameUpdate:
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_WALKING
    bne Move 

    dec VaderCrab + VaderCrabStruct::Anim_Timer
    bne Move ; Se nao chegou a zero, nao faz nada ainda
    
    ; 2. O timer zerou! Reseta o timer para o valor padrao
    lda #WALK_ANIM_SPEED ; Ajuste este valor para mais rapido ou mais lento
    sta VaderCrab + VaderCrabStruct::Anim_Timer
    
    ; 3. Alterna o Frame (Se era 0 vira 1, se era 1 vira 0)
    lda VaderCrab + VaderCrabStruct::Anim_Frame
    eor #$01 ; Logica XOR inverte o bit 0 perfeitamente (0 <-> 1)
    sta VaderCrab + VaderCrabStruct::Anim_Frame

;=== logica para mover
;=== logica para mover
Move:

    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_ATACKING
    bne ContinuaFisicaNormal
    jmp Done                        ; Vai direto para o fim da rotina sem olhar mais nada!

ContinuaFisicaNormal:
    ; 1. Calcular a distância absoluta em X: |VaderCrab_X - BigHero_X|
    lda VaderCrab + VaderCrabStruct::X_Pos
    clc
    adc #16                          ; Ajusta o centro do VaderCrab em relação ao Hero. Hero 16, Vader 32. Dist = Vader + 32 - Hero + 16 -> Dist = Vader + 16
    sec
    sbc BigHero + BigHeroStruct::X_Pos
    bcs CalculateAbsoluteDistance   ; Se VaderCrab_X >= BigHero_X, o resultado já é positivo

    ; Se for negativo, aplica o complemento de 2 para positivar o valor (Módulo)
    eor #$FF                
    clc
    adc #1                  

CalculateAbsoluteDistance:   
    ; Agora o Acumulador contém a distância real em pixels no eixo X
    cmp #ENEMY_ATTACK_DISTANCE
    bcc StopHorizontalMove  ; Se a distância for MENOR que a de ataque, PARA de andar em X
    beq StopHorizontalMove  ; Se for IGUAL, também PARA e fica na distância ideal

    ; Se a distância for maior que o alcance, decide para qual lado andar
    lda VaderCrab + VaderCrabStruct::X_Pos
    cmp BigHero + BigHeroStruct::X_Pos
    bcc WalkRight           ; Se VaderCrab_X < BigHero_X, vai para a direita

WalkLeft:
    sec
    sbc #WALK_SPEED                 ; Move 1 pixel por frame para a esquerda
    sta VaderCrab + VaderCrabStruct::X_Pos
    
    ;lda #WALK_ANIM_SPEED
    ;sta VaderCrab + VaderCrabStruct::Walk_Anim_Speed
    stz VaderCrab + VaderCrabStruct::Facing ;Olhando para a esquerda

    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer

    bra CheckVerticalMove
    
WalkRight:
    clc
    adc #WALK_SPEED                  ; Move 1 pixel por frame para a direita
    sta VaderCrab + VaderCrabStruct::X_Pos
    
    ;lda #WALK_ANIM_SPEED
    ;sta VaderCrab + VaderCrabStruct::Walk_Anim_Speed
    lda #1
    sta VaderCrab + VaderCrabStruct::Facing ;Olhando para a direita
    
    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer

    bra CheckVerticalMove

StopHorizontalMove:
    ; Se já estiver atacando ou preparando, não mexe no estado!
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_ATACKING
    beq @KeepStateX
    cmp #STATE_PREPARING
    beq @KeepStateX
    
    lda #STATE_PREPARING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer

    stz VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
    lda #PREPARING_ANIM_SPEED
    sta VaderCrab + VaderCrabStruct::Preparing_Anim_Timer

@KeepStateX:
    bra CheckVerticalMove

CheckVerticalMove:

    ; === Alinhamento no Eixo Y com tolerancia===
     ; === 1. Calcular a distância absoluta em Y: |VaderCrab_Y - BigHero_Y|
    lda VaderCrab + VaderCrabStruct::Y_Pos
    sec
    sbc BigHero + BigHeroStruct::Y_Pos
    bcs CalculateAbsoluteY          ; Se VaderCrab_Y >= BigHero_Y, o resultado já é positivo

    ; Se for negativo, aplica o complemento de 2 para positivar o valor (Módulo)
    eor #$FF                
    clc
    adc #1 

CalculateAbsoluteY:
    ; Agora o Acumulador contém a distância vertical exata em pixels
    cmp #ENEMY_ATTACK_Y_RANGE
    bcc StopVerticalMove            ; Se a distância for MENOR que o range, o Y está alinhado!
    beq StopVerticalMove            ; Se for IGUAL ao range, também está alinhado e PARA

    ; === 2. Fora do Range: Decidir se deve subir ou descer ===
    lda VaderCrab + VaderCrabStruct::Y_Pos
    cmp BigHero + BigHeroStruct::Y_Pos    
    bcc MoveDown                    ; Se VaderCrab_Y < BigHero_Y, ele está acima, então desce (+1)


    lda VaderCrab + VaderCrabStruct::Y_Pos
    cmp BigHero + BigHeroStruct::Y_Pos    
    beq ExitMovement        ; Se igual, mantém
    bcc MoveDown            ; Se VaderCrab_Y < BigHero_Y, ele está ACIMA, então deve DESCER (+1)

MoveUp:
    sec
    sbc #WALK_SPEED                  ; Está abaixo, então SOBE (-1) em direção ao herói
    sta VaderCrab + VaderCrabStruct::Y_Pos
    
    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer
    bra ExitMovement
    
MoveDown:
    clc
    adc #WALK_SPEED                  ; Está acima, então DESCE (+1) em direção ao herói
    sta VaderCrab + VaderCrabStruct::Y_Pos
    
    lda #STATE_WALKING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer
    bra ExitMovement
    
StopVerticalMove:
    ; O Y está perfeitamente dentro da janela de ataque! 
    ; Não altera a posição Y neste frame, mantendo o inimigo estável na linha.

    ; Se já estiver atacando ou preparando, mantém o fluxo intacto e não deixa reverter para WALKING
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_ATACKING
    beq Done
    cmp #STATE_PREPARING
    beq Done

    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_WALKING
    beq ExitMovement

    lda #STATE_PREPARING
    sta VaderCrab + VaderCrabStruct::State
    stz VaderCrab + VaderCrabStruct::Preparing_Timer
    
    stz VaderCrab + VaderCrabStruct::Preparing_Anim_Frame
    lda #PREPARING_ANIM_SPEED
    sta VaderCrab + VaderCrabStruct::Preparing_Anim_Timer

ExitMovement:
    lda VaderCrab + VaderCrabStruct::State
    cmp #STATE_WALKING
    bne Done
    lda #WALK_ANIM_SPEED
    sta VaderCrab + VaderCrabStruct::Walk_Anim_Speed
    bra Done

RestFrameUpdate:
    ;decrementa mais, para ficar mais tempo andando que descansando
    DEC VaderCrab + VaderCrabStruct::Resting_Timer
    
    jsr rand            ; Chama a sua rotina aleatória. Retorna valor em A (8-bits ativo aqui)
    and #$10            ; Isola o primeiro bit (Resultado será apenas 0 ou 1)
    beq RestFrameUpdate ; Se for 1 (50% de chance), ele desiste do ataque neste ciclo!

    
    lda #STATE_RESTING
    sta VaderCrab + VaderCrabStruct::State
    
    bra Done

DesistirMover:
Done:
    jsr UpdateVaderGeometry
    rts
               
                               
.endproc



.proc UpdateVaderGeometry
        lda VaderCrab + VaderCrabStruct::X_Pos
        sta VaderCrab + VaderCrabStruct::Hurtbox_X1
        clc
        adc #48                             ; Aumentado para 48px para casar com a arte do caranguejo grande
        sta VaderCrab + VaderCrabStruct::Hurtbox_X2

        lda VaderCrab + VaderCrabStruct::Y_Pos
        sta VaderCrab + VaderCrabStruct::Hurtbox_Y1
        clc
        adc #64                             ; Altura real dos 4 blocos verticais (4 * 16px = 64)
        sta VaderCrab + VaderCrabStruct::Hurtbox_Y2
        rts
.endproc
;-------------------------------------------------------------------------------

; Formato por linha: Offset_X, Offset_Y, Tile_ID, Atributos(Paleta/Flip)
; =============================================================================
; BANCO DE MATRIZES DE ANIMAÇÃO DO VADERCRAB
; =============================================================================
; FRAME: Neutro / Parado
VaderCrab_Layout:
    .byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$06,$01
    .byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$26,$01
    .byte 0, 32,$40,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$46,$01
    .byte 0, 48,$60,$01, 16, 48,$62,$01, 32, 48,$64,$01, 48, 48,$66,$01

; FRAME: Andando
VaderCrab_Layout_Frame1:
    .byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$06,$01
    .byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$26,$01
    .byte 0, 32,$48,$01, 16, 32,$42,$01, 32, 32,$44,$01, 48, 32,$4E,$01
    .byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01

; FRAME: Tomando Dano / Hitstun (Cabeça e olhos mudam para os blocos $08-$0E)
VaderCrab_Layout_Hurt:
    .byte 0,  10,$00,$01, 16,  10,$02,$01, 32,  10,$04,$01, 48,  10,$06,$01
    .byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$26,$01
    .byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
    .byte 0, 48,$68,$01, 16, 48,$6A,$01, 32, 48,$6C,$01, 48, 48,$6E,$01


; =============================================================================
; FRAME 0: INIMIGO Preparing 
; =============================================================================
VaderCrab_Layout_FramePreparing0:
    .byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$06,$01
    .byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$26,$01
    .byte 0, 32,$48,$01, 16, 32,$4A,$01, 32, 32,$4C,$01, 48, 32,$4E,$01
    .byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01

; =============================================================================
; FRAME 1: INIMIGO Preparing 
; =============================================================================
VaderCrab_Layout_FramePreparing1:
    .byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$06,$01
    .byte 0, 16,$20,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$26,$01
    .byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
    .byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01


; =============================================================================
; FRAME 2: INIMIGO Preparing 
; =============================================================================
VaderCrab_Layout_FramePreparing2:
 .byte 0,  0,$00,$01, 16,  0,$02,$01, 32,  0,$04,$01, 48,  0,$06,$01
    .byte 0, 16,$80,$01, 16, 16,$22,$01, 32, 16,$24,$01, 48, 16,$26,$01
    .byte 0, 32,$A0,$01, 16, 32,$A2,$01, 32, 32,$A4,$01, 48, 32,$A6,$01
    .byte 0, 48,$C0,$01, 16, 48,$C2,$01, 32, 48,$C4,$01, 48, 48,$C6,$01






; =============================================================================
; FRAME 0: INIMIGO Attacking 
; =============================================================================
VaderCrab_Layout_FrameAttacking0:
   .byte 0,  0,$00,$01, 16,  0,$0A,$01, 32,  0,$0C,$01, 48,  0,$06,$01
    .byte 0, 16,$80,$01, 16, 16,$2A,$01, 32, 16,$2C,$01, 48, 16,$26,$01
     .byte 0, 32,$A0,$31, 16, 32,$A2,$31, 32, 32,$A4,$31, 48, 32,$A6,$31
    .byte 0, 48,$C0,$31, 16, 48,$C2,$31, 32, 48,$C4,$31, 48, 48,$C6,$31




; =============================================================================
; FRAME 1: INIMIGO Attacking 
; =============================================================================
VaderCrab_Layout_FrameAttacking1:
    .byte 0,  0,$00,$01, 16,  0,$0A,$01, 32,  0,$0C,$01, 48,  0,$06,$01
    .byte 0, 16,$20,$01, 16, 16,$2A,$01, 32, 16,$2C,$01, 48, 16,$8E,$01
    .byte 0, 32,$A8,$01, 16, 32,$AA,$01, 32, 32,$AC,$01, 48, 32,$AE,$01
    .byte 0, 48,$C8,$01, 16, 48,$CA,$01, 32, 48,$CC,$01, 48, 48,$CE,$01



;-------------------------------------------------------------------------------
;   DrawVaderCrab
;-------------------------------------------------------------------------------
.proc DrawVaderCrab
        ; 1. Transiciona temporariamente o acumulador para 16-bit para ler o endereço completo
        rep #$20                        
        .a16
        
        lda 3,s                         ; Carrega o endereço de 16-bit da Struct direto da pilha
        tay                             ; Transfere instantaneamente para o registrador Y!

        ; Retorna o acumulador para 8-bit, pois o restante do jogo usa .a8
        sep #$20                        
        .a8
        
        ; 2. Salva uma cópia rápida (Cache) dos dados da Struct para a Direct Page
        ; Agora o Y está carregado perfeitamente com o endereço correto da WRAM
        lda a:VaderCrabStruct::X_Pos, y
        sta z:DP_ENEMY_X
        
        lda a:VaderCrabStruct::Y_Pos, y
        sta z:DP_ENEMY_Y
        
        lda a:VaderCrabStruct::Facing, y
        sta z:DP_ENEMY_FACING


        ; 3. MÁQUINA DE ESTADOS: Decide qual Layout Gráfico usar
        lda a:VaderCrabStruct::HurtTimer, y
        beq @CheckStates

        ldy #.loword(VaderCrab_Layout_Hurt)
        bra @SaveLayout

@CheckStates:
        lda a:VaderCrabStruct::State, y
        cmp #STATE_PREPARING
        bne @CheckAttacking

        ; --- Estado: Preparando Ataque ---
        lda a:VaderCrabStruct::Preparing_Anim_Frame, y
        cmp #1
        beq @Prep1
        cmp #2
        beq @Prep2
@Prep0: 
        ldy #.loword(VaderCrab_Layout_FramePreparing0) 
        bra @SaveLayout
@Prep1: 
        ldy #.loword(VaderCrab_Layout_FramePreparing1) 
        bra @SaveLayout
@Prep2: 
        ldy #.loword(VaderCrab_Layout_FramePreparing2) 
        bra @SaveLayout

@CheckAttacking:
        cmp #STATE_ATACKING
        bne @CheckWalking

        ; --- Estado: Atacando ---
        lda a:VaderCrabStruct::Attacking_Anim_Frame, y
        bne @Attack1
@Attack0: 
        ldy #.loword(VaderCrab_Layout_FrameAttacking0) 
        bra @SaveLayout
@Attack1: 
        ldy #.loword(VaderCrab_Layout_FrameAttacking1) 
        bra @SaveLayout

@CheckWalking:
        ; --- Estado Padrão: Caminhada / Idle ---
        lda a:VaderCrabStruct::Anim_Frame, y
        bne @Walk1
@Walk0: 
        ldy #.loword(VaderCrab_Layout)
        bra @SaveLayout
@Walk1: 
        ldy #.loword(VaderCrab_Layout_Frame1)

@SaveLayout:
        sty z:DP_VADER_LAYOUT_PTR

        ; 4. Dispara o motor isolado de renderização de sprites
        jsr RenderVaderSprites
        rts
.endproc


;-------------------------------------------------------------------------------
;   RenderVaderSprites (Motor de Desenho Otimizado e Purificado)
;   X = Indexador OAM (Preservado do Main)
;   Y = Indexador Layout (Inicia em 0 e vai até 64)
;-------------------------------------------------------------------------------
.proc RenderVaderSprites
        ldy #$0000              ; Inicializa Y estritamente para andar na matriz do layout

@DrawLoop:
        ; === 1. PROCESSAR POSIÇÃO X COM ESPELHAMENTO ===
        lda z:DP_ENEMY_FACING
        bne @DrawXNormal         

@DrawXInverted:
        lda #48
        sec
        sbc (DP_VADER_LAYOUT_PTR), y 
        clc
        adc z:DP_ENEMY_X
        sta OAMMIRROR, x
        bra @ProcessY

@DrawXNormal:
        lda (DP_VADER_LAYOUT_PTR), y
        clc
        adc z:DP_ENEMY_X
        sta OAMMIRROR, x                          

@ProcessY:
        inx                                       
        iny                     ; Aponta para o Offset Y no Layout

        ; === 2. PROCESSAR POSIÇÃO Y ===
        lda (DP_VADER_LAYOUT_PTR), y
        clc
        adc z:DP_ENEMY_Y
        sta OAMMIRROR, x                          
        
        inx
        iny                     ; Aponta para o Tile ID no Layout

        ; === 3. PROCESSAR TILE ID ===
        lda (DP_VADER_LAYOUT_PTR), y
        sta OAMMIRROR, x
        
        inx
        iny                     ; Aponta para os Atributos no Layout

        ; === 4. PROCESSAR ATRIBUTOS E INJETAR H-FLIP HIERÁRQUICO ===
        lda (DP_VADER_LAYOUT_PTR), y
        sta z:DP_TEMP_00        ; Guarda os atributos originais do Layout
        
        lda z:DP_ENEMY_FACING   ; Testamos o Facing direto no Acumulador para manter Y intocado
        bne @NoFlip             
        
        lda z:DP_TEMP_00
        eor #%01000000          ; Aplica o Flip se for Esquerda (Facing = 0)
        sta z:DP_TEMP_00

@NoFlip:
        lda z:DP_TEMP_00
        sta OAMMIRROR, x        
        inx
        
        iny                     ; Avança Y para o início do próximo bloco de 4 bytes
        cpy #64                 ; Processou todos os 16 sub-sprites (16 * 4 = 64 bytes)?
        bne @DrawLoop 

        rts
.endproc


;---------------- DEBUG ---------------
.proc DrawVaderHitboxDebug
    ; Primeiro, checa se a hitbox está ativa. Se não estiver, não desenha nada!
    ;lda VaderCrab + VaderCrabStruct::Hitbox_Active
    ;bne @Desenhar
    ;rts

@Desenhar:
    ; --- SPRITE 1 (Lado Esquerdo da Hitbox) ---
    ; Posição X
    lda VaderCrab + VaderCrabStruct::Hitbox_X1
    sta a:OAMMIRROR, X
    inx
    
    ; Posição Y
    lda VaderCrab + VaderCrabStruct::Hitbox_Y1
    sta a:OAMMIRROR, X
    inx
    
    ; Tile ID (Substitua por um ID de tile quadrado do seu jogo)
    lda #$A0            ; Exemplo: tile $FE é um quadrado vermelho/branco
    sta a:OAMMIRROR, X
    inx
    
    ; Atributos (Paleta de debug para ficar visível)
    lda #$31      ; Escolha uma paleta com cor forte (ex: Paleta 4, prioridade alta)
    sta a:OAMMIRROR, X
    inx

    ; --- SPRITE 2 --
    ; Posição X
    lda VaderCrab + VaderCrabStruct::Hitbox_X2
    ;sec
    ;sbc #16
    sta a:OAMMIRROR, X
    inx
    
    ; Posição Y (Mesmo Y)
    lda VaderCrab + VaderCrabStruct::Hitbox_Y2
    sta a:OAMMIRROR, X
    inx
    
    ; Mesmo Tile ID
    lda #$A2            
    sta a:OAMMIRROR, X
    inx
    
    ; Mesmo Atributo
    lda #$31      
    sta OAMMIRROR, X    
    inx

    rts
.endproc


;------------FIM DEBUG -------------