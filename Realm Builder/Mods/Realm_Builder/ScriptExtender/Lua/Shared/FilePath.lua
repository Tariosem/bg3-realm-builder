local configPath = "Realm_Builder/Config.json"
local visualPresetsPath = "Realm_Builder/VisualPresets/"
local visRefPath = "Realm_Builder/VisualPresets/References.json"
local effRefPath = "Realm_Builder/CustomEffects/References.json"
local effPath = "Realm_Builder/CustomEffects/"
local presetRefPath = "Realm_Builder/Presets/References.json"
local presetPath = "Realm_Builder/Presets/"
local localGenPath = "Realm_Builder/Localization/"
local keybindPath = "Realm_Builder/Keybind.json"

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

local mapModsPath = "Realm_Builder/Map_Mods/"
local mapModMetaFile = mapModsPath .. "%s/Mods/%s/meta.lsx"
local mapModLocalizationFile = mapModsPath .. "%s/Localization/%s/%s.xml"

local mapCharacterVisualPath = mapModsPath .. "%s/Public/%s/Content/[PAK]_CharacterVisuals/%s.lsx"
local mapCharacterPresetPath = mapModsPath .. "%s/Public/%s/Content/Assets/Characters/[PAK]_Character_Presets/%s.lsx"

local mapItemVisualPath = mapModsPath .. "%s/Public/%s/Content/[PAK]_ItemVisuals/%s.lsx"
local mapItemPresetPath = mapModsPath .. "%s/Public/%s/Content/Assets/Items/[PAK]_Item_Presets/%s.lsx"

local mapTemplatePath = mapModsPath .. "%s/Mods/%s/Levels/%s/%s/%s.lsx"


local mapModCachePath = "Realm_Builder/Map_Mod_Uuids.json"

RealmPath = {}

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

function RealmPath.GetKeybindPath()
    return keybindPath
end

function RealmPath.GetCCAModMetaPath(modName)
    return string.format(ccaModMetaFile, modName, modName)
end

---@param modName string
---@param lang string
---@return string
function RealmPath.GetCCALocalizationPath(modName, lang)
    return string.format(ccaLocalizationFile, modName, lang, modName)
end

function RealmPath.GetCCAModCachePath(modName, version)
    local versionStr = type(version) == "table" and BuildVersionString(version[1], version[2], version[3], version[4]) or version

    local fileName = string.format("%s_%s_Cache.json", modName, versionStr)

    return string.format(ccaModCachePath .. fileName)
end

function RealmPath.GetCCAModCacheRefPath()
    return ccaModCacheRefPath
end

function RealmPath.GetCCAMaterialPresetsFile(presetType, modName, customName)
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

function RealmPath.GetCCAPresetsFile(presetType, modName)
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

function RealmPath.GetCCASkinColorPath(modName)
    return string.format(ccaSkinColorFile, modName, modName)
end

function RealmPath.GetConfigPath()
    return configPath
end

function RealmPath.GetMapModMetaPath(modName)
    return string.format(mapModMetaFile, modName, modName)
end

function RealmPath.GetMapModLocalizationPath(modName, lang)
    return string.format(mapModLocalizationFile, modName, lang, modName)
end

local templateTypeToFolder = {
    character = "Characters",
    item = "Items",
    scenery = "Scenery",
    trigger = "Triggers",
}

function RealmPath.GetTemplatePath(modName, levelName, guid, templateType)
    templateType = templateTypeToFolder[templateType]
    if not templateType then
        Error("Invalid template type: " .. tostring(templateType))
        return nil
    end
    return string.format(mapTemplatePath, modName, modName, levelName, templateType, guid)
end

function RealmPath.GetCharacterVisualPath(modName, visualName)
    return string.format(mapCharacterVisualPath, modName, modName, visualName)
end

function RealmPath.GetCharacterPresetPath(modName, presetName)
    return string.format(mapCharacterPresetPath, modName, modName, presetName)
end

function RealmPath.GetItemVisualPath(modName, visualName)
    return string.format(mapItemVisualPath, modName, modName, visualName)
end

function RealmPath.GetItemPresetPath(modName, presetName)
    return string.format(mapItemPresetPath, modName, modName, presetName)
end

function RealmPath.GetMapModCachePath()
    return mapModCachePath
end