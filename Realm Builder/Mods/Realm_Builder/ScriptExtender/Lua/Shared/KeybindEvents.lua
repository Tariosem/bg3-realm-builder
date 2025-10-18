--- @alias KeybindingIdentifier string format like "A|LCtrl|LShift"

--- @class Keybinding
--- @field Key SimplifiedInputCode
--- @field Modifiers SDLKeyModifier[]|nil
--- @field new fun(key:SimplifiedInputCode, modifiers:SDLKeyModifier[]|nil):Keybinding
--- @field CreateIdentifier fun(self: Keybinding): KeybindingIdentifier
--- @field FromIdentifier fun(identifier: KeybindingIdentifier): Keybinding

Keybinding = _Class("Keybinding")

function Keybinding:__init(key, modifiers)
    self.Key = key
    self.Modifiers = modifiers or {}
end

function Keybinding:CreateIdentifier()
    if #self.Modifiers == 0 then
        return self.Key
    end
    return self.Key .. "|" .. table.concat(self.Modifiers, "|")
end

function Keybinding.FromIdentifier(identifier)
    local parts = string.split(identifier, "|")
    local key = parts[1]
    local modifiers = {}
    for i = 2, #parts do
        table.insert(modifiers, parts[i])
    end
    return Keybinding.new(key, modifiers)
end

Keybinding.__eq = function(a, b)
    if a.Key ~= b.Key then
        return false
    end

    if #a.Modifiers ~= #b.Modifiers then
        return false
    end

    for i = 1, #a.Modifiers do
        if a.Modifiers[i] ~= b.Modifiers[i] then
            return false
        end
    end

    return true
end

Keybinding.__tostring = function(t)
    return t:CreateIdentifier()
end

--- @type table<string, table<string, Keybinding>>
DEFAULT_KEYBINDS = {}

--- @diagnostic disable
DEFAULT_KEYBINDS.TransformToolbar = {
    ["MultiSelect"] = { Key = "M"},
    ["Select"] = { Key = "MMB" },
    ["ClearSelection"] = { Key = "ESCAPE" },
    ["Duplicate"] = { Key = "D", Modifiers = { "LShift" } },
    ["BoxSelect"] = { Key = "B" },
    ["HideSelection"] = { Key = "H" },
    ["ShowSelection"] = { Key = "H", Modifiers = { "LShift" } },
    ["ApplyGravity"] = { Key = "G", Modifiers = { "LShift" } },
    ["FreezeGravity"] = { Key = "F", Modifiers = { "LShift" } },
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
        "SlowDown",
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
KeybindHelpers = {
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
    KeybindHelpers.KeyToChar[ch] = ch:lower()
    KeybindHelpers.ShiftKeyToChar[ch] = ch
end

for i=0, 9 do
    KeybindHelpers.KeyToChar["NUM_" .. i] = tostring(i)
    KeybindHelpers.KeyToChar["KP_" .. i] = tostring(i)
    KeybindHelpers.ShiftKeyToChar["KP_" .. i] = tostring(i)
end

--- @param e SimplifiedInputEvent|EclLuaKeyInputEvent
function KeybindHelpers.ParseInputToCharInput(e)
    local isShift = false
    if type(e.Modifiers) ~= "table" then
        local mask = e.Modifiers or 0
        isShift = ((mask & Enums.SDLKeyModifier.LShift) ~= 0) or ((mask & Enums.SDLKeyModifier.RShift) ~= 0)
    else
        local mods = e.Modifiers or {}
        isShift = (table.find(mods, "LShift") ~= nil) or (table.find(mods, "RShift") ~= nil)
    end

    if isShift then
        return KeybindHelpers.ShiftKeyToChar[e.Key] or e.Key
    else
        return KeybindHelpers.KeyToChar[e.Key] or e.Key
    end
end