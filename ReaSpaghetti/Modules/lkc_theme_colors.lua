-- lkc_theme_colors.lua
-- Reusable module: reads REAPER theme color-processing parameters
-- (Gamma, Shadows, Midtones, Highlights, Saturation, Tint) from
-- Default_7.0_theme_adjuster params and provides utilities to adapt
-- ImGui RGBA colors accordingly.
--
-- Usage:
--   local TC = dofile(script_path .. "lkc_theme_colors.lua")
--   TC.Refresh()                -- call once per frame (internally rate-limited)
--   local col = TC.Apply(0x333333ff)   -- adapt a base color to current theme
--   local sch = TC.Scheme()            -- get a full set of pre-adapted UI colors
--
-- All colors are 0xRRGGBBAA unsigned integers as used by ReaImGui.

local TC = {}

-- ── Color math ───────────────────────────────────────────────────────────────

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- r,g,b in [0,1] → h [0,360), s [0,1], l [0,1]
local function RgbToHsl(r, g, b)
    local mx = math.max(r, g, b)
    local mn = math.min(r, g, b)
    local l  = (mx + mn) * 0.5
    if mx == mn then return 0, 0, l end
    local d = mx - mn
    local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
    local h
    if     mx == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif mx == g then h = (b - r) / d + 2
    else                h = (r - g) / d + 4
    end
    return h * 60, s, l
end

-- h [0,360), s [0,1], l [0,1] → r,g,b in [0,1]
local function HslToRgb(h, s, l)
    if s == 0 then return l, l, l end
    local function hue2rgb(p, q, t)
        t = t % 1
        if t < 1/6 then return p + (q - p) * 6 * t
        elseif t < 1/2 then return q
        elseif t < 2/3 then return p + (q - p) * (2/3 - t) * 6
        else return p end
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    h = h / 360
    return hue2rgb(p,q,h+1/3), hue2rgb(p,q,h), hue2rgb(p,q,h-1/3)
end

local function UnpackRgba(col)
    return ((col >> 24) & 0xff) / 255,
           ((col >> 16) & 0xff) / 255,
           ((col >>  8) & 0xff) / 255,
           ( col        & 0xff) / 255
end

local function PackRgba(r, g, b, a)
    return (math.floor(clamp(r,0,1)*255 + 0.5) << 24) |
           (math.floor(clamp(g,0,1)*255 + 0.5) << 16) |
           (math.floor(clamp(b,0,1)*255 + 0.5) <<  8) |
            math.floor(clamp(a,0,1)*255 + 0.5)
end

-- ── Theme parameter cache ─────────────────────────────────────────────────────

-- Current remapped (display-range) values; neutral defaults shown.
local p = {
    gamma      = 100,   -- display range  25–200,  neutral = 100
    shadows    =   0,   -- display range -100–100, neutral = 0
    midtones   =   0,
    highlights =   0,
    saturation = 100,   -- display range   0–200,  neutral = 100
    tint       =   0,   -- display range -180–180, neutral = 0  (degrees)
}

-- Read one layout parameter and remap from native range to display range.
local function ReadParam(idx, neutral, disp_min, disp_max)
    local ok, _, val, _, p_min, p_max = reaper.ThemeLayout_GetParameter(idx)
    if not ok or val == nil then return neutral end
    if p_min and p_max and p_max ~= p_min then
        return (val - p_min) / (p_max - p_min) * (disp_max - disp_min) + disp_min
    end
    return val
end

local REFRESH_INTERVAL = 0.5   -- seconds between param re-reads
local last_refresh     = -math.huge

--- Refresh the internal param cache (rate-limited; safe to call every frame).
function TC.Refresh()
    local now = reaper.time_precise()
    if now - last_refresh < REFRESH_INTERVAL then return end
    last_refresh = now
    p.gamma      = ReadParam(-1000, 100,   25, 200)
    p.shadows    = ReadParam(-1001,   0, -100, 100)
    p.midtones   = ReadParam(-1002,   0, -100, 100)
    p.highlights = ReadParam(-1003,   0, -100, 100)
    p.saturation = ReadParam(-1004, 100,    0, 200)
    p.tint       = ReadParam(-1005,   0, -180, 180)
end

--- Expose current param values (read-only intent).
function TC.Params() return p end

-- ── Color transformation ──────────────────────────────────────────────────────

