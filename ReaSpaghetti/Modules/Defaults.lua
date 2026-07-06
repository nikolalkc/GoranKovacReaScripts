--@noindex
--NoIndex: true

WIDGETS_LIVE_UPDATE_SPEED = 10 -- FRAMES

-- EDGE GRAG SCROLLING
EDGE_SCROLLING_ZONE = 80
EDGE_SCROLLING_SPEED = 5

-- ENABLE GRID
GRID = true
GRID_SIZE = 32 -- grid cell size in canvas units (drives grid drawing AND node snapping)

-- BACKGROUND COLOR OPTIONS
-- "gray" = gray bg, "dark" = dark bg, "legacy" = legacy light bg
BG_COLOR_MODE = "gray"
BG_COLOR_GRAY   = 0x333333ff -- gray bg
BG_COLOR_DARK   = 0x181818ff -- dark bg (rgb 40,40,40)
BG_COLOR_LEGACY = 0xACAEAEff -- legacy light bg (rgb 220,222,222)

-- GRID COLOR - adjusted per background theme (slightly darker than bg)
GRID_COLOR_GRAY   = 0x404040ff -- rgb 64,64,64
GRID_COLOR_DARK   = 0x2A2A2Aff -- rgb 42,42,42
GRID_COLOR_LEGACY = 0x8E9090ff -- slightly darker than legacy bg

-- LEGACY (CLASSIC) THEME NODE COLORS - matches old light UI reference
NODE_TEXT_COLOR_LEGACY   = 0x000000FF -- black text
NODE_BG_COLOR_LEGACY     = 0xD9D2B8FF -- cream/beige node body
NODE_HEADER_COLOR_LEGACY = 0x8A6D3BFF -- tan/khaki node header

-- THRESHOLD FOR NEW PROJECT SAVE PROMPT
NEW_PROJECT_NODE_CONDITION = 1

-- FONT SIZE FOR ZOOMING (UPDATES ON ZOOM - EVERYTHING IN NODE)
FONT_SIZE = 16
ORG_FONT_SIZE = FONT_SIZE

-- STATIC FONT SIZE (WONT UPDATE ON ZOOM - TOOLTIPS)
FONT_SIZE_STATIC = 15

TOOLTIP = true
DEBUG = false
PROFILE_DEBUG = false

PROJECT_NAME = 'Untitled Spaghetti'
