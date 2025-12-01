local StatsObjectInit = false

local spellEffectTypes = Enums.SpellEffectType
local statusEffectTypes = Enums.StatusEffectType
local passiveEffectTypes = {}

local EffectToInfo = {}
local EffectToAnimation = {}
local StaticDataNameToUuid = {}

local function InitEffectStats()
    if StatsObjectInit then return end

    local function parseEffectValue(s)
        local results, seen = {}, {}
        for match in string.gmatch(s, "(VFX[^:;]+):") do
            if not seen[match] then
                seen[match] = true
                table.insert(results, match)
            end
        end
        return #results > 0 and results or { s }
    end

    local function tryToFetchAnimation(stat)
        if not stat.SpellAnimation or stat.SpellAnimation == "" then
            return nil
        end
        local animationSet = { SpellAnimation = stat.SpellAnimation }
        if stat.WeaponTypes and stat.WeaponTypes ~= "" then
            animationSet.WeaponTypes = stat.WeaponTypes
        end
        if stat.Sheathing and stat.Sheathing ~= "" then
            animationSet.Sheathing = stat.Sheathing
        end
        return animationSet
    end

    local function processStat(stat, effectType, statType)
        local value = stat[effectType]
        if not value or value == "" or value == "NONE" then return end

        local animSet = (statType == "SpellData") and tryToFetchAnimation(stat) or nil

        local function addEffectInfo(key)
            if not EffectToInfo[key] then
                EffectToInfo[key] = {
                    Type = effectType,
                    Icon = stat.Icon,
                    DisplayName = GetLoca(stat.DisplayName, "Unknown")
                }
                
                if animSet then
                    EffectToAnimation[key] = animSet
                end
            end
        end

        if IsUuid(value) then
            addEffectInfo(value)
        else
            for _, v in ipairs(parseEffectValue(value)) do
                addEffectInfo(v)
            end
        end
    end
    
    local function processStats(statType, effectTypes)
        for _, entry in pairs(Ext.Stats.GetStats(statType)) do
            local stat = Ext.Stats.Get(entry)
            for effectType,_ in pairs(effectTypes or {}) do
                processStat(stat, effectType, statType)
            end
        end
    end

    --- @param resType ExtResourceManagerType
    local function processStaticData(resType)
        for _, entry in pairs(Ext.StaticData.GetAll(resType)) do
            local res = Ext.StaticData.Get(entry, resType)
            StaticDataNameToUuid[res.Name] = { Uuid = entry, Type = resType }
        end
    end

    processStats("SpellData",  spellEffectTypes)
    processStats("StatusData", statusEffectTypes)
    processStats("PassiveData", passiveEffectTypes)
    processStats("InterruptData")
    processStaticData("Tag")

    StatsObjectInit = true
end

function GetEffectInfo(effectUuid)
    if not next(EffectToInfo) then
        InitEffectStats()
    end

    local info = EffectToInfo[effectUuid]

    if not info then
        if RB_MultiEffectManager.UuidToEffectName[effectUuid] then
            local multiEffectName = RB_MultiEffectManager.UuidToEffectName[effectUuid]
            info = EffectToInfo[multiEffectName]
        end
    end

    if not info then
        return nil
    end

    if info.Icon == "" or info.Icon == "unknown" or ICON_BLACKLIST[info.Icon] then
        info.Icon = "Item_Unknown"
    end

    info.Icon = CheckIcon(info.Icon, "Item_Unknown")

    return info
end

local unknownNames = {}
function GetStaticDataByName(name)
    if not StatsObjectInit then
        InitEffectStats()
    end

    if not name or name == "" then
        return nil
    end

    if not StaticDataNameToUuid[name] and not unknownNames[name] then
        unknownNames[name] = true
        Debug("Unknown resource name:", name)
        return nil
    end

    local savedEntry = StaticDataNameToUuid[name]
    if not savedEntry then
        unknownNames[name] = true
        Debug("Unknown resource name:", name)
        return nil
    end
    local resourceObj = nil
    resourceObj = Ext.StaticData.Get(savedEntry.Uuid, savedEntry.Type)


    return resourceObj, savedEntry.Type
end

function GetEffectAnimation(any)
    if not StatsObjectInit then
        InitEffectStats()
    end

    if EffectToAnimation[any] then
        return EffectToAnimation[any]
    end

    if RB_MultiEffectManager.UuidToEffectName[any] and EffectToAnimation[RB_MultiEffectManager.UuidToEffectName[any]] then
        return EffectToAnimation[RB_MultiEffectManager.UuidToEffectName[any]]
    end

    return nil
end

local function ClearStatData()
    StatsObjectInit = false
    EffectToInfo = {}
    EffectToAnimation = {}
    StaticDataNameToUuid = {}
end

local function ReInitStats()
    ClearStatData()
    InitEffectStats()
end


function ClearEffectToInfo()
    EffectToInfo = {}
end

ReInitStats()