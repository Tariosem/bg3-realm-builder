--- @class EffectFlags
--- @field PlayLoop boolean
--- @field PlayOnObject boolean
--- @field PlayAtObject boolean
--- @field PlayAtPosition boolean
--- @field PlayAtPositionAndRotation boolean
--- @field PlayBeamEffect boolean

--- @class EffectData
--- @field DisplayName string
--- @field FxName string
--- @field Object GUIDSTRING|GUIDSTRING[]
--- @field Target GUIDSTRING|GUIDSTRING[]
--- @field SourceBone string
--- @field TargetBone string
--- @field Scale number
--- @field Tags EffectFlags
--- @field Duration number
--- @field SpellAnimation string

--- @class EffectsManager
--- @field name string
--- @field ActivatedFX table<string, table<string, {Handle:integer,FxName:string}>>
--- @field Statuses table<string, string>
--- @field _activeStatuses {Object:GUIDSTRING, Status:string}[]
--- @field Spells table<string, string>
--- @field init fun(self:EffectsManager, name?:string):EffectsManager
--- @field PlayLoopEffect fun(self:EffectsManager, data:EffectData):integer
--- @field PlayEffect fun(self:EffectsManager, data:EffectData)
--- @field PlayEffects fun(self:EffectsManager, datas:EffectData[])
--- @field PlayLoopEffects fun(self:EffectsManager, datas:EffectData[])
--- @field StopEffect fun(self:EffectsManager, object:GUIDSTRING, name:string)
--- @field StopEffectByObject fun(self:EffectsManager, object:GUIDSTRING)
--- @field StopEffectByFxName fun(self:EffectsManager, fxName:string|string[])
--- @field StopEffectByComb fun(self:EffectsManager, fxName:string, object:GUIDSTRING|GUIDSTRING[])
EffectsManager = {}

local STATUS_PREFIX = "VFX_LOP_STATUS_"
local SPELL_PREFIX = "VFX_LOP_SPELL_"
local DEFAULT_SPELL_ANIM = "dd86aa43-8189-4d9f-9a5c-454b5fe4a197,,;,,;7abe77ed-9c77-4eac-872c-5b8caed070b6,,;cb171bda-f065-4520-b470-e447f678ba1f,,;cc5b0caf-3ed1-4711-a50d-11dc3f1fdc6a,,;,,;1715b877-4512-472e-9bd0-fd568a112e90,,;bcc3b0d9-f04f-4448-aab0-e0ad641167cc,,;bf924cc6-8b39-4c3b-b1c0-eda264cf6150,,"

function EffectsManager:init(name)
    self.name = name or "EffectsManager"
    self.ActivatedFX = {}
    self.Statuses = {}
    self._activeStatuses = {}
    self.Spells = {}
    return self
end

--#region Multi Effect Management

local function NormalizeData(data)
    local tags = data.Tags or {}
    return {
        DisplayName = data.DisplayName or "",
        FxName = data.FxName or "",
        Object = NormalizeGuidList(data.Object) or { Osi.GetHostCharacter() },
        Target = NormalizeGuidList(data.Target) or { Osi.GetHostCharacter() },
        SourceBone = data.SourceBone or "",
        TargetBone = data.TargetBone or "",
        Scale = data.Scale or 1.0,
        Tags = {
            PlayLoop = tags.PlayLoop or TableContains(tags, "PlayLoop") or false,
            PlayOnObject = tags.PlayOnObject or TableContains(tags, "PlayOnObject") or false,
            PlayAtObject = tags.PlayAtPosition or TableContains(tags, "PlayAtObject") or false,
            PlayAtPosition = tags.PlayAtPosition or TableContains(tags, "PlayAtPosition") or false,
            PlayAtPositionAndRotation = tags.PlayAtPositionAndRotation or TableContains(tags, "PlayAtPositionAndRotation") or false,
            PlayBeamEffect = tags.PlayBeamEffect or TableContains(tags, "PlayBeamEffect") or false
        }
    }
