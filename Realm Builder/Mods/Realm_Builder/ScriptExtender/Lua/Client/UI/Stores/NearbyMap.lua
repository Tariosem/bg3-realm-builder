local nearByGuidToDisplayName = {}
local nearByDisplayNameToGuid = {}
local nearByEntries = {}

local function GetUniqueName(name)
    local baseName = name
    local suffix = 1
    while nearByDisplayNameToGuid[name] or EntityStore:GetGuidFromPropName(name) do
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

---@param pos Vec3?
---@param radius number?
function UpdateNearbyMap(pos, radius)
    ClearNearbyMap()

    if not pos then
        pos = {CGetPosition(CGetHostCharacter())}
    end
    radius = radius or 18

    local entries = GetNearbyCharactersAndItems(pos, radius)
    if not entries or #entries == 0 then return end

    for _,entry in pairs(entries) do
        local guid = entry.Guid
        local displayName = nil
        if EntityStore:GetPropNameFromGuid(guid) then
            displayName = EntityStore:GetPropNameFromGuid(guid) --[[@as string]]
        else
            displayName = GetUniqueName(entry.DisplayName)
        end
        if not displayName then
            displayName = GetUniqueName("Unknown Entity")
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
    if EntityStore:GetGuidFromPropName(displayName) then
        return EntityStore:GetGuidFromPropName(displayName)
    end
    if nearByDisplayNameToGuid[displayName] then
        return nearByDisplayNameToGuid[displayName]
    end
    return nil
end

function GetDisplayNameFromGuid(guid)
    if EntityStore:GetPropNameFromGuid(guid) then
        return EntityStore:GetPropNameFromGuid(guid)
    end
    if nearByGuidToDisplayName[guid] then
        return nearByGuidToDisplayName[guid]
    end
    if IsCamera(guid) then
        return GetLoca("Camera")
    end
    return nil
end