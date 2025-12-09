--- @alias KeybindingIdentifier string format like "A|CTRL|SHIFT"

--- @class Keybinding
--- @field Key SimplifiedInputCode
--- @field Modifiers SimplifiedModfier[]
--- @field new fun(key:SimplifiedInputCode, modifiers:SimplifiedModfier[]|nil):Keybinding
--- @field CreateIdentifier fun(self: Keybinding): KeybindingIdentifier
--- @field FromIdentifier fun(identifier: KeybindingIdentifier): Keybinding
Keybinding = _Class("Keybinding")

function Keybinding:__init(key, modifiers)
    self.Key = key
    self.Modifiers = modifiers or {}
    self.Identifier = self:CreateIdentifier()
end

function Keybinding:CreateIdentifier()
    if self.Identifier then return self.Identifier end
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
        ["MINUS"] = "-",
        ["EQUALS"] = "=",
        ["LEFTBRACKET"] = "[",
        ["RIGHTBRACKET"] = "]",
        ["BACKSLASH"] = "\\",
        ["SEMICOLON"] = ";",
        ["APOSTROPHE"] = "'",
        ["COMMA"] = ",",
        ["PERIOD"] = ".",
        ["SLASH"] = "/",
        ["SPACE"] = " ",
        ["GRAVE"] = "`",
    },
    ShiftKeyToChar = {
        ["NUM_1"] = "!",
        ["NUM_2"] = "@",
        ["NUM_3"] = "#",
        ["NUM_4"] = "$",
        ["NUM_5"] = "%",
        ["NUM_6"] = "^",
        ["NUM_7"] = "&",
        ["NUM_8"] = "*",
        ["NUM_9"] = "(",
        ["NUM_0"] = ")",
        ["KP_DECIMAL"] = ".",
        ["KP_MINUS"] = "-",
        ["KP_PLUS"] = "+",
        ["KP_DIVIDE"] = "/",
        ["KP_MULTIPLY"] = "*",
        ["MINUS"] = "_",
        ["EQUALS"] = "+",
        ["LEFTBRACKET"] = "{",
        ["RIGHTBRACKET"] = "}",
        ["BACKSLASH"] = "|",
        ["SEMICOLON"] = ":",
        ["APOSTROPHE"] = "\"",
        ["COMMA"] = "<",
        ["PERIOD"] = ">",
        ["SLASH"] = "?",
        ["SPACE"] = " ",
        ["GRAVE"] = "~",
    }
}

for c = string.byte("A"), string.byte("Z") do
    local ch = string.char(c)
    KeybindHelpers.KeyToChar[ch] = ch:lower()
    KeybindHelpers.ShiftKeyToChar[ch] = ch
end

for i = 0, 9 do
    KeybindHelpers.KeyToChar["NUM_" .. i] = tostring(i)
    KeybindHelpers.KeyToChar["KP_" .. i] = tostring(i)
    KeybindHelpers.ShiftKeyToChar["KP_" .. i] = tostring(i)
end

--- @param e SimplifiedInputEvent|EclLuaKeyInputEvent
function KeybindHelpers.ParseInputToCharInput(e)
    local isShift = false
    local mask = RBUtils.LightCToArray(e.Modifiers) or {}
    isShift = table.find(mask, "SHIFT") or table.find(mask, "RShift") or table.find(mask, "LShift")

    if isShift then
        return KeybindHelpers.ShiftKeyToChar[e.Key]
    else
        return KeybindHelpers.KeyToChar[e.Key]
    end
end
