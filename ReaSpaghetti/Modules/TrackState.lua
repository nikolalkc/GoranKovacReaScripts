--@noindex
--NoIndex: true

local r = reaper

local EXT_KEY = "P_EXT:ReaSpaghetti_Graph"

-- SERIALIZED DATA CONTAINS NEWLINES WHICH ARE NOT SAFE IN TRACK CHUNK EXT STATE
local function EncodeGraphData(data)
    return data:gsub("[%%\r\n]", function(c) return string.format("%%%02X", c:byte()) end)
end

local function DecodeGraphData(data)
    return data:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
end

local function GetTrackGraphData(track)
    local rv, data = r.GetSetMediaTrackInfo_String(track, EXT_KEY, "", false)
    if rv and data ~= "" then return data end
end

function SaveGraphToTrack(track)
    if not track then return end
    if not r.ValidatePtr2(0, track, "MediaTrack*") then return end
    -- DONT POLLUTE VISITED TRACKS WITH AN UNTOUCHED DEFAULT GRAPH
    if not AreFunctionsDirty() and not GetTrackGraphData(track) then return end
    local data = EncodeGraphData(StoreNodes())
    r.GetSetMediaTrackInfo_String(track, EXT_KEY, data, true)
end

local function SetBlankProject()
    ClearProject()
    CANVAS = GetFUNCTIONS()[CURRENT_FUNCTION].CANVAS
    DIRTY = nil
    ClearUndo()
end

function LoadGraphFromTrack(track)
    local data = GetTrackGraphData(track)
    if not data or not RestoreNodes(DecodeGraphData(data)) then
        SetBlankProject()
    else
        ClearUndo()
    end
    local _, tr_name = r.GetTrackName(track)
    local tr_num = math.floor(r.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    PROJECT_NAME = tr_num .. ": " .. tr_name
end

local watcher_initialized
local ACTIVE_PROJECT
function TrackSelectionWatcher()
    local proj = r.EnumProjects(-1)
    if watcher_initialized and proj ~= ACTIVE_PROJECT then
        -- PROJECT TAB SWITCHED - STOP ANY RUNNING/DEFERRED FLOW BEFORE THE GRAPH IT REFERS TO IS GONE
        StopFlowExecution()
        -- FLUSH CURRENT GRAPH TO ITS TRACK BEFORE THE OLD TRACK POINTER GOES STALE
        SaveGraphToTrack(ACTIVE_TRACK)
        ACTIVE_TRACK = nil
    end
    ACTIVE_PROJECT = proj

    local sel = r.GetSelectedTrack(0, 0)
    if watcher_initialized and sel == ACTIVE_TRACK then return end
    watcher_initialized = true
    -- TRACK SELECTION CHANGED - STOP ANY RUNNING/DEFERRED FLOW BEFORE SWAPPING THE GRAPH OUT
    StopFlowExecution()
    SaveGraphToTrack(ACTIVE_TRACK)
    ACTIVE_TRACK = sel
    if sel then
        LoadGraphFromTrack(sel)
    else
        SetBlankProject()
        PROJECT_NAME = "No Track Selected"
    end
end
