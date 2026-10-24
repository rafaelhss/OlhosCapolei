.ifndef GAME_CONSTANTS_INC
GAME_CONSTANTS_INC = 1
; -----------------------------------------------------------------------------
;   File: GameConstants.inc
;   Description: Constant values used by this demo
; -----------------------------------------------------------------------------

;----- Game Constants ----------------------------------------------------------
 ROM_BASE = $0000
    ; we use these constants to check for collisions with the screen boundaries
SCREEN_LEFT     = $00   ; left screen boundary = 0
SCREEN_RIGHT    = $ff   ; right screen boundary = 255
SCREEN_TOP      = $00   ; top screen boundary = 0
SCREEN_BOTTOM   = $df   ; bottom screen boundary = 223


STATE_WALKING = 0
STATE_PREPARING = 1
STATE_ATACKING = 2
STATE_RESTING = 3

; a simple constant to define the sprite movement speed
SPRITE_SIZE     = $08   ; sprites are 8 by 8 pixel
SPRITE_SPEED    = $03   ; Velocidade base do heroi

ENEMY_ATTACK_DISTANCE = $32   ;Chegou aqui, para e ataca   
ENEMY_ATTACK_Y_RANGE  = $08   ;tolerancia no Y. Nao precisa estar exatamente na mesma linha

; --- Limites Preventivos contra Underflow (Zonas de Amortecimento) ---
HERO_SAFE_LIMIT  = (SPRITE_SPEED + SPRITE_SPEED) ;- atencao. com speed 4 nao funciona. no turbo (v=8) ele escapa na borda direita 

; --- Limites de Tela Automatizados para o Code Review do Senior ---
HERO_SCREEN_SAFE_LIMIT  = SCREEN_RIGHT - HERO_SAFE_LIMIT


OAMMIRROR_SIZE  = $0220 ; OAMRAM can hold data for 128 sprites, 4 bytes each

OAM_EXTRA_OFFSET = $0200; O valor #$0200 (512 em decimal) aponta exatamente para o primeiro byte da Tabela OAM Extra.

    ; constants to use as masks
UP_BUTTON       = $0800
DOWN_BUTTON     = $0400
LEFT_BUTTON     = $0200
RIGHT_BUTTON    = $0100
A_BUTTON        = $0080
;-------------------------------------------------------------------------------





; ======== Hero padrao (Corrigido para 8-bit)
.struct HeroStruct
    X_Pos       .byte   ; 8-bit horizontal position (0-255)
    Y_Pos       .byte   ; 8-bit vertical position
    Tile_Count  .byte   ; Guarda quantos blocos compoem esse Hero
.endstruct

; ======== NOVO: BigHero padrão (Estilo Beat 'em Up 32x64)
.struct BigHeroStruct
    X_Pos       .byte   ; Posição X âncora (0-255)
    Y_Pos       .byte   ; Posição Y âncora (0-255)
    Tile_Count  .byte   ; Quantidade de sprites na OAM (Serão 6 para este arranjo)
    Anim_Timer  .byte   ; Contador de frames da caminhada
    Anim_Frame  .byte   ; Frame atual dos pés (0 ou 1)
.endstruct



; ======== InimigoGrande padrao (Corrigido para 8-bit)
.struct EnemyStruct
    X_Pos       .byte   ; 8-bit horizontal position (0-255)
    Y_Pos       .byte   ; 8-bit vertical position
    Tile_Count  .byte   ; Guarda quantos blocos compoem esse inimigo
    Anim_Timer  .byte   ; Contador para velocidade da animacao
    Anim_Frame  .byte   ; Frame atual (0, 1, 2...)
    Anim_Ptr    .res 2  ; Reserva 2 bytes para armazenar o ponteiro de animacao
.endstruct


.struct PennyCrabStruct
    X_Pos       .byte   ; 8-bit horizontal position (0-255)
    Y_Pos       .byte   ; 8-bit vertical position
    Tile_Count  .byte   ; Guarda quantos blocos compoem esse inimigo
    Walk_Anim_Speed .byte ;quanto menor mais rapido. 0 para;
    Anim_Timer  .byte   ; Contador para velocidade da animacao
    Anim_Frame  .byte   ; Frame atual (0, 1, 2...)
    Anim_Ptr    .res 2  ; Reserva 2 bytes para armazenar o ponteiro de animacao
    Facing              .byte   ; 0 = Olhando para a Direita, 1 = Olhando para a Esquerda
    State               .byte   ; Estado atual da IA (Walk, Prepare, Attack)
    State_Timer         .byte   ; Contador de frames para as transições de estado
    Preparing_Timer     .byte   ; Contador de frames antes de atacar, depois de chegar
    Preparing_Anim_Timer     .byte   ; Contador de frames para animacao
    Preparing_Anim_Frame .byte
    
    Attacking_Timer     .byte   ; Contador de frames durante atacar
    Attacking_Anim_Timer     .byte   ; Contador de frames para animacao
    Attacking_Anim_Frame .byte    
    
    Resting_Timer       .byte ;contador de frames para ficar parado
    
    ; --- Nova estrutura de Hitbox de Ataque (O "Rastro") ---
    Hitbox_Active       .byte   ; 0 = Inativa, 1 = Ativa (Rastro para o motor de colisão)
    Hitbox_X1           .byte   ; Canto esquerdo da área de dano na tela
    Hitbox_X2           .byte   ; Canto direito da área de dano na tela
    Hitbox_Y1           .byte   ; Canto superior da área de dano na tela
    Hitbox_Y2           .byte   ; Canto inferior da área de dano na tela

.endstruct


.struct VaderCrabStruct
    X_Pos       .byte   ; 8-bit horizontal position (0-255)
    Y_Pos       .byte   ; 8-bit vertical position
    Tile_Count  .byte   ; Guarda quantos blocos compoem esse inimigo
    Walk_Anim_Speed .byte ;quanto menor mais rapido. 0 para;
    Anim_Timer  .byte   ; Contador para velocidade da animacao
    Anim_Frame  .byte   ; Frame atual (0, 1, 2...)
    Anim_Ptr    .res 2  ; Reserva 2 bytes para armazenar o ponteiro de animacao
    Facing              .byte   ; 0 = Olhando para a Direita, 1 = Olhando para a Esquerda
    State               .byte   ; Estado atual da IA (Walk, Prepare, Attack)
    State_Timer         .byte   ; Contador de frames para as transições de estado
    Preparing_Timer     .byte   ; Contador de frames antes de atacar, depois de chegar
    Preparing_Anim_Timer     .byte   ; Contador de frames para animacao
    Preparing_Anim_Frame .byte
    
    Attacking_Timer     .byte   ; Contador de frames durante atacar
    Attacking_Anim_Timer     .byte   ; Contador de frames para animacao
    Attacking_Anim_Frame .byte    

    Resting_Timer       .byte ;contador de frames para ficar parado
    
    ; --- Nova estrutura de Hitbox de Ataque (O "Rastro") ---
    Hitbox_Active       .byte   ; 0 = Inativa, 1 = Ativa (Rastro para o motor de colisão)
    Hitbox_X1           .byte   ; Canto esquerdo da área de dano na tela
    Hitbox_X2           .byte   ; Canto direito da área de dano na tela
    Hitbox_Y1           .byte   ; Canto superior da área de dano na tela
    Hitbox_Y2           .byte   ; Canto inferior da área de dano na tela

.endstruct


.endif
