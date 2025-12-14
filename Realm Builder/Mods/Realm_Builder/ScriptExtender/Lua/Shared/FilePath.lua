local rootFolder = "Realm Builder/"

local configPath = rootFolder .. "UIConfig.json"
local visualPresetsPath = rootFolder .. "Visual Presets/"
local visRefPath = rootFolder .. "Visual Presets/References.json"
local effRefPath = rootFolder .. "Custom Effects/References.json"
local effPath = rootFolder .. "Custom Effects/"
local presetRefPath = rootFolder .. "Scenes/References.json"
local presetPath = rootFolder .. "Scenes/"
local localGenPath = rootFolder .. "Localization/"
local keybindPath = rootFolder .. "Keybind.json"
local browserSettingPath = rootFolder .. "Browsers/%s.json"
local generatedPrefabPath = rootFolder .. "Prefabs/"

local logPath = rootFolder .. "Logs/"
local mapModLogPath = logPath .. "Map_Mods_Export_Log_%s.json"
local ccaModLogPath = logPath .. "CC_Mods_Export_Log_%s.json"
local xmlErrorLogPath = logPath .. "XML_Stringify_Errors_%s.json"

local ccPath = rootFolder .. "CC Mods/"
local ccModCachePath = rootFolder .. "CC Mod Cache/"
local ccModCacheRefPath = ccModCachePath .. "CCAModCache_References.json"

local ccaModMetaFile = ccPath .. "%s/Mods/%s/meta.lsx"

local ccaLocalizationFile = ccPath .. "%s/Localization/%s/%s.xml"

local ccaPresetsPath = ccPath .. "%s/Public/%s/CharacterCreationPresets/"

local ccaEyeColorFile = ccaPresetsPath .. "CharacterCreationEyeColors.lsx"
local ccaHairColorFile = ccaPresetsPath .. "CharacterCreationHairColors.lsx"
local ccaSkinColorFile = ccaPresetsPath .. "CharacterCreationSkinColors.lsx"

local matPresetsPath = ccPath .. "%s/Public/%s/Content/Assets/Characters/Character Editor Presets/"
local ccaEyeColorPath = matPresetsPath .. "Eye Presets/[PAK]_%s/"
local ccaHairColorPath = matPresetsPath .. "Hair Color Presets/[PAK]_%s/"
local ccaSkinColorPath = matPresetsPath .. "Skin Presets/[PAK]_%s/"

local mapModsPath = rootFolder .. "Map Mods/"
local mapModMetaFile = mapModsPath .. "%s/Mods/%s/meta.lsx"
local mapModLocalizationFile = mapModsPath .. "%s/Localization/%s/%s.xml"

local mapCharacterVisualPath = mapModsPath .. "%s/Public/%s/Content/[PAK]_CharacterVisuals/%s.lsx"
local mapCharacterPresetPath = mapModsPath .. "%s/Public/%s/Content/Assets/Characters/[PAK]_Character_Presets/%s.lsx"

local mapItemRootTemplatePath = mapModsPath .. "%s/Public/%s/RootTemplates/%s.lsx"
local mapItemVisualPath = mapModsPath .. "%s/Public/%s/Content/[PAK]_ItemVisuals/%s.lsx"
local mapItemPresetPath = mapModsPath .. "%s/Public/%s/Content/Assets/Items/[PAK]_Item_Presets/%s.lsx"

local mapTemplatePath = mapModsPath .. "%s/Mods/%s/Levels/%s/%s/%s.lsx"

local mapModCachePath = mapModsPath .. "Map_Mod_Uuids.json"

FilePath = {}

function FilePath.GetUIConfigPath()
    return configPath
end

function FilePath.GetVisualPresetsPath(templateName)
    return visualPresetsPath .. templateName .. ".json"
end

function FilePath.GetCustomEffectPath(displayName)
    return effPath .. displayName .. ".json"
end

function FilePath.GetPresetPath(presetName)
    return presetPath .. presetName .. ".json"
end

function FilePath.GetPresetReferencePath()
    return presetRefPath
end

function FilePath.GetVisualReferencePath()
    return visRefPath
end

function FilePath.GetEffectReferencePath()
    return effRefPath
end

function FilePath.GetLocalizationPath()
    return localGenPath .. ".json"
end

