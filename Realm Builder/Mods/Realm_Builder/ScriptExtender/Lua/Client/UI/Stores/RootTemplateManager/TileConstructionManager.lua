--- @class RB_TileConstruction
--- @field Uuid string
--- @field TemplateId string

--- @class TileConstructionManager : ManagerBase
--- @field Data table<string, RB_TileConstruction>
TileConstructionManager = _Class("TileConstructionManager", ManagerBase)

function TileConstructionManager:PopulateConstruction(template)
    self.Data[template.Id] = {
        Uuid = template.Id,
        TemplateId = template.Name .. "_" .. template.Id,
        TemplateName = template.Name,
        VisualTemplate = template.VisualTemplate,
        DisplayName = template.Name,
        Icon = "Item_Unknown",
    }
end