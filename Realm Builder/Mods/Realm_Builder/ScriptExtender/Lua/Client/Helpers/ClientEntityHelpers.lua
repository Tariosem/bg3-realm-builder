local specialGuids = {
    [CAMERA_SYMBOL] = "Item_DEN_VoloOperation_ErsatzEye",
}

local defaultIcon = "Item_Unknown"
local ECMODLoaded = Ext.Mod.IsModLoaded("5b5ad5b6-ce37-4a63-8dea-a1fee4cee156")
local FocusAddonLoaded = Ext.Mod.IsModLoaded("ff8b5278-f929-45d1-9a51-7efa609620c4")
local defautlCharacterIcon = RB_ICONS.Character
local originIconPrefix = ECMODLoaded and "EC_Portrait_" or nil
local defaultPartyMemberIcon = RB_ICONS.Character_Fill
local windowForCheckIcon = GLOBAL_DEBUG_WINDOW

function CheckIcon(icon, fallback)
    if not windowForCheckIcon then
        return "Item_Unknown"
    end

    local isValid = true
    local image = windowForCheckIcon:AddImage(icon)
    if image.ImageData.Icon == "" then
        isValid = false
    end
    image:Destroy()

    return isValid and icon or fallback or "Item_Unknown"
end

function GetIcon(guid)
    if not guid or guid == "" then
        return defaultIcon
    end

    if specialGuids[guid] then
        return specialGuids[guid]
    end

    if SceneryRegistry[guid] then
        return RB_ICONS.Scenery
    end

    if RBUtils.IsCamera(guid) then
        return specialGuids[CAMERA_SYMBOL]
    end

    local stored = EntityStore:GetStoredData(guid)

    if stored and stored.TemplateId then
        local icon = GetIconForTemplateId(stored.TemplateId)
        return CheckIcon(icon, defaultIcon)
    end

    if not RBUtils.IsUuid(guid) then
        return defaultIcon
    end

    local entity = UuidToHandle(guid)
    -- Hijack easycheat and focus addon icons for characters XD
    if EntityHelpers.IsCharacter(guid) then
        local icon = EntityHelpers.IsPartyMember(guid) and defaultPartyMemberIcon or defautlCharacterIcon
        if originIconPrefix and entity.Origin then
            local origin = entity.Origin.Origin
            if origin == "DarkUrge" or origin == "Alfira" then
                icon = originIconPrefix .. "Generic"
            else
                icon = originIconPrefix .. origin
            end
        end
        return icon
    end

    if not entity then
        return defaultIcon
    end

    if entity.Scenery then
        return RB_ICONS.Scenery_Fill
    end

    if entity.Icon then
        local icon = entity.Icon.Icon
        if icon and icon ~= "" and not ICON_BLACKLIST[icon] then
            return CheckIcon(icon, defaultIcon)
        end
    end

    if entity.GameObjectVisual then
        local icon = entity.GameObjectVisual.Icon
        if icon and icon ~= "" and not ICON_BLACKLIST[icon] then
            return CheckIcon(icon, defaultIcon)
        end
    end

    return defaultIcon
end

---@param guid GUIDSTRING
---@return string
function GetName(guid)
    local outlineName = EntityStore:GetPropNameFromGuid(guid)
    if outlineName then
        return outlineName
    end

    if not RBUtils.IsUuid(guid) then
        return "Unknown"
    end

    local entity = Ext.Entity.Get(guid)
    if entity and entity.DisplayName then
        local name = entity.DisplayName.Name:Get()
        if name and name ~= "" then
            return name
        end
    end

    local templateId = EntityHelpers.GetTemplateId(guid)
    if not templateId or templateId == "" then
        return "Unknown"
    end
    local template = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(templateId))
    if not template then
        return "Unknown"
    end

    return template.Name or "Unknown"
end

local templateTypeToIcon = {
    scenery = RB_ICONS.Scenery,
    character = RB_ICONS.Character,
    TileConstruction = RB_ICONS.Scenery_Fill
}

function GetIconForTemplateId(uuid)
    uuid = EntityHelpers.TakeTailTemplate(uuid)
    local template = Ext.Template.GetTemplate(uuid)
    if not template then
        return "Item_Unknown"
    end
    if template.TemplateType == "item" then
        local icon = template.Icon
        return icon
    else
        return templateTypeToIcon[template.TemplateType] or defaultIcon
    end
    return "Item_Unknown"
end

function GetDisplayNameForEntity(entity)
    if type(entity) == "string" then
        entity = Ext.Entity.Get(entity)
    end
    if entity.DisplayName then
        return entity.DisplayName.Name:Get()
    end
    return nil
end

function GetDisplayNameForTemplateId(uuid)
    uuid = EntityHelpers.TakeTailTemplate(uuid)
    local template = Ext.Template.GetTemplate(uuid)
    if not template then
        local isVisual = Ext.Resource.Get(uuid, "Visual") --[[@as ResourceVisualResource]]
        if not isVisual then return "Unknown" end
        return RBStringUtils.GetLastPath(isVisual.SourceFile)
    end
    if template.TemplateType == "TileConstruction" then return template.Name end
    local transalatedString = template.DisplayName.Handle.Handle
    local translated = Ext.Loca.GetTranslatedString(transalatedString)
    if not translated or translated == "" or translated == transalatedString or translated == "Object" then
        return template.Name
    end
    return translated
end

function GetTemplateNameForGuid(guid)
    local templateId = EntityHelpers.GetTemplateId(guid)
    if not templateId or templateId == "" then return nil end
    local template = Ext.Template.GetTemplate(EntityHelpers.TakeTailTemplate(templateId))
    if not template then
        --Error("GetTemplateNameForGuid: No template found for guid: " .. guid)
        return nil
    end
    return template.Name
end

---@param guid GUIDSTRING
---@param duration integer in ms
---@param speed number in seconds per full rotation
---@param turns number of full rotations
---@return RunningAnimation|nil
function RotatingEntity(guid, duration, speed, turns)
    local movable = MovableProxy.CreateByGuid(guid)
    if not movable then return nil end

    movable:SaveTransform()

    speed = speed or 30
    duration = duration or 10000
    turns = turns or duration / (1000 * speed)
    local angle = 0
    local toAngle = math.pi * 2 * turns

    local anim = AnimateValue(90, angle, toAngle, duration, AnimationEasing.Linear, function ()
        movable:RestoreTransform()
    end, function (value, eased)
        value = value % (math.pi * 2)
        local quat = Ext.Math.QuatFromEuler({0, value, 0})
        movable:SetWorldRotation(quat)
    end)
    
    return anim
end