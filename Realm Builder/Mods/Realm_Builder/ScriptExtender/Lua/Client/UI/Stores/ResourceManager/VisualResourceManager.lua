--- @class VisualResourceManager : ManagerBase
--- @field SetupVisualBrowser fun(self):RootTemplateBrowser
VisualResourceManager = _Class("VisualResourceManager", ManagerBase)

--- @class CCAVManager : ManagerBase
--- @field PopulateAll fun(self)
--- @field SetupCCAVBrowser fun(self):CCAVBrowser
--- @field new fun():CCAVManager
CCAVManager = _Class("CCAVManager", ManagerBase)


--- @class RB_CCAV
--- @field DisplayName string
--- @field Uuid GUIDSTRING

function CCAVManager:PopulateAll()
    --- currently merge in CCAVs as well
    RBPrintPurple("[Realm Builder] Populating Character Creation Appearance Visuals...")
    local now = Ext.Timer.MonotonicTime()
    
    local ccavIds = Ext.StaticData.GetAll("CharacterCreationAppearanceVisual")

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
    })

    local raceCache = {}
    local newSlot = {}
    for _,ccavId in pairs(ccavIds) do
        local ccav = Ext.StaticData.Get(ccavId, "CharacterCreationAppearanceVisual") --[[@as ResourceCharacterCreationAppearanceVisual]]
        local raceRes = Ext.StaticData.Get(ccav.RaceUUID, "Race") --[[@as ResourceRace]]

        self.Data[ccavId] = {
            DisplayName = ccav.DisplayName:Get(),
            Uuid = ccavId,
        }

        if raceRes then
            local displayName = raceCache[ccav.RaceUUID] or raceRes.DisplayName:Get()
            if not displayName or displayName == "" then

            else
                self:AddTagToData(ccavId, displayName)
                if not raceCache[ccav.RaceUUID] then
                    raceCache[ccav.RaceUUID] = displayName
                    self.tagTree:AddLeaf(displayName, 0, "Races")
                end
            end
        end
        self:AddTagToData(ccavId, ccav.SlotName)
        local bodyTypeTag = bodyTypeToBodyShapeToTag[ccav.BodyType] and bodyTypeToBodyShapeToTag[ccav.BodyType][ccav.BodyShape]
        if not bodyTypeTag then
            Warning("[Realm Builder] Unknown BodyType/BodyShape combination for CCAV " .. ccavId .. ": BodyType=" .. tostring(ccav.BodyType) .. ", BodyShape=" .. tostring(ccav.BodyShape))
            goto continue
        end
        self:AddTagToData(ccavId, bodyTypeTag[1])
        if not newSlot[ccav.SlotName] then
            newSlot[ccav.SlotName] = true
            self.tagTree:AddLeaf(ccav.SlotName, 0, "Slots")
        end
        ::continue::
    end



    self.populated = true
    RBPrintPurple("[Realm Builder] Populated " .. #ccavIds .. " Character Creation Appearance Visuals in" .. string.format(" %.2f", Ext.Timer.MonotonicTime() - now) .. " ms.")
end

--- @class RB_Visual
--- @field SourceFile string
--- @field Uuid GUIDSTRING
--- @field Path string

function VisualResourceManager:PopulateAllVisualResources()
    local visualResources = Ext.Resource.GetAll("Visual")
    local now = Ext.Timer.MonotonicTime()
    RBPrintPurple("[Realm Builder] Populating Visual Resources...")
    for _, resId in pairs(visualResources) do
        local res = Ext.Resource.Get(resId, "Visual") --[[@as ResourceVisualResource]]
        local fileName = RBStringUtils.GetLastPath(res.SourceFile)
        local path = LSXHelpers.GetPathAfterData(res.SourceFile)
        self.Data[res.Guid] = {
            SourceFile = fileName,
            Uuid = resId,
            Path = path,
        }
    end
    
    local elapsed = Ext.Timer.MonotonicTime() - now
    RBPrintPurple("[Realm Builder] Populated " .. #visualResources .. " visual resources in " .. string.format("%.2f", elapsed) .. " ms.")


    self.populated = true
end

function VisualResourceManager:SetupVisualBrowser()
    local visualBrowser = RootTemplateBrowser.new(self, "Visual - Browser")

    visualBrowser.selectedFields = { ["SourceFile"] = true }
    visualBrowser.iconTooltipName = "SourceFile"
    visualBrowser.tooltipNameOptions = { "SourceFile", "Uuid"}

    return visualBrowser
end

function CCAVManager:SetupCCAVBrowser()
    local ccavBrowser = CCAVBrowser.new(self, "Character Creation Appearance Visuals - Browser")
    return ccavBrowser
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

local function populateVisualResource()
    local bef = Ext.Utils.GetMemoryUsage()
    if not RB_VisualManager then
        RB_VisualManager = VisualResourceManager.new()
    end
    RB_VisualManager:PopulateAllVisualResources()
    RBPrintPurple("[Realm Builder] Visual Resource Manager memory usage: " .. (Ext.Utils.GetMemoryUsage() - bef)/1000/1000 .. " MB")
end

local function populateCCAVResource()
    local bef = Ext.Utils.GetMemoryUsage()
    if not RB_CCAVManager then
        RB_CCAVManager = CCAVManager.new()
    end
    RB_CCAVManager:PopulateAll()
    RBPrintPurple("[Realm Builder] CCAV Manager memory usage: " .. (Ext.Utils.GetMemoryUsage() - bef)/1000/1000 .. " MB")
end

if Ext.Debug.IsDeveloperMode() then
    EventsSubscriber.RegisterOnSessionLoaded(function ()
        populateVisualResource()
        populateCCAVResource()
    end)
end

RegisterConsoleCommand("rb_enable_visual_manager", function ()
    if RB_VisualManager and RB_VisualManager.populated then
        RBPrintPurple("[Realm Builder] Visual Resource Manager is already enabled and populated.")
        return
    end
    populateVisualResource()
    populateCCAVResource()

    if RBMenu and RBMenu.browsers and not RBMenu.browsers.visual then
        RBMenu.browsers.visual = RB_VisualManager:SetupVisualBrowser()
        RBMenu.browsers.visual:CreateCachedSort("SourceFile")
        Debug("Visual Browser initialized.")
        RBMenu.browsers.CCAV = RB_CCAVManager:SetupCCAVBrowser()
        RBMenu.browsers.CCAV:CreateCachedSort("DisplayName")
        Debug("CCAV Browser initialized.")
        
        RBMenu.browserBtns["visual"].Visible = true
        RBMenu.browserBtns["CCAV"].Visible = true
    end

end, "Enables and populates the Visual Resource Manager.")