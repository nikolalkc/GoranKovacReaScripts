--@noindex
--NoIndex: true

-- SLIDER / KNOB CONTROLLER NODES
-- WIDGETS ADAPTED FROM LKC VARIATOR (MySlider / MyKnob), STRIPPED TO SINGLE VALUE

local r = reaper

local min, floor, cos, sin, pi = math.min, math.floor, math.cos, math.sin, math.pi

local COL_TRACK_BG       = 0x1E1E1EFF -- REAPER 7: dark input bg
local COL_TRACK_BG_HOVER = 0x2A2A2AFF
local COL_FILL           = 0x15BC99CC -- REAPER green fill
local COL_ANCHOR         = 0xF0F0F0FF -- near-white marker
local COL_ARC_BG         = 0x33333355

-- RAW (UNROUNDED) DRAG VALUES PER NODE, ONLY ALIVE WHILE DRAGGING
-- SO INTEGER MODE CAN ACCUMULATE SUB-STEP MOUSE MOVEMENT
local drag_state = {}

local function RoundInt(v) return floor(v + 0.5) end

local function ClampVal(v, ctrl)
    if v < ctrl.min then v = ctrl.min end
    if v > ctrl.max then v = ctrl.max end
    if ctrl.is_int then v = RoundInt(v) end
    return v
end

local function CurrentValue(pin, ctrl)
    local v = pin.i_val
    if type(v) ~= "number" then v = ctrl.min end
    return ClampVal(v, ctrl)
end

local function OpenSettingsOnRightClick(node)
    if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseReleased(ctx, 1) and not IS_DRAGGING_RIGHT_CANVAS then
        CTRL_SETTINGS_NODE = node
        OPEN_CTRL_SETTINGS = true
    end
end

local function ValueTooltip(v, ctrl)
    if r.ImGui_BeginTooltip(ctx) then
        r.ImGui_PushFont(ctx, FONT_STATIC)
        r.ImGui_Text(ctx, ctrl.is_int and ('%d'):format(v) or ('%.3f'):format(v))
        r.ImGui_PopFont(ctx)
        r.ImGui_EndTooltip(ctx)
    end
end

local function FineAdjust()
    return r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl()) or r.ImGui_IsKeyDown(ctx, r.ImGui_Key_RightCtrl())
end

-- APPLY RAW DRAG VALUE -> CLAMPED/ROUNDED VALUE, RETURN (value, changed)
local function ApplyDrag(node, ctrl, value, raw)
    if raw < ctrl.min then raw = ctrl.min end
    if raw > ctrl.max then raw = ctrl.max end
    drag_state[node.guid] = raw
    local new_val = ClampVal(raw, ctrl)
    if new_val ~= value then return new_val, true end
    return value, false
end

local function DrawSlider(node, pin, x, y, w, h)
    local ctrl = node.ctrl
    local dl = r.ImGui_GetWindowDrawList(ctx)
    local is_vertical = h > w
    local value = CurrentValue(pin, ctrl)
    local changed = false

    r.ImGui_SetCursorScreenPos(ctx, x, y)
    r.ImGui_InvisibleButton(ctx, "##ctrl" .. node.guid, w, h)
    local is_active = r.ImGui_IsItemActive(ctx)
    local is_hovered = r.ImGui_IsItemHovered(ctx)
    OpenSettingsOnRightClick(node)

    if is_active and r.ImGui_IsMouseDown(ctx, 0) then
        local raw
        if FineAdjust() then
            -- FINE ADJUST: RELATIVE DRAG, 10X SLOWER
            local dx, dy = r.ImGui_GetMouseDelta(ctx)
            local delta = is_vertical and -dy or dx
            local span = is_vertical and h or w
            raw = (drag_state[node.guid] or value) + delta * ((ctrl.max - ctrl.min) / span) * 0.1
        else
            -- VALUE FOLLOWS MOUSE POSITION (CLICK JUMPS STRAIGHT TO POINT)
            local mx, my = r.ImGui_GetMousePos(ctx)
            local t = is_vertical and (1 - ((my - y) / h)) or ((mx - x) / w)
            if t < 0 then t = 0 end
            if t > 1 then t = 1 end
            raw = ctrl.min + t * (ctrl.max - ctrl.min)
        end
        value, changed = ApplyDrag(node, ctrl, value, raw)
    else
        drag_state[node.guid] = nil
    end

    local rounding = 3 * CANVAS.scale
    local track_col = (is_active or is_hovered) and COL_TRACK_BG_HOVER or COL_TRACK_BG
    r.ImGui_DrawList_AddRectFilled(dl, x, y, x + w, y + h, track_col, rounding)

    local range = ctrl.max - ctrl.min
    local t = range ~= 0 and (value - ctrl.min) / range or 0
    if is_vertical then
        local fill_y = y + h * (1 - t)
        r.ImGui_DrawList_AddRectFilled(dl, x, fill_y, x + w, y + h, COL_FILL, rounding)
        r.ImGui_DrawList_AddLine(dl, x, fill_y, x + w, fill_y, COL_ANCHOR, 2 * CANVAS.scale)
    else
        local fill_x = x + w * t
        r.ImGui_DrawList_AddRectFilled(dl, x, y, fill_x, y + h, COL_FILL, rounding)
        r.ImGui_DrawList_AddLine(dl, fill_x, y, fill_x, y + h, COL_ANCHOR, 2 * CANVAS.scale)
    end

    if is_active or is_hovered then ValueTooltip(value, ctrl) end
    return changed, value
