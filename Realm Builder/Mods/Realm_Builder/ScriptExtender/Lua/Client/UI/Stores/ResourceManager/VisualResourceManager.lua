--- @class VisualResourceManager : ManagerBase<RB_Visual>
--- @field PopulateAllVisualResources fun(self):number, number -- returns count, time taken
--- @field new fun():VisualResourceManager
VisualResourceManager = _Class("VisualResourceManager", ManagerBase)

--- @class CCAVManager : ManagerBase<RB_CCAV>
--- @field PopulateAll fun(self):number, number -- returns count, time taken
--- @field new fun():CCAVManager
CCAVManager = _Class("CCAVManager", ManagerBase)


--- @class RB_CCAV
--- @field DisplayName string
--- @field Uuid GUIDSTRING

function CCAVManager:PopulateAll()
    --RBPrintPurple("[Realm Builder] Populating Character Creation Appearance Visuals...")
    local now = Ext.Timer.MonotonicTime()
    
    local ccavIds = Ext.StaticData.GetAll("CharacterCreationAppearanceVisual")
    local ccsvIds = Ext.StaticData.GetAll("CharacterCreationSharedVisual")
    local uuid_blacklist = RESOUCE_UUID_BLACKLIST or {}

    local bodyTypeToBodyShapeToTag = {
        [0] = {
            [0] = {
                "Body Type - 2"
            },
            [1] = {
                "Body Type - 4"
            }
        },
        [1] = {
            [0] = {
                "Body Type - 1"
            },
            [1] = {
                "Body Type - 3"
            }
        }
    }

    self.tagTree:FromTable({
        ["Body Type"] = {
            ["Body Type - 1"] = 0,
            ["Body Type - 2"] = 0,
            ["Body Type - 3"] = 0,
            ["Body Type - 4"] = 0,
        },
        ["Races"] = {},
        ["Slots"] = {},
        ["Bones"] = {},
        ["Accessory Sets"] = {},
    })

    local raceCache = {}
    local tagCache = {}
    local isModdedCache = {}
    local newSlot = {}
    for _,ccavId in pairs(ccavIds) do
        if uuid_blacklist[ccavId] then goto continue end
        local ccav = Ext.StaticData.Get(ccavId, "CharacterCreationAppearanceVisual") --[[@as ResourceCharacterCreationAppearanceVisual]]
        local vres = Ext.Resource.Get(ccav.VisualResource, "Visual") --[[@as ResourceVisualResource]]
        local vresName = vres and RBStringUtils.GetLastPath(vres.SourceFile) or "Unknown Visual Resource"
        local raceRes = Ext.StaticData.Get(ccav.RaceUUID, "Race") --[[@as ResourceRace]]

        self.Data[ccavId] = {
            DisplayName = ccav.DisplayName:Get() or "Unknown CCAV",
            VisualName = vresName,
            Uuid = ccavId,
        }

        if raceRes then
            local displayName = raceCache[ccav.RaceUUID] or raceRes.DisplayName:Get()
            if not displayName or displayName == "" then

            else
                self:AddTagToData(ccavId, displayName)
                if not raceCache[ccav.RaceUUID] then
                    raceCache[ccav.RaceUUID] = displayName
                    self.tagTree:Reparent(displayName, "Races")
                end
            end
        end
        self:AddTagToData(ccavId, ccav.SlotName)
        local bodyTypeTag = bodyTypeToBodyShapeToTag[ccav.BodyType] and bodyTypeToBodyShapeToTag[ccav.BodyType][ccav.BodyShape]
        if not bodyTypeTag then
            --Warning("[Realm Builder] Unknown BodyType/BodyShape combination for CCAV " .. ccavId .. ": BodyType=" .. tostring(ccav.BodyType) .. ", BodyShape=" .. tostring(ccav.BodyShape))
            goto continue
        end
        self:AddTagToData(ccavId, bodyTypeTag[1])
        if not newSlot[ccav.SlotName] then
            newSlot[ccav.SlotName] = true
            self.tagTree:Reparent(ccav.SlotName, "Slots")
        end
        for _, tag in pairs(ccav.Tags) do
            if tagCache[tag] and tagCache[tag] ~= "" then
                self:AddTagToData(ccavId, tagCache[tag])
            else
                local tagRes = Ext.StaticData.Get(tag, "Tag") --[[@as ResourceTag]]
                if tagRes and tagRes.DisplayName:Get() and tagRes.DisplayName:Get() ~= "" then
                    local tagName = tagRes.DisplayName:Get()
                    --- @diagnostic disable-next-line
                    self:AddTagToData(ccavId, tagName)
                    tagCache[tag] = tagName
                else
                    tagCache[tag] = ""
                end
            end
        end
        ::continue::
    end

    local seenBones = {}
    for _,ccsvId in pairs(ccsvIds) do
        if uuid_blacklist[ccsvId] then goto continue end
        local ccsv = Ext.StaticData.Get(ccsvId, "CharacterCreationSharedVisual") --[[@as ResourceCharacterCreationSharedVisual]]
        local vres = Ext.Resource.Get(ccsv.VisualResource, "Visual") --[[@as ResourceVisualResource]]
        local vresName = vres and RBStringUtils.GetLastPath(vres.SourceFile) or "Unknown Visual Resource"
        self.Data[ccsvId] = {
            DisplayName = ccsv.DisplayName:Get() or "Unknown CCSV",
            VisualName = vresName,
            Uuid = ccsvId,
        }
        self:AddTagToData(ccsvId, "Shared Visuals")
        self:AddTagToData(ccsvId, ccsv.SlotName)
        if ccsv.BoneName and ccsv.BoneName ~= "" then
            self:AddTagToData(ccsvId, ccsv.BoneName)
            if not seenBones[ccsv.BoneName] then
                seenBones[ccsv.BoneName] = true
                self.tagTree:Reparent(ccsv.BoneName, "Bones")
            end
        end
        for _, tag in pairs(ccsv.Tags) do
            if tagCache[tag] and tagCache[tag] ~= "" then
                self:AddTagToData(ccsvId, tagCache[tag])
            else
                local tagRes = Ext.StaticData.Get(tag, "Tag") --[[@as ResourceTag]]
                if tagRes and tagRes.DisplayName:Get() and tagRes.DisplayName:Get() ~= "" then
                    --- @diagnostic disable-next-line
                    self:AddTagToData(ccsvId, tagRes.DisplayName:Get())
                    tagCache[tag] = tagRes.DisplayName:Get()
                else
                    tagCache[tag] = ""
                end
            end
        end
        ::continue::
    end

    local allSets = Ext.StaticData.GetAll("CharacterCreationAccessorySet")
    for _, setId in pairs(allSets) do
        local set = Ext.StaticData.Get(setId, "CharacterCreationAccessorySet") --[[@as ResourceCharacterCreationAccessorySet]]
        local setName = set.DisplayName:Get() or "Unknown Accessory Set"
        for _, visual in pairs(set.VisualUUID) do
            if not self.Data[visual] then goto continue end 
            self:AddTagToData(visual, setName)
            self.tagTree:Reparent(setName, "Accessory Sets")
            ::continue::
        end
    end

    self.populated = true
    raceCache = nil
    isModdedCache = nil
    newSlot = nil
    --RBPrintPurple("[Realm Builder] Populated " .. #ccavIds + #ccsvIds .. " Character Creation Appearance Visuals in" .. string.format(" %.2f", Ext.Timer.MonotonicTime() - now) .. " ms.")

    tagCache = nil
    raceCache = nil
    return #ccavIds + #ccsvIds, Ext.Timer.MonotonicTime() - now
end

--- @class RB_Visual
--- @field SourceFile string
--- @field Uuid GUIDSTRING
--- @field Path string

function VisualResourceManager:PopulateAllVisualResources()
    local visualResources = Ext.Resource.GetAll("Visual")
    local now = Ext.Timer.MonotonicTime()
    --RBPrintPurple("[Realm Builder] Populating Visual Resources...")
    local uuid_blacklist = RESOUCE_UUID_BLACKLIST or {}
    for _, resId in pairs(visualResources) do
        if uuid_blacklist[resId] then goto continue end

        local res = Ext.Resource.Get(resId, "Visual") --[[@as ResourceVisualResource]]
        local fileName = RBStringUtils.GetLastPath(res.SourceFile)
        local path = RBStringUtils.GetPathAfterData(res.SourceFile)
        self.Data[res.Guid] = {
            SourceFile = fileName,
            Uuid = resId,
            Path = path,
        }
    
        ::continue::
    end
    
    local elapsed = Ext.Timer.MonotonicTime() - now
    --RBPrintPurple("[Realm Builder] Populated " .. #visualResources .. " visual resources in " .. string.format("%.2f", elapsed) .. " ms.")


    self.populated = true
    return #visualResources, elapsed
end


function CCAVManager:CreateDynamicTags(uuid)
    self:ClearTag(self.lastDynamicTag)
    local entity = Ext.Entity.Get(uuid) --[[@as EntityHandle]]

    if not entity.CharacterCreationAppearance then
        return false
    end

    local lastDynamicTag = RBGetName(uuid) .. "'s Visuals"
    self.lastDynamicTag = lastDynamicTag

    local uniqueVisuals = {}
    for i,visualId in pairs(entity.CharacterCreationAppearance.Visuals) do
        if uniqueVisuals[visualId] then
            goto continue
        end
        self:AddTagToDataNonCustomization(visualId, lastDynamicTag)
        uniqueVisuals[visualId] = true
        ::continue::
    end
    return true
end

--[[]]