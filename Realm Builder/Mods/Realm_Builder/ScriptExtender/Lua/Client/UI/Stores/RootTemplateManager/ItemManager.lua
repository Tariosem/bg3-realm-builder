--- @class RB_ItemManager:ManagerBase
--- @field new fun():RB_ItemManager
--- @field CheckHostValidEquipmentVisual fun(self: RB_ItemManager, guid:string):boolean
ItemManager = _Class("ItemManager", ManagerBase)

function ItemManager:__init()
    ManagerBase.__init(self)
    self.modCache = {}
    self.BodyTypeToEquipments = {}
    self.TemplateNameToUuid = {}
    self.UuidToTemplateName = {}
    self.dynamicTags = {}
    self.tagMap = {}
    self.tagCount = {}
    self:HardCodeHierachy()
end

function ItemManager:AddEquipmentToRace(equipmentUuid, raceUuid)
    local bodyType = EquipmentRaceToBodyType[raceUuid]
    if not bodyType then return end
    self.BodyTypeToEquipments[bodyType] = self.BodyTypeToEquipments[bodyType] or {}
    self.BodyTypeToEquipments[bodyType][equipmentUuid] = true
end

function ItemManager:GetEquipmentsForRace(raceUuid)
    local bodyType = EquipmentRaceToBodyType[raceUuid]
    if not bodyType then return nil end
    return self.BodyTypeToEquipments[bodyType]
end

function ItemManager:CheckHostValidEquipmentVisual(guid)
    if self.lastPartyMember == guid and self.lastDynamicTag then return false end

    if self.lastDynamicTag then
        self.tagMap[self.lastDynamicTag] = nil
        self.tagCount[self.lastDynamicTag] = nil
        self.tagTree:Remove(self.lastDynamicTag)
    end

    local entity = guid and UuidToHandle(guid) or _C()
    self.lastPartyMember = guid
    if not entity then return false end
    if not EntityHelpers.IsPartyMember(entity) then return false end

    local raceUuid = entity.GameObjectVisual.RootTemplateId
    local cTemplate = Ext.Template.GetRootTemplate(raceUuid)
    if not cTemplate then return false end
    local equipmentRace = cTemplate.EquipmentRace
    local displayName = entity.DisplayName.Name:Get() or "Host"
    local dynamicTag = GetLoca("Valid Visuals for ") .. displayName
    self.dynamicTags[dynamicTag] =
    "This tag is dynamically generated to show valid equipment visuals for the selected character. (Not 100% accurate)"
    self.lastDynamicTag = dynamicTag
    self.lastPartyMember = guid

    local data = self:GetEquipmentsForRace(equipmentRace)
    if not data then
        Info("No valid equipment visual for host")
        return false
    end
    local cnt = 0
    for uuid, _ in pairs(data) do
        local tag = dynamicTag
        self.tagCount[tag] = (self.tagCount[tag] or 0) + 1
        self.tagMap[tag] = self.tagMap[tag] or {}
        self.tagMap[tag][uuid] = true
        cnt = cnt + 1
    end

    return true
end

