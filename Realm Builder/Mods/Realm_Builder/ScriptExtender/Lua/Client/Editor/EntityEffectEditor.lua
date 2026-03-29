--- @class EntityEffectEditor
--- @field GetEntity fun():EntityHandle?
--- @field Effects RB_EffectsTable
--- @field ResetParams RB_EffectsTable
--- @field SaveCurrentProperties fun()
--- @field MakeKey fun(self:EntityEffectEditor, compType: EntityEffectComponentType, compIndex: integer): string
--- @field ParseKey fun(self:EntityEffectEditor, key: string): EntityEffectComponentType?, integer?
--- @field SetProperty fun(self:EntityEffectEditor, compIndex: integer, propertyName: string, value: any): boolean
--- @field SetPropertyDirectly fun(self:EntityEffectEditor, comp: AspkComponent, compIndex: any, propertyName: any, value: any): boolean
--- @field ResetProperty fun(self:EntityEffectEditor, compIndex: integer, propertyName: string): boolean
--- @field ApplyToAllSameType fun(self:EntityEffectEditor, compType: EntityEffectComponentType, sourceCompIndex: integer)
--- @field HasChanges fun(self:EntityEffectEditor, compType: EntityEffectComponentType, compIndex: integer): boolean
--- @field Reapply fun():boolean
--- @field ResetAll fun():boolean
--- @field ExportChanges fun():RB_EffectsTable
--- @field ImportChanges fun(self:EntityEffectEditor, effectsTable: RB_EffectsTable): boolean
--- @field new fun(entityGetter: fun():EntityHandle?): EntityEffectEditor
EntityEffectEditor = _Class("EntityEffectEditor")


--- @enum EntityEffectComponentType
EntityEffectComponentType = {
    Light = 1,
    ParticleSystem = 2,
    [1] = "Light",
    [2] = "ParticleSystem",
}

local currenSupportEffects = {
    ["Light"] = true,
    ["ParticleSystem"] = true,
}

local lightCompProperties = {
    "IntensityProperty",
    "RadiusProperty",
    "FlickerSpeedProperty",
    "FlickerAmountProperty",
    "ColorProperty",
    "OverrideLightTemplateColor",
    "OverrideLightTemplateFlickerSpeed",
    "ModulateLightTemplateRadius",
}

local lightEntityProperties = {
    "LightChannelFlag",
    "Flags",
    "LightType",
    "SpotLightInnerAngle",
    "SpotLightOuterAngle",
    "Gain",
    "EdgeSharpening",
    "ScatteringIntensityScale",
    "IntensityOffset",
    --"Kelvin",
    "DirectionLightAttenuationFunction",
    "DirectionLightAttenuationEnd",
    "DirectionLightAttenuationSide",
    "DirectionLightAttenuationSide2",
    "DirectionLightDimensions",
    "Color",
}

local lightPropValid = {}
for _, propName in ipairs(lightCompProperties) do
    lightPropValid[propName] = true
end
for _, propName in ipairs(lightEntityProperties) do
    lightPropValid[propName] = true
end

local particleSystemCompProperties = {
    "Brightness_",
    "UniformScale",
    "Color"
}

local particleSystemPropValid = {}
for _, propName in ipairs(particleSystemCompProperties) do
    particleSystemPropValid[propName] = true
end

local validMap = {
    ["Light"] = lightPropValid,
    ["ParticleSystem"] = particleSystemPropValid,
}

local function checkCompPropValid(comp, propName)
    local typeName = comp.TypeName
    return validMap[typeName] and validMap[typeName][propName]
end

--- @param entity EntityHandle
--- @param compIndex integer
--- @return AspkComponent?
local function getEntityEffectComponent(entity, compIndex)
    if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then return nil end
    return entity.Effect.Timeline.Components[compIndex]
end

local function copyLightComponentToTable(component, table)
    for _, propName in ipairs(lightCompProperties) do
        local value = VisualHelpers.GetEffectComponentValue(component, propName)
        table[propName] = value
    end
    local lightEntity = component.LightEntity
    if lightEntity and lightEntity.Light then
        local light = lightEntity.Light --[[@as LightComponent]]
        for _, propName in ipairs(lightEntityProperties) do
            local value = light[propName]
            table[propName] = value
        end
    end
end

local function copyParticleSystemComponentToTable(component, table)
    for _, propName in ipairs(particleSystemCompProperties) do
        local value = component[propName]
        table[propName] = value
    end
end

--- @type table<string, fun(component:EffectComponent, to:table)>
local effectComponentCopyHandlers = {
    Light = copyLightComponentToTable,
    ParticleSystem = copyParticleSystemComponentToTable,
}

