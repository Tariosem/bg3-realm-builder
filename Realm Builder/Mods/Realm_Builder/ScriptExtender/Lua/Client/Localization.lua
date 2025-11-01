---@return string
function MakeTranslatedHandle()
    local template = "hxxxxxxxxgxxxxgxxxxgxxxxgxxxxxxxxxxx"
    local handle = template:gsub("x", function()
        return string.format("%x", math.random(0, 15))
    end)

    return handle
end


local StringToHandle = {}
local unseenStrings = {}

local vanillaLocalization = Ext.Require("Client/VanillaLocalization.lua")
for str, handle in pairs(vanillaLocalization) do
    StringToHandle[str] = handle
end

function GetLoca(text)
    if StringToHandle[text] then
        return Ext.Loca.GetTranslatedString(StringToHandle[text], text)
    end

    local isHandle = Ext.Loca.GetTranslatedString(text, text)

    if text ~= isHandle then
        return isHandle
    else
        unseenStrings[text] = true
    end

    return text
end

local function ExportUnseenStrings()
    local toSave = {}
    for name in pairs(unseenStrings) do
        table.insert(toSave, name)
    end

    local string, stringToHandle = LSXHelpers.GenerateLocalization(toSave, 1)

    local path = "Realm_Builder/Mods/Realm_Builder/Localization/UnseenStrings.lsx"
    local stringToHandlePath = "Realm_Builder/Mods/Realm_Builder/Localization/UnseenStrings_StringToHandle.json"
    local suc = Ext.IO.SaveFile(path, string)
    Ext.IO.SaveFile(stringToHandlePath, Ext.Json.Stringify(stringToHandle))

    if not suc then
        Error("ExportUnseenStrings: Failed to save unseen strings LSX file at " .. path)
        return nil
    end

    return suc
end

Ext.RegisterConsoleCommand("rb_export_unseen_strings", function()
    ExportUnseenStrings()
end)