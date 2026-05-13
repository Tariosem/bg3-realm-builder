--- @class DyeSave
--- @field EntityDyes table<GUIDSTRING, DyePreset>

local DyeManager = {
    --- @type table<GUIDSTRING, DyePreset> 
    -- maps entity id to dye preset
    EntityDyes = {
    },

    --- @type table<GUIDSTRING, GUIDSTRING>
    -- maps material preset guid to appiled entitiy
    MatPresetToEnt = {
    
    },

    --- @type table<GUIDSTRING, any> 
    -- all material presets that can be used for dyeing, 
    AllMatPresets = Ext.Require("Shared/MaterialPresets.lua") or {},
}

local this = DyeManager

--- @return DyeSave
local function getModVar()
    local modVar = Ext.Vars.GetModVariables(ModuleUUID)
    if not modVar.DyeManager then
        modVar.DyeManager = {
            EntityDyes = {},
        }
    end
    return modVar.DyeManager
end

local function setModVar(modVar)
    local allModVars = Ext.Vars.GetModVariables(ModuleUUID)
    allModVars.DyeManager = modVar
    Ext.Vars.DirtyModVariables(ModuleUUID)
end

function DyeManager.SaveModVar()
    local modVar = getModVar()
    modVar.EntityDyes = this.EntityDyes
    setModVar(modVar)
end

function DyeManager.LoadModVar()
    local modVar = getModVar()
    this.EntityDyes = modVar.EntityDyes or {}

    for item, dyePreset in pairs(this.EntityDyes) do
        local itemEnt = Ext.Entity.Get(item)
        if itemEnt and itemEnt.ItemDye then
            this.ApplyDye(item, dyePreset)
        end
    end
end

function DyeManager.RemoveItemDye(guid)
    this.FreeItemDye(guid)
    this.EntityDyes[guid] = nil

    local itemEnt = Ext.Entity.Get(guid)
    if itemEnt and itemEnt.ItemDye then
        itemEnt.ItemDye.Color = GUID_NULL
        itemEnt:Replicate("ItemDye")
    end

    this.SaveModVar()
end

--- free the material preset used by the item
--- @param guid GUIDSTRING
function DyeManager.FreeItemDye(guid)
    local itemEnt = Ext.Entity.Get(guid)
    if not itemEnt or not itemEnt.ItemDye then return end

    local matPreset = itemEnt.ItemDye.Color
    if matPreset and this.MatPresetToEnt[matPreset] then
        this.MatPresetToEnt[matPreset] = nil
        _P("Freed material preset "..matPreset.." from item "..guid)
    end
end

--- check if a material preset is currently in use by any item
--- @param matPreset GUIDSTRING
--- @return boolean
function DyeManager.IsMatPresetInUse(matPreset)
    local using = this.MatPresetToEnt[matPreset]

    if using then
        local itemEnt = Ext.Entity.Get(using) or {}
        if not itemEnt.Wielding then -- item no longer equipped
            this.FreeItemDye(using)
        end
    end

    return this.MatPresetToEnt[matPreset] ~= nil
end

--- @return string?
function DyeManager.FindAvailableMatPreset()
    for guid, _ in pairs(this.AllMatPresets) do
        if not this.IsMatPresetInUse(guid) then
            return guid
        end
    end

    Warning("No available material presets for dyeing!")
    return nil
end