function EntityEffectEditor:__init(entityGetter)
    self.GetEntity = entityGetter
    self.Effects = {}
    self.ResetParams = {}

    self:SaveCurrentProperties()

end

local function makeComponentKey(compType, compIndex)
    return compType .. "::" .. tostring(compIndex)
end

--- @param key string
--- @return EntityEffectComponentType?, integer?
local function parseComponentKey(key)
    local splited = RBStringUtils.Split(key, "::")
    if #splited ~= 2 then return nil end

    local compType = splited[1]
    local compIndex = tonumber(splited[2]) --[[@as integer]]

    return compType, compIndex
end

function EntityEffectEditor:MakeKey(compType, compIndex)
    return makeComponentKey(compType, compIndex)
end

function EntityEffectEditor:ParseKey(key)
    return parseComponentKey(key)
end

function EntityEffectEditor:SaveCurrentProperties()
    local entity = self:GetEntity()
    if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then
        return
    end
    local components = entity.Effect.Timeline.Components

    for compIndex, comp in pairs(components) do
        local effectType = comp.TypeName
        local copyHandler = effectComponentCopyHandlers[effectType]
        if not copyHandler then
            goto continue
        end

        local compKey = makeComponentKey(effectType, compIndex)
        self.ResetParams[compKey] = {}
        copyHandler(comp, self.ResetParams[compKey])

        ::continue::
    end
end

function EntityEffectEditor:ExportChanges()
    return RBUtils.DeepCopy(self.Effects)
end

--- @param effectsTable RB_EffectsTable
function EntityEffectEditor:ImportChanges(effectsTable)
    self.Effects = RBUtils.DeepCopy(effectsTable)

    local entity = self:GetEntity()
    if not entity then
        Warning("EntityEffectEditor: Could not find entity. Cannot import changes.")
        return false
    end
    for compKey, properties in pairs(self.Effects) do
        local compType, compIndex = parseComponentKey(compKey)
        if not compType or not compIndex then
            Warning("EntityEffectEditor: Invalid component key '" .. tostring(compKey) .. "' in effects table.")
            goto continue
        end

        local comp = getEntityEffectComponent(entity, compIndex)
        if not comp or comp.TypeName ~= compType then
            Warning("EntityEffectEditor: Could not find component of type '" .. tostring(compType) .. "' at index " .. tostring(compIndex) .. " in entity. Cannot apply changes.")
            self.Effects[compKey] = nil
            goto continue
        end

        for propertyName, value in pairs(properties) do
            self:SetPropertyDirectly(comp, compIndex, propertyName, value)
        end

        ::continue::
    end
    return true
end

--- @param compIndex integer
--- @param propertyName string
--- @param value any
--- @return boolean
function EntityEffectEditor:SetProperty(compIndex, propertyName, value)
    local entity = self:GetEntity()
    if not entity then
        Warning("EntityEffectEditor: Could not find entity.")
        return false
    end

    local component = getEntityEffectComponent(entity, compIndex)
    if not component then
        Warning("EntityEffectEditor: Could not find component at index " .. tostring(compIndex) .. " to set property '" .. tostring(propertyName) .. "'.")
        return false
    end

    if not checkCompPropValid(component, propertyName) then
        Warning("EntityEffectEditor: Invalid property '" .. tostring(propertyName) .. "' for component type '" .. tostring(component.TypeName) .. "'. Cannot set value.")
        return false
    end

    VisualHelpers.SetEffectComponentValue(component, propertyName, value)

    local compKey = makeComponentKey(component.TypeName, compIndex)
    self.Effects[compKey] = self.Effects[compKey] or {}
    self.Effects[compKey][propertyName] = value

    return true
end

--- @param compIndex integer
--- @param propertyName string
--- @return any
function EntityEffectEditor:GetProperty(compIndex, propertyName)
    local entity = self:GetEntity()
    if not entity then
        Warning("EntityEffectEditor: Could not find entity for guid '" .. tostring(self.guid) .. "'.")
        return nil
    end

    local component = getEntityEffectComponent(entity, compIndex)
    if not component then
        Warning("EntityEffectTab:GetProperty - Component not found at index " .. tostring(compIndex))
        return nil
    end
    
    if not checkCompPropValid(component, propertyName) then
        Warning("EntityEffectEditor: Invalid property '" .. tostring(propertyName) .. "' for component type '" .. tostring(component.TypeName) .. "'. Cannot get value.")
        return nil
    end

    return VisualHelpers.GetEffectComponentValue(component, propertyName)
end