function ItemManager:HardCodeHierachy()
    local tree = self.tagTree

    self.tagTree:FromTable({
        ["Equipment"] = {
            ["Weapon"] = {
                ["SimpleWeapons"] = {},
                ["MartialWeapons"] = {}
            },
            ["Armor"] = {
            },
            ["MusicalInstrument"] = {
                ["Lute"] = 0,
                ["Flute"] = 0,
                ["Drum"] = 0,
                ["Lyre"] = 0,
                ["Violin"] = 0,
            }
        },
        ["ArmorType"] = {},
        ["Consumable"] = {
            ["Food"] = 0,
            ["Drink"] = 0,
            ["Scroll"] = 0,
            ["Arrow"] = 0,
            ["Grenade"] = 0,
            ["Poison"] = 0,
            ["Magical"] = 0,
            ["Alchemy"] = 0,
            ["Potion"] = 0,
        },
    })

    for itemSlot, _ in pairs(Ext.Enums.ItemSlot) do
        if itemSlot ~= "None" and itemSlot ~= "Count" and tonumber(itemSlot) == nil then
            local node = self.tagTree:AddLeaf(itemSlot, 0, "Equipment")
        end
    end

    tree.Equipment.Weapon["Melee Main Weapon"] = 0
    tree.Equipment.Weapon["Melee Offhand Weapon"] = 0
    tree.Equipment.Weapon["Ranged Main Weapon"] = 0

    tree.Equipment.Armor.Breast = 0
    tree.Equipment.Armor.Gloves = 0
    tree.Equipment.Armor.Boots = 0
    tree.Equipment.Armor.Helmet = 0
    tree.Equipment.Armor.Cloak = 0

    self.tagIcons = {
        Amulet = "Item_LOOT_GEN_KeepsakeLocket_A",
        Boots = "Item_ARM_Boots_Leather_A",
        Breast = "Item_ARM_ScaleMail",
        Cloak = "Generated_ARM_Cloak",
        Gloves = "Item_ARM_Gloves_Leather",
        Helmet = "Item_ARM_Helmet_Leather",
        ["Melee Main Weapon"] = "Item_WPN_HUM_Greataxe_A_0",
        ["Melee Offhand Weapon"] = "Item_WPN_HUM_Shield_A_0",
        ["Ranged Main Weapon"] = "Item_WPN_HUM_Longbow_A_0",
        Ring = "Item_LOOT_GEN_Ring_A_Simple_Gold",
        Underwear = "Item_Underwear_Humans_A",
        VanityBody = "Generated_ARM_Camp_Body_Astarion",
        VanityBoots = "Generated_ARM_Camp_Shoes_Astarion",
        Destruction = "Item_BLD_Village_House_Door_A_Wood_Scenery_B",
        Consumable = "Item_CONS_Potion_Healing_A",
        BooksAndKeys = "Item_BOOK_GEN_Book_A",
        ArmorType = "Item_ARM_Leather",
        Equipment = "Item_WPN_HUM_Longsword_A_0",
    }

    --[[
    for armorType, _ in pairs(Ext.Enums.ArmorType) do
        if armorType ~= "None" and armorType ~= "Count" and tonumber(armorType) == nil then
            self.tagTree["ArmorType"][armorType] = 0
            self.tagIcons[armorType] = "Item_ARM_" .. armorType
        end
    end
    ]]

    self.tagIcons.BreastPlate = "Item_ARM_Breastplate"
    self.tagIcons.Cloth = "Item_ARM_Robe"

    local simpleWeaponCate = {
        Clubs = 0,
        Daggers = 0,
        Handaxes = 0,
        Javelins = 0,
        LightHammers = 0,
        Maces = 0,
        Sickles = 0,
        Quarterstaves = 0,
        Spears = 0,
        GreatClubs = 0,
        Slings = 0,
        LightCrossbows = 0,
        Shortbows = 0,
    }

    for prof, _ in pairs(Ext.Enums.ProficiencyGroupFlags) do
        if prof == "SimpleWeapons" or prof == "MartialWeapons" then goto continue end
        if prof ~= "None" and prof ~= "Count" and prof ~= "MusicalInstrument" and tonumber(prof) == nil then
            if simpleWeaponCate[prof] then
                self.tagTree:AddLeaf(prof, 0, "SimpleWeapons")
                --self.tagTree["Equipment"]["Weapon"]["SimpleWeapons"][prof] = 0
            else
                self.tagTree:AddLeaf(prof, 0, "MartialWeapons")
                --self.tagTree["Equipment"]["Weapon"]["MartialWeapons"][prof] = 0
            end

            self.tagIcons[prof] = "Item_WPN_HUM_" .. prof:gsub("s$", "") .. "_A_0"
        end
        ::continue::
    end

    tree.Equipment.Armor.HeavyArmor = 0
    tree.Equipment.Armor.MediumArmor = 0
    tree.Equipment.Armor.LightArmor = 0

    self.tagIcons["HeavyArmor"] = "Item_ARM_ChainMail_2"
    self.tagIcons["HeavyCrossbows"] = "WPN_HUM_HeavyCrossbow_A_0"
    self.tagIcons["LightArmor"] = "Item_ARM_Leather_3"
    self.tagIcons["MartialWeapons"] = "Item_WPN_HUM_Battleaxe_A_0"
    self.tagIcons["MediumArmor"] = "Item_ARM_Breastplate_2"
    self.tagIcons["SimpleWeapons"] = "Item_WPN_HUM_CleaverAxe_A"
    self.tagIcons["Warhammers"] = "Item_WPN_HUM_WarHammer_A_0"

    self.tagIcons["Lute"] = "Item_TOOL_GEN_Music_Guitar_Lute_A"
    self.tagIcons["Flute"] = "Item_TOOL_GEN_Music_Flute_A"
    self.tagIcons["Drum"] = "Item_TOOL_GEN_Music_Drum_Small_A"
    self.tagIcons["Lyre"] = "Item_TOOL_GEN_Music_Lyre_A"
    self.tagIcons["Violin"] = "Item_TOOL_GEN_Music_Viol_A"

    self.tagIcons["Alchemy"] = "Item_alch_extract_air_1"
    self.tagIcons["Arrow"] = "Item_ARR_Arrow_Of_Ricochet"
    self.tagIcons["Drink"] = "Item_CONS_Drink_Mug_Metal_A_Beer"
    self.tagIcons["Food"] = "Item_CONS_GEN_Food_Bread_Loaf_A"
    self.tagIcons["Grenade"] = "Item_GRN_FireFlask_A"
    self.tagIcons["Poison"] = "Item_GRN_Poison_vial_B"
    self.tagIcons["Potion"] = "Item_CONS_Potion_Healing_A"
    self.tagIcons["Scroll"] = "Item_LOOT_SCROLL_Counterspell"

    --tree:Reparent("ArmorType", "Equipment")
