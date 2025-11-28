DecalManager = _Class("DecalManager", ManagerBase)

function DecalManager:PopulateDecal(template)
    self.Data[template.Id] = {
        Uuid = template.Id,
        MaterialId = template.MaterialUUID,
        TemplateId = template.Name .. "_" .. template.Id,
        TemplateName = template.Name,
        Icon = "Item_Unknown",
    }
end