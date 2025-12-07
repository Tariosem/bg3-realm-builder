--- @class VisualResourceManager : ManagerBase
--- @field SetupVisualBrowser fun(self):RootTemplateBrowser
VisualResourceManager = _Class("VisualResourceManager", ManagerBase)

--- @class RB_Visual
--- @field SourceFile string
--- @field Uuid GUIDSTRING
--- @field TemplateId GUIDSTRING -- for forward compatibility
--- @field IsCCAV boolean

--- @param resId GUIDSTRING
function VisualResourceManager:AddResource(resId)
    local res = Ext.Resource.Get(resId, "Visual") --[[@as ResourceVisualResource]]
    local fileName = GetLastPath(res.SourceFile)
    self.Data[res.Guid] = {
        DisplayName = fileName,
        SourceFile = fileName,
        Uuid = resId,
        --TemplateId = resId,
    }
end

function VisualResourceManager:PopulateAllVisualResources()
    local visualResources = Ext.Resource.GetAll("Visual")
    local now = Ext.Timer.MonotonicTime()
    RBPrintPurple("[Realm Builder] Populating Visual Resources...")
    for _, res in pairs(visualResources) do
        self:AddResource(res)
    end
    
    local elapsed = Ext.Timer.MonotonicTime() - now
    RBPrintPurple("[Realm Builder] Populated " .. #visualResources .. " visual resources in " .. string.format("%.2f", elapsed) .. " ms.")

    --- currently merge in CCAVs as well
    RBPrintPurple("[Realm Builder] Populating Character Creation Appearance Visuals...")
    now = Ext.Timer.MonotonicTime()
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

    for _,ccavId in pairs(ccavIds) do
        local ccav = Ext.StaticData.Get(ccavId, "CharacterCreationAppearanceVisual") --[[@as ResourceCharacterCreationAppearanceVisual]]
        local vr = self.Data[ccav.VisualResource]
        self.Data[ccavId] = {
            DisplayName = ccav.DisplayName:Get(),
            SourceFile = vr and vr.SourceFile or "Unknown",
            Uuid = ccavId,
            TemplateId = vr and vr.Uuid or nil,
            IsCCAV = true,
        }

        self:AddTagToData(ccavId, "Character Creation Appearance Visuals")
        self:AddTagToData(ccavId, bodyTypeToBodyShapeToTag[ccav.BodyType][ccav.BodyShape][1])

        self:AddTagToData(ccavId, ccav.SlotName)

        ::continue::
    end

    self.tagTree:FromTable({
        ["Body Type"] = {
            ["Body Type - 1"] = 0,
            ["Body Type - 2"] = 0,
            ["Body Type - 3"] = 0,
            ["Body Type - 4"] = 0,
        },
    })

    RBPrintPurple("[Realm Builder] Populated " .. #ccavIds .. " Character Creation Appearance Visuals in" .. string.format(" %.2f", Ext.Timer.MonotonicTime() - now) .. " ms.")
    self.populated = true
end

function VisualResourceManager:SetupVisualBrowser()
    local visualBrowser = RootTemplateBrowser.new(self, "Visual - Browser")
    local function addVisual(ccavId, target)
        NetChannel.VisualOverride:RequestToServer({
            Function = "AddCustomVisualOverride",
            Args = {
                target,
                ccavId
            }
        }, function (response)
            
        end)
    end
    local function removeVisual(ccavId, target)
        NetChannel.VisualOverride:RequestToServer({
            Function = "RemoveCustomVisualOvirride",
            Args = {
                target,
                ccavId
            }
        }, function (response)
            
        end)
    end

    visualBrowser.AddOtherContextItems = function(bro, menu, item)
        local res = item --[[@as RB_Visual]]
        if not res.IsCCAV then return end
        menu:AddItem("Add Custom Visual Override", function()
            local target = bro:GetSelected()
            addVisual(res.Uuid, target)
            HistoryManager:PushCommand({
                Name = "Add Custom Visual Override",
                Undo = function ()
                    removeVisual(res.Uuid, target)
                end,
                Redo = function ()
                    addVisual(res.Uuid, target)
                end
            })
        end)

        menu:AddItem("Remove Custom Visual Override", function()
            local target = bro:GetSelected()
            NetChannel.VisualOverride:RequestToServer({
                Function = "RemoveCustomVisualOvirride",
                Args = {
                    target,
                    res.Uuid
                }
            }, function (response)
                
            end)
            HistoryManager:PushCommand({
                Name = "Remove Custom Visual Override",
                Undo = function ()
                    addVisual(res.Uuid, target)
                end,
                Redo = function ()
                    removeVisual(res.Uuid, target)
                end
            })
        end)
    end
    visualBrowser.OnSelectChange = function (bro, guid)
        self:CreateDynamicTags(guid)
        bro:AddTagsFilter()
    end
    visualBrowser.selectedFields = { ["SourceFile"] = true, ["DisplayName"] = true }
    visualBrowser.iconTooltipName = "DisplayName"
    visualBrowser.tooltipNameOptions = {"DisplayName", "SourceFile", "Uuid"}

    return visualBrowser
end

function VisualResourceManager:CreateDynamicTags(uuid)
    self:ClearTag(self.lastDynamicTag)
    local entity = Ext.Entity.Get(uuid) --[[@as EntityHandle]]

    if not entity.CharacterCreationAppearance then
        return false
    end

    local lastDynamicTag = GetName(uuid) .. "'s Visuals"
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

if Ext.Debug.IsDeveloperMode() then
    RegisterOnSessionLoaded(function ()
        populateVisualResource()
    end)
end

RegisterConsoleCommand("rb_enable_visual_manager", function ()
    if RB_VisualManager and RB_VisualManager.populated then
        RBPrintPurple("[Realm Builder] Visual Resource Manager is already enabled and populated.")
        return
    end
    populateVisualResource()

    if RBMenu and RBMenu.browsers and not RBMenu.browsers.visual then
        RBMenu.browsers.visual = RB_VisualManager:SetupVisualBrowser()
        RBMenu.browsers.visual:CreateCachedSort("DisplayName")
        Debug("Visual Browser initialized.")

        RBMenu.browserBtns["visual"].Visible = true
    end

end, "Enables and populates the Visual Resource Manager.")