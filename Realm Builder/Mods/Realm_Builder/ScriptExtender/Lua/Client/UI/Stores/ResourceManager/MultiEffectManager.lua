--- @class MultiEffectManager:ManagerBase
--- @field new fun():MultiEffectManager
--- @field Data table<string, RB_Effect>
MultiEffectManager = _Class("MultiEffectManager", ManagerBase)
function MultiEffectManager:__init()
    ManagerBase.__init(self)
    self.Data = {}
    self.EffectNameToUuid = {}
    self.UuidToEffectName = {}
end

--- @class RB_Effect
--- @field Uuid string
--- @field EffectName string
--- @field SpellName string -- which spell/status this effect is associated with
--- @field Icon string
--- @field isBeam boolean
--- @field isLoop boolean
--- @field FxNames string[] -- List of Effect Resource GUIDs
--- @field SourceBone string
--- @field TargetBone string
--- @field Repeat number -- How many times this effect is used in a multi-effect
--- @field isMultiEffect boolean

function MultiEffectManager:PopulateMultiEffectInfo(uuid)
    local raw = Ext.StaticData.Get(uuid, "MultiEffectInfo") --[[@as ResourceMultiEffectInfo]]
    local Entries, FxNameMap, BoneNameCounter = {}, {}, {}
    local MultiEffectEntry = {
        Uuid = uuid,
        Icon = "Item_Unknown",
        EffectName = raw.Name or "Unknown Multi-Effect",
        SpellName = "",
        FxNames = {},
        isMultiEffect = true,
        isLoop = false,
        Note = "",
    }
    self:AddTagToData(uuid, "Multi-Effect")

    local unnamedCount = 0

    for _, effect in ipairs(raw.EffectInfo) do
        local fxName = effect.EffectResourceGuid
        local res = Ext.Resource.Get(fxName, "Effect") --[[@as ResourceEffectResource]]
        if not res then
            goto continue
        end

        table.insert(MultiEffectEntry.FxNames, fxName)

        local entry = FxNameMap[fxName]
        if entry then
            entry.Repeat = entry.Repeat + 1
        else
            local SourceBones = RBUtils.LightCToArray(effect.SourceBone)
            local TargetBones = RBUtils.LightCToArray(effect.TargetBone)
            local sourceBoneStr = table.concat(SourceBones, ",") or ""
            local targetBoneStr = table.concat(TargetBones, ",") or ""
            local isBeam = targetBoneStr ~= "" and sourceBoneStr ~= ""

            --- @type RB_Effect
            entry = {
                Uuid = fxName,
                FxNames = {fxName},
                EffectName = res.EffectName,
                Icon = "Item_Unknown",
                SpellName = "",
                SourceBone = sourceBoneStr,
                TargetBone = targetBoneStr,
                Repeat = 1,
                isMultiEffect = false,
                isLoop = false,
                isBeam = isBeam,
                Note = "",
            }

            if entry.TargetBone ~= "" then
                BoneNameCounter[entry.TargetBone] = (BoneNameCounter[entry.TargetBone] or 0) + 1
            else
                unnamedCount = unnamedCount + 1
            end

            FxNameMap[fxName] = entry
            table.insert(Entries, entry)
        end
        ::continue::
    end

    table.insert(Entries, MultiEffectEntry)
    return Entries
end

--- @param res ResourceEffectResource
function MultiEffectManager:PopulateEffect(res)
    --- @type RB_Effect
    local entry = {
        Uuid = res.Guid,
        EffectName = res.EffectName or "Unknown",
        SpellName = "",
        Icon = "Item_Unknown",
        FxNames = {res.Guid},
        isBeam = false,
        isLoop = res.Looping or false,
        Repeat = 1,
        isMultiEffect = false,
        Note = "",
    }
    return entry
end

function MultiEffectManager:PopulateAllEffects()
    if self.populated then return -1 end
    local raw = Ext.StaticData.GetAll("MultiEffectInfo")
    for _, ResourceId in ipairs(raw) do
        local entries = self:PopulateMultiEffectInfo(ResourceId)
        for _, entry in ipairs(entries) do
            if entry.Uuid and entry.isMultiEffect then
                self.Data[entry.Uuid] = entry
                self.UuidToEffectName[entry.Uuid] = entry.EffectName
                self.EffectNameToUuid[entry.EffectName] = entry.Uuid
            elseif entry.Uuid then
                self.Data[entry.Uuid] = entry
            end
        end
    end

    local rawEffects = Ext.Resource.GetAll("Effect")
    for _, effect in ipairs(rawEffects) do
        if self.Data[effect] then
            goto continue
        end
        local res = Ext.Resource.Get(effect, "Effect") --[[@as ResourceEffectResource]]
        local entry = self:PopulateEffect(res)
        self.Data[res.Guid] = entry
        ::continue::
    end

    local function isValidIcon(icon)
        return icon and icon ~= "Item_Unknown" and icon ~= ""
    end

    for uuid, entry in pairs(self.Data) do
        local effectInfo = StatsHelpers.GetEffectInfo(uuid)

        if effectInfo then
            entry.Icon = isValidIcon(effectInfo.Icon) and effectInfo.Icon or ""
            entry.SpellName = effectInfo.DisplayName or ""
            if effectInfo.Type ~= "" then
                self:AddTagToData(uuid, effectInfo.Type)
            end

            local isLoop = effectInfo.Type == "PrepareEffect" or effectInfo.Type == "StatusEffect" or false
            for _, fxName in ipairs(entry.FxNames) do
                if entry.Icon and not isValidIcon(self.Data[fxName].Icon) then
                    self.Data[fxName].Icon = entry.Icon
                end

                if isLoop then
                    self.Data[fxName].isLoop = true
                end
            end

            if entry.SpellName:sub(1, 3) == "%%%" then
                entry.SpellName = entry.SpellName:sub(5)
            end
            if entry.SpellName == "EMPTY" or entry.SpellName == "Empty" or entry.SpellName == "Unknown" then
                entry.SpellName = ""
            end
        end
    end

    for uuid, entry in pairs(self.Data) do
        if not isValidIcon(entry.Icon) then
            entry.Icon = "Item_Unknown"
            self:AddTagToData(uuid, "Unknown Icon")
        end
        if entry.DisplayName == '<LSTag Type="Image" Info="SoftWarning"/> Add <b>Elf</b> Tag.' or entry.DisplayName == "" then
            entry.DisplayName = entry.TemplateName
        end
    end

    self.populated = true
    ClearEffectToInfo()
    return RBTableUtils.CountMap(self.Data)
end