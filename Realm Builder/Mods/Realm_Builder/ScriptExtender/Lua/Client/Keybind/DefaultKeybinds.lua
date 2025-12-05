--- @type table<string, table<string, Keybinding>>
local DEFAULT_KEYBINDS = {

    GeneralShortcuts = {
        ["OpenMainMenu"] = { Key = "GRAVE" },
        ["OpenBrowserMenu"] = { Key = "F1" },
        ["OpenTransformToolbar"] = { Key = "TAB" },
        ["OpenVisualTab"] = { Key = "SLASH" },
        ["DeleteAllGizmos"] = { Key = "X", Modifiers = { "SHIFT" } },
    },

    TransformToolbar = {
        ["MultiSelect"] = { Key = "LSHIFT" },
        ["Select"] = { Key = "MMB" },
        ["ClearSelection"] = { Key = "ESCAPE" },
        ["Duplicate"] = { Key = "D", Modifiers = { "SHIFT" } },
        ["BoxSelect"] = { Key = "LMB", Modifiers = { "SHIFT" } },
        ["DeleteSelection"] = { Key = "DEL" },
        ["HideSelection"] = { Key = "H" },
        ["ShowSelection"] = { Key = "H", Modifiers = { "SHIFT" } },
        ["ApplyGravity"] = { Key = "G", Modifiers = { "SHIFT" } },
        ["FreezeGravity"] = { Key = "F", Modifiers = { "SHIFT" } },
        ["Undo"] = { Key = "Z", Modifiers = { "CTRL" } },
        ["Redo"] = { Key = "Y", Modifiers = { "CTRL" } },
        ["Move3DCursor"] = { Key = "RMB", Modifiers = { "SHIFT" } },
    },

    TransformEditor = {
        ["Grab"] = { Key = "G" },
        ["Rotate"] = { Key = "R" },
        ["Scale"] = { Key = "L" },
        ["FollowTarget"] = { Key = "KP_PERIOD" },
        ["CycleMode"] = { Key = "T" }
    },

    BindUtility = {
        ["BindPopup"] = { Key = "K", Modifiers = { "SHIFT" } },
        ["BindTo"] = { Key = "B", Modifiers = { "SHIFT" } },
        ["Unbind"] = { Key = "U" },
        ["Snap"] = { Key = "S", Modifiers = { "CTRL" } },
    },
    
}

return DEFAULT_KEYBINDS