end

--- @class RB_Item
--- @field Uuid string
--- @field TemplateId string -- Name + "_" + Uuid
--- @field TemplateName string
--- @field DisplayName string
--- @field Icon string
--- @field StatsName string
--- @field Description string
--- @field ShortDescription string
--- @field Mod string
--- @field ModId string
--- @field ModAuthor string
--- @field Note string
--- @field CanBePickedUp boolean
--- @field StoryItem boolean
--- @field Rarity string

--- @param template ItemTemplate
--- @return RB_Item?
function ItemManager:PopulateItem(template, statsObj)
    if not template then return nil end

    local uuid = template.Id
    local templateName = template.Name
    --- @type RB_Item
    local entry = {
        Uuid = uuid,
        TemplateId = template.Name .. "_" .. uuid,
        TemplateName = template.Name,
        DisplayName = template.DisplayName:Get() or "",
        Icon = template.Icon or RB_ICONS.Box,
        Description = template.Description:Get() or "",
        ShortDescription = template.ShortDescription:Get() or "",
        Mod = "",
        ModId = "",
        ModAuthor = "",
        Note = "",
        CanBePickedUp = template.CanBePickedUp and true or false,
        StoryItem = template.StoryItem and true or false,
        Rarity = "",
    }

    statsObj = statsObj or Ext.Stats.Get(template.Stats) --[[@as StatsObject]]
    if statsObj then
        local ok, err = xpcall(function ()
            self:CategorizeItem(entry, statsObj, templateName)
        end, debug.traceback)
    
        if not ok then
            _P("Error categorizing item " .. entry.TemplateId .. ": " .. err)
        end
    else
    end

    if entry.TemplateName == "" then
        entry.TemplateName = entry.TemplateId
    end

    --- fallback to template name if display name is empty or generic
    if not entry.DisplayName or entry.DisplayName == "" or entry.DisplayName == template.DisplayName.Handle.Handle or entry.DisplayName == "Object" or entry.DisplayName == '<LSTag Type="Image" Info="SoftWarning"/> Add <b>Elf</b> Tag.' then
        entry.DisplayName = entry.TemplateName
    end

    if ICON_BLACKLIST[entry.Icon] then
        entry.Icon = RB_ICONS.Box
    end
    if entry.Icon == RB_ICONS.Box then
        self:AddTagToData(entry.Uuid, "Unknown Icon")
    end

    if entry.Icon == "Item_BLD_Village_House_Door_A_Wood_Scenery_B" then
        self:AddTagToData(entry.Uuid, "Destruction")
    end

    if template.StoryItem then
        self:AddTagToData(entry.Uuid, "Story Item")
    end

    if template.Equipment and template.Equipment.Visuals then
        for raceUuid, _ in pairs(template.Equipment.Visuals) do
            self:AddEquipmentToRace(uuid, raceUuid)
        end
    end

    return entry
