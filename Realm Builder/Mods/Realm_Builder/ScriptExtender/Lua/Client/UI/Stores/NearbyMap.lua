local nearByEntries = {}

local function ClearNearbyMap()
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

    if #pos ~= 3 then
        Error("Failed To Get Host's Position")
        return
    end

    local entries = GetNearbyCharactersAndItems(pos, radius)
    if not entries or #entries == 0 then return end

    for _,entry in pairs(entries) do
        local guid = entry.Guid
        local displayName = GetName(guid)
        entry.DisplayName = displayName
        entry.Entity = nil
    end
    nearByEntries = entries
end

--- @return NearbyEntry[]
function GetAllNearbyEntries()
    return DeepCopy(nearByEntries)
end
