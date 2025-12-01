--- @class VisualResourceManager : ManagerBase
VisualResourceManager = _Class("VisualResourceManager", ManagerBase)

function VisualResourceManager:__init()
    ManagerBase.__init(self)



    self:PopulateAllVisualResources()
end

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
    RBPrintPurple("VisualResourceManager: Populating visual resources... (Found " .. #visualResources .. " resources)")
    for _, res in pairs(visualResources) do
        self:AddResource(res)
    end
    local elapsed = Ext.Timer.MonotonicTime() - now
    RBPrintPurple("VisualResourceManager: Populated " .. #visualResources .. " visual resources in " .. string.format("%.2f", elapsed) .. " ms.")
end