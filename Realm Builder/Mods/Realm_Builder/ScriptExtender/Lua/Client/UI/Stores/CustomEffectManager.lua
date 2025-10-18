

--- @class CustomEffectManager : ManagerBase
CustomEffectManager = _Class("CustomEffectManager", ManagerBase)

function CustomEffectManager:RegisterNewEffect(displayName, icon)
    if not displayName or displayName == "" then
        Warning("Invalid effect display name")
        return
    end

    if self.Data[displayName] then
        Warning("Effect with display name " .. displayName .. " already exists")
        return
    end

    local effect = {
        DisplayName = displayName,
        Icon = icon or "",
        Group = "",
        Tags = {},
        Note = "",
    }

    self.Data[displayName] = effect
    return effect
end