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
SpriteData: .incbin "SpritesBig8.vra"
VaderData: .incbin "VaderSprites6.vra"
ColorData:  .incbin "SpritesBig8c.pal"
BackgroundData: .incbin "Background.pal"

;-------------------------------------------------------------------------------
