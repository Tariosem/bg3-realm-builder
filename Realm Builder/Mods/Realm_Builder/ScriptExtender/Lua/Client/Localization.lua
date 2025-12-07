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

--- @param text string
--- @return string
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

    local path = "Realm_Builder/Localization/Realm_Builder_GeneratedLocalization.xml"
    local stringToHandlePath = "Realm_Builder/Localization/GeneratedLocalization.lua"
    local suc = Ext.IO.SaveFile(path, string)
    local luaFileContent = ""
    luaFileContent = luaFileContent .. "return {\n"
    for str,handle in pairs(stringToHandle) do
        luaFileContent = luaFileContent .. string.format("    [%q] = %q,\n", str, handle[1])
    end
    
    luaFileContent = luaFileContent .. "}\n"
    local suc2 = Ext.IO.SaveFile(stringToHandlePath, luaFileContent)

    if not suc then
        Error("Failed to save unseen localization strings to " .. path)
    else
        RBPrintPurple("[Realm Builder] Exported " .. #toSave .. " unseen localization strings to " .. path)
    end
    if not suc2 then
        Error("Failed to save unseen localization string-to-handle mapping to " .. stringToHandlePath)
    else
        RBPrintPurple("[Realm Builder] Exported unseen localization string-to-handle mapping to " .. stringToHandlePath)
    end

    return suc
end

RegisterConsoleCommand("rb_export_loca", function(command, args)
    ExportUnseenStrings()
end, "Exports unseen localization strings to a XML file and a Lua mapping file.")