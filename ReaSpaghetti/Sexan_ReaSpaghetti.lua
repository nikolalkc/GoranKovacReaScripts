-- @description ReaSpaghetti Visual Scripter
-- @author Sexan
-- @license GPL v3
-- @version 0.49.3
-- @changelog
--  Improve data serializer to handle inf,-inf,nan (hopefully) V2
-- @provides
--   api_file.txt
--   Modules/*.lua
--   Examples/*.reanodes
--   Library/*.reanlib
--   ExportedActions/dummy.lua
--   Docs/*.pdf
--   Examples/SCHWA/*.png
--   [main] Sexan_ReaSpaghetti.lua

package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
PATH = debug.getinfo(1).source:match("@?(.*[\\|/])")
NATIVE_SEPARATOR = package.config:sub(1, 1)

local r = reaper

local crash = function(e)
    r.ShowConsoleMsg(e .. '\n' .. debug.traceback())
end
dofile(r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.7')

-- IMGUI SETUP
ctx = r.ImGui_CreateContext('My script')

require("Modules/Defaults")

FONT = r.ImGui_CreateFont('sans-serif', FONT_SIZE, r.ImGui_FontFlags_Bold())
FONT_STATIC = r.ImGui_CreateFont('sans-serif', FONT_SIZE_STATIC)
FONT_CODE = r.ImGui_CreateFont('monospace', FONT_SIZE, r.ImGui_FontFlags_Bold())

r.ImGui_Attach(ctx, FONT)
r.ImGui_Attach(ctx, FONT_STATIC)
r.ImGui_Attach(ctx, FONT_CODE)

r.ImGui_SetConfigVar(ctx, r.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1)
local WND_FLAGS = r.ImGui_WindowFlags_NoScrollbar()
    | r.ImGui_WindowFlags_NoScrollWithMouse()
    | r.ImGui_WindowFlags_MenuBar()

FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()
-- IMGUI SETUP

local profiler2 = require("Modules/profiler")
INSPECT = require("Modules/inspect")
--local profiler = require("Modules/ProFi")

if r.file_exists(r.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua") then
    dofile(r.GetResourcePath() .. "/UserPlugins/ultraschall_api.lua")
    ULTRA_API = true
end

FLUX = require("Modules/flux")
BEZIER = require("Modules/path2d_bezier3")
BEZIER_HIT = require("Modules/path2d_bezier3_hit")
require("Modules/APIParser")
require("Modules/UI")
require("Modules/Utils")
require("Modules/FileManager")
require("Modules/Canvas")
require("Modules/Controllers")
require("Modules/NodeDraw")
require("Modules/Flow")
require("Modules/CustomFunctions")
require("Modules/ExportToAction")
require("Modules/Library")
require("Modules/Undo")
require("Modules/TrackState")

if STANDALONE_RUN then return end

local old_time = r.time_precise()
local function UpdateDeltaTime()
    local now_time = r.time_precise()
    local DT = now_time - old_time
    old_time = now_time
    FLUX.update(DT)
end

local function frame()
    Top_Menu()
    if r.ImGui_BeginChild(ctx, "SideListMain", 240, 0) then
        if r.ImGui_BeginChild(ctx, "SideListChild", 0, -25, 1) then
            Sidebar()
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_SetNextItemWidth(ctx, 200)
        r.ImGui_LabelText(ctx, "##INFO", "Nodes:" .. #GetNodeTBL() .. " Selected:" .. #CntSelNodes())
        r.ImGui_EndChild(ctx)
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 0, 0)
    local visible = r.ImGui_BeginChild(ctx, "Canvas", 0, 0, 1,
        r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse())
    r.ImGui_PopStyleVar(ctx)
    if visible then
        --r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), 0, 0)
        FunctionTabs()
        if r.ImGui_BeginChild(ctx, "Canvas2", 0, 0, 1, r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoScrollWithMouse()) then
            -- WE NEED TO CENTER CANVAS IN ITS WINDOW (IN ORDER TO NODE TO BE IN CENTER)
            if not CANVAS then
                CANVAS = InitCanvas()
            end
            Popups()
            CanvasLoop()
            UI_Buttons()

            r.ImGui_EndChild(ctx) -- END CANVAS2
            CheckWindowPayload()
        end
        r.ImGui_EndChild(ctx) -- END CANVAS1
    end
end

DIRTY = nil
local function loop()
    if PROFILE_DEBUG then
        PROFILE_STARTED = true
        profiler2.start()
    end

    UpdateDeltaTime()
    UpdateZoomFont()
    TrackSelectionWatcher()
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(),              0x333333FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(),             0x333333FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(),              0x333333FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBgActive(),        0x2D4F47FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ResizeGripHovered(),    0x42FAD1AB)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ResizeGripActive(),     0x42FAD1F2)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ResizeGrip(),           0x42FAD133)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Tab(),                  0x42FAD14F)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TabHovered(),           0x33AD92FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TabActive(),            0x3B9D87FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TabUnfocused(),         0x112622F8)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TabUnfocusedActive(),   0x236C5CFF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(),        0x33AD92FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),         0x0FFAC5FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(),              0x297A688A)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgHovered(),       0x42FAD166)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgActive(),        0x42FAD1AB)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBgActive(),        0x297A68FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_CheckMark(),            0x42FAD1FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrab(),           0x3DE0BBFF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrabActive(),     0x42FAD1FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),               0x42FAD166)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Header(),               0x297A688A)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderHovered(),        0x42FAD14F)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderActive(),         0x42FAD14F)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Separator(),            0x6E807C80)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SeparatorHovered(),     0x1ABF9AC7)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SeparatorActive(),      0x1ABF9AFF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DockingPreview(),       0x42FAD1B3)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TextSelectedBg(),       0x42FAD159)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_NavHighlight(),         0x42FAD1FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(),              0x297A5C8A)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgHovered(),       0x42FA9466)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgActive(),        0x42FA73AB)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBgActive(),        0x297A4BFF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_CheckMark(),            0x42FA84FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrab(),           0x3DE099FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrabActive(),     0x4DFA42FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),               0x42FAE766)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(),        0x42FA63FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),         0x0FFA5CFF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Header(),               0x42FAB54F)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderHovered(),        0x42FAC0CC)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderActive(),         0x42FA9FFF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Separator(),            0x6E807280)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TabHovered(),           0x42FA89CC)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Tab(),                  0x2E945CDC)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TabActive(),            0x33AD92FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TabSelectedOverline(),  0x42FA52FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DockingPreview(),       0x42FACBB3)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TextLink(),             0x42FA63FF)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TextSelectedBg(),       0x42FA8459)
    -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_NavCursor(),            0x42FA6EFF)


    local BG_COLOR = BG_ATTACHED and BG_COLOR_ATTACHED or BG_COLOR_CURRENT
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), BG_COLOR) -- LKC -- toggleable BG
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), BG_COLOR) -- LKC -- toggleable BG
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_PopupBg(), BG_COLOR) -- LKC -- toggleable BG
    r.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), 0x2D4F47FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(), 0x42FAD1AB)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(), 0x42FAD1F2)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(), 0x42FAD133)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(), 0x42FAD14F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(), 0x33AD92FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabActive(), 0x3B9D87FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocused(), 0x112622F8)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocusedActive(), 0x236C5CFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x33AD92FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x0FFAC5FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0x297A688A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), 0x42FAD166)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), 0x42FAD1AB)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), 0x297A68FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), 0x42FAD1FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), 0x3DE0BBFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), 0x42FAD1FF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x42FAD166)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), 0x297A688A)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), 0x42FAD14F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), 0x42FAD14F)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), 0x6E807C80)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorHovered(), 0x1ABF9AC7)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorActive(), 0x1ABF9AFF)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DockingPreview(), 0x42FAD1B3)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextSelectedBg(), 0x42FAD159)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavHighlight(), 0x42FAD1FF)



    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(),  7, 4)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(),   7, 7)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FrameRounding(), 2)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_WindowPadding(), 5, 5)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(),  2, 3)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(),   5, 2)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 1100, 500, FLT_MAX, FLT_MAX)
    r.ImGui_SetNextWindowSize(ctx, 1000, 800, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, 'ReaSpaghetti - ALPHA - ' .. PROJECT_NAME .. '###ReaSpaghetti', true,
        WND_FLAGS)
    TOOLBAR_DRAG = r.ImGui_IsItemHovered(ctx)
    if visible then
        -- Check for ESC key to exit (unless a popup is using it)
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) and
            not r.ImGui_IsPopupOpen(ctx, '', r.ImGui_PopupFlags_AnyPopupId() | r.ImGui_PopupFlags_AnyPopupLevel()) then
            open = false
        end
        if not ACTIVE_TRACK then
            -- NO TRACK SELECTED - GRAPH IS NOT PERSISTED ANYWHERE SO BLOCK EDITING
            r.ImGui_BeginDisabled(ctx)
            frame()
            r.ImGui_EndDisabled(ctx)
            local wx, wy = r.ImGui_GetWindowPos(ctx)
            local ww, wh = r.ImGui_GetWindowSize(ctx)
            local hint = "Select a track to edit its graph"
            local tw = r.ImGui_CalcTextSize(ctx, hint)
            r.ImGui_DrawList_AddText(r.ImGui_GetForegroundDrawList(ctx),
                wx + (ww - tw) / 2, wy + wh / 2, 0xFFFFFFFF, hint)
        else
            frame()
        end
        r.ImGui_End(ctx)
    end
    r.ImGui_PopStyleVar(ctx, 6)
    reaper.ImGui_PopStyleColor(ctx, 31)

    if not CLOSE then
        r.defer(function() xpcall(loop, crash) end)
    end

    if not open then
        SaveGraphToTrack(ACTIVE_TRACK)
        CLOSE = true
    end
    NEXT_FRAME = true
    if PROFILE_DEBUG and PROFILE_STARTED then
        profiler2.stop()
        profiler2.report(PATH .. "profiler.log")
        PROFILE_DEBUG, PROFILE_STARTED = false, nil
        OpenFile(PATH .. "profiler.log")
    end
end
InitApi()
InitLibrary()
InitStartFunction()
r.defer(function() xpcall(loop, crash) end)
