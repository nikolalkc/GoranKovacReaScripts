--@noindex
--NoIndex: true

-- UNDO SYSTEM
-- Each entry is a full serialized snapshot of the node graph (FUNCTIONS +
-- CURRENT_FUNCTION), taken BEFORE a mutating action runs. Undoing restores the
-- snapshot via RestoreNodes(), which also relinks every metatable. Using full
-- snapshots (instead of per-node deltas) means any operation - wire delete,
-- node delete with its cascading cleanup, paste, etc. - is undone correctly
-- without bespoke revert logic per operation.

local UNDO = {}
local UNDO_LIMIT = 30

function ClearUndo()
    UNDO = {}
end

-- Push a snapshot of the CURRENT graph state onto the undo stack.
-- Call this BEFORE performing the mutating action so the snapshot captures the
-- pre-action state. `label` is optional and only used for readability/debugging.
function AddUndo(label)
    UNDO[#UNDO + 1] = { state = StoreNodes(), label = label }
    -- TRIM OLDEST ENTRIES IF WE EXCEED THE LIMIT
    while #UNDO > UNDO_LIMIT do
        table.remove(UNDO, 1)
    end
end

function DoUndo()
    if #UNDO == 0 then return end
    local entry = table.remove(UNDO, #UNDO)
    RestoreNodes(entry.state)
end
