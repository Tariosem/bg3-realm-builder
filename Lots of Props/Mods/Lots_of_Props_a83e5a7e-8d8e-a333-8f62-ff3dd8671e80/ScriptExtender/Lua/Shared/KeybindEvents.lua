DEFAULT_KEYBINDS = DEFAULT_KEYBINDS or {}

DEFAULT_KEYBINDS.TransformToolbar = {
    ["MultiSelect"] = { Key = "M"},
    ["Select"] = { Key = "2" },
    ["ClearSelection"] = { Key = "ESCAPE" },
    ["Duplicate"] = { Key = "D", Modifiers = { "LShift" } },
    ["BoxSelect"] = { Key = "B" },
    ["Undo"] = { Key = "Z", Modifiers = { "LCtrl" }},
    ["Redo"] = { Key = "X", Modifiers = { "LCtrl" } },
    ["OpenVisualTab"] = { Key = "TAB", Modifiers = { "LShift" } },
}

DEFAULT_KEYBINDS.TransformEditor = {
    ["TranslateMode"] = { Key = "G" },
    ["RotateMode"] = { Key = "R" },
    ["ScaleMode"] = { Key = "L" },
    ["FollowTarget"] = { Key = "KP_PERIOD" },
    ["DeleteSelection"] = { Key = "X" },
    ["DeleteAllGizmos"] = { Key = "X", Modifiers = { "LShift" }}
}

DEFAULT_KEYBINDS.BindUtility = {
    ["BindPopup"] = { Key = "K", Modifiers = { "LShift" } },
    ["BindTo"] = { Key = "B", Modifiers = { "LShift" } },
    ["Unbind"] = { Key = "U" },
    ["Snap"] = { Key = "S", Modifiers = { "LCtrl" } },
    ["LookAt"] = { Key = "F" },
}

KEYBIND_MODULE_RENDER_ORDER = {
    "Generic",
    "TransformToolbar",
    "TransformEditor",
    "BindUtility",
}

KEYBIND_EVENT_RENDER_ORDER = {
    TransformToolbar = {
        "MultiSelect",
        "BoxSelect",
        "Select",
        "ClearSelection",
        "Duplicate",
        "Undo",
        "Redo",
        "OpenVisualTab",
        "HideSelection",
        "ShowSelection",
        "ApplyGravity",
        "FreezeGravity",
    },
    TransformEditor = {
        "TranslateMode",
        "RotateMode",
        "ScaleMode",
        "FollowTarget",
        "DeleteSelection",
        "DeleteAllGizmos",
    },
    BindUtility = {
        "BindPopup",
        "BindTo",
        "Unbind",
        "Snap",
        "LookAt",
    },
}