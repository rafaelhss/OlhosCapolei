; -----------------------------------------------------------------------------
;   File: Assets.s
;   Description: Creates a segment for all assets and exports symbols to make
;   them accessible to other parts of the project.
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     SpriteData
.export     ColorData
.export     BackgroundData
;-------------------------------------------------------------------------------

;----- Assset Data -------------------------------------------------------------
.segment "SPRITEDATA"
SpriteData: .incbin "SpritesBig3.vra"
ColorData:  .incbin "Sprites11.pal"
BackgroundData: .incbin "Background.pal"

;-------------------------------------------------------------------------------