end

function EffectsManager:StoreLoopEffect(fxhandle, obj, fx)
    if not fxhandle or fxhandle == 0 then
        return
    end

    if not self.ActivatedFX[obj] then
        self.ActivatedFX[obj] = {}
    end

    table.insert(self.ActivatedFX[obj], { Handle = fxhandle, FxName = fx })

    --Debug("Stored loop effect: " .. tostring(fx) .. " for object: " .. tostring(obj) .. " with handle: " .. tostring(fxhandle))

    return fxhandle
end

function EffectsManager:PlayLoopEffect(data)
    data = NormalizeData(data)
    local fxname = data.FxName
    local fxhandle = nil

    local tags = data.Tags or {}
    local sourceBone = data.SourceBone or ""
    local targetBone = data.TargetBone or ""

    for _, obj in ipairs(data.Object) do
        if IsCamera(obj) then
            Warning("PlayLoopEffect: Cannot play loop effect on camera object.")
            goto continue
        end
        if tags.PlayBeamEffect then
            for _, tgt in ipairs(data.Target) do
                fxhandle = Osi.PlayLoopBeamEffect(obj, tgt, fxname, sourceBone, targetBone)
                self:StoreLoopEffect(fxhandle, obj, fxname)
            end
        elseif tags.PlayAtPositionAndRotation then
            local x, y, z = CGetPosition(obj)
            local pitch, yaw, roll = Osi.GetRotation(obj)
            fxhandle = Osi.PlayLoopEffectAtPositionAndRotation(fxname, x, y, z, pitch, yaw, roll, data.Scale)
            self:StoreLoopEffect(fxhandle, obj, fxname)
        elseif tags.PlayAtPosition then
            local x, y, z = CGetPosition(obj)
            fxhandle = Osi.PlayLoopEffectAtPosition(fxname, x, y, z, data.Scale)
            self:StoreLoopEffect(fxhandle, obj, fxname)
        else
            if targetBone then
                fxhandle = Osi.PlayLoopEffect(obj, fxname, targetBone, data.Scale)
            elseif sourceBone then
                fxhandle = Osi.PlayLoopEffect(obj, fxname, sourceBone, data.Scale)
            else
                local x, y, z = CGetPosition(obj)
                fxhandle = Osi.PlayLoopEffectAtPosition(fxname, x, y, z, data.Scale)
            end
            self:StoreLoopEffect(fxhandle, obj, fxname)
        end
        --_P("Playing loop effect: " .. fxname .. " on object: " .. tostring(obj) .. " with target: " .. tostring(targetBone) .. " and source: " .. tostring(sourceBone))
        ::continue::
    end

    return fxhandle --[[@as integer]]
end

function EffectsManager:PlayEffect(data)
    data = NormalizeData(data)
    local fxname = data.FxName

    local sourceBone = data.SourceBone or ""
    local targetBone = data.TargetBone or ""

    local tags = data.Tags or {}
    for _, obj in ipairs(data.Object) do
        if IsCamera(obj) then
            Warning("PlayEffect: Cannot play effect on camera object.")
            goto continue
        end
        if tags.PlayBeamEffect then
            for _, tgt in ipairs(data.Target) do
                Osi.PlayBeamEffect(obj, tgt, fxname, sourceBone, targetBone)
            end
        elseif tags.PlayAtPositionAndRotation then
            local x, y, z = CGetPosition(obj)
            local p, yaw = CGetRotation(obj)
            Osi.PlayEffectAtPositionAndRotation(fxname, x, y, z, yaw, data.Scale)  
        elseif tags.PlayAtPosition then
            local x, y, z = CGetPosition(obj)
            Osi.PlayEffectAtPosition(fxname, x, y, z, data.Scale)
        elseif tags.PlayOnObject then
            if targetBone then
                Osi.PlayEffect(obj, fxname, targetBone, data.Scale)
            elseif sourceBone then
                Osi.PlayEffect(obj, fxname, sourceBone, data.Scale)
            else
                Osi.PlayEffect(obj, fxname, nil, data.Scale)
            end
        else
            Osi.PlayEffect(obj, fxname)
        end
        --_P("Playing effect: " .. fxname .. " on object: " .. tostring(obj) .. " with target: " .. tostring(targetBone) .. " and source: " .. tostring(sourceBone))
        ::continue::
    end
