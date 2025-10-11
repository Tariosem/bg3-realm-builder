local nearByGuidToDisplayName = {}
local nearByDisplayNameToGuid = {}
local nearByEntries = {}

local function GetUniqueName(name)
    local baseName = name
    local suffix = 1
    while nearByDisplayNameToGuid[name] or PropStore:GetGuidFromPropName(name) do
        name = string.format("%s (%d)", baseName, suffix)
        suffix = suffix + 1
    end
    return name
end

local function ClearNearbyMap()
    nearByGuidToDisplayName = {}
    nearByDisplayNameToGuid = {}
    nearByEntries = {}
end

---@param pos Vec3
---@param radius number
function UpdateNearbyMap(pos, radius)
    ClearNearbyMap()
    local entries = GetNearbyCharactersAndItems(pos, radius)
    if not entries or #entries == 0 then return end

    for _,entry in pairs(entries) do
        local guid = entry.Guid
        local displayName = nil
        if PropStore:GetPropNameFromGuid(guid) then
            displayName = PropStore:GetPropNameFromGuid(guid) --[[@as string]]
        else
            displayName = GetUniqueName(entry.DisplayName)
        end
        entry.DisplayName = displayName
        nearByGuidToDisplayName[guid] = displayName
        nearByDisplayNameToGuid[displayName] = guid
        entry.Entity = nil
    end
    nearByEntries = entries
end

--- @return NearbyEntry[]
function GetAllNearbyEntries()
    return DeepCopy(nearByEntries)
end

function GetGuidFromDisplayName(displayName)
    if PropStore:GetGuidFromPropName(displayName) then
        return PropStore:GetGuidFromPropName(displayName)
    end
    if nearByDisplayNameToGuid[displayName] then
        return nearByDisplayNameToGuid[displayName]
    end
    return nil
end

function GetDisplayNameFromGuid(guid)
    if PropStore:GetPropNameFromGuid(guid) then
        return PropStore:GetPropNameFromGuid(guid)
    end
    if nearByGuidToDisplayName[guid] then
        return nearByGuidToDisplayName[guid]
    end
    if IsCamera(guid) then
        return GetLoca("Camera")
    end
    return nil
end