function FilePath.GetKeybindPath()
    return keybindPath
end

function FilePath.GetCCAModMetaPath(modName, modFolderName)
    return string.format(ccaModMetaFile, modName, modFolderName)
end

function FilePath.GetPrefabPath(internalName, uuid)
    local fileName = string.format("%s_%s.lsx", internalName, uuid)
    return generatedPrefabPath .. fileName
end

---@param modName string
---@param lang string
---@return string
function FilePath.GetCCALocalizationPath(modName, modFolderName, lang)
    return string.format(ccaLocalizationFile, modName, lang, modFolderName)
end

function FilePath.GetCCAModCachePath(modName, version)
    local versionStr = type(version) == "table" and RBUtils.BuildVersionString(version[1], version[2], version[3], version[4]) or version

    local fileName = string.format("%s_%s_Cache.json", modName, versionStr)

    return string.format(ccModCachePath .. fileName)
end

function FilePath.GetCCAModCacheRefPath()
    return ccModCacheRefPath
end

function FilePath.GetCCAMaterialPresetsFile(presetType, modName, modFolderName, customName)
    local ccaMatPresetPath = {
        CharacterCreationEyeColors = ccaEyeColorPath,
        CharacterCreationHairColors = ccaHairColorPath,
        CharacterCreationSkinColors = ccaSkinColorPath,
    }

    if not ccaMatPresetPath[presetType] then
        Error("Invalid preset type: " .. tostring(presetType))
        return nil
    end

    local path = string.format(ccaMatPresetPath[presetType], modName, modFolderName, modFolderName)

    local filePath = path .. "_" .. (customName or "merged") .. ".lsx"

    return filePath
end

function FilePath.GetCCAPresetsFile(presetType, modName, modFolderName)
    local ccaPresetPath = {
        CharacterCreationEyeColors = ccaEyeColorFile,
        CharacterCreationHairColors = ccaHairColorFile,
        CharacterCreationSkinColors = ccaSkinColorFile,
    }

    if not ccaPresetPath[presetType] then
        Error("Invalid preset type: " .. tostring(presetType))
        return nil
    end

    return string.format(ccaPresetPath[presetType], modName, modFolderName)
end

function FilePath.GetCCASkinColorPath(modName)
    return string.format(ccaSkinColorFile, modName, modName)
end

function FilePath.GetConfigPath()
    return configPath
end

function FilePath.GetMapModMetaPath(modName)
    return string.format(mapModMetaFile, modName, modName)
end

function FilePath.GetMapModLocalizationPath(modName, lang)
    return string.format(mapModLocalizationFile, modName, lang, modName)
end

local templateTypeToFolder = {
    character = "Characters",
    item = "Items",
    scenery = "Scenery",
    trigger = "Triggers",
}

function FilePath.GetTemplatePath(modName, levelName, guid, templateType)
    templateType = templateTypeToFolder[templateType]
    if not templateType then
        Error("Invalid template type: " .. tostring(templateType))
        return nil
    end
    return string.format(mapTemplatePath, modName, modName, levelName, templateType, guid)
end

function FilePath.GetCharacterVisualPath(modName, visualName)
    return string.format(mapCharacterVisualPath, modName, modName, visualName)
end

function FilePath.GetCharacterPresetPath(modName, presetName)
    return string.format(mapCharacterPresetPath, modName, modName, presetName)
end

function FilePath.GetRootTemplatePath(modName, templateName)
    return string.format(mapItemRootTemplatePath, modName, modName, templateName)
end

function FilePath.GetItemVisualPath(modName, visualName)
    return string.format(mapItemVisualPath, modName, modName, visualName)
end

function FilePath.GetItemPresetPath(modName, presetName)
    return string.format(mapItemPresetPath, modName, modName, presetName)
end

function FilePath.GetMapModCachePath()
    return mapModCachePath
end

function FilePath.GetBrowserSettingPath(browserName)
    return string.format(browserSettingPath, browserName)
end

function FilePath.GetMapModLogPath(timeStamp)
    return string.format(mapModLogPath, timeStamp)
end

function FilePath.GetCCModLogPath(timeStamp)
    return string.format(ccaModLogPath, timeStamp)
end

function FilePath.GetXMLErrorLogPath(timeStamp)
    return string.format(xmlErrorLogPath, timeStamp)
end