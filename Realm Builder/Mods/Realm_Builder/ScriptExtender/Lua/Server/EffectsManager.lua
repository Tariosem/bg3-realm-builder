--- @class RB_EffectsPlayFlags
--- @field PlayLoop boolean
--- @field PlayAtPosition boolean
--- @field PlayAtPositionAndRotation boolean
--- @field PlayBeamEffect boolean

--- @class RB_EffectPlayData
--- @field DisplayName string
--- @field FxName string
--- @field Object GUIDSTRING[]
--- @field Target GUIDSTRING[]
--- @field SourceBone string
--- @field TargetBone string
--- @field Scale number
--- @field Flags RB_EffectsPlayFlags
--- @field Duration number
--- @field SpellAnimation string

--- @class RB_EffectsManager
--- @field name string
--- @field ActivatedFX table<string, table<string, {Handle:integer,FxName:string}>>
--- @field Statuses table<string, string>
--- @field _activeStatuses {Object:GUIDSTRING, Status:string}[]
--- @field Spells table<string, string>
--- @field init fun(self:RB_EffectsManager, name?:string):RB_EffectsManager
--- @field PlayLoopEffect fun(self:RB_EffectsManager, data:RB_EffectPlayData):integer
--- @field PlayEffect fun(self:RB_EffectsManager, data:RB_EffectPlayData)
--- @field PlayEffects fun(self:RB_EffectsManager, datas:RB_EffectPlayData[]):integer[]
--- @field PlayLoopEffects fun(self:RB_EffectsManager, datas:RB_EffectPlayData[])
--- @field StopEffect fun(self:RB_EffectsManager, object:GUIDSTRING, name:string)
--- @field StopEffectByObject fun(self:RB_EffectsManager, object:GUIDSTRING)
--- @field StopEffectByFxName fun(self:RB_EffectsManager, fxName:string|string[])
--- @field StopEffectByComb fun(self:RB_EffectsManager, fxName:string, object:GUIDSTRING|GUIDSTRING[])
EffectsManager = {}

local STATUS_PREFIX = "VFX_RB_STATUS_"
local SPELL_PREFIX = "VFX_RB_SPELL_"
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

