local configPath = "Lots_of_Props/Config.json"
local visualPresetsPath = "Lots_of_Props/VisualPresets/"
local visRefPath = "Lots_of_Props/VisualPresets/References.json"
local effRefPath = "Lots_of_Props/CustomEffects/References.json"
local effPath = "Lots_of_Props/CustomEffects/"
local presetRefPath = "Lots_of_Props/Presets/References.json"
local presetPath = "Lots_of_Props/Presets/"
local localGenPath = "Lots_of_Props/Localization/"
local keybindPath = "Lots_of_Props/Keybinds.json"

function GetConfigFilePath()
    return configPath
end

function GetVisualPresetsPath(templateName)
    return visualPresetsPath .. templateName .. ".json"
end

function GetCustomEffectPath(displayName)
    return effPath .. displayName .. ".json"
end

function GetPresetPath(presetName)
    return presetPath .. presetName .. ".json"
end

function GetPresetReferencePath()
    return presetRefPath
end

function GetVisualReferencePath()
    return visRefPath
end

function GetEffectReferencePath()
    return effRefPath
end

function GetModPath(name)
    return "Lots_of_Props/" .. name .. ".json"
end

function GetLocalizationPath()
    return localGenPath .. ".json"
end

function GetKeybindsPath()
    return keybindPath
end