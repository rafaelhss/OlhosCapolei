; -----------------------------------------------------------------------------
;   File: Assets.s
;   Description: Creates a segment for all assets and exports symbols to make
;   them accessible to other parts of the project.
; -----------------------------------------------------------------------------

;----- Export ------------------------------------------------------------------
.export     SpriteData
.export     VaderData
.export     ColorData
.export     BackgroundData
;-------------------------------------------------------------------------------

;----- Assset Data -------------------------------------------------------------
.segment "SPRITEDATA"
SpriteData: .incbin "SpritesBig7.vra"
VaderData: .incbin "VaderSprites3.vra"
ColorData:  .incbin "SpritesBig5c.pal"
BackgroundData: .incbin "Background.pal"

;-------------------------------------------------------------------------------
