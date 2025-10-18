local configPath = "Realm_Builder/Config.json"
local visualPresetsPath = "Realm_Builder/VisualPresets/"
local visRefPath = "Realm_Builder/VisualPresets/References.json"
local effRefPath = "Realm_Builder/CustomEffects/References.json"
local effPath = "Realm_Builder/CustomEffects/"
local presetRefPath = "Realm_Builder/Presets/References.json"
local presetPath = "Realm_Builder/Presets/"
local localGenPath = "Realm_Builder/Localization/"
local keybindPath = "Realm_Builder/Keybinds.json"

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
    return "Realm_Builder/" .. name .. ".json"
end

function GetLocalizationPath()
    return localGenPath .. ".json"
end

function GetKeybindsPath()
    return keybindPath
end