end

local function DrawKnob(node, pin, x, y, w, h)
    local ctrl = node.ctrl
    local dl = r.ImGui_GetWindowDrawList(ctx)
    local value = CurrentValue(pin, ctrl)
    local changed = false

    local radius = min(w, h) / 2
    local cx, cy = x + w / 2, y + h / 2

    r.ImGui_SetCursorScreenPos(ctx, x, y)
    r.ImGui_InvisibleButton(ctx, "##ctrl" .. node.guid, w, h)
    local is_active = r.ImGui_IsItemActive(ctx)
    local is_hovered = r.ImGui_IsItemHovered(ctx)
    OpenSettingsOnRightClick(node)

    if is_active and r.ImGui_IsMouseDown(ctx, 0) then
        local _, dy = r.ImGui_GetMouseDelta(ctx)
        if dy ~= 0 then
            local step_factor = FineAdjust() and 1000 or 200
            local raw = (drag_state[node.guid] or value) - dy * ((ctrl.max - ctrl.min) / step_factor)
            value, changed = ApplyDrag(node, ctrl, value, raw)
        end
    else
        drag_state[node.guid] = nil
    end

    local ANGLE_MIN, ANGLE_MAX = pi * 0.75, pi * 2.25
    local range = ctrl.max - ctrl.min
    local t = range ~= 0 and (value - ctrl.min) / range or 0
    local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
    local thickness = radius * 0.15 > 2 and radius * 0.15 or 2
    local arc_radius = radius - thickness / 2
    local radius_inner = radius * 0.40

    local knob_col = (is_active or is_hovered) and COL_TRACK_BG_HOVER or COL_TRACK_BG
    r.ImGui_DrawList_AddCircleFilled(dl, cx, cy, radius, knob_col)

    -- FULL RANGE BG ARC
    r.ImGui_DrawList_PathArcTo(dl, cx, cy, arc_radius, ANGLE_MIN, ANGLE_MAX)
    r.ImGui_DrawList_PathStroke(dl, COL_ARC_BG, r.ImGui_DrawFlags_None(), thickness)

    -- VALUE ARC
    if angle > ANGLE_MIN then
        r.ImGui_DrawList_PathArcTo(dl, cx, cy, arc_radius, ANGLE_MIN, angle)
        r.ImGui_DrawList_PathStroke(dl, COL_FILL, r.ImGui_DrawFlags_None(), thickness)
    end

    -- INDICATOR LINE
    local acos, asin = cos(angle), sin(angle)
    r.ImGui_DrawList_AddLine(dl, cx + acos * radius_inner, cy + asin * radius_inner,
        cx + acos * (radius - thickness), cy + asin * (radius - thickness),
        COL_ANCHOR, 2 * CANVAS.scale)

    if is_active or is_hovered then ValueTooltip(value, ctrl) end
    return changed, value
end

function DrawControllerWidget(node, pin, x, y, w, h)
    if w < 4 or h < 4 then return end
    -- INIT PIN VALUES ON FIRST DRAW SO UNTOUCHED CONTROLLERS STILL OUTPUT A NUMBER
    if type(pin.i_val) ~= "number" then
        pin.i_val = CurrentValue(pin, node.ctrl)
        pin.o_val = pin.i_val
    end
    local changed, value
    if node.type == "slider" then
        changed, value = DrawSlider(node, pin, x, y, w, h)
    else
        changed, value = DrawKnob(node, pin, x, y, w, h)
    end
    if changed then
        pin.i_val = value
        pin.o_val = value
    end
    return changed
end

-- BODY OF THE "CTRL_SETTINGS" POPUP (REGISTERED IN UI.lua Popups())
function DrawControllerSettings(node)
    if not node then return end
    local ctrl = node.ctrl
    local changed = false

    r.ImGui_PushFont(ctx, FONT_STATIC)
    r.ImGui_Text(ctx, node.label)
    r.ImGui_Separator(ctx)

    local fmt = ctrl.is_int and '%.0f' or '%.3f'
    r.ImGui_SetNextItemWidth(ctx, 120)
    local rv_min, new_min = r.ImGui_DragDouble(ctx, "MIN", ctrl.min, 0.1, 0, 0, fmt)
    if rv_min then
        ctrl.min = new_min > ctrl.max and ctrl.max or new_min
        changed = true
    end
    r.ImGui_SetNextItemWidth(ctx, 120)
    local rv_max, new_max = r.ImGui_DragDouble(ctx, "MAX", ctrl.max, 0.1, 0, 0, fmt)
    if rv_max then
        ctrl.max = new_max < ctrl.min and ctrl.min or new_max
        changed = true
    end

    local rv_int, new_int = r.ImGui_Checkbox(ctx, "INTEGER OUTPUT", ctrl.is_int)
    if rv_int then
        ctrl.is_int = new_int
        node.outputs[1].type = new_int and "INTEGER" or "NUMBER"
        if new_int then
            ctrl.min = RoundInt(ctrl.min)
            ctrl.max = RoundInt(ctrl.max)
        end
        changed = true
    end
    r.ImGui_PopFont(ctx)

    if changed then
        -- RE-CLAMP CURRENT VALUE INTO THE NEW RANGE/MODE
        local pin = node.outputs[1]
        if type(pin.i_val) == "number" then
            pin.i_val = ClampVal(pin.i_val, ctrl)
            pin.o_val = pin.i_val
        end
    end
    return changed
end
