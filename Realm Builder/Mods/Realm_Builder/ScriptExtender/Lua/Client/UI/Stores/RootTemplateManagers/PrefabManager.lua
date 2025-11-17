--- @class RB_Prefab
--- @field Uuid string
--- @field TemplateId string
--- @field TemplateName string

--- @class PrefabManager : ManagerBase
--- @field Data table<string, RB_Prefab> Mapping of prefab UUIDs to RB_Prefab objects
--- @field new fun():PrefabManager
PrefabManager = _Class("PrefabManager", ManagerBase)

function PrefabManager:PopulatePrefab(template)
    self.Data[template.Id] = {
        Uuid = template.Id,
        TemplateId = template.Name .. "_" .. template.Id,
        TemplateName = template.Name,
        Icon = "Item_Unknown",
    }
end