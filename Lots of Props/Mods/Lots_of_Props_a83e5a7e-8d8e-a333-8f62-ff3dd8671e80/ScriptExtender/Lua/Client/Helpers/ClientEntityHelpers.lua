local specialGuids = {
    [CameraSymbol] = "Item_DEN_VoloOperation_ErsatzEye",
}

local defaultIcon = "Item_Unknown"
local ECMODLoaded = Ext.Mod.IsModLoaded("5b5ad5b6-ce37-4a63-8dea-a1fee4cee156")
local FocusAddonLoaded = Ext.Mod.IsModLoaded("ff8b5278-f929-45d1-9a51-7efa609620c4")
local defautlCharacterIcon = ECMODLoaded and "EC_Portrait_Generic" or FocusAddonLoaded and "FOCUSLODESTONES_Lodestone_Generic" or "Spell_Enchantment_HoldPerson"
local originIconPrefix = ECMODLoaded and "EC_Portrait_" or FocusAddonLoaded and "FOCUSLODESTONES_Lodestone_" or nil
local defaultPartyMemberIcon = "Skill_Fighter_Rally"

function CheckIcon(icon, fallback)
    local windowForCheckIcon = GLOBAL_DEBUG_WINDOW
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

    if IsCamera(guid) then
        return specialGuids[CameraSymbol]
    end

    if not Ext.Entity.Get(guid) then
        return defaultIcon
    end

    local entity = UuidToHandle(guid)
    -- Hijack easycheat and focus addon icons for characters XD
    if entity and entity.IsCharacter then
        local icon = IsPartyMember(guid) and defaultPartyMemberIcon or defautlCharacterIcon
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
    if GetDisplayNameFromGuid(guid) then
        return GetDisplayNameFromGuid(guid) or "Unknown"
    end

    local entity = Ext.Entity.Get(guid)
    if entity and entity.DisplayName then
        local name = entity.DisplayName.Name:Get()
        if name and name ~= "" then
            return name
        end
    end

    local templateId = GetTemplateId(guid)
    if not templateId or templateId == "" then
        return "Unknown"
    end
    local template = Ext.ClientTemplate.GetTemplate(TakeTailTemplate(templateId))
    if not template then
        return "Unknown"
    end

    return template.Name or "Unknown"
end

function GetIconForTemplateId(uuid)
    uuid = TakeTailTemplate(uuid)
    local template = Ext.ClientTemplate.GetTemplate(uuid)
    local icon = template and template.Icon
    if icon and icon ~= "" then
        if ICON_BLACKLIST[icon] then
            return "Item_Unknown"
        end
        return CheckIcon(icon, "Item_Unknown")
    end
    return "Item_Unknown"
end

function GetIconForTemplateName(templateName)
    local uuid = LOP_ItemManager.TemplateNameToUuid[templateName]
    if uuid then
        return GetIconForTemplateId(uuid)
    else
        Error("GetIconForTemplateName: No UUID found for template name: " .. templateName)
        return "Item_Unknown"
    end
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
    uuid = TakeTailTemplate(uuid)
    local template = Ext.ClientTemplate.GetTemplate(uuid)
    local transalatedString = template.DisplayName.Handle.Handle
    local translated = Ext.Loca.GetTranslatedString(transalatedString)
    if not translated or translated == "" or translated == transalatedString or translated == "Object" then
        return template.Name
    end
    return translated
end

function GetTemplateNameForGuid(guid)
    local templateId = GetTemplateId(guid)
    if not templateId or templateId == "" then return nil end
    local template = Ext.ClientTemplate.GetTemplate(TakeTailTemplate(templateId))
    if not template then
        --Error("GetTemplateNameForGuid: No template found for guid: " .. guid)
        return nil
    end
    return template.Name
end


---@param func string
---@param args any
---@param callback fun(data: any)
function RequestOsiris(func, args, callback)
    if type(args) ~= "table" then
        args = {args}
    end
    local requestId = tostring(math.random(1, 1000000)) .. tostring(Ext.Utils.MonotonicTime())
    Post("OsirisRequest", {
        Function = func,
        Args = args,
        RequestId = requestId,
    })

    ClientSubscribe("OsirisResponse_" .. requestId, function (data)
        if callback then
            callback(data)
        end
        return UNSUBSCRIBE_SYMBOL
    end)
end

---@param requests table<number, {Function: string, Args: any[]}>
---@param callback fun(data: table<number, {Function: string, Result: any}>)
function BunchOsirisRequest(requests, callback)
    local requestId = tostring(math.random(1, 1000000)) .. tostring(Ext.Utils.MonotonicTime())
    Post("BunchOsirisRequest", {
        Calls = requests,
        RequestId = requestId,
    })

    ClientSubscribe("BunchOsirisResponse_" .. requestId, function (data)
        if callback then
            callback(data)
        end
        return UNSUBSCRIBE_SYMBOL
    end)
end