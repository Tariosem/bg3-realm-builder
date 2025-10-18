--- @class MultiEffectManager:ManagerBase
MultiEffectManager = _Class("MultiEffectManager", ManagerBase)
function MultiEffectManager:__init()
    ManagerBase.__init(self)
    self.Data = {}
    self.EffectNameToUuid = {}
    self.UuidToEffectName = {}
end

--- @class RB_Effect
--- @field Uuid string
--- @field TemplateId string
--- @field TemplateName string
--- @field DisplayName string
--- @field Icon string
--- @field isBeam boolean
--- @field isLoop boolean
--- @field fxNames string[]
--- @field SourceBones string[]
--- @field TargetBones string[]
--- @field SourceBone string
--- @field TargetBone string
--- @field Repeat number
--- @field isMultiEffect boolean
--- @field Note string
--- @field Group string
--- @field Tags string[]

function MultiEffectManager:PopulateMultiEffectInfo(uuid)
    local raw = Ext.StaticData.Get(uuid, "MultiEffectInfo")
    local Entries, FxNameMap, BoneNameCounter = {}, {}, {}
    local MultiEffectEntry = {
        Uuid = uuid,
        Icon = "Item_Unknown",
        TemplateId = uuid,
        DisplayName = raw.Name or "Unknown",
        TemplateName = raw.Name,
        fxNames = {},
        isMultiEffect = true,
        isLoop = false,
        Note = "",
        Group = "",
        Tags = {"Multi-Effect"},
    }

    local unnamedCount = 0

    for _, effect in ipairs(raw.EffectInfo) do
        local fxName = effect.EffectResourceGuid
        table.insert(MultiEffectEntry.fxNames, fxName)

        local entry = FxNameMap[fxName]
        if entry then
            entry.Repeat = entry.Repeat + 1
        else
            entry = {
                Uuid = fxName,
                DisplayName = nil,
                fxNames = {fxName},
                SourceBones = LightCToArray(effect.SourceBone),
                TargetBones = LightCToArray(effect.TargetBone),
                SourceBone = effect.SourceBone and effect.SourceBone[1] or "",
                TargetBone = effect.TargetBone and effect.TargetBone[1] or "",
                Repeat = 1,
                isMultiEffect = false,
                isLoop = false,
                Note = "",
                Group = "",
                Tags = {},
            }

            if entry.TargetBone ~= "" then
                BoneNameCounter[entry.TargetBone] = (BoneNameCounter[entry.TargetBone] or 0) + 1
                --entry.DisplayName = raw.Name .. "_" .. entry.TargetBone .. "_" .. BoneNameCounter[entry.TargetBone]
            else
                unnamedCount = unnamedCount + 1
                --entry.DisplayName = raw.Name .. "_" .. unnamedCount
            end

            FxNameMap[fxName] = entry
            table.insert(Entries, entry)
        end
    end

    table.insert(Entries, MultiEffectEntry)
    return Entries
end

function MultiEffectManager:PopulateEffect(res)
    --- @type RB_Effect
    local entry = {
        Uuid = res.Guid,
        TemplateId = res.Guid,
        TemplateName = res.EffectName,
        DisplayName = res.EffectName or "Unknown",
        Icon = "Item_Unknown",
        fxNames = {res.Guid},
        isBeam = false,
        isLoop = res.Looping or false,
        SourceBones = {},
        TargetBones = {},
        Repeat = 1,
        isMultiEffect = false,
        Note = "",
        Group = "",
        Tags = {},
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
                self.UuidToEffectName[entry.Uuid] = entry.TemplateName
                self.EffectNameToUuid[entry.TemplateName] = entry.Uuid
            elseif entry.Uuid then
                self.Data[entry.Uuid] = entry
            end
        end
    end

    local rawEffects = Ext.Resource.GetAll("Effect")
    for _, effect in ipairs(rawEffects) do
        local res = Ext.Resource.Get(effect, "Effect")
        local entry = self:PopulateEffect(res)
        if not self.Data[res.Guid] then
            self.Data[res.Guid] = entry
        else
            self.Data[res.Guid].TemplateName = res.EffectName
            self.Data[res.Guid].DisplayName = res.EffectName
        end
    end

    local function isValidIcon(icon)
        return icon and icon ~= "Item_Unknown" and icon ~= ""
    end

    for uuid, entry in pairs(self.Data) do
        local effectInfo = GetEffectInfo(uuid)

        if effectInfo then
            entry.Icon = isValidIcon(effectInfo.Icon) and effectInfo.Icon or nil
            entry.DisplayName = effectInfo.DisplayName
            if effectInfo.Type ~= "" then
                table.insert(entry.Tags, effectInfo.Type)
            end

            local isLoop = effectInfo.Type == "PrepareEffect" or effectInfo.Type == "StatusEffect" or false
            for _, fxName in ipairs(entry.fxNames) do
                if entry.Icon and not isValidIcon(self.Data[fxName].Icon) then
                    self.Data[fxName].Icon = entry.Icon
                end

                if isLoop then
                    self.Data[fxName].isLoop = true
                end
            end

            if entry.DisplayName:sub(1, 3) == "%%%" then
                entry.DisplayName = entry.DisplayName:sub(5)
            end
            if entry.DisplayName == "EMPTY" or entry.DisplayName == "Empty" or entry.DisplayName == "Unknown" then
                entry.DisplayName = entry.TemplateName
            end
        end
    end

    for uuid, entry in pairs(self.Data) do
        if not isValidIcon(entry.Icon) then
            entry.Icon = "Item_Unknown"
            table.insert(entry.Tags, "Unknown Icon")
        end
        if entry.DisplayName == '<LSTag Type="Image" Info="SoftWarning"/> Add <b>Elf</b> Tag.' then
            entry.DisplayName = entry.TemplateName
        end
    end

    self.populated = true
    return CountMap(self.Data)
end