---@param comp AspkComponent
---@param compIndex any
---@param propertyName any
---@param value any
---@return boolean
function EntityEffectEditor:SetPropertyDirectly(comp, compIndex, propertyName, value)
    if not comp then return false end

    VisualHelpers.SetEffectComponentValue(comp, propertyName, value)

    local compKey = makeComponentKey(comp.TypeName, compIndex)
    self.Effects[compKey] = self.Effects[compKey] or {}
    self.Effects[compKey][propertyName] = value

    return true
end

---@param compIndex integer
---@param propertyName string
---@return boolean
function EntityEffectEditor:ResetProperty(compIndex, propertyName)
    local entity = self:GetEntity()
    if not entity then
        Warning("EntityEffectEditor: Could not find entity.")
        return false
    end

    local component = getEntityEffectComponent(entity, compIndex)
    if not component then
        Warning("EntityEffectEditor: Could not find component at index " .. tostring(compIndex) .. " to reset property '" .. tostring(propertyName) .. "'.")
        return false
    end

    if not checkCompPropValid(component, propertyName) then
        Warning("EntityEffectEditor: Invalid property '" .. tostring(propertyName) .. "' for component type '" .. tostring(component.TypeName) .. "'. Cannot reset.")
        return false
    end

    local compType = component.TypeName
    local compKey = makeComponentKey(compType, compIndex)
    if not self.ResetParams[compKey] or self.ResetParams[compKey][propertyName] == nil then
        Warning("EntityEffectEditor: No reset value found for component '" .. tostring(compKey) .. "' property '" .. tostring(propertyName) .. "'.")
        return false
    end

    local resetValue = self.ResetParams[compKey][propertyName]
    self:SetProperty(compIndex, propertyName, resetValue)
    self.Effects[compKey] = self.Effects[compKey] or {}
    self.Effects[compKey][propertyName] = nil
    if not next(self.Effects[compKey]) then
        self.Effects[compKey] = nil
    end
    return true
end

function EntityEffectEditor:ApplyToAllSameType(compType, sourceCompIndex)
    local entity = self:GetEntity()
    if not entity or not entity.Effect then return end

    local sourceKey = makeComponentKey(compType, sourceCompIndex)
    local modifiedParams = self.Effects[sourceKey]
    if not modifiedParams then return end

    local components = entity.Effect.Timeline.Components
    for compIndex, comp in pairs(components) do
        if comp.TypeName == compType and compIndex ~= sourceCompIndex then
            for propertyName, value in pairs(modifiedParams) do
                self:SetPropertyDirectly(comp, compIndex, propertyName, value)
            end
        end
    end
end

function EntityEffectEditor:HasChanges(compType, compIndex)
    local compKey = makeComponentKey(compType, compIndex)
    local modifiedParams = self.Effects[compKey]
    if not modifiedParams then return false end

    local entity = self:GetEntity()
    if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then return false end
    local component = entity.Effect.Timeline.Components[compIndex]
    if not component or component.TypeName ~= compType then return false end

    for propertyName, modifiedValue in pairs(modifiedParams) do
        local currentValue = VisualHelpers.GetEffectComponentValue(component, propertyName)
        if currentValue ~= modifiedValue then
            return true
        end
    end

    return false
end


--- @return boolean
function EntityEffectEditor:Reapply()
    local entity = self:GetEntity()
    if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then return false end
    local components = entity.Effect.Timeline.Components

    for compIndex, comp in pairs(components) do
        local compType = comp.TypeName
        local compKey = makeComponentKey(compType, compIndex)
        local modifiedParams = self.Effects[compKey]
        if modifiedParams then
            for propertyName, value in pairs(modifiedParams) do
                VisualHelpers.SetEffectComponentValue(comp, propertyName, value)
            end
        end
    end
    return true
end

function EntityEffectEditor:ResetAll()
    local entity = self:GetEntity()
    if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then return false end
    local components = entity.Effect.Timeline.Components

    for compIndex, comp in pairs(components) do
        local compType = comp.TypeName
        local compKey = makeComponentKey(compType, compIndex)
        local modifiedParams = self.Effects[compKey]
        if modifiedParams then
            for propertyName, _ in pairs(modifiedParams) do
                local resetValue = self.ResetParams[compKey] and self.ResetParams[compKey][propertyName]
                if resetValue ~= nil then
                    VisualHelpers.SetEffectComponentValue(comp, propertyName, resetValue)
                end
            end
        end
    end
    self.Effects = {}
    return true
end

function EntityEffectEditor:GetAllComponents()
    local entity = self:GetEntity()
    if not entity or not entity.Effect or not entity.Effect.Timeline or not entity.Effect.Timeline.Components then return {} end
    return entity.Effect.Timeline.Components
end

function EntityEffectEditor:GetEntityEffect()
    local entity = self:GetEntity()
    return entity and entity.Effect
end