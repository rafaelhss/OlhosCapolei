.ifndef GAME_CONSTANTS_INC
GAME_CONSTANTS_INC = 1
; -----------------------------------------------------------------------------
;   File: GameConstants.inc
;   Description: Constant values and unified memory maps used by OlhosCapolei
; -----------------------------------------------------------------------------

;----- Game Constants ----------------------------------------------------------
ROM_BASE        = $0000
SCREEN_LEFT     = $00   ; Limite esquerdo da tela = 0
SCREEN_RIGHT    = $ff   ; Limite direito da tela = 255
SCREEN_TOP      = $00   ; Limite superior da tela = 0
SCREEN_BOTTOM   = $df   ; Limite inferior da tela = 223

; --- Máquina de Estados Geral ---
STATE_WALKING   = 0
STATE_PREPARING = 1
STATE_ATACKING  = 2
STATE_RESTING   = 3

STATE_HURT_NOT  = 0
STATE_HURT      = 1


WEAPON_STATE_EQUIPPED = 0  ; Coletada, colada na mão do herói
WEAPON_STATE_GROUND   = 1  ; Esperando no chão para ser coletada
WEAPON_STATE_THROWN   = 2  ; Voando pelo ar em parábola

; --- Configurações de Sprites e Velocidade ---
SPRITE_SIZE     = $08   ; Sprites base são 8x8 pixels
SPRITE_SPEED    = $01   ; Velocidade base do herói

ENEMY_ATTACK_DISTANCE = $32   ; Distância de engajamento do ataque da IA   
ENEMY_ATTACK_Y_RANGE  = $08   ; Tolerância no eixo Y para alinhamento tridimensional

; --- Limites Preventivos contra Underflow (Zonas de Amortecimento) ---
HERO_SAFE_LIMIT         = (SPRITE_SPEED + SPRITE_SPEED) 
HERO_SCREEN_SAFE_LIMIT  = SCREEN_RIGHT - HERO_SAFE_LIMIT

OAMMIRROR_SIZE          = $0220 ; Espelho OAM comporta 128 sprites (4 bytes cada)
OAM_EXTRA_OFFSET        = $0200 ; Aponta exatamente para o primeiro byte da Tabela OAM Extra

; --- Máscaras de Hardware dos Botões do Controle (16-bit Auto-polling) ---
Y_BUTTON        = $4000
UP_BUTTON       = $0800
DOWN_BUTTON     = $0400
LEFT_BUTTON     = $0200
RIGHT_BUTTON    = $0100
A_BUTTON        = $0080
X_BUTTON        = $0040 ; Centralizado para coleta e ações de herói

; =============================================================================
; MAPA CENTRALIZADO DE ALOCAÇÃO DA DIRECT PAGE (DP MEMORY LAYOUT)
; =============================================================================
; --- Zona Volátil Geral (Rascunhos Rápidos da CPU - Compartilhada em Sub-rotinas) ---
DP_TEMP_00              = $00
DP_TEMP_01              = $01
DP_TEMP_02              = $02
DP_TEMP_03              = $03

; --- Zona Exclusiva do Subsistema do Herói (BigHero.s) ---
DP_HERO_LAYOUT_PTR      = $04   ; Ocupa $04 e $05 (Ponteiro de 16-bit para matriz de animação na ROM)
DP_HERO_OAM_BACKUP      = $06   ; Ocupa $06 e $07 (Preserva temporariamente o reg X OAM)

; --- Zona Exclusiva do Subsistema de Armas e Projéteis (Weapon.s) ---
DP_WEAPON_TILE_TMP      = $08   ; Ocupa $08 (Guarda o Tile_ID do item arremessável)
DP_WEAPON_OAM_BACKUP    = $0A   ; Ocupa $0A e $0B (Preserva temporariamente o reg X OAM)
DP_WEAPON_POOL_PTR      = $0C   ; Ocupa $0C (Índice de controle de varredura da RAM do Pool)

; --- Categorias Unificadas de Armas ---
WEAPON_TYPE_MELEE      = $00  ; Arma Branca (Cano, Faca, Pau)
WEAPON_TYPE_PROJECTILE = $01  ; Arma de Disparo/Arremesso (Pedra, Pistola, Bazuca)
WEAPON_TYPE_THROWABLE  = $02  ; Arma jogavel (pedra, martelo, bosta)


; --- Tabela Oficial de IDs de Armas ---
WEAPON_ID_UNARMED      = 0
WEAPON_ID_KNIFE        = 1
WEAPON_ID_PIPE         = 2
WEAPON_ID_WOOD         = 3
WEAPON_ID_ROCK         = 4    ; Pedra de Arremesso oficial do jogo
WEAPON_ID_PISTOL       = 5
WEAPON_ID_BAZOOKA      = 6
WEAPON_ID_HAMMER       = 7

; =============================================================================
; DEFINIÇÕES DE ESTRUTURAS DE DADOS (WRAM TABLES)
; =============================================================================

; ======== Hero Padrão (8-bit)
.struct HeroStruct
    X_Pos       .byte   
    Y_Pos       .byte   
    Tile_Count  .byte   
.endstruct