--- @param data RB_EffectPlayData
--- @return RB_EffectPlayData
local function NormalizeData(data)
    local flags = data.Flags or {}
    return {
        DisplayName = data.DisplayName or "",
        FxName = data.FxName or "",
        Object = RBUtils.NormalizeGuidList(data.Object) or { Osi.GetHostCharacter() },
        Target = RBUtils.NormalizeGuidList(data.Target) or { Osi.GetHostCharacter() },
        SourceBone = data.SourceBone or "",
        TargetBone = data.TargetBone or "",
        Scale = data.Scale or 1.0,
        Duration = data.Duration or 5000,
        Flags = {
            PlayLoop = flags.PlayLoop or table.find(flags, "PlayLoop") or false,
            PlayAtPosition = flags.PlayAtPosition or table.find(flags, "PlayAtPosition") or false,
            PlayAtPositionAndRotation = flags.PlayAtPositionAndRotation or table.find(flags, "PlayAtPositionAndRotation") or false,
            PlayBeamEffect = flags.PlayBeamEffect or table.find(flags, "PlayBeamEffect") or false
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

--- @param data RB_EffectPlayData
function EffectsManager:PlayLoopEffect(data)
    data = NormalizeData(data)
    local fxname = data.FxName
    local fxhandle = nil

    local flags = data.Flags or {}
    local sourceBone = data.SourceBone or ""
    local targetBone = data.TargetBone or ""

    for _, obj in ipairs(data.Object) do
        if RBUtils.IsCamera(obj) then
            Warning("PlayLoopEffect: Cannot play loop effect on camera object.")
            goto continue
        end
        if flags.PlayBeamEffect then
            for _, tgt in ipairs(data.Target) do
                fxhandle = Osi.PlayLoopBeamEffect(obj, tgt, fxname, sourceBone, targetBone)
                self:StoreLoopEffect(fxhandle, obj, fxname)
            end
        elseif flags.PlayAtPositionAndRotation then
            local x, y, z = RBGetPosition(obj)
            local pitch, yaw, roll = Osi.GetRotation(obj)
            fxhandle = Osi.PlayLoopEffectAtPositionAndRotation(fxname, x, y, z, pitch, yaw, roll, data.Scale)
            self:StoreLoopEffect(fxhandle, obj, fxname)
        elseif flags.PlayAtPosition then
            local x, y, z = RBGetPosition(obj)
            fxhandle = Osi.PlayLoopEffectAtPosition(fxname, x, y, z, data.Scale)
            self:StoreLoopEffect(fxhandle, obj, fxname)
        else
            if targetBone then
                fxhandle = Osi.PlayLoopEffect(obj, fxname, targetBone, data.Scale)
            elseif sourceBone then
                fxhandle = Osi.PlayLoopEffect(obj, fxname, sourceBone, data.Scale)
            else
                local x, y, z = RBGetPosition(obj)
                fxhandle = Osi.PlayLoopEffectAtPosition(fxname, x, y, z, data.Scale)
            end
            self:StoreLoopEffect(fxhandle, obj, fxname)
        end
        --_P("Playing loop effect: " .. fxname .. " on object: " .. tostring(obj) .. " with target: " .. tostring(targetBone) .. " and source: " .. tostring(sourceBone))
        ::continue::
    end

    if data.Duration and data.Duration > 0 then
        Timer:After(data.Duration, function()
            self:StopEffectByComb(fxname, data.Object)
        end)
    end

    return fxhandle --[[@as integer]]
end

--- @param data RB_EffectPlayData
function EffectsManager:PlayEffect(data)
    data = NormalizeData(data)
    local fxname = data.FxName

    local sourceBone = data.SourceBone or ""
    local targetBone = data.TargetBone or ""

    local flags = data.Flags or {}
    for _, obj in ipairs(data.Object) do
        if RBUtils.IsCamera(obj) then
            Warning("PlayEffect: Cannot play effect on camera object.")
            goto continue
        end
        if flags.PlayBeamEffect then
            for _, tgt in ipairs(data.Target) do
                Osi.PlayBeamEffect(obj, tgt, fxname, sourceBone, targetBone)
            end
        elseif flags.PlayAtPositionAndRotation then
            local x, y, z = RBGetPosition(obj)
            local p, yaw = RBGetRotation(obj)
            Osi.PlayEffectAtPositionAndRotation(fxname, x, y, z, yaw, data.Scale)  
        elseif flags.PlayAtPosition then
            local x, y, z = RBGetPosition(obj)
            Osi.PlayEffectAtPosition(fxname, x, y, z, data.Scale)
        else
            if targetBone then
                Osi.PlayEffect(obj, fxname, targetBone, data.Scale)
            elseif sourceBone then
                Osi.PlayEffect(obj, fxname, sourceBone, data.Scale)
            else
                Osi.PlayEffect(obj, fxname, nil, data.Scale)
            end
        end
        --_P("Playing effect: " .. fxname .. " on object: " .. tostring(obj) .. " with target: " .. tostring(targetBone) .. " and source: " .. tostring(sourceBone))
        ::continue::
    end
end

--- @param datas RB_EffectPlayData[]
--- @return integer[] Handles of loop effects
function EffectsManager:PlayEffects(datas)
    if type(datas) ~= "table" then
        Warning("PlayEffects: Invalid parameter. Expected table, got " .. type(datas))
        return {}
    end
    local allLoopHandles = {}
    for _, data in ipairs(datas) do
        if data.Flags and (data.Flags.PlayLoop or table.find(data.Flags, "PlayLoop")) then
            local handle = self:PlayLoopEffect(data)
            table.insert(allLoopHandles, handle)
        else
            self:PlayEffect(data)
        end
        ::continue::
    end
    return allLoopHandles
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

    local uuids = RBUtils.NormalizeGuidList(object) or {}
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

function EffectsManager:StopEffectByHandle(handle)
    if not handle then
        Warning("StopEffectByHandle: Invalid handle parameter.")
        return
    end

    Osi.StopLoopEffect(handle)
    for object, fxData in pairs(self.ActivatedFX) do
        for obj, fxHandle in pairs(fxData) do
            if fxHandle.Handle == handle then
                fxData[obj] = nil
                --Info("Stopped effect with handle: " .. tostring(handle) .. " for object: " .. tostring(object))
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

--- @param data RB_CustomStatusData
--- @return string
local function makeStatusName(data)
    return STATUS_PREFIX .. data.Uuid
end

--- @param data RB_CustomStatusData
--- @return StatusData
function EffectsManager:CreateStatus(data)
    local newStatName = makeStatusName(data)

    local newStat = Ext.Stats.Create(newStatName, "StatusData", "_PASSIVES") --[[@as StatusData]]
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

--- @param data RB_CustomStatusData
--- @return StatusData
function EffectsManager:UpdateStatus(data)
    local statName = makeStatusName(data)
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

--- @param data RB_CustomStatusData
function EffectsManager:PlayStatus(data)
    local statName = makeStatusName(data)
    local stat = self:UpdateStatus(data)
    if not stat then
        stat = self:CreateStatus(data)
        if not stat then
            Error("PlayStatus: Failed to create status " .. statName)
            return
        end
    end

    local removeData = {
        Uuid = data.Uuid,
        Object = data.Object,
    }
    self:RemoveStatus(removeData)

    local toApply = RBUtils.NormalizeGuidList(data.Object)
    if #toApply == 0 then
        toApply = { Osi.GetHostCharacter() }
    end

    for _, obj in ipairs(toApply) do
        if EntityHelpers.EntityExists(obj) then
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

--- @param data RB_CustomStatusData
function EffectsManager:RemoveStatus(data)
    local statName = makeStatusName(data)
    local stat = Ext.Stats.Get(statName)
    if not stat then
        --Error("RemoveStatus: Status with name " .. statName .. " does not exist.")
        return
    end

    local toRemove = RBUtils.NormalizeGuidList(data.Object) or {}

    for _, obj in ipairs(toRemove) do
        if EntityHelpers.EntityExists(obj) then
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

local function makeSpellName(data)
    return SPELL_PREFIX .. data.Uuid
end

--- @alias SpellSheathing 'Melee'|'Ranged'|'Instrument'|'Sheathed'|'WeaponSet'|'Somatic'|'DontChange'

function EffectsManager:CreateSpell(data)
    local newSpellName = makeSpellName(data)
    if Ext.Stats.Get(newSpellName) then
        Info("Spell with name " .. newSpellName .. " already exists.")
        return self:UpdateSpell(data)
    end

    local newSpell = Ext.Stats.Create(newSpellName, "SpellData")
    if not newSpell then
        Error("CreateSpell: Failed to create spell " .. newSpellName)
        return
    end
    RBPrintBlue("Creating new spell: " .. newSpellName)
    for name,_ in pairs(Enums.SpellEffectType) do
        if data[name] then
            newSpell[name] = data[name]
        end
    end
    if not data.SpellAnimation or data.SpellAnimation == "" then
        data.SpellAnimation = DEFAULT_SPELL_ANIM
    end

    local displayNameHandle = RBUtils.MakeTranslatedHandle()
    Ext.Loca.UpdateTranslatedString(displayNameHandle, data.DisplayName)

    newSpell.SpellType = "Target"
    newSpell.Level = 0
    newSpell.MemoryCost = 0
    newSpell.UseCosts = "ActionPoint:1"
    newSpell.SpellSchool = "Evocation"
    newSpell.CastTextEvent = "Cast"
    newSpell.TargetRadius = tostring(data.TargetRadius) or "18"
    newSpell.AreaRadius = data.AreaRadius or 9
    newSpell.DisplayName = displayNameHandle
    newSpell.Description = "h16fe61ec41a74a86b9973ef6185543421ege"
    newSpell.ReappearEffectTextEvent = "Cast"
    newSpell.Icon = "Skill_Wizard_LearnSpell"
    newSpell.SpellFlags = {"IsSpell"}
    newSpell.VerbalIntent = "Utility"
    newSpell.SpellAnimation = data.SpellAnimation
    newSpell.HitAnimationType = "MagicalNonDamage"
    newSpell.Sheathing = data.Sheathing or "Melee"
    --newSpell.WeaponTypes = data.WeaponTypes or "Melee"
    --newSpell.Autocast = "Yes"

    ---@diagnostic disable-next-line: missing-parameter
    newSpell:Sync()

    self.Spells[newSpellName] = newSpellName

    return newSpell
end

function EffectsManager:UpdateSpell(data)
    local spellName = makeSpellName(data)
    local spell = Ext.Stats.Get(spellName) --[[@as SpellData]]
    if not spell then
        spell = self:CreateSpell(data) --[[@as SpellData]]
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

    if data.DisplayName ~= nil then
        Ext.Loca.UpdateTranslatedString(spell.DisplayName, data.DisplayName)
    end

    spell.SpellAnimation = data.SpellAnimation
    --spell.WeaponTypes = data.WeaponTypes or "Melee"
    spell.Sheathing = data.Sheathing or "Melee"
    spell.AreaRadius = data.AreaRadius or 9
    spell.TargetRadius = tostring(data.TargetRadius) or "18"
    spell.Icon = data.Icon or "Skill_Wizard_LearnSpell"
    if data.FXScale then
        spell.FXScale = data.FXScale
    end

    --PrintDivider("UpdateSpell")
    --_D(spell)

    --- @diagnostic disable-next-line: missing-parameter
    spell:Sync()

    return spell
end

function EffectsManager:PlaySpell(data)
    local spellName = makeSpellName(data)
    local spell = self:UpdateSpell(data)
    if not spell then
        spell = self:CreateSpell(data) --[[@as SpellData]]
        if not spell then
            Error("PlaySpell: Failed to create spell " .. spellName)
            return
        end
    end

    local toUse = RBUtils.NormalizeGuidList(data.Object)
    local toTgt = RBUtils.NormalizeGuidList(data.Target)
    if #toUse == 0 then
        toUse = { Osi.GetHostCharacter() }
    end
    if #toTgt == 0 then
        toTgt = { Osi.GetHostCharacter() }
    end

    for _, obj in ipairs(toUse) do
        if not EntityHelpers.EntityExists(obj) then
            goto continue
        end

        for _, tgt in ipairs(toTgt) do
            if not EntityHelpers.EntityExists(tgt) then
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