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
    self.disableIcon = true

    self.iconButtonBgColor = ColorUtils.HexToRGBA("FF615238")
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
        button:SetColor("Button", self.iconButtonBgColor or ColorUtils.HexToRGBA("FF615238"))
        iconImage = button
    end

    iconImage.OnClick = function()
        if not popup then
            popup = cell:AddPopup("Root Template Details")
            popup.IDContext = entry.Uuid .. "Popup" .. RBUtils.Uuid_v4()
            local attrs = {
                Uuid = entry.Uuid,
                TemplateName = entry.TemplateName,
                Icon = entry.Icon,
                TemplateId = entry.TemplateId,
                SourceFile = entry.SourceFile,
                Path = entry.Path,
            }
            ImguiElements.AddReadOnlyAttrTable(popup, attrs)
        end
        popup:Open()
    end

    iconImage.OnRightClick = function()
        if not rPopup then
            rPopup = cell:AddPopup("Preview Template")
            rPopup.IDContext = entry.Uuid .. "RPopup" .. RBUtils.Uuid_v4()
            self:RenderCustomizationTab(rPopup, entry)
            local actTab = ImguiElements.AddContextMenu(rPopup, "Actions")
            actTab:AddItem(GetLoca("Spawn"), function()
                local selected = self.selectedGuid or RBGetHostCharacter()
                if not selected then return end
                local spawnPos = {RBGetPosition(selected)}
                local spawnRot = {RBGetRotation(selected)}
                if not spawnPos or not spawnRot then return end
                local spawnId = entry.TemplateId or entry.Uuid
                Commands.SpawnCommand(spawnId, { Position=spawnPos, Rotation=spawnRot })
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
        if self.templateType == "prefab" or self.templateType == "character" then
            Timer:Ticks(20, function (timerID)
                local spawnPos, spawnRot = PickingUtils.GetPickingHitPosAndRot()
                if not spawnPos or not spawnRot then return end
                Commands.SpawnCommand(entry.TemplateId, { Position=spawnPos, Rotation=spawnRot })
            end)
        else
            PlacementPreview:StartPreview(entry, entry[self.iconTooltipName])
        end
    end

    iconImage:Tooltip():AddText(entry[self.iconTooltipName] or "Unknown")

    return iconImage
end
