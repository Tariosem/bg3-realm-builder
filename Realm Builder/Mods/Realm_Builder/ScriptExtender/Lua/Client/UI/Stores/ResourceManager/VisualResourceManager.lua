--- @class VisualResourceManager : ManagerBase
--- @field SetupVisualBrowser fun(self):RootTemplateBrowser
VisualResourceManager = _Class("VisualResourceManager", ManagerBase)

--- @class RB_Visual
--- @field SourceFile string
--- @field Uuid GUIDSTRING
--- @field TemplateId GUIDSTRING -- for forward compatibility

--- @param resId GUIDSTRING
function VisualResourceManager:AddResource(resId)
    local res = Ext.Resource.Get(resId, "Visual") --[[@as ResourceVisualResource]]
    self.Data[res.Guid] = {
        SourceFile = GetLastPath(res.SourceFile),
        Uuid = resId,
        TemplateId = resId,
    }

    if res.Slot and res.Slot ~= "" then 
        self:AddTagToData(resId, res.Slot)
    end
    if res.SkeletonSlot and res.SkeletonSlot ~= "" then 
        self:AddTagToData(resId, res.SkeletonSlot)
    end
end

function VisualResourceManager:PopulateAllVisualResources()
    local visualResources = Ext.Resource.GetAll("Visual")
    local now = Ext.Timer.MonotonicTime()
    RBPrintPurple("[Realm Builder] Populating Visual Resources...")
    for _, res in pairs(visualResources) do
        self:AddResource(res)
    end
    self.populated = true
    local elapsed = Ext.Timer.MonotonicTime() - now
    RBPrintPurple("[Realm Builder] Populated " .. #visualResources .. " visual resources in " .. string.format("%.2f", elapsed) .. " ms.")
end

function VisualResourceManager:SetupVisualBrowser()
    local visualBrowser = RootTemplateBrowser.new(self, "Visual - Browser")
    visualBrowser.AddOtherContextItems = function(bro, menu, item)
        local res = item --[[@as RB_Visual]]
        menu:AddItem("Add Custom Visual Override", function()
            NetChannel.CallOsiris:RequestToServer({
                Function = "AddCustomVisualOverride",
                Args = {
                    bro:GetSelected(),
                    res.Uuid,
                }
            }, function (response)
                
            end)
        end)

        menu:AddItem("Remove Custom Visual Override", function()
            NetChannel.CallOsiris:RequestToServer({
                Function = "RemoveCustomVisualOvirride",
                Args = {
                    bro:GetSelected(),
                    res.Uuid,
                }
            }, function (response)
                
            end)
        end)
    end
    return visualBrowser
end

if Ext.Debug.IsDeveloperMode() then
    RegisterOnSessionLoaded(function ()
        if not RB_VisualManager then
            RB_VisualManager = VisualResourceManager.new()
        end
        RB_VisualManager:PopulateAllVisualResources()
    end)
end

RegisterConsoleCommand("rb_enable_visual_manager", function ()
    if RB_VisualManager and RB_VisualManager.populated then
        RBPrintPurple("[Realm Builder] Visual Resource Manager is already enabled and populated.")
        return
    end
    if not RB_VisualManager then
        RB_VisualManager = VisualResourceManager.new()
    end
    RB_VisualManager:PopulateAllVisualResources()

    if RBMenu and RBMenu.browsers and not RBMenu.browsers.visual then
        RBMenu.browsers.visual = RB_VisualManager:SetupVisualBrowser()
        RBMenu.browsers.visual.iconTooltipName = "SourceFile"
        RBMenu.browsers.visual.TooltipChangeLogic = function()
        
        end
        RBMenu.browsers.visual:CreateCachedSort("SourceFile")
        Debug("Visual Browser initialized.")

        RBMenu.browserBtns["visual"].Visible = true
    end

end, "Enables and populates the Visual Resource Manager.")