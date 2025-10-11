local StringToHandle = {}

local unseenStrings = {}

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
    for str in pairs(unseenStrings) do
        table.insert(toSave, str)
    end

    local filePath = GetLocalizationPath()
    Ext.IO.SaveFile(filePath, Ext.Json.Stringify(toSave))
    print("Saved " .. #toSave .. " unseen strings to " .. filePath)
end

local function LoadStringHandles()
    

end