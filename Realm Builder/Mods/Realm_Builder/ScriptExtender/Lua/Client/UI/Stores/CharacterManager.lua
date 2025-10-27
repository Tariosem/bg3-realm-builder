--- @class RB_CharacterManager : ManagerBase
--- @field Characters table<string, RB_Character> Mapping of character UUIDs to RB_Character objects
CharacterManager = _Class("CharacterManager", ManagerBase)

local raceCache = {}

--- @param template CharacterTemplate
function CharacterManager:PopulateCharacter(template)
    self.Data[template.Id] = {
        Uuid = template.Id,
        TemplateId = template.Name .. "_" .. template.Id,
        TemplateName = template.Name,
        DisplayName = template.DisplayName:Get(),
        Icon = template.Icon,
    }

    if not self.Data[template.Id].DisplayName then
        self.Data[template.Id].DisplayName = self.Data[template.Id].TemplateName
        if not self.Data[template.Id].DisplayName or self.Data[template.Id].DisplayName == "" then
            self.Data[template.Id].DisplayName = "Unknown"
        end
    end

    if template.Race then
        if raceCache[template.Race] == nil then
            local raceRes = Ext.StaticData.Get(template.Race, "Race") --[[@as ResourceRace]]
            local displayName = raceRes and raceRes.DisplayName:Get() or "Unknown"
            raceCache[template.Race] = displayName
        else
        end
        self:AddTagToData(template.Id, raceCache[template.Race])
    end
end