; ======== BigHero (Estilo Beat 'em Up 32x64)
.struct BigHeroStruct
    X_Pos               .byte   ; Posição X âncora (0-255)
    Y_Pos               .byte   ; Posição Y âncora (0-255)
    Tile_Count          .byte   ; Quantidade de sprites na OAM
    Anim_Timer          .byte   ; Contador de frames da caminhada
    Anim_Frame          .byte   ; Frame atual dos pés (0 ou 1)
    Facing              .byte   ; $00 = Olhando para a Direita, $01 = Olhando para a Esquerda
    Hurtbox_Active      .byte   ; Controle de invencibilidade/vulnerabilidade
    Hurtbox_X1          .byte   ; Retângulo AABB - Esquerda
    Hurtbox_X2          .byte   ; Retângulo AABB - Direita
    Hurtbox_Y1          .byte   ; Retângulo AABB - Topo
    Hurtbox_Y2          .byte   ; Retângulo AABB - Base
    HurtTimer           .byte   ; Contador de hitstun (cara amassada)
    Current_Weapon_ID   .byte   ; Endereco da arma atualmente equipada (0 a 6)
.endstruct

; ======== Enemy Padrão (8-bit)
.struct EnemyStruct
    X_Pos       .byte   
    Y_Pos       .byte   
    Tile_Count  .byte   
    Anim_Timer  .byte   
    Anim_Frame  .byte   
    Anim_Ptr    .res 2  
.endstruct

; ======== PennyCrab IA
.struct PennyCrabStruct
    X_Pos                .byte   
    Y_Pos                .byte   
    Tile_Count           .byte   
    Walk_Anim_Speed      .byte 
    Anim_Timer           .byte   
    Anim_Frame           .byte   
    Anim_Ptr             .res 2  
    Facing               .byte   
    State                .byte   
    State_Timer          .byte   
    Preparing_Timer      .byte   
    Preparing_Anim_Timer .byte   
    Preparing_Anim_Frame .byte
    Attacking_Timer      .byte   
    Attacking_Anim_Timer .byte   
    Attacking_Anim_Frame .byte    
    Resting_Timer        .byte 
    Hitbox_Active        .byte   
    Hitbox_X1            .byte   
    Hitbox_X2            .byte   
    Hitbox_Y1            .byte   
    Hitbox_Y2            .byte   
.endstruct

; ======== VaderCrab IA
.struct VaderCrabStruct
    X_Pos                .byte   
    Y_Pos                .byte   
    Tile_Count           .byte   
    Walk_Anim_Speed      .byte 
    Anim_Timer           .byte   
    Anim_Frame           .byte   
    Anim_Ptr             .res 2  
    Facing               .byte   
    State                .byte   
    State_Timer          .byte   
    Preparing_Timer      .byte   
    Preparing_Anim_Timer .byte   
    Preparing_Anim_Frame .byte
    Attacking_Timer      .byte   
    Attacking_Anim_Timer .byte   
    Attacking_Anim_Frame .byte    
    Resting_Timer        .byte 
    Hitbox_Active        .byte   
    Hitbox_X1            .byte   
    Hitbox_X2            .byte   
    Hitbox_Y1            .byte   
    Hitbox_Y2            .byte 
    Hurtbox_X1            .byte   
    Hurtbox_X2            .byte   
    Hurtbox_Y1            .byte   
    Hurtbox_Y2            .byte 
    HurtTimer            .byte 
      
.endstruct

; ======== Registro do Pool de Projéteis Dinâmicos
.struct ProjectileEntity
    Active      .byte   ; 0 = Inativo, 1 = Em movimento no ar        
    X_Pos       .byte   ; Coordenada X na tela          
    Y_Pos       .byte   ; Coordenada Y na tela          
    Tile_ID     .byte   ; Grafismo correto indexado da ROM          
    Attrs       .byte   ; Atributos de hardware da PPU (Paleta/Flip)          
    Speed_X     .byte   ; Velocidade horizontal com sinal
    Speed_Y     .byte   ; Força vertical/parábola com sinal        
.endstruct

; ======== Registro de Itens Soltos no Cenário
.struct WeaponStruct
    Active      .byte   ; 0 = Vazio, 1 = Visível no chão esperando coleta
    Weapon_ID   .byte   ; ID associado à Weapon_Data_Table (1 a 6)
    Tile_ID     .byte   ; Tile base do gráfico
    Tile_Size   .byte   ; Quantidade de tiles que compõem o weapon
    X_Pos       .byte   
    Y_Pos       .byte   
    Speed_X     .byte   ; Velocidade horizontal do arremesso
    Speed_Y     .byte   ; Força vertical/parábola
    Target_Y    .byte   ; Guarda o pixel exato do chão onde a pedra pousa
    Melee_Timer .byte   ; Contador de frames de duração da porretada
    Melee_Frame .byte   ; ID do frame visual da animação (0, 1 ou 2)
    ; ◄ NOVOS CAMPOS EXCLUSIVOS DA SOLUÇÃO 2 (HITBOX DA ARMA BRANCA):
    Hitbox_Active       .byte   ; 1 = Janela de dano ativa, 0 = Inativa
    Hitbox_X1           .byte   ; Limite Esquerdo
    Hitbox_X2           .byte   ; Limite Direito
    Hitbox_Y1           .byte   ; Limite Superior
    Hitbox_Y2           .byte   ; Limite Inferior
.endstruct


.endif
