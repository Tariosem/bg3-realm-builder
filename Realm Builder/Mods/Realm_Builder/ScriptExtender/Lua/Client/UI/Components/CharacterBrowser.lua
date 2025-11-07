--- @class CharacterBrowser : IconBrowser
--- @field DataManager RB_CharacterManager
--- @field new fun(dataManager:RB_CharacterManager, title:string):CharacterBrowser
CharacterBrowser = _Class("CharacterBrowser", IconBrowser)

function CharacterBrowser:SubclassInit()
    local config = self:GetConfig()

    self.iconToName = true
    self.iconPR = config.IconPerRow or 2
    self.iconPC = config.IconPerColumn or 25
    self.iconWidth = config.IconWidth or 600

    self.iconButtonBgColor = config.ButtonBgColor or HexToRGBA("FF615238")
end

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

    local popup = nil
    local rPopup = nil

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
        local disName = entry[self.iconTooltipName]
        if not disName or disName == "" then
            disName = "Unknown"
        end
        local button = cell:AddButton(disName .. "##" ..entry.Uuid)
        button:SetColor("Button", self.iconButtonBgColor or HexToRGBA("FF615238"))
        iconImage = button
    end

    iconImage.OnClick = function()
        if not popup then
            popup = cell:AddPopup(GetLoca("Character Template Details"))
            popup.IDContext = entry.Uuid .. "Popup" .. Uuid_v4()
            local attrs = {
                Uuid = entry.Uuid,
                DisplayName = entry.DisplayName,
                TemplateName = entry.TemplateName,
                Icon = entry.Icon,
                TemplateId = entry.TemplateId,
            }
            StyleHelpers.AddReadOnlyAttrTable(popup, attrs)
        end
        popup:Open()
    end

    iconImage.OnRightClick = function()
        if not rPopup then
            rPopup = cell:AddPopup(GetLoca("Character Template Preview"))
            rPopup.IDContext = entry.Uuid .. "RPopup" .. Uuid_v4()
            local actTab = StyleHelpers.AddSelectionTable(rPopup, "Actions")
            actTab:AddSelectable(GetLoca("Spawn Character"), function()
                local selected = self.selectedGuid or CGetHostCharacter()
                if not selected then return end
                local spawnPos = {CGetPosition(selected)}
                local spawnRot = {CGetRotation(selected)}
                if not spawnPos or not spawnRot then return end
                Commands.SpawnCommand(entry.TemplateId, spawnPos, spawnRot)
            end)
        end
        rPopup:Open()
    end

    iconImage.CanDrag = true
    iconImage.DragDropType = "RB_CharacterTemplate"

    iconImage.OnDragStart = function(sel)
        sel.DragPreview:AddText(entry[self.iconTooltipName] or "Unknown")
    end

    iconImage.OnDragEnd = function()
        Timer:Ticks(20, function (timerID)
            local spawnPos, spawnRot = GetPickingHitPosAndRot()
            if not spawnPos or not spawnRot then return end
            Commands.SpawnCommand(entry.TemplateId, spawnPos, spawnRot)
        end)
    end

    iconImage:Tooltip():AddText(entry[self.iconTooltipName] or "Unknown")

    return iconImage
end
