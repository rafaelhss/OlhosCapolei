.p816
.a8
.i16

.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.INCLUDE "Util.inc"
.include "Init.inc"

.import  PennyCrab, VaderCrab
.import DengueCrab, RapaNuiCrab
.import Camera_X
.import Stage_Script_Ptr

.segment "RODATA"
; Formato de cada evento (8 bytes):
; .word Trigger_Cam_X  (Quando Camera_X chegar aqui, a rachadura aparece)
; .word Spawn_World_X  (Posição X no mundo onde o olho brota)
; .byte Spawn_World_Y  (Posição Y no chão: 96..159)
; .byte Enemy_Type     (ENEMY_TYPE_RAPA, VADER ou DENGUE)
; .byte Attack_Sector  (0, 1, 2 ou 3)
; .byte Spawn_Delay    (0 = pula quando o herói chegar perto! >0 = timer em frames)
.export Stage1_Script
Stage1_Script:
    ; Assim que o jogo começa (Cam_X = 0), já tem uma rachadura esperando em X = 180!
    .word 0, 180
    .byte 130, ENEMY_TYPE_DENGUE, $00, 0

    ; Quando o jogador andar até Cam_X = 120, outra rachadura aparece lá na frente em X = 350
    .word 120, 350
    .byte 110, ENEMY_TYPE_VADER, $01, 0

    ; Emboscada dupla em Cam_X = 300
    .word 300, 520
    .byte 140, ENEMY_TYPE_RAPA, $02, 0

    .word 300, 540
    .byte 105, ENEMY_TYPE_RAPA, $03, 90

    ; Fim da fase
    .word $FFFF


.segment "CODE"


.export UpdateStageDirector
.proc UpdateStageDirector
        ldy Stage_Script_Ptr
        
        ; 1. Lê Trigger_Cam_X (16-bit)
        rep #$20
        .a16
        lda a:0, y
        cmp #$FFFF                      ; Fim da tabela?
        beq @Done16
        cmp Camera_X                    ; Camera_X >= Trigger_Cam_X?
        beq @TriggerEvent
        bcs @Done16                     ; Ainda não chegou no ponto X da câmera

@TriggerEvent:
        sep #$20
        .a8
        ; 2. Procura um slot livre (STATE_DEAD) entre VaderCrab, DengueCrab e RapaNuiCrab
        ldx #.loword(VaderCrab)
        lda a:MeleeCrabStruct::State, x
        cmp #STATE_DEAD
        beq @SlotFound

        ldx #.loword(DengueCrab)
        lda a:MeleeCrabStruct::State, x
        cmp #STATE_DEAD
        beq @SlotFound

        ldx #.loword(RapaNuiCrab)
        lda a:MeleeCrabStruct::State, x
        cmp #STATE_DEAD
        beq @SlotFound

        ; Todos os 3 slots estão ocupados na tela! Espera um morrer.
        rts

@SlotFound:
        ; 3. Preenche o slot livre (X) com os dados da tabela da fase (Y)
        rep #$20
        .a16
        lda a:2, y                      ; Spawn_World_X
        sta a:MeleeCrabStruct::X_Pos, x
        sep #$20
        .a8

        lda a:4, y                      ; Spawn_World_Y
        sta a:MeleeCrabStruct::Y_Pos, x

        lda a:5, y                      ; Enemy_Type
        sta a:MeleeCrabStruct::Enemy_Type, x

        lda a:6, y                      ; Attack_Sector
        sta a:MeleeCrabStruct::Attack_Sector, x

        lda a:7, y                      ; Spawn_Delay
        sta a:MeleeCrabStruct::Spawn_Delay, x

        ; Inicializa os timers e coloca no estado STATE_PRE_SPAWN!
        phy
        jsr SetupPreSpawnMeleeStats     ; Você já criou essa rotina no Init.s! (lembre de dar .export nela)
        ply

        ; 4. Avança Stage_Script_Ptr em 8 bytes para o próximo evento da fase
        rep #$20
        .a16
        lda Stage_Script_Ptr
        clc
        adc #8
        sta Stage_Script_Ptr
@Done16:
        sep #$20
        .a8
        rts
.endproc

