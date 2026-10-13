RB_KEYBIND_LOOKUP = {
    GeneralShortcuts = {
        ["OpenMainMenu"] = "OpenMainMenu",
        ["OpenBrowserMenu"] = "OpenBrowserMenu",
        ["OpenTransformToolbar"] = "OpenTransformToolbar",
        ["OpenVisualTab"] = "OpenVisualTab",
        ["DeleteAllGizmos"] = "DeleteAllGizmos",
    },
    TransformToolbar = {
        ["Select"] = "Select",
        ["ClearSelection"] = "ClearSelection",
        ["Duplicate"] = "Duplicate",
        ["BoxSelect"] = "BoxSelect",
        ["DeleteSelection"] = "DeleteSelection",
        ["ToggleGravity"] = "ToggleGravity",
        ["ToggleVisibility"] = "ToggleVisibility",
        ["SnapToHover"] = "SnapToHover",
        ["SnapToGround"] = "SnapToGround",
        ["OpenNearbyPopup"] = "OpenNearbyPopup",
        ["MoveToCursor"] = "MoveToCursor",
        ["LookAtCursor"] = "LookAtCursor",
        ["Undo"] = "Undo",
        ["Redo"] = "Redo",
        ["Move3DCursor"] = "Move3DCursor",
    },
    TransformEditor = {
        ["Grab"] = "Grab",
        ["Rotate"] = "Rotate",
        ["Scale"] = "Scale",
        ["CycleMode"] = "CycleMode"
    },
    BindUtility = {
        ["BindPopup"] = "BindPopup",
        ["BindTo"] = "BindTo",
        ["Unbind"] = "Unbind",
    },
    CameraTool = {
        ["ToggleOrbitalCamera"] = "ToggleOrbitalCamera",
        ["ToggleCameraToolWindow"] = "ToggleCameraToolWindow",
    }
}

RB_KEYBIND_LOCALIZED_NAMES = {
    GeneralShortcuts = "General Shortcuts",

    OpenMainMenu = "Toggle Main Menu",
    OpenBrowserMenu = "Toggle Browser Menu",
    OpenTransformToolbar = "Toggle Transform Toolbar",
    OpenVisualTab = "Open Visual Tab",
    DeleteAllGizmos = "Clear All Gizmos",

    TransformToolbar = "Transform Toolbar",

    MultiSelect = "Multi Select",
    BoxSelect = "Box Select",
    Select = "Select",
    ClearSelection = "Clear Selection",
    DeleteSelection = "Delete Selection",
    Duplicate = "Duplicate Selection",
    ToggleVisibility = "Toggle Visibility",
    ToggleGravity = "Toggle Gravity",
    SnapToGround = "Snap To Ground",
    OpenNearbyPopup = "Depth Selection Popup",
    MoveToCursor = "Move To Cursor",
    LookAtCursor = "Look At Cursor",
    Move3DCursor = "Move 3D Cursor",
    Snap3DCursor = "Snap 3D Cursor",
    SnapToHover = "Snap To Hover",
    Undo = "Undo",
    Redo = "Redo",

    TransformEditor = "Transform Editor",

    CycleMode = "Cycle Mode",
    Grab = "Grab",
    Rotate = "Rotate",
    Scale = "Scale",

    BindUtility = "Bind Utility",

    BindPopup = "Open Bind Popup",
    BindTo = "Bind To Hover",
    Unbind = "Unbind Selection",

    CameraTool = "Camera Tool",

    ToggleOrbitalCamera = "Toggle Orbital Camera",
    ToggleCameraToolWindow = "Toggle Camera Tool Window",
}

--- @type table<string, table<string, Keybinding>>
return {
    GeneralShortcuts = {
        ["OpenMainMenu"] = { Key = "GRAVE" },
        ["OpenBrowserMenu"] = { Key = "F1" },
        ["OpenTransformToolbar"] = { Key = "F2" },
        --["OpenVisualTab"] = { Key = "SLASH" },
        ["DeleteAllGizmos"] = { Key = "X", Modifiers = { "SHIFT" } },
    },

    TransformToolbar = {
        ["Select"] = { Key = "MMB" },
        --["ClearSelection"] = { Key = "ESCAPE" },
        ["Duplicate"] = { Key = "D", Modifiers = { "SHIFT" } },
        ["BoxSelect"] = { Key = "LMB", Modifiers = { "SHIFT" } },
        ["DeleteSelection"] = { Key = "DEL" },
        ["ToggleVisibility"] = { Key = "H" },
        ["ToggleGravity"] = { Key = "G", Modifiers = { "SHIFT" } },
        ["SnapToHover"] = { Key = "S", Modifiers = { "CTRL" } },
        ["SnapToGround"] = { Key = "G", Modifiers = { "CTRL" } },
        ["OpenNearbyPopup"] = { Key = "D", Modifiers = { "CTRL" } },
        ["Undo"] = { Key = "Z", Modifiers = { "CTRL" } },
        ["Redo"] = { Key = "Y", Modifiers = { "CTRL" } },
        ["Move3DCursor"] = { Key = "RMB", Modifiers = { "SHIFT" } },
    },

    TransformEditor = {
        ["Grab"] = { Key = "G" },
        ["Rotate"] = { Key = "R" },
        ["Scale"] = { Key = "L" },
        ["CycleMode"] = { Key = "T" }
    },

    BindUtility = {
        ["BindPopup"] = { Key = "K", Modifiers = { "SHIFT" } },
        ["BindTo"] = { Key = "B", Modifiers = { "SHIFT" } },
        ["Unbind"] = { Key = "U" },
    },

    CameraTool = {
        ["ToggleOrbitalCamera"] = { Key = "KP_PERIOD" },
     }
}