--- Apply current theme color-processing to a single RGBA uint (0xRRGGBBAA).
-- @param rgba      base color as 0xRRGGBBAA
-- @param influence 0.0 = no effect, 1.0 = full effect (default 1.0)
-- @return          adapted color as 0xRRGGBBAA
function TC.Apply(rgba, influence)
    influence = influence or 1.0
    if influence == 0 then return rgba end

    local r, g, b, a = UnpackRgba(rgba)
    local h, s, l = RgbToHsl(r, g, b)

    -- ── Tint (hue rotation) ──────────────────────────────────────────────────
    -- For chromatic colors: rotate hue by tint degrees.
    -- For near-grey colors (s < 0.05): add a faint colorize toward the tint hue
    -- so neutral backgrounds pick up the theme cast without going garish.
    local tint_deg = p.tint * influence
    if s < 0.05 and math.abs(p.tint) > 5 then
        h = p.tint >= 0 and p.tint or (p.tint + 360)
        s = clamp(math.abs(p.tint) / 180, 0, 1) * 0.06 * influence
    else
        h = (h + tint_deg) % 360
        if h < 0 then h = h + 360 end
    end

    -- ── Saturation ───────────────────────────────────────────────────────────
    -- saturation 100 = neutral (× 1.0); 0 = grayscale; 200 = doubled.
    local sat_factor = 1 + (p.saturation / 100 - 1) * influence
    s = clamp(s * sat_factor, 0, 1)

    -- ── Tonal adjustments (Shadows / Midtones / Highlights) ──────────────────
    -- Each curve affects a smooth luminosity band (max ±0.15 l).
    local shdw_w  = clamp(1 - l / 0.4,          0, 1) * 0.5
    local hilit_w = clamp((l - 0.6) / 0.4,      0, 1) * 0.5
    local mid_w   = clamp(1 - shdw_w - hilit_w, 0, 1) * 0.5
    local tone_shift = (p.shadows    * shdw_w
                      + p.midtones   * mid_w
                      + p.highlights * hilit_w) / 100 * 0.15 * influence
    l = clamp(l + tone_shift, 0, 1)

    -- Back to RGB for gamma (power function, same space REAPER uses)
    r, g, b = HslToRgb(h, s, l)

    -- ── Gamma ─────────────────────────────────────────────────────────────────
    -- REAPER applies gamma as a power curve on each RGB channel.
    -- gamma 100 = neutral (exponent 1.0); higher = darker (exponent > 1).
    -- Interpolate the exponent by influence so partial application is smooth.
    local eff_exp = 1.0 + (p.gamma / 100 - 1.0) * influence
    r = clamp(r, 0.001, 1) ^ eff_exp
    g = clamp(g, 0.001, 1) ^ eff_exp
    b = clamp(b, 0.001, 1) ^ eff_exp

    return PackRgba(r, g, b, a)
end

--- Read a raw REAPER theme color (pre-gamma/processing) as 0xRRGGBBAA.
-- Returns nil if the key is not found in the current theme.
-- @param key  REAPER theme color ini key, e.g. "col_main_bg", "col_tracklistbg"
function TC.ReadThemeColor(key)
    local col = reaper.GetThemeColor(key, 0)
    if not col or col == -1 then return nil end
    local r, g, b = reaper.ColorFromNative(col)
    return PackRgba(r / 255, g / 255, b / 255, 1.0)
end

-- ── Base color palette ────────────────────────────────────────────────────────

-- Neutral starting colors for LKC ImGui scripts.
-- Override any of these before calling TC.Scheme() to customise your palette.
TC.Base = {
    wnd_bg         = 0x333333ff,
    tab_bg         = 0x383838ff,
    elm_frame      = 0x606060ff,
    elm_fill       = 0x149477ff,   -- teal/green accent
    elm_outline    = 0x202020ff,
    txt            = 0xc0c0c0ff,
    track_bg       = 0x272727ff,
    track_bg_hover = 0x2f2f2fff,
}

-- ── Scheme ────────────────────────────────────────────────────────────────────

--- Build and return a table of themed colors.
-- Background and frame colors are anchored to REAPER's actual theme color
-- (col_tracklistbg) when available, so they track REAPER precisely.
-- Accent/interactive colors are derived from TC.Base with full influence.
-- Call after TC.Refresh(), typically once per frame.
-- @return table with the same keys as TC.Base
function TC.Scheme()
    local B = TC.Base

    -- Anchor backgrounds to REAPER's actual (pre-processed) TCP background.
    -- Applying our full transforms on the raw value replicates what REAPER renders.
    local reaper_tcp_bg = TC.ReadThemeColor("col_tracklistbg")
                       or TC.ReadThemeColor("col_main_bg")
    local base_bg       = reaper_tcp_bg or B.wnd_bg

    -- Derive darker/lighter variants relative to the anchored background.
    local r, g, b = ((base_bg >> 24) & 0xff) / 255,
                    ((base_bg >> 16) & 0xff) / 255,
                    ((base_bg >>  8) & 0xff) / 255
    local track_bg_base  = PackRgba(r * 0.83, g * 0.83, b * 0.83, 1.0)
    local track_bg_hover = PackRgba(r * 0.92, g * 0.92, b * 0.92, 1.0)
    local tab_bg_base    = PackRgba(r * 1.06, g * 1.06, b * 1.06, 1.0)
    local outline_base   = PackRgba(r * 0.63, g * 0.63, b * 0.63, 1.0)

    -- bg: partial influence so the power function doesn't collapse dark backgrounds.
    -- acc: stronger but not full, keeps accents readable across the gamma range.
    local bg  = 0.45
    local acc = 0.85
    return {
        wnd_bg         = TC.Apply(base_bg,        bg),
        tab_bg         = TC.Apply(tab_bg_base,    bg),
        elm_frame      = TC.Apply(B.elm_frame,    bg),
        elm_fill       = TC.Apply(B.elm_fill,     acc),
        elm_outline    = TC.Apply(outline_base,   bg),
        txt            = TC.Apply(B.txt,          acc),
        track_bg       = TC.Apply(track_bg_base,  bg),
        track_bg_hover = TC.Apply(track_bg_hover, bg),
    }
end

return TC