end

function EffectsManager:PlayEffects(datas)
    if type(datas) ~= "table" then
        Warning("PlayEffects: Invalid parameter. Expected table, got " .. type(datas))
        datas = {datas}
    end
    for _, data in ipairs(datas) do
        if data.Tags and (data.Tags.PlayLoop or TableContains(data.Tags, "PlayLoop")) then
            self:PlayLoopEffect(data)
        else
            self:PlayEffect(data)
        end
        ::continue::
    end
end

function EffectsManager:PlayLoopEffects(datas)
    for _, data in ipairs(datas) do
        self:PlayLoopEffect(data)
    end
end

function EffectsManager:StopEffect(object, name)
    if not object or not name then
        Error("StopEffect: Invalid parameters. Object or name is nil.")
        return
    end

    local fxData = self.ActivatedFX[object]
    if not fxData then
        Warning("StopEffect: No effects found for object: " .. tostring(object))
        return
    end

    local fxHandle = fxData[name].Handle
    if not fxHandle then
        Warning("StopEffect: No effect found with name: " .. tostring(name) .. " for object: " .. tostring(object))
        return
    end

    Osi.StopLoopEffect(fxHandle)
    fxData[name] = nil
end

function EffectsManager:StopEffectByObject(object)
    if not object then
        Error("StopEffectByObject: Invalid object parameter.")
        return
    end

    local fxData = self.ActivatedFX[object]
    if not fxData then
        --Warning("StopEffectByObject: No effects found for object: " .. tostring(object))
        return
    end

    for obj, handle in pairs(fxData) do
        Osi.StopLoopEffect(handle.Handle)
        --Info("Stopped effect: " .. tostring(name) .. " for object: " .. tostring(object))
    end

    self.ActivatedFX[object] = nil
end

function EffectsManager:StopEffectByFxName(fxName)
    if not fxName then
        Error("StopEffectByFxName: Invalid fxName parameter.")
        return
    end

    if type(fxName) == "table" then
        for _, name in ipairs(fxName) do
            self:StopEffectByFxName(name)
        end
        return
    end

    for object, fxData in pairs(self.ActivatedFX) do
        for obj, handle in pairs(fxData) do
            if handle.FxName == fxName then
                Osi.StopLoopEffect(handle.Handle)
                fxData[obj] = nil
                --Info("Stopped effect: " .. tostring(fxName) .. " for object: " .. tostring(object))
            end
        end
        if next(fxData) == nil then
            self.ActivatedFX[object] = nil
        end
    end
end

function EffectsManager:StopEffectByComb(fxName, object)
    if not fxName or not object then
        Warning("StopEffectByComb: Invalid parameters. fxName or object is nil.")
        return
    end

    local uuids = NormalizeGuidList(object) or {}
    if #uuids == 0 then
        --Warning("StopEffectByComb: No valid objects found for given GUID.")
        return
    end

    for _, object in ipairs(uuids) do
        local fxData = self.ActivatedFX[object]
        if not fxData then
            --Warning("StopEffectByComb: No effects found for object: " .. tostring(object))
            return
        end

        for obj, handle in pairs(fxData) do
            if handle.FxName == fxName then
                Osi.StopLoopEffect(handle.Handle)
                fxData[obj] = nil
                --Info("Stopped effect: " .. tostring(fxName) .. " for object: " .. tostring(object))
            end
        end

        if next(fxData) == nil then
            self.ActivatedFX[object] = nil
        end
    end
end