end

local function categorize_equipment(manager, statsObj, templateName, uuid)
    if EQUIPMENTS_HAS_ARMORTYPE[statsObj.Slot] and statsObj.ArmorType ~= "None" then
        --manager:AddTagToData(uuid, statsObj.ArmorType)
    end
    local profGroup = statsObj["Proficiency Group"]
    if profGroup and next(profGroup) then
        for _, prof in pairs(profGroup) do
            if prof ~= "MartialWeapons" and prof ~= "SimpleWeapons" then
                manager:AddTagToData(uuid, prof)
            end
        end
        if EQUIPMENTS_HAS_ARMORTYPE[statsObj.Slot] then
            manager:AddTagToData(uuid, statsObj.Slot)
        end
    else
        manager:AddTagToData(uuid, statsObj.Slot)
    end
end

local function categorize_consumable(manager, statsObj, uuid)
    local useType = statsObj.ItemUseType
    if useType == "Consumable" then
        manager:AddTagToData(uuid, "Drink")
    elseif useType == "None" then
        manager:AddTagToData(uuid, "Food")
    else
        manager:AddTagToData(uuid, useType)
    end
end

local magical_lookup = {
    MagicScroll = "Scroll",
    Arrow = "Arrow",
    Throwable = "Grenade",
    Poison = "Poison",
}

local function categorize_magical(manager, statsObj, templateName, uuid)
    local objCat = statsObj.ObjectCategory
    for prefix, tag in pairs(magical_lookup) do
        if objCat:find(prefix, 1, true) == 1 then
            manager:AddTagToData(uuid, tag)
            return
        end
    end
    if objCat == "Poison" or templateName:find("CONS_Poison", 1, true) == 1 or templateName:find("GRN_Poison", 1, true) == 1 then
        manager:AddTagToData(uuid, "Poison")
    elseif objCat == "" then
        manager:AddTagToData(uuid, "Magical")
    else
        manager:AddTagToData(uuid, objCat)
    end
end

local function categorize_alchemy(manager, statsObj, templateName, uuid)
    if statsObj.Name:find("ALCH", 1, true) == 1 or templateName:find("CONS_Herb", 1, true) == 1 then
        manager:AddTagToData(uuid, "Alchemy")
        return true
    end
    return false
end

-- switch switch and switch
function ItemManager:CategorizeItem(entry, statsObj, templateName)
    entry.ModId = statsObj.ModId
    local modInfo = self.modCache[entry.ModId] or Ext.Mod.GetMod(entry.ModId)
    if modInfo then
        entry.Mod = modInfo.Info.Name or ""
        entry.ModAuthor = modInfo.Info.Author or "Unknown"
        if VANILLA_MODULES[entry.Mod] then
            entry.ModAuthor = "Larian"
        end
    end

    entry.StatsName = statsObj.Name
    if entry.StatsName == "MinorIllusion" then return end -- why is this even an item ???
    if statsObj.Rarity and statsObj.Rarity ~= "" then
        entry.Rarity = statsObj.Rarity
    end

    if statsObj.InventoryTab and statsObj.InventoryTab ~= "" then
        local tab = statsObj.InventoryTab
        if tab == "Equipment" then
            categorize_equipment(self, statsObj, templateName, entry.Uuid)
        elseif tab == "Consumable" then
            categorize_consumable(self, statsObj, entry.Uuid)
        elseif tab == "Magical" then
            categorize_magical(self, statsObj, templateName, entry.Uuid)
        elseif categorize_alchemy(self, statsObj, templateName, entry.Uuid) then
            -- categorized as alchemy inside helper
        else
            self:AddTagToData(entry.Uuid, tab)
        end
    end
    self.modCache[entry.ModId] = modInfo
end

--- @class RB_Weapon:RB_Item
--- @field DefaultBoost string
--- @field Boosts string
--- @field Damage string
--- @field Range integer
--- @field DamageType string
--- @field DamageRange integer
--- @field PassivesOnEquip string
--- @field PassivesMainHand string
--- @field PassivesOffHand string
--- @field BoostsOnEquipMainHand string
--- @field BoostsOnEquipOffHand string
--- @field BoostsOnEquip string

