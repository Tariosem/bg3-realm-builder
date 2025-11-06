--- @class SceneryBrowser : IconBrowser
--- @field DataManager SceneryManager
--- @field new fun(dataManager:SceneryManager, title:string):SceneryBrowser
SceneryBrowser = _Class("SceneryBrowser", IconBrowser)

function SceneryBrowser:SubclassInit()
    local config = self:GetConfig()

    self.iconToName = true
    self.iconPR = config.IconPerRow or 2
    self.iconPC = config.IconPerColumn or 25
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
    CONFIG.SceneryBrowser.StickToRight = self.stickToRight
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
        local disName = entry[self.iconTooltipName]
        if not disName or disName == "" then
            disName = "Unknown"
        end
        local button = cell:AddButton(disName .. "##" ..entry.Uuid)
        button:SetColor("Button", self.iconButtonBgColor or HexToRGBA("FF615238"))
        iconImage = button
    end

    local st = rPopup:AddTable("SpawnTable", 1)
    st.BordersInnerH = true
    local spwanRow = st:AddRow()

    spwanRow:AddCell():AddSelectable("Spawn##" .. entry.Uuid).OnClick = function(sel)
        sel.Selected = false
        local target = self.selectedGuid or CGetHostCharacter()
        local pos = {CGetPosition(target)}
        local rot = {CGetRotation(target)}

        Commands.SpawnCommand(entry.TemplateId, pos, rot, { IsScenery = true })
    end

    iconImage.OnClick = function()
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
            Commands.SpawnCommand(entry.TemplateId, spawnPos, spawnRot, { IsScenery = true })
        end)
    end

    iconImage:Tooltip():AddText(entry[self.iconTooltipName] or "Unknown")

    return iconImage
end
