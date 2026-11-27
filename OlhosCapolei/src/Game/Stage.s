.p816
.a8
.i16

.include "GameConstants.inc"
.include "MemoryMapWRAM.inc"
.INCLUDE "Util.inc"
.include "Init.inc"



.import  PennyCrab, VaderCrab
.import DengueCrab, RapaNuiCrab
.import WeaponA, WeaponB, WeaponC, WeaponD, WeaponE
.import SetupWeaponStats
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

    ; Arma logo no início (Cam_X = 0) em X = 120, Y = 150:
    ; Byte 5 = SPAWN_KIND_WEAPON | WEAPON_ID_*
    ; Byte 6 = Tile_ID ($6D = Pedra, $06 = Pau/Pistola/Corrente, $0E = Martelo)
    ; Byte 7 = Tile_Size / Layout ($01 = 1x1/2x2, $04 = 1x4 horizontal, ou WEAPON_LAYOUT_*)
    .word 0, 120
    .byte 150, (SPAWN_KIND_WEAPON | WEAPON_ID_ROCK), $6D, $01

    ; Pedra no chão (Cam_X = 0): Single-tile -> Tile_ID = $6D, Tile_Size = 1
    .word 0, 220
    .byte 200, (SPAWN_KIND_WEAPON | WEAPON_ID_HAMMER), $0E, $01

     .word 0, 210
    .byte 165, (SPAWN_KIND_WEAPON | WEAPON_ID_WOOD), $00, $04


    .word 0, 310
    .byte 200, (SPAWN_KIND_WEAPON | WEAPON_ID_CHAIN), $00, $04

    .word 0, 410
    .byte 165, (SPAWN_KIND_WEAPON | WEAPON_ID_PISTOL), $00, $04

    .word 0, 510
    .byte 165, (SPAWN_KIND_WEAPON | WEAPON_ID_HAMMER), $00, $04


    ; Quando o jogador andar até Cam_X = 120, outra rachadura aparece lá na frente em X = 350
    .word 120, 140
    .byte 110, ENEMY_TYPE_VADER, $01, 0

    ; Emboscada dupla em Cam_X = 300
    .word 300, 320
    .byte 140, ENEMY_TYPE_RAPA, $02, 0

    .word 300, 360
    .byte 105, ENEMY_TYPE_RAPA, $03, 90



    ; Fim da fase
    .word $FFFF


.export Stage2_Script
Stage2_Script:
    ; Fase 2 (Anoitecer): Já começa com dois inimigos brotando!
    .word 0, 160
    .byte 120, ENEMY_TYPE_VADER, $00, 0


    .word 0, 210
    .byte 145, ENEMY_TYPE_RAPA, $01, 60

    ; Arma logo no início (Cam_X = 0) em X = 120, Y = 150:
    ; Byte 5 = SPAWN_KIND_WEAPON | WEAPON_ID_*
    ; Byte 6 = Tile_ID ($6D = Pedra, $06 = Pau/Pistola/Corrente, $0E = Martelo)
    ; Byte 7 = Tile_Size / Layout ($01 = 1x1/2x2, $04 = 1x4 horizontal, ou WEAPON_LAYOUT_*)
    .word 0, 120
    .byte 150, (SPAWN_KIND_WEAPON | WEAPON_ID_ROCK), $6D, $01

    ; Pedra no chão (Cam_X = 0): Single-tile -> Tile_ID = $6D, Tile_Size = 1
    .word 0, 220
    .byte 150, (SPAWN_KIND_WEAPON | WEAPON_ID_HAMMER), $0E, $01

     .word 0, 210
    .byte 165, (SPAWN_KIND_WEAPON | WEAPON_ID_WOOD), $00, $04


    .word 0, 310
    .byte 165, (SPAWN_KIND_WEAPON | WEAPON_ID_CHAIN), $00, $04

    .word 0, 410
    .byte 165, (SPAWN_KIND_WEAPON | WEAPON_ID_PISTOL), $00, $04

    .word 0, 510
    .byte 165, (SPAWN_KIND_WEAPON | WEAPON_ID_HAMMER), $00, $04



    .word 150, 380
    .byte 115, ENEMY_TYPE_DENGUE, $02, 0



    .word $FFFF

.export Stage_Scripts_Table
Stage_Scripts_Table:
    .word .loword(Stage1_Script)
    .word .loword(Stage2_Script)

