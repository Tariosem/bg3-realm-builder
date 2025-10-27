local configPath = "Realm_Builder/Config.json"
local visualPresetsPath = "Realm_Builder/VisualPresets/"
local visRefPath = "Realm_Builder/VisualPresets/References.json"
local effRefPath = "Realm_Builder/CustomEffects/References.json"
local effPath = "Realm_Builder/CustomEffects/"
local presetRefPath = "Realm_Builder/Presets/References.json"
local presetPath = "Realm_Builder/Presets/"
local localGenPath = "Realm_Builder/Localization/"
local keybindPath = "Realm_Builder/Keybinds.json"

local ccaPath = "Realm_Builder/CC_Mods/"
local ccaModCachePath = "Realm_Builder/CC_Mod_Cache/"
local ccaModCacheRefPath = ccaModCachePath .. "CCAModCache_References.json"

local ccaModMetaFile = ccaPath .. "%s/Mods/%s/meta.lsx"

local ccaLocalizationFile = ccaPath .. "%s/Localization/%s/%s.xml"

local ccaPresetsPath = ccaPath .. "%s/Public/%s/CharacterCreationPresets/"

local ccaEyeColorFile = ccaPresetsPath .. "CharacterCreationEyeColors.lsx"
local ccaHairColorFile = ccaPresetsPath .. "CharacterCreationHairColors.lsx"
local ccaSkinColorFile = ccaPresetsPath .. "CharacterCreationSkinColors.lsx"

local matPresetsPath = ccaPath .. "%s/Public/%s/Content/Assets/Characters/Character Editor Presets/"
local ccaEyeColorPath = matPresetsPath .. "Eye Presets/[PAK]_%s/"
local ccaHairColorPath = matPresetsPath .. "Hair Color Presets/[PAK]_%s/"
local ccaSkinColorPath = matPresetsPath .. "Skin Presets/[PAK]_%s/"

RealmPaths = {}

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

function RealmPaths.GetCCAModMetaPath(modName)
    return string.format(ccaModMetaFile, modName, modName)
end

---@param modName string
---@param lang string
---@return string
function RealmPaths.GetCCALocalizationPath(modName, lang)
    return string.format(ccaLocalizationFile, modName, lang, modName)
end

function RealmPaths.GetCCAModCachePath(modName, version)
    local versionStr = type(version) == "table" and BuildVersionString(version[1], version[2], version[3], version[4]) or version

    local fileName = string.format("%s_%s_Cache.json", modName, versionStr)

    return string.format(ccaModCachePath .. fileName)
end

function RealmPaths.GetCCAModCacheRefPath()
    return ccaModCacheRefPath
end

function RealmPaths.GetCCAMaterialPresetsFile(presetType, modName, customName)
    local ccaMatPresetPath = {
        CharacterCreationEyeColors = ccaEyeColorPath,
        CharacterCreationHairColors = ccaHairColorPath,
        CharacterCreationSkinColors = ccaSkinColorPath,
    }

    if not ccaMatPresetPath[presetType] then
        Error("Invalid preset type: " .. tostring(presetType))
        return nil
    end

    local path = string.format(ccaMatPresetPath[presetType], modName, modName, modName)

    local filePath = path .. "_" .. (customName or "merged") .. ".lsx"

    return filePath
end

function RealmPaths.GetCCAPresetsFile(presetType, modName)
    local ccaPresetPath = {
        CharacterCreationEyeColors = ccaEyeColorFile,
        CharacterCreationHairColors = ccaHairColorFile,
        CharacterCreationSkinColors = ccaSkinColorFile,
    }

    if not ccaPresetPath[presetType] then
        Error("Invalid preset type: " .. tostring(presetType))
        return nil
    end

    return string.format(ccaPresetPath[presetType], modName, modName)
end

function RealmPaths.GetCCASkinColorPath(modName)
    return string.format(ccaSkinColorFile, modName, modName)
end

function RealmPaths.GetConfigPath()
    return configPath
end