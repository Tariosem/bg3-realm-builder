DEFAULT_KEYBINDS = DEFAULT_KEYBINDS or {}

DEFAULT_KEYBINDS.TransformToolbar = {
    ["MultiSelect"] = { Key = "M"},
    ["Select"] = { Key = "MMB" },
    ["ClearSelection"] = { Key = "ESCAPE" },
    ["Duplicate"] = { Key = "D", Modifiers = { "LShift" } },
    ["BoxSelect"] = { Key = "B" },
    ["Undo"] = { Key = "Z", Modifiers = { "LCtrl" }},
    ["Redo"] = { Key = "X", Modifiers = { "LCtrl" } },
    ["OpenVisualTab"] = { Key = "TAB", Modifiers = { "LShift" } },
    ["FocusInput"] = { Key = "GRAVE" }
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
--- @class KeybindHelper
--- @field KeyToChar table<SDLScanCode, string>
--- @field ShiftKeyToChar table<SDLScanCode, string>
KeybindHelper = {
    KeyToChar = {
        ["KP_DECIMAL"] = ".",
        ["KP_MINUS"] = "-",
        ["KP_PLUS"] = "+",
        ["KP_DIVIDE"] = "/",
        ["KP_MULTIPLY"] = "*",
        ["MINUS"] = "-", ["EQUALS"] = "=",
        ["LEFTBRACKET"] = "[", ["RIGHTBRACKET"] = "]",
        ["BACKSLASH"] = "\\",
        ["SEMICOLON"] = ";", ["APOSTROPHE"] = "'",
        ["COMMA"] = ",", ["PERIOD"] = ".", ["SLASH"] = "/",
        ["SPACE"] = " ",
        ["GRAVE"] = "`",
    },
    ShiftKeyToChar = {
        ["NUM_1"] = "!", ["NUM_2"] = "@", ["NUM_3"] = "#", ["NUM_4"] = "$", ["NUM_5"] = "%",
        ["NUM_6"] = "^", ["NUM_7"] = "&", ["NUM_8"] = "*", ["NUM_9"] = "(", ["NUM_0"] = ")",
        ["KP_DECIMAL"] = ".",
        ["KP_MINUS"] = "-",
        ["KP_PLUS"] = "+",
        ["KP_DIVIDE"] = "/",
        ["KP_MULTIPLY"] = "*",
        ["MINUS"] = "_", ["EQUALS"] = "+",
        ["LEFTBRACKET"] = "{", ["RIGHTBRACKET"] = "}",
        ["BACKSLASH"] = "|",
        ["SEMICOLON"] = ":", ["APOSTROPHE"] = "\"",
        ["COMMA"] = "<", ["PERIOD"] = ">", ["SLASH"] = "?",
        ["SPACE"] = " ",
        ["GRAVE"] = "~",
    }
}

for c = string.byte("A"), string.byte("Z") do
    local ch = string.char(c)
    KeybindHelper.KeyToChar[ch] = ch:lower()
    KeybindHelper.ShiftKeyToChar[ch] = ch
end

for i=0, 9 do
    KeybindHelper.KeyToChar["NUM_" .. i] = tostring(i)
    KeybindHelper.KeyToChar["KP_" .. i] = tostring(i)
    KeybindHelper.ShiftKeyToChar["KP_" .. i] = tostring(i)
end

--- @param e SimplifiedInputEvent
function KeybindHelper.ParseInputToCharInput(e)
    local isShift = table.find(e.Modifiers or {}, "LShift") or table.find(e.Modifiers or {}, "RShift")

    if isShift then
        return KeybindHelper.ShiftKeyToChar[e.Key] or e.Key
    else
        return KeybindHelper.KeyToChar[e.Key] or e.Key
    end
end