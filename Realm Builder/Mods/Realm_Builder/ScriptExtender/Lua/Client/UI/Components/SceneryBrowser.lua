--- @class SceneryBrowser : IconBrowser
--- @field DataManager SceneryManager
--- @field new fun(dataManager:SceneryManager, title:string):SceneryBrowser
SceneryBrowser = _Class("SceneryBrowser", IconBrowser)

function SceneryBrowser:SubclassInit()
    local config = self:GetConfig()

    self.iconToName = true
    self.iconPR = config.IconPerRow or 1
    self.iconPC = config.IconPerColumn or 20
    self.iconWidth = config.IconWidth or 600

    self.iconButtonBgColor = config.ButtonBgColor or HexToRGBA("FF615238")
end

function SceneryBrowser:GetConfig()
    if not CONFIG.SceneryBrowser then
        CONFIG.SceneryBrowser = {}
    end

    return CONFIG.SceneryBrowser
end

function SceneryBrowser:SaveToConfig()
    self.lastPosition = self.panel.LastPosition
    self.lastSize = self.panel.LastSize
    CONFIG.SceneryBrowser.IconWidth = self.iconWidth
    CONFIG.SceneryBrowser.IconPerRow = self.iconPR
    CONFIG.SceneryBrowser.IconPerColumn = self.iconPC
    CONFIG.SceneryBrowser.CellsPadding = self.cellsPadding
    CONFIG.SceneryBrowser.autoSave = self.autoSave
    CONFIG.SceneryBrowser.ButtonBgColor = self.iconButtonBgColor
    CONFIG.SceneryBrowser.BackgroundColor = self.browserBackgroundColor
    CONFIG.SceneryBrowser.LastPosition = self.lastPosition
    CONFIG.SceneryBrowser.LastSize = self.lastSize
    SaveConfig("SceneryBrowser")
end

function SceneryBrowser:TooltipChangeLogic()
    if self.iconTooltipName == "DisplayName" then
        self.iconTooltipName = "TemplateName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Template Name")
    elseif self.iconTooltipName == "TemplateName" then
        self.iconTooltipName = "DisplayName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Display Name")
    end
end

--- @param entry RB_Scenery
--- @param cell ExtuiTableCell
--- @return ExtuiImageButton|ExtuiStyledRenderable?
function SceneryBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[SceneryBrowser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field.")
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
            popup = cell:AddPopup(GetLoca("Scenery Template Details"))
            popup.IDContext = entry.Uuid .. "Popup" .. Uuid_v4()
            local attrs = {
                Uuid = entry.Uuid,
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
            rPopup = cell:AddPopup(GetLoca("Preview Scenery"))
            rPopup.IDContext = entry.Uuid .. "RPopup" .. Uuid_v4()
            local actTab = StyleHelpers.AddContextMenu(rPopup, "Actions")
            actTab:AddItem(GetLoca("Spawn Scenery"), function()
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
    iconImage.DragDropType = "RB_SceneryTemplate"

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
