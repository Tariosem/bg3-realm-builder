local StatsObjectInit = false

local spellEffectTypes = Enums.SpellEffectType
local statusEffectTypes = Enums.StatusEffectType
local passiveEffectTypes = {}

local EffectToInfo = {}
local EffectToAnimation = {}
local StatsNameToUuid = {}

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
            StatsNameToUuid[stat.Name] = { Uuid = entry, Type = statType }
        end
    end

    --- @param resType ExtResourceManagerType
    local function processStaticData(resType)
        for _, entry in pairs(Ext.StaticData.GetAll(resType)) do
            local res = Ext.StaticData.Get(entry, resType)
            StatsNameToUuid[res.Name] = { Uuid = entry, Type = resType }
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
    if not StatsObjectInit then
        InitEffectStats()
    end

    local info = EffectToInfo[effectUuid]

    if not info then
        if LOP_MultiEffectManager.UuidToEffectName[effectUuid] then
            local multiEffectName = LOP_MultiEffectManager.UuidToEffectName[effectUuid]
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
function GetStatsObjByName(name)

    if not StatsObjectInit then
        InitEffectStats()
    end
    if not name or name == "" then
        return nil
    end
    if name:match("^['\"].*['\"]$") then
        name = name:sub(2, -2)
    end

    if not StatsNameToUuid[name] and not unknownNames[name] then
        unknownNames[name] = true
        Debug("Unknown stats name:", name)
        return GetStatsObjByOther(name)
    end

    local savedEntry = StatsNameToUuid[name]
    if not savedEntry then
        unknownNames[name] = true
        Debug("Unknown stats name:", name)
        return GetStatsObjByOther(name)
    end
    local statsObj = nil
    if savedEntry.Type == "Tag" and name ~= "POISONED" then
        statsObj = Ext.StaticData.Get(savedEntry.Uuid, savedEntry.Type)
    else
        statsObj = Ext.Stats.Get(savedEntry.Uuid)
    end

    return statsObj, savedEntry.Type
end

function GetStatsObjByOther(name)
    local statsObj = Ext.Stats.Get(name)
    if statsObj then
        return statsObj, "Unknown"
    end

    return nil 
end

function GetEffectAnimation(any)
    if not StatsObjectInit then
        InitEffectStats()
    end

    if EffectToAnimation[any] then
        return EffectToAnimation[any]
    end

    if LOP_MultiEffectManager.UuidToEffectName[any] and EffectToAnimation[LOP_MultiEffectManager.UuidToEffectName[any]] then
        return EffectToAnimation[LOP_MultiEffectManager.UuidToEffectName[any]]
    end

    return nil
end

function ReInitStats()
    ClearStatData()
    InitEffectStats()
end

function ClearStatData()
    StatsObjectInit = false
    EffectToInfo = {}
    EffectToAnimation = {}
    StatsNameToUuid = {}
end

function ClearEffectToInfo()
    EffectToInfo = {}
end

ReInitStats()