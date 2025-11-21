--- @class RootTemplateBrowser : IconBrowser
--- @field DataManager ManagerBase
--- @field new fun(dataManager:ManagerBase, title:string):RootTemplateBrowser
RootTemplateBrowser = _Class("RootTemplateBrowser", IconBrowser)

function RootTemplateBrowser:SubclassInit()
    self.iconToName = true
    self.iconTooltipName = "TemplateName"
    self.iconPR = 2
    self.iconPC = 20
    self.iconWidth = 600
    self.browserWidth = self.iconPR * self.iconWidth + 20
    self.browserHeight = self.iconPC * (36 * SCALE_FACTOR + self.cellsPadding[2]) + 240 * SCALE_FACTOR
    self.lastSize = { self.browserWidth * 1.5, self.browserHeight * 1.5 }

    self.iconButtonBgColor = HexToRGBA("FF615238")
end


--- @param entry RB_Scenery
--- @param cell ExtuiTableCell
--- @return ExtuiImageButton|ExtuiStyledRenderable?
function RootTemplateBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[Browser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field. Browser: " .. tostring(self.displayName))
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
            popup = cell:AddPopup(GetLoca("Root Template Details"))
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
            rPopup = cell:AddPopup("Preview Template")
            rPopup.IDContext = entry.Uuid .. "RPopup" .. Uuid_v4()
            self:RenderCustomizationTab(rPopup, entry)
            local actTab = StyleHelpers.AddContextMenu(rPopup, "Actions")
            actTab:AddItem(GetLoca("Spawn"), function()
                local selected = self.selectedGuid or CGetHostCharacter()
                if not selected then return end
                local spawnPos = {CGetPosition(selected)}
                local spawnRot = {CGetRotation(selected)}
                if not spawnPos or not spawnRot then return end
                Commands.SpawnCommand(entry.TemplateId, { Position=spawnPos, Rotation=spawnRot })
            end)
        end
        rPopup:Open()
    end

    iconImage.CanDrag = true
    iconImage.DragDropType = self.displayName

    iconImage.OnDragStart = function(sel)
        sel.DragPreview:AddText(entry[self.iconTooltipName] or "Unknown")
    end

    iconImage.OnDragEnd = function()
        Timer:Ticks(20, function (timerID)
            local spawnPos, spawnRot = GetPickingHitPosAndRot()
            if not spawnPos or not spawnRot then return end
            Commands.SpawnCommand(entry.TemplateId, { Position=spawnPos, Rotation=spawnRot })
        end)
    end

    iconImage:Tooltip():AddText(entry[self.iconTooltipName] or "Unknown")

    return iconImage
end