; Paleta da Fase 2 (Anoitecer - 64 bytes igual a Test_BG_Palettes)
; Os primeiros 2 bytes ($00 da CGRAM) definem a cor do céu!
.export Stage2_Sky_Color
Stage2_Sky_Color:
    .word $2406                         ; Azul-arroxeado escuro (Anoitecer)





.segment "CODE"


.export UpdateStageDirector
.proc UpdateStageDirector
        ldy Stage_Script_Ptr
        
        ; 1. Lê Trigger_Cam_X (16-bit)
        rep #$20
        .a16
        lda a:0, y
        cmp #$FFFF                      ; Fim da tabela?
        bne @CheckCam
        jmp @Done16

@CheckCam:
        cmp Camera_X                    ; Camera_X >= Trigger_Cam_X?
        beq @TriggerEvent
        bcc @TriggerEvent
        jmp @Done16                     ; Ainda não chegou no ponto X da câmera

@TriggerEvent:

        sep #$20
        .a8
        ; Verifica Bit 7 do Byte 5: 0 = Inimigo, 1 = Arma (SPAWN_KIND_WEAPON)
        lda a:5, y
        bit #SPAWN_KIND_WEAPON
        bne @SpawnWeapon

        ; =====================================================================
        ; CAMINHO A: SPAWN DE INIMIGO
        ; =====================================================================
        ldx #.loword(VaderCrab)
        lda a:MeleeCrabStruct::State, x
        cmp #STATE_DEAD
        beq @EnemySlotFound

        ldx #.loword(DengueCrab)
        lda a:MeleeCrabStruct::State, x
        cmp #STATE_DEAD
        beq @EnemySlotFound

        ldx #.loword(RapaNuiCrab)
        lda a:MeleeCrabStruct::State, x
        cmp #STATE_DEAD
        beq @EnemySlotFound

        ; Todos os 3 slots ocupados
        rts

@EnemySlotFound:
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

        phy
        jsr SetupPreSpawnMeleeStats
        ply
        bra @AdvanceScript

        ; =====================================================================
        ; CAMINHO B: SPAWN DE ARMA (WeaponA..WeaponD)
        ; =====================================================================
@SpawnWeapon:
        ldx #.loword(WeaponA)
        lda a:WeaponStruct::Active, x
        cmp #WEAPON_STATE_INACTIVE
        beq @WeaponSlotFound

        ldx #.loword(WeaponB)
        lda a:WeaponStruct::Active, x
        cmp #WEAPON_STATE_INACTIVE
        beq @WeaponSlotFound

        ldx #.loword(WeaponC)
        lda a:WeaponStruct::Active, x
        cmp #WEAPON_STATE_INACTIVE
        beq @WeaponSlotFound

        LDX #.loword(WeaponD)
        lda a:WeaponStruct::Active, x
        cmp #WEAPON_STATE_INACTIVE
        BEQ @WeaponSlotFound

        LDX #.loword(WeaponE)
        lda a:WeaponStruct::Active, x
        cmp #WEAPON_STATE_INACTIVE
        beq @WeaponSlotFound

        ; Todos os 4 slots ocupados
        bra @AdvanceScript


@WeaponSlotFound:
        rep #$20
        .a16
        lda a:2, y                      ; Spawn_World_X
        sta a:WeaponStruct::X_Pos, x
        sep #$20
        .a8

        lda a:4, y                      ; Spawn_World_Y
        sta a:WeaponStruct::Y_Pos, x

        lda a:5, y                      ; Extrai Weapon_ID removendo o Bit 7 (SPAWN_KIND_WEAPON)
        and #$7F
        sta a:WeaponStruct::Weapon_ID, x

        lda a:6, y                      ; Byte 6 = Tile_ID
        sta a:WeaponStruct::Tile_ID, x

        lda a:7, y                      ; Byte 7 = Tile_Size / WEAPON_LAYOUT_*
        sta a:WeaponStruct::Tile_Size, x

        phy                             ; Salva ponteiro do Stage_Script
        txy                             ; Y = Ponteiro do slot (WeaponA..WeaponD)
        jsr SetupWeaponStats
        ply                             ; Restaura ponteiro do Stage_Script


@AdvanceScript:
        ; Avança Stage_Script_Ptr em 8 bytes para o próximo evento da fase
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
