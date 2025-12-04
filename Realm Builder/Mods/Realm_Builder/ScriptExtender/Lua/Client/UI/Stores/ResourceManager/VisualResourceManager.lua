--- @class VisualResourceManager : ManagerBase
VisualResourceManager = _Class("VisualResourceManager", ManagerBase)

--- @param resId GUIDSTRING
function VisualResourceManager:AddResource(resId)
    local res = Ext.Resource.Get(resId, "Visual") --[[@as ResourceVisualResource]]
    self.Data[res.Guid] = {
        SourceFile = GetLastPath(res.SourceFile),
        Uuid = resId,
        TemplateId = resId,
    }
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
        RBMenu.browsers.visual = RootTemplateBrowser.new(RB_VisualManager, "Visual - Browser")
        RBMenu.browsers.visual.iconTooltipName = "SourceFile"
        RBMenu.browsers.visual.TooltipChangeLogic = function()
        
        end
        RBMenu.browsers.visual:CreateCachedSort("SourceFile")
        Debug("Visual Browser initialized.")

        RBMenu.browserBtns["visual"].Visible = true
    end

end, "Enables and populates the Visual Resource Manager.")