--- @param item GUIDSTRING
--- @param dyePreset DyePreset
--- @param retryCnt integer?
function DyeManager.ApplyDye(item, dyePreset, retryCnt)
    this.FreeItemDye(item)
    retryCnt = retryCnt or 0
    local maxRetries = 5
    if retryCnt > maxRetries then
        Error("Failed to apply dye after "..maxRetries.." retries. Item: "..item)
        return
    end
    local itemEnt = Ext.Entity.Get(item)
    if not itemEnt then 
        Error("Item not found: "..item)
        return
    end

    if not itemEnt.ItemDye then
        itemEnt:CreateComponent("ItemDye")
    end

    if not itemEnt.ItemDye then
        --Error("Failed to create ItemDye component on item ".. item .. "Retrying... ("..(retryCnt + 1).."/"..maxRetries..")")
        Ext.OnNextTick(function()
            this.ApplyDye(item, dyePreset, retryCnt + 1)
        end)
        return
    end

    local matPreset = this.FindAvailableMatPreset()
    if not matPreset then return end

    local matPresetRes = Ext.Resource.Get(matPreset, "MaterialPreset") --[[@as ResourceMaterialPresetResource]]

    for _, value in ipairs(matPresetRes.Presets.Vector3Parameters) do
        if dyePreset[value.Parameter] then
            value.Value = dyePreset[value.Parameter]
        end
    end


    itemEnt.ItemDye.Color = matPreset
    itemEnt:Replicate("ItemDye")

    local itemName = itemEnt.DisplayName and itemEnt.DisplayName.Name:Get() or item
    Debug(
        "Applied dye to item ["..itemName.."] ("..item..").\n"..
        "Retry count: "..retryCnt
    )

    this.EntityDyes[item] = dyePreset
    this.MatPresetToEnt[matPreset] = item

    this.SaveModVar()
end

--- @param data {Guid: GUIDSTRING, DyePreset: DyePreset,}
--- @param userID string
function DyeManager.HandleDyeRequest(data, userID)
    if not data.Guid then
        Error("Invalid dye request data from user "..userID)
        return
    end

    if data.DyePreset then
        this.ApplyDye(data.Guid, data.DyePreset)
    else
        this.RemoveItemDye(data.Guid)
    end 
end

NetChannel.Dye:SetRequestHandler(DyeManager.HandleDyeRequest)
NetChannel.Dye:SetHandler(DyeManager.HandleDyeRequest)

Ext.Osiris.RegisterListener("Equipped", 2, "after", function(item, character)
    item = RBUtils.TakeTailTemplate(item)
    character = RBUtils.TakeTailTemplate(character)
    NetChannel.OsirisSubscription:Broadcast({Event = "Equipped", Args = {item, character}})
    local itemEnt = Ext.Entity.Get(item)
    if not itemEnt then return end

    local itemDyeComp = itemEnt.ItemDye
    if not itemDyeComp then return end

    local matPreset = itemDyeComp.Color
    if matPreset == "" then return end

    if DyeManager.MatPresetToEnt[matPreset] then
        local dyePreset = DyeManager.EntityDyes[item]
        if dyePreset then
            DyeManager.ApplyDye(item, dyePreset)
        end
    end
end)

Ext.Osiris.RegisterListener("Unequipped", 2, "after", function(item, character)
    item = RBUtils.TakeTailTemplate(item)
    character = RBUtils.TakeTailTemplate(character)
    NetChannel.OsirisSubscription:Broadcast({Event = "Unequipped", Args = {item, character}})
    DyeManager.FreeItemDye(item)
end)

Ext.Entity.Subscribe("ArmorSetState", function(entity)
    local uuid = entity.Uuid and entity.Uuid.EntityUuid
    if not uuid then return end

    Ext.OnNextTick(function()
        NetChannel.ComponentSubscription:Broadcast({Guid = uuid, Component = "ArmorSetState"})
    end)
end)

Ext.Events.SessionLoaded:Subscribe(function()
    DyeManager.LoadModVar()
end)

RegisterConsoleCommand("rb_dump_dye_data", function()

    local duplicateCheck = {}

    for guid, _ in pairs(DyeManager.AllMatPresets) do
        if not DyeManager.IsMatPresetInUse(guid) then return end
        local using = DyeManager.MatPresetToEnt[guid] or GUID_NULL
        print("MatPreset "..guid.." is in use by item: "..using)
        if duplicateCheck[using] then
            local ent = Ext.Entity.Get(using)
            local displayName = ent and ent.DisplayName and ent.DisplayName:Get() or using
            print("WARNING: Item "..displayName.." ("..using..") is using multiple presets.")
            print("Presets in use by this item:")
            for _, preset in pairs(duplicateCheck[using]) do
                print("- "..preset)
            end
        end

        duplicateCheck[using] = duplicateCheck[using] or {}
        table.insert(duplicateCheck[using], guid)
    end
end)