function EffectsManager:StopAllEffects()
    for object, fxData in pairs(self.ActivatedFX) do
        for obj, fxHandle in pairs(fxData) do
            Osi.StopLoopEffect(fxHandle.Handle)
            --Info("Stopped effect: " .. tostring(name) .. " for object: " .. tostring(object))
        end
        self.ActivatedFX[object] = nil
    end
    --Info("Stopped all effects.")
end

--#endregion Multi Effect Management

--#region Status Management

function EffectsManager:CreateStatus(data)
    local newStatName = STATUS_PREFIX .. data.DisplayName

    local newStat = Ext.Stats.Create(newStatName, "StatusData", "_PASSIVES")
    for name,_ in pairs(Enums.StatusEffectType) do
        if data[name] then
            newStat[name] = data[name]
        end
    end

    newStat.StackId = newStatName

    ---@diagnostic disable-next-line: missing-parameter
    newStat:Sync()

    self.Statuses[newStatName] = newStatName

    --PrintDivider("CreateStatus")
    return newStat
end

function EffectsManager:UpdateStatus(data)
    local statName = STATUS_PREFIX .. data.DisplayName
    local stat = Ext.Stats.Get(statName)
    if not stat then
        stat = self:CreateStatus(data)
        --Error("UpdateStatus: Status with name " .. statName .. " does not exist.")
        return stat
    end

    for name,_ in pairs(Enums.StatusEffectType) do
        if data[name] then
            stat[name] = data[name]
        elseif data[name] == "null" then
            stat[name] = nil
        end
    end

    stat:Sync()
    --PrintDivider("UpdateStatus")
    return stat
end

function EffectsManager:PlayStatus(data)
    local statName = STATUS_PREFIX .. data.DisplayName
    local stat = self:UpdateStatus(data)
    if not stat then
        stat = self:CreateStatus(data)
        if not stat then
            Error("PlayStatus: Failed to create status " .. statName)
            return
        end
    end

    local removeData = {
        DisplayName = data.DisplayName
    }
    self:RemoveStatus(removeData)

    local toApply = NormalizeGuidList(data.Object) or { Osi.GetHostCharacter()}

    for _, obj in ipairs(toApply) do
        if EntityExists(obj) then
            --PrintDivider("PlayStatus")
            --_D(Ext.Stats.Get(statName).StatusEffect)
            Osi.ApplyStatus(obj, statName, data.Duration or 10, 1)
            table.insert(self._activeStatuses, { Object = obj, Status = statName })
        else
            Warning("PlayStatus: Object " .. tostring(obj) .. " is not a character or player character.")
        end
    end

    return stat
end

function EffectsManager:RemoveStatus(data)
    local statName = STATUS_PREFIX .. data.DisplayName
    local stat = Ext.Stats.Get(statName)
    if not stat then
        --Error("RemoveStatus: Status with name " .. statName .. " does not exist.")
        return
    end

    local toRemove = NormalizeGuidList(data.Object) or {}

    for _, obj in ipairs(toRemove) do
        if EntityExists(obj) then
            Osi.RemoveStatus(obj, statName)
        else
            Warning("RemoveStatus: Object " .. tostring(obj) .. " is not a character or player character.")
        end
    end

    if not data.Object or #toRemove == 0 then
        for i = #self._activeStatuses, 1, -1 do
            local entry = self._activeStatuses[i]
            if entry.Status == statName then
                table.remove(self._activeStatuses, i)
                Osi.RemoveStatus(entry.Object, statName)
            end
        end
    end

    return stat
end

function EffectsManager:RemoveAllStatuses()
    for i = #self._activeStatuses, 1, -1 do
        local entry = self._activeStatuses[i]
        table.remove(self._activeStatuses, i)
        Osi.RemoveStatus(entry.Object, entry.Status)
    end
end

--#endregion Status Management

--#region Spell Management

