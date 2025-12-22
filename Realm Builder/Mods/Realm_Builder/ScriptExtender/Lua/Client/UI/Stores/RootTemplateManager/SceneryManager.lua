--- @class RB_Scenery
--- @field Uuid string
--- @field TemplateId string -- Name + "_" + Uuid
--- @field TemplateName string
--- @field DisplayName string
--- @field VisualTemplate string
--- @field Icon string

--- @class SceneryManager : ManagerBase
--- @field Data table<string, RB_Scenery> Mapping of scenery UUIDs to RB_Scenery objects
--- @field new fun():SceneryManager
SceneryManager = _Class("SceneryManager", ManagerBase)

--- @param template SceneryTemplate
function SceneryManager:PopulateScenery(template)
    self.Data[template.Id] = {
        Uuid = template.Id,
        TemplateId = template.Name .. "_" .. template.Id,
        TemplateName = template.Name,
        VisualTemplate = template.VisualTemplate,
        DisplayName = template.DisplayName:Get() or "",
    }

    if not self.Data[template.Id].DisplayName or self.Data[template.Id].DisplayName == "" then
        self.Data[template.Id].DisplayName = self.Data[template.Id].TemplateName
        if not self.Data[template.Id].DisplayName or self.Data[template.Id].DisplayName == "" then
            self.Data[template.Id].DisplayName = "Unknown"
        end
    end
end

