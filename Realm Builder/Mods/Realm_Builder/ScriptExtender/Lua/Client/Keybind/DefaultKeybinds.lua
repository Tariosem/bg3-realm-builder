--- @type table<string, table<string, Keybinding>>
local DEFAULT_KEYBINDS = {}

DEFAULT_KEYBINDS.TransformToolbar = {
    ["MultiSelect"] = { Key = "LSHIFT" },
    ["Select"] = { Key = "MMB" },
    ["ClearSelection"] = { Key = "ESCAPE" },
    ["Duplicate"] = { Key = "D", Modifiers = { "SHIFT" } },
    ["BoxSelect"] = { Key = "LMB", Modifiers = { "SHIFT" } },
    ["HideSelection"] = { Key = "H" },
    ["ShowSelection"] = { Key = "H", Modifiers = { "SHIFT" } },
    ["ApplyGravity"] = { Key = "G", Modifiers = { "SHIFT" } },
    ["FreezeGravity"] = { Key = "F", Modifiers = { "SHIFT" } },
    ["Undo"] = { Key = "Z", Modifiers = { "CTRL" } },
    ["Redo"] = { Key = "Y", Modifiers = { "CTRL" } },
    ["OpenVisualTab"] = { Key = "TAB", Modifiers = { "SHIFT" } },
    ["DeleteAllGizmos"] = { Key = "X", Modifiers = { "SHIFT" } },
    ["Move3DCursor"] = { Key = "RMB", Modifiers = { "SHIFT" } },
}

DEFAULT_KEYBINDS.TransformEditor = {
    ["TranslateMode"] = { Key = "G" },
    ["RotateMode"] = { Key = "R" },
    ["ScaleMode"] = { Key = "L" },
    ["FollowTarget"] = { Key = "KP_PERIOD" },
}

DEFAULT_KEYBINDS.BindUtility = {
    ["BindPopup"] = { Key = "K", Modifiers = { "SHIFT" } },
    ["BindTo"] = { Key = "B", Modifiers = { "SHIFT" } },
    ["Unbind"] = { Key = "U" },
    ["Snap"] = { Key = "S", Modifiers = { "CTRL" } },
}

return DEFAULT_KEYBINDS