function EffectsManager:CreateSpell(data)
    local newSpellName = SPELL_PREFIX .. data.DisplayName
    if Ext.Stats.Get(newSpellName) then
        Info("Spell with name " .. newSpellName .. " already exists.")
        return self:UpdateSpell(data)
    end

    local newSpell = Ext.Stats.Create(newSpellName, "SpellData")
    for name,_ in pairs(Enums.SpellEffectType) do
        if data[name] then
            newSpell[name] = data[name]
        end
    end
    if not data.SpellAnimation or data.SpellAnimation == "" then
        data.SpellAnimation = DEFAULT_SPELL_ANIM
    end
    newSpell.SpellType = "Target"
    newSpell.Level = 0
    newSpell.MemoryCost = 0
    newSpell.UseCosts = "ActionPoint:1"
    newSpell.SpellSchool = "Evocation"
    newSpell.CastTextEvent = "Cast"
    newSpell.TargetRadius = tostring(data.TargetRadius) or "18"
    newSpell.AreaRadius = data.AreaRadius or 9
    newSpell.DisplayName = "h16fe61ec41a74a86b9973ef6185543421ege"
    newSpell.Description = "h16fe61ec41a74a86b9973ef6185543421ege"
    newSpell.ReappearEffectTextEvent = "Cast"
    newSpell.Icon = "Skill_Wizard_LearnSpell"
    newSpell.SpellFlags = {"IsSpell"}
    newSpell.VerbalIntent = "Utility"
    newSpell.SpellAnimation = data.SpellAnimation
    newSpell.HitAnimationType = "MagicalNonDamage"
    newSpell.Sheathing = data.Sheathing or "Melee"
    newSpell.WeaponTypes = data.WeaponTypes or "Melee"
    --newSpell.Autocast = "Yes"

    -- Helper 
    ---@diagnostic disable-next-line: missing-parameter
    newSpell:Sync()

    self.Spells[newSpellName] = newSpellName
    --_P("CreateSpell")
    --_D(newSpell)

    return newSpell
end

function EffectsManager:UpdateSpell(data)
    local spellName = SPELL_PREFIX .. data.DisplayName
    local spell = Ext.Stats.Get(spellName)
    if not spell then
        spell = self:CreateSpell(data)
        return spell
    end

    for name,_ in pairs(Enums.SpellEffectType) do
        if data[name] then
            spell[name] = data[name]
        elseif data[name] == "Null" then
            spell[name] = nil
        end
    end

    for key, value in pairs(spell) do
        if data[key] then
            spell[key] = value
        end
    end

    if data.SpellAnimation == "" or not data.SpellAnimation then
        data.SpellAnimation = DEFAULT_SPELL_ANIM
    end
    spell.SpellAnimation = data.SpellAnimation
    spell.WeaponTypes = data.WeaponTypes or "Melee"
    spell.Sheathing = data.Sheathing or "Melee"
    spell.AreaRadius = data.AreaRadius or 9
    spell.TargetRadius = tostring(data.TargetRadius) or "18"
    if data.FXScale then
        spell.FXScale = data.FXScale
    end

    --PrintDivider("UpdateSpell")
    --_D(spell)

    spell:Sync()

    return spell
end

function EffectsManager:PlaySpell(data)
    local spellName = SPELL_PREFIX .. data.DisplayName
    local spell = self:UpdateSpell(data)
    if not spell then
        spell = self:CreateSpell(data)
        if not spell then
            Error("PlaySpell: Failed to create spell " .. spellName)
            return
        end
    end

    local toUse = NormalizeGuidList(data.Object) or { Osi.GetHostCharacter()}
    local toTgt = NormalizeGuidList(data.Target) or { Osi.GetHostCharacter()}

    for _, obj in ipairs(toUse) do
        if not EntityExists(obj) then
            goto continue
        end

        for _, tgt in ipairs(toTgt) do
            if not EntityExists(tgt) then
                goto continue
            end
            if data.AtPosition then
                local x, y, z = Osi.GetPosition(tgt)
                Osi.UseSpellAtPosition(obj, spellName, x, y, z)
            else
                Osi.UseSpell(obj, spellName, tgt)
            end
            ::continue::
        end
        ::continue::
    end

end

--#endregion Spell Management