local weaponLookupInStatsObj = {
    DefaultBoosts = "DefaultBoosts",
    Boosts = "Boosts",
    Damage = "Damage",
    WeaponRange = "Range",
    DamageType = "Damage Type",
    DamageRange = "Damage Range",
    PassivesOnEquip = "PassivesOnEquip",
    PassivesMainHand = "PassivesMainHand",
    PassivesOffHand = "PassivesOffHand",
    BoostsOnEquipMainHand = "BoostsOnEquipMainHand",
    BoostsOnEquipOffHand = "BoostsOnEquipOffHand",
}

--- @param statsObj Weapon
function ItemManager:PopulateWeapon(statsObj, statsId)
    --- @diagnostic disable-next-line
    local baseEntry = self:PopulateItem(Ext.Template.GetTemplate(statsObj.RootTemplate), statsObj)

    if not baseEntry then
        --Warning("Failed to populate weapon for stats object: " .. statsObj.RootTemplate)
        return nil
    end

    setmetatable(baseEntry, { __index = function(t, k)
        local statsObj = Ext.Stats.Get(statsId) --[[@as Weapon]]
        local lookupKey = weaponLookupInStatsObj[k]
        if not statsObj or not lookupKey then return nil end
        return statsObj and statsObj[lookupKey] or nil
    end})

    --[[
    baseEntry.DefaultBoosts = statsObj.DefaultBoosts
    baseEntry.Boosts = statsObj.Boosts
    baseEntry.Damage = statsObj.Damage
    baseEntry.Range = statsObj.WeaponRange
    baseEntry.DamageType = statsObj["Damage Type"] or "Physical"
    baseEntry.DamageRange = statsObj["Damage Range"] or 0
    baseEntry.PassivesOnEquip = statsObj.PassivesOnEquip or ""
    baseEntry.PassivesMainHand = statsObj.PassivesMainHand or ""
    baseEntry.PassivesOffHand = statsObj.PassivesOffHand or ""
    baseEntry.BoostsOnEquipMainHand = statsObj.BoostsOnEquipMainHand or ""
    baseEntry.BoostsOnEquipOffHand = statsObj.BoostsOnEquipOffHand or ""
    ]]

    return baseEntry
end

--- @class RB_Armor : RB_Item
--- @field ArmorClass integer
--- @field DefaultBoosts string
--- @field Boosts string
--- @field PassivesOnEquip string

local armorLookupInStatsObj = {
    ArmorClass = "ArmorClass",
    DefaultBoosts = "DefaultBoosts",
    Boosts = "Boosts",
    PassivesOnEquip = "PassivesOnEquip",
}

--- @param statsObj Armor
--- @return RB_Armor?
function ItemManager:PopulateArmor(statsObj, statsId)
    --- @diagnostic disable-next-line
    local baseEntry = self:PopulateItem(Ext.Template.GetTemplate(statsObj.RootTemplate), statsObj)

    if not baseEntry then
        --Warning("Failed to populate armor for stats object: " .. statsObj.RootTemplate)
        return nil
    end

    setmetatable(baseEntry, { __index = function(t, k)
        local sId = baseEntry.StatsName
        local sO = Ext.Stats.Get(sId) --[[@as Armor]]
        local lookupKey = armorLookupInStatsObj[k]
        if not sO or not lookupKey then return nil end
        return sO and sO[lookupKey] or nil
    end})

    --[[
    baseEntry.ArmorClass = statsObj.ArmorClass or 0
    baseEntry.DefaultBoosts = statsObj.DefaultBoosts
    baseEntry.Boosts = statsObj.Boosts
    baseEntry.PassivesOnEquip = statsObj.PassivesOnEquip or ""
    ]]

    if statsObj.Slot == "MusicalInstrument" and statsObj.InstrumentType ~= "None" then
        --- @diagnostic disable-next-line
        self:AddTagToData(baseEntry.Uuid, statsObj.InstrumentType)
    end

    --- @type RB_Armor
    return baseEntry
end
