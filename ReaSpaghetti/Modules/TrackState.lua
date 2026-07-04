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

-- TRACKS WITHOUT THEIR OWN GRAPH INHERIT FROM THE NEAREST FOLDER PARENT THAT HAS ONE
local function GetGraphOwnerTrack(track)
    if GetTrackGraphData(track) then return track end
    local parent = r.GetParentTrack(track)
    while parent do
        if GetTrackGraphData(parent) then return parent end
        parent = r.GetParentTrack(parent)
    end
    return track
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

local function TrackLabel(track)
    local _, tr_name = r.GetTrackName(track)
    local tr_num = math.floor(r.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    return tr_num .. ": " .. tr_name
end

function IsGraphInherited()
    return ACTIVE_TRACK ~= nil and GRAPH_TRACK ~= nil and ACTIVE_TRACK ~= GRAPH_TRACK
end

function GetGraphOwnerLabel()
    if GRAPH_TRACK and r.ValidatePtr2(0, GRAPH_TRACK, "MediaTrack*") then
        return TrackLabel(GRAPH_TRACK)
    end
end

-- GIVE THE SELECTED CHILD ITS OWN GRAPH SO IT STOPS INHERITING FROM THE PARENT
function OverrideGraphToSelectedTrack(blank)
    if not IsGraphInherited() then return end
    if not r.ValidatePtr2(0, ACTIVE_TRACK, "MediaTrack*") then return end
    if blank then
        -- RUNNING FLOW REFERS TO THE PARENT GRAPH THAT IS ABOUT TO BE WIPED FROM VIEW
        StopFlowExecution()
        SetBlankProject()
    end
    -- EXPLICIT OVERRIDE - BYPASS THE UNTOUCHED-GRAPH GUARD SO THE CHILD ALWAYS GETS ITS OWN DATA
    r.GetSetMediaTrackInfo_String(ACTIVE_TRACK, EXT_KEY, EncodeGraphData(StoreNodes()), true)
    GRAPH_TRACK = ACTIVE_TRACK
    PROJECT_NAME = TrackLabel(ACTIVE_TRACK)
end

function SelectedTrackHasOwnGraphData()
    if not ACTIVE_TRACK or not r.ValidatePtr2(0, ACTIVE_TRACK, "MediaTrack*") then return false end
    return GetTrackGraphData(ACTIVE_TRACK) ~= nil
end

-- DELETE THE SELECTED TRACK'S OWN GRAPH DATA SO IT FALLS BACK TO INHERITING FROM A PARENT (OR BLANK)
function DeleteGraphFromSelectedTrack()
    if not SelectedTrackHasOwnGraphData() then return end
    -- THE LOADED GRAPH IS BEING DISCARDED FROM UNDER ANY RUNNING FLOW
    StopFlowExecution()
    r.GetSetMediaTrackInfo_String(ACTIVE_TRACK, EXT_KEY, "", true)
    -- FORCE A RELOAD OF WHATEVER THE TRACK RESOLVES TO NOW (PARENT GRAPH OR BLANK)
    GRAPH_TRACK = nil
    LoadGraphFromTrack(ACTIVE_TRACK)
end

function LoadGraphFromTrack(track)
    local owner = GetGraphOwnerTrack(track)
    -- OWNER GRAPH ALREADY LOADED (E.G. MOVING BETWEEN A PARENT AND ITS DATALESS CHILDREN) - KEEP IT
    if owner ~= GRAPH_TRACK then
        local data = GetTrackGraphData(owner)
        if not data or not RestoreNodes(DecodeGraphData(data)) then
            SetBlankProject()
        else
            ClearUndo()
        end
    end
    GRAPH_TRACK = owner
    PROJECT_NAME = TrackLabel(track)
    if owner ~= track then
        PROJECT_NAME = PROJECT_NAME .. "  [graph from parent " .. TrackLabel(owner) .. "]"
    end
end

local watcher_initialized
local ACTIVE_PROJECT
function TrackSelectionWatcher()
    local proj = r.EnumProjects(-1)
    if watcher_initialized and proj ~= ACTIVE_PROJECT then
        -- PROJECT TAB SWITCHED - STOP ANY RUNNING/DEFERRED FLOW BEFORE THE GRAPH IT REFERS TO IS GONE
        StopFlowExecution()
        -- FLUSH CURRENT GRAPH TO ITS TRACK BEFORE THE OLD TRACK POINTER GOES STALE
        SaveGraphToTrack(GRAPH_TRACK)
        ACTIVE_TRACK = nil
        GRAPH_TRACK = nil
    end
    ACTIVE_PROJECT = proj

    local sel = r.GetSelectedTrack(0, 0)
    if watcher_initialized and sel == ACTIVE_TRACK then return end
    watcher_initialized = true
    -- ONLY STOP/FLUSH WHEN THE LOADED GRAPH IS ACTUALLY BEING SWAPPED OUT -
    -- MOVING BETWEEN A PARENT AND ITS DATALESS CHILDREN KEEPS THE FLOW RUNNING
    local owner = sel and GetGraphOwnerTrack(sel) or nil
    if owner ~= GRAPH_TRACK then
        StopFlowExecution()
        SaveGraphToTrack(GRAPH_TRACK)
    end
    ACTIVE_TRACK = sel
    if sel then
        LoadGraphFromTrack(sel)
    else
        SetBlankProject()
        GRAPH_TRACK = nil
        PROJECT_NAME = "No Track Selected"
    end
end
