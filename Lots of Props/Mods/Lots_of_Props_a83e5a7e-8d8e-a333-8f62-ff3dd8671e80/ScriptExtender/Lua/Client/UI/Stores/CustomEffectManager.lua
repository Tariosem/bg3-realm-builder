--- @class LOP_Effect : LOP_CategorizableObject
--- @field Description string
--- @field DisplayName string
--- @field Icon string

--- @class LOP_MultiEffect : LOP_Effect
--- @field fxNames LOP_FxName[]

--- @class LOP_FxName
--- @field DisplayName string
--- @field FxName string[]|string
--- @field Icon string
--- @field Uuid string
--- @field TemplateName string
--- @field isMultiEffect boolean
--- @field SourceBone string
--- @field TargetBone string

--- @class LOP_StatsEffect : LOP_MultiEffect
--- @field StatsType "StatusData"|"SpellData"

--- @class LOP_SpellEffect : LOP_StatsEffect
--- @field fxGroupType table<SpellEffectType, "SingleEffect"|"MultiEffect">
--- @field AreaRadius number
--- @field TargetRadius number
--- @field fxNames table<SpellEffectType, table<string, LOP_FxName>> -- displayName -> fxName

--- @class LOP_StatusEffect : LOP_StatsEffect
--- @field fxGroupType table<StatusEffectType, "SingleEffect"|"MultiEffect">
--- @field Duration number
--- @field fxNames table<StatusEffectType, table<string, LOP_FxName>> -- displayName -> fxName

--- @class CustomEffectManager : ManagerBase
--- @field Data table<string, LOP_Effect|LOP_StatsEffect|LOP_SpellEffect|LOP_StatusEffect>
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