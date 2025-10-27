--- @class CharacterBrowser : IconBrowser
CharacterBrowser = _Class("CharacterBrowser", IconBrowser)

function CharacterBrowser:GetConfig()
    return CONFIG.CharacterBrowser or {}
end

function CharacterBrowser:SaveToConfig()
    self.lastPosition = self.panel.LastPosition
    self.lastSize = self.panel.LastSize
    CONFIG.CharacterBrowser.IconWidth = self.iconWidth
    CONFIG.CharacterBrowser.IconPerRow = self.iconPR
    CONFIG.CharacterBrowser.IconPerColumn = self.iconPC
    CONFIG.CharacterBrowser.CellsPadding = self.cellsPadding
    CONFIG.CharacterBrowser.autoSave = self.autoSave
    CONFIG.CharacterBrowser.ButtonBgColor = self.iconButtonBgColor
    CONFIG.CharacterBrowser.BackgroundColor = self.browserBackgroundColor
    CONFIG.CharacterBrowser.StickToRight = self.stickToRight
    CONFIG.CharacterBrowser.LastPosition = self.lastPosition
    CONFIG.CharacterBrowser.LastSize = self.lastSize
    SaveConfig("CharacterBrowser")
end

function CharacterBrowser:TooltipChangeLogic()
    if self.iconTooltipName == "DisplayName" then
        self.iconTooltipName = "TemplateName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Template Name")
    elseif self.iconTooltipName == "TemplateName" then
        self.iconTooltipName = "DisplayName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Display Name")
    end
end

--- @param entry RB_Character
--- @param cell ExtuiTableCell
--- @return ExtuiImageButton|ExtuiStyledRenderable?
function CharacterBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[CharacterBrowser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field.")
        return nil
    end

    local popup = cell:AddPopup("IconPopup")
    local rPopup = cell:AddPopup("SpawnPopup")

    local iconImage = nil
    if not self.iconToName then
        iconImage = cell:AddImageButton(entry.Uuid, entry.Icon)
        if iconImage.Image.Icon == "" then
           iconImage:Destroy()
           iconImage = cell:AddImageButton(entry.Uuid, "Item_Unknown")
        end

        if self.iconButtonBgColor then
            iconImage.Background = self.iconButtonBgColor
        end
        iconImage.Image.Size = {self.iconWidth, self.iconWidth}
    else
        local button = cell:AddSelectable(entry[self.iconTooltipName] .. "##" ..entry.Uuid)
        iconImage = button
    end

    iconImage.OnClick = function()
        local target = self.selectedGuid or CGetHostCharacter()
        local pos = {CGetPosition(target)}
        local rot = {CGetRotation(target)}

        Commands.SpawnCommand(entry.TemplateId, pos, rot)
    end

    iconImage.OnDragEnd = function()
        Timer:Ticks(15, function (timerID)
            local spawnPos, spawnRot = GetPickingHitPosAndRot()
            if not spawnPos or not spawnRot then return end
            Commands.SpawnCommand(entry.TemplateId, spawnPos, spawnRot)
        end)
    end

    iconImage:Tooltip():AddText(entry[self.iconTooltipName] or "Unknown")

    return iconImage
end
