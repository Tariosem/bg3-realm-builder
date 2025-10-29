--- @class ItemIconBrowser : IconBrowser
ItemIconBrowser = _Class("ItemIconBrowser", IconBrowser)

function ItemIconBrowser:GetConfig()
    return CONFIG.ItemBrowser or {}
end

function ItemIconBrowser:SaveToConfig()
    CONFIG.ItemBrowser.IconWidth = self.iconWidth
    CONFIG.ItemBrowser.IconPerColumn = self.iconPC
    CONFIG.ItemBrowser.ButtonBgColor = self.iconButtonBgColor
    CONFIG.ItemBrowser.BackgroundColor = self.browserBackgroundColor
    CONFIG.ItemBrowser.IconPerRow = self.iconPR
    CONFIG.ItemBrowser.CellsPadding = self.cellsPadding
    CONFIG.ItemBrowser.StickToRight = self.stickToRight
    CONFIG.ItemBrowser.LastPosition = self.lastPosition
    CONFIG.ItemBrowser.LastSize = self.lastSize
    SaveConfig("ItemsBrowser")
end

function ItemIconBrowser:TooltipChangeLogic()
    if self.iconTooltipName == "DisplayName" then
        self.iconTooltipName = "TemplateName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Template Name")
    elseif self.iconTooltipName == "TemplateName" then
        self.iconTooltipName = "StatsName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Stats Name")
    else
        self.iconTooltipName = "DisplayName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Display Name")
    end
end

---@param entry RB_Item
---@param cell ExtuiTableCell
---@return ExtuiImageButton|ExtuiStyledRenderable?
function ItemIconBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[ItemIconBrowser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field.")
        Warning(entry)
        return nil
    end

    local popup = cell:AddPopup("IconPopup")
    local lazyRenders = {}
    local spawnPopup = nil
    local attributePopup = nil

    local iconImage = nil
    if not self.iconToName then
        iconImage = cell:AddImageButton(entry.Uuid, entry.Icon)
        if iconImage.Image.Icon == "" then
            iconImage:Destroy()
            iconImage = cell:AddImageButton(entry.Uuid, "Item_Unknown")
        end
        local iconWidth = self.iconWidth
        local rarityColor = RARITY_COLORS[entry.Rarity]
        if entry.StoryItem then
            rarityColor = RARITY_COLORS["StoryItem"]
        end

        iconImage.Image.Size = { iconWidth, iconWidth }
        if self.iconButtonBgColor and rarityColor[4] == 0 then
            --iconImage.Background = self.iconButtonBgColor
        elseif rarityColor and rarityColor[4] ~= 0 then
            --iconImage.Background = AdjustColor(rarityColor, -0.1, nil, -0.1)
        end

        if rarityColor and rarityColor[4] ~= 0 then
            iconImage:SetStyle("FrameBorderSize", 3 * SCALE_FACTOR)
            iconImage:SetColor("Border", AdjustColor(rarityColor, 0.2, 0.2))
        end
    else
        local image = cell:AddImage(entry.Icon, { self.iconWidth, self.iconWidth })
        iconImage = cell:AddSelectable(entry[self.iconTooltipName] or "Unknown")
        iconImage.SameLine = true
    end

    iconImage.CanDrag = true
    iconImage.DragDropType = "ForItemPreview"

    popup.IDContext = entry.Uuid .. "Popup" .. Uuid_v4()

    iconImage.UserData = iconImage.UserData or {}

    local spawnRendered = false
    iconImage.OnRightClick = function()
        if not spawnRendered then
            spawnPopup = cell:AddPopup("SpawnPopup##" .. entry.Uuid)
            self:RenderCustomizationTab(spawnPopup, entry, attributePopup)
            self:RenderItemSpawnTab(spawnPopup, iconImage, entry)
            spawnRendered = true
        end
        if not spawnPopup then return end
        spawnPopup:Open()
    end

    iconImage.OnDragStart = function()
        iconImage.DragPreview:AddImage(entry.Icon, IMAGESIZE.MEDIUM)
    end

    iconImage.OnDragEnd = function()
        if self.IsPreviewing then return end

        self:SetupTemplatePreview(entry)
    end

    local renderedTooltip = false
    iconImage.OnHoverEnter = function()
        if renderedTooltip then return end
        local iconTooltip = iconImage:Tooltip()
        local tooltipName = entry[self.iconTooltipName] or ""
        if tooltipName == "" then
            tooltipName = entry.TemplateName or "Unknown"
            tooltipName = tooltipName
        end

        if self.iconToName then
            local imageTooltip = iconTooltip:AddImage(entry.Icon, { 64 * SCALE_FACTOR, 64 * SCALE_FACTOR })
            imageTooltip.IDContext = entry.Uuid .. "TooltipImage"
        else
            iconTooltip:AddText(tooltipName).TextWrapPos = self.browserWidth
        end

        local addSepaDescs = function(desc)
            if desc and desc ~= "" then
                local descText = iconTooltip:AddText(desc)
                descText.TextWrapPos = self.browserWidth
                descText.Font = "Tiny"
                descText:SetColor("Text", HexToRGBA("FF939393"))
            end
        end

        addSepaDescs(entry.Description, GetLoca("Description"))
        addSepaDescs(entry.ShortDescription, GetLoca("Short Description"))
        renderedTooltip = true
    end


    iconImage.OnClick = function()
        self:RenderInfoPopup(popup, entry)
        popup:Open()
    end

    
    if entry.DefaultBoosts or entry.Passives or entry.Boosts or entry.BoostsOnEquipMainHand or entry.BoostsOnEquipOffHand then
        self:RenderAttrPopup(iconImage, cell, entry, popup)
    end

    return iconImage
end

--- @param entry RB_Item
function ItemIconBrowser:SetupTemplatePreview(entry)

    Timer:Ticks(15, function (timerID)
        local spawnPos, spawnRot = GetPickingHitPosAndRot()
        if not spawnPos or not spawnRot then return end
        Commands.SpawnCommand(entry.TemplateId, spawnPos, spawnRot)
    end)

    if true then return end

    self.IsPreviewing = true

    local notif = Notification.new("Is Previewing Item...")
    notif.Pivot = { 0.5, 0 }
    notif.Duration = 5000
    
    notif:Show("Item Preview", function (panel)
        local midAlighTab = panel:AddTable("Midddd", 3)
        midAlighTab.ColumnDefs[1] = { WidthStretch = true }
        midAlighTab.ColumnDefs[2] = { WidthFixed = true }
        midAlighTab.ColumnDefs[3] = { WidthStretch = true }
        local row = midAlighTab:AddRow()
        local _,midCell,_ = row:AddCell(), row:AddCell(), row:AddCell()
        local icon = CheckIcon(entry.Icon or "Item_Unknown")
        local image = midCell:AddImage(icon, ToVec2(64 * SCALE_FACTOR))
        midCell:AddText(GetLoca(entry.DisplayName) or "Unknown").SameLine = true

        panel:AddText(GetLoca("Left click to spawn the item at the previewed location.")).Font = "Tiny"
        panel:AddText(GetLoca("Scroll mouse wheel to rotate the item.")).Font = "Tiny"
        local caution = panel:AddText(GetLoca("Press ESCAPE or BACKSPACE to cancel the preview."))
        caution:SetColor("Text", HexToRGBA("FFFFFFFF"))
        caution.Font = "Large"
    end)

    local previewItem = nil
    local mouseButtonSub = nil
    local mouseWheelSub = nil
    local stickTimer = nil
    local cancelSub = nil
    local rotationOffset = Quat.new(0,0,0,1)

    local startPos, startRot = GetPickingHitPosAndRot()

    NetChannel.SpawnPreview:RequestToServer({
        TemplateId = entry.TemplateId,
        Position = startPos,
        Rotation = startRot,
    }, function (response)
        if not response.Guid then
            Warning("[ItemIconBrowser] Failed to spawn preview for templateId: " .. tostring(entry.TemplateId))
            self.IsPreviewing = false
            return
        end
        previewItem = response.Guid
        TransformEditor:AddToBlacklist(previewItem)

        local rotatedirty = false
        local dirtyRotation = nil
        stickTimer = Timer:EveryFrame(function (timerID)
            if not previewItem then return UNSUBSCRIBE_SYMBOL end

            local hitPos, hitRot = nil, nil

            local hitOnPreview = GetPickingGuid() == previewItem
            if hitOnPreview then
                local mouseRay = ScreenToWorldRay()
                if not mouseRay then return end
                local planeNormal = Quat.new({CGetRotation(previewItem)}):Rotate(GLOBAL_COORDINATE.Y)

                local hit = mouseRay:IntersectPlane({CGetPosition(previewItem)}, planeNormal)

                if not hit then return end
                hitPos = hit.Position
            else
                hitPos, hitRot = GetPickingHitPosAndRot()
            end


            if not hitPos then hitPos = startPos or Vec3.new(0,0,0) end
            if not hitRot then 
                if dirtyRotation then
                    hitRot = DeepCopy(dirtyRotation)
                    dirtyRotation = nil
                else
                    hitRot = {CGetRotation(previewItem)}
                end
            end

            if not hitOnPreview or rotatedirty then
                hitRot = Ext.Math.QuatMul(hitRot, rotationOffset)
                dirtyRotation = DeepCopy(hitRot)
                rotatedirty = false
            end

            local selectedGuid = self.selectedGuid or CGetHostCharacter()

            hitPos = Vec3.new(hitPos)
            hitRot = Quat.new(hitRot)

            hitPos:Sanitize({CGetPosition(selectedGuid)})
            hitRot:Sanitize({CGetRotation(selectedGuid)})

            NetChannel.SetTransform:SendToServer({
                Guid = previewItem,
                Transforms = {
                    [previewItem] = {
                        Translate = hitPos,
                        RotationQuat = hitRot,
                    }
                }
            })
        end)

        mouseButtonSub = SubscribeMouseInput({}, function (e)
            if not previewItem then return UNSUBSCRIBE_SYMBOL end
            if not e.Pressed and e.Clicks > 0 then return end

            if e.Button == 1 then
                local data = {
                    TemplateId = entry.TemplateId,
                    Position = {CGetPosition(previewItem)},
                    Rotation = {CGetRotation(previewItem)}
                }
                Commands.SpawnCommand(entry.TemplateId, data.Position, data.Rotation)
            end
        end)

        mouseWheelSub = SubscribeMouseWheel({}, function (e)
            if not previewItem then return UNSUBSCRIBE_SYMBOL end
            if e.ScrollY == 0 then return end

            local angle = math.rad(15) * (e.ScrollY > 0 and 1 or -1)
            local quatOffset = Quat.new(Ext.Math.QuatFromEuler({0, angle, 0}))
            rotationOffset = Ext.Math.QuatMul(quatOffset, rotationOffset)
            rotatedirty = true
        end)

        cancelSub = SubscribeKeyInput({}, function (e)
            if not previewItem then NetChannel.Delete:SendToServer({ Guid = previewItem }) return UNSUBSCRIBE_SYMBOL end
            if e.Pressed and (e.Key == "ESCAPE" or e.Key == "BACKSPACE") then
                NetChannel.Delete:SendToServer({ Guid = previewItem })
                previewItem = nil
                self.IsPreviewing = false
                TransformEditor:RemoveFromBlacklist(previewItem)
                return UNSUBSCRIBE_SYMBOL
            end
        end)

    end)

end

function ItemIconBrowser:RenderInfoPopup(popup, entry)
    popup.UserData = popup.UserData or {}
    if popup.UserData.InfoRendered then return end

    local infoFields = {
        Icon = entry.Icon,
        DisplayName = entry.DisplayName,
        TemplateId = entry.TemplateId,
        TemplateName = entry.TemplateName,
        Mod = entry.Mod,
        ModAuthor = entry.ModAuthor,
    }

    for field, value in pairs(infoFields) do
        if value and value ~= "" then

            AddPrefixInput(popup, field .. " :", value, true)
        end
    end

    popup.UserData.InfoRendered = true
end

function ItemIconBrowser:RenderAttrPopup(iconImage, cell, entry, popup)
    local popupRendered = false
    local attributePopup = nil

    local function addAttrTitle(text)
        if not attributePopup then return end
        local title = attributePopup:AddText(text)
        title:SetColor("Text", HexToRGBA("FFFFA743"))
        attributePopup:AddSeparator()
        return title
    end

    local function addAttrSubTitle(text)
        if not attributePopup then return end
        local tab = attributePopup:AddDummy(20, 10)
        local title = attributePopup:AddText(text)
        title.SameLine = true
        title:SetColor("Text", HexToRGBA("FF6B7B7B"))
        return title
    end

    iconImage.OnClick = function()
        if popupRendered and attributePopup then
            attributePopup:Open()
            return
        end
        attributePopup = cell:AddPopup("AttributesPopup##" .. entry.Uuid)

        local popupBtn = popup:AddButton(GetLoca("Infos"))
        popupBtn.OnClick = function()
            self:RenderInfoPopup(popup, entry)
            popup:Open()
        end

        addAttrTitle("Attributes")
        
        if entry.Damage then
            addAttrTitle("Damage : ")
            local damageText = attributePopup:AddText(entry.Damage)
            local damageColor = DAMAGE_TYPES_COLOR[entry.DamageType] or DAMAGE_TYPES_COLOR["Slashing"]
            damageText:SetColor("Text", damageColor)
            local damageTypeText = attributePopup:AddText(" (" .. (entry.DamageType or "Physical") .. ")")
            damageTypeText:SetColor("Text", damageColor)

            damageText.SameLine = true
            damageTypeText.SameLine = true
            attributePopup:AddSeparator()
        end

        if entry.ArmorClass and entry.ArmorClass ~= 0 then
            addAttrTitle("Armor Class : ")
            local armorText = attributePopup:AddText(tostring(entry.ArmorClass))
            armorText:SetColor("Text", HexToRGBA("FFD1C4A9"))
            attributePopup:AddSeparator()
            armorText.SameLine = true
        end

        if entry.DefaultBoosts and entry.DefaultBoosts ~= "" then
            local parsed = StatsParser:ParseBoosts(entry.DefaultBoosts)
            addAttrTitle("Default Boosts")
            for _, render in ipairs(parsed or {}) do
                render(attributePopup)
            end
        end

        if entry.Boosts and entry.Boosts ~= "" then
            local parsed = StatsParser:ParseBoosts(entry.Boosts)
            if parsed and #parsed > 0 then
                addAttrTitle("Boosts")
                attributePopup:AddSeparator()
                for _, render in ipairs(parsed) do
                    render(attributePopup)
                end
            end
        end

        if entry.BoostsOnEquipMainHand and entry.BoostsOnEquipMainHand ~= "" then
            local parsed = StatsParser:ParseBoosts(entry.BoostsOnEquipMainHand)
            if parsed and #parsed > 0 then
                attributePopup:AddSeparator()
                attributePopup:AddDummy(20, 10)
                addAttrSubTitle("On Equip Main Hand :")
                for _, render in ipairs(parsed) do
                    render(attributePopup)
                end
            end
        end

        if entry.BoostsOnEquipOffHand and entry.BoostsOnEquipOffHand ~= "" then
            local parsed = StatsParser:ParseBoosts(entry.BoostsOnEquipOffHand)
            if parsed and #parsed > 0 then
                attributePopup:AddSeparator()
                attributePopup:AddDummy(20, 10)
                addAttrSubTitle("On Equip Off Hand :")
                for _, render in ipairs(parsed) do
                    render(attributePopup)
                end
            end
        end

        if attributePopup then
            attributePopup:AddSeparator()
        end

        if entry.Passives then
            for onSomething, passive in pairs(entry.Passives) do
                local renderFunc = StatsParser:ParsePassives(passive, onSomething)
                if renderFunc then
                    addAttrTitle("Passives")
                    attributePopup:AddSeparator()
                    addAttrSubTitle(onSomething .. " :")
                    for _, render in ipairs(renderFunc) do
                        render(attributePopup)
                    end
                end
            end
        end
        popupRendered = true
        attributePopup:Open()
    end
end

function ItemIconBrowser:RenderItemSpawnTab(popup, iconImage, entry)
    local spawnTab = popup

    local spawnButton = spawnTab:AddButton(GetLoca("Spawn"))

    local function spawnHandle(isPreview)
        if isPreview then
            local data = {
                TemplateId = entry.TemplateId,
                Type = "Preview",
                Position = {CGetPosition(self.selectedGuid or CGetHostCharacter())},
                Rotation = {CGetRotation(self.selectedGuid or CGetHostCharacter())}
            }

            NetChannel.Spawn:SendToServer(data)
        else
            local data = {
                Guid = entry.Uuid,
                TemplateId = entry.TemplateId,
                Type = "Spawn",
                Position = {CGetPosition(self.selectedGuid or CGetHostCharacter())},
                Rotation = {CGetRotation(self.selectedGuid or CGetHostCharacter())}
            }
            Commands.SpawnCommand(entry.TemplateId, data.Position, data.Rotation, data)
        end
    end

    ApplyConfirmButtonStyle(spawnButton)
    spawnButton.OnClick = function() spawnHandle(false) end


    spawnTab:AddDummy(10, 10).SameLine = true

    local deleteAllButton = spawnTab:AddButton(GetLoca("Delete All"))
    ApplyDangerButtonStyle(deleteAllButton)
    deleteAllButton.OnClick = function()
        local data = {
            Uuid = entry.Uuid,
            TemplateId = entry.TemplateId,
        }
        ConfirmPopup:DangerConfirm(
            GetLoca("Delete all props with the same template ?"),
            function()
                Post("DeletePropsByTemplateId", data)
            end,
            nil
        )
    end
    deleteAllButton.SameLine = true

    if not entry.CanBePickedUp then return iconImage end

    local countInput = nil
    local cheatButton = spawnTab:AddButton(GetLoca("Cheat"))
    local warningImage = spawnTab:AddImage(WARNING_ICON)
    warningImage.SameLine = true
    warningImage.ImageData.Size = { 32 * SCALE_FACTOR, 32 * SCALE_FACTOR }
    warningImage:Tooltip():AddText(GetLoca("Items added to your inventory will not be monitored by this mod."))
    warningImage:Tooltip():AddText(GetLoca("Not all items can be added to the inventory."))
    ApplyConfirmButtonStyle(cheatButton)
    cheatButton.OnClick = function()
        if not countInput then return end
        local captureValue = math.floor(countInput.Value[1])
        ConfirmPopup:QuickConfirm(
            string.format(GetLoca("Add %d '%s'?"), captureValue,
                entry[self.iconTooltipName] or entry.TemplateName or "Unknown"),
            function()
                local data = {
                    Guid = entry.Uuid,
                    TemplateId = entry.TemplateId,
                    Count = captureValue,
                    Target = self.selectedGuid or CGetHostCharacter(),
                }

                NetChannel.AddItem:SendToServer(data)
            end,
            nil,
            10)
    end


    local decre5Button = spawnTab:AddButton("-5")
    decre5Button.IDContext = "CntDecre5Button"
    decre5Button.SameLine = true
    local decreButton = spawnTab:AddButton("-")
    decreButton.IDContext = "CntDecreButton"
    decreButton.SameLine = true
    countInput = spawnTab:AddInputInt("")
    countInput.IDContext = "CntInput"
    countInput.ItemWidth = 50 * SCALE_FACTOR
    countInput.SameLine = true
    local increButton = spawnTab:AddButton("+")
    increButton.IDContext = "CntIncreButton"
    increButton.SameLine = true
    local incre5Button = spawnTab:AddButton("+5")
    incre5Button.IDContext = "CntIncre5Button"
    incre5Button.SameLine = true

    local checkValue = function()
        if countInput.Value[1] <= 1 then
            countInput.Value = ToVec4(1)
            decre5Button.Disabled = true
            decreButton.Disabled = true
        else
            decre5Button.Disabled = false
            decreButton.Disabled = false
        end
    end

    decre5Button.OnClick = function()
        countInput.Value = ToVec4(countInput.Value[1] - 5)
        checkValue()
    end
    decreButton.OnClick = function()
        countInput.Value = ToVec4(countInput.Value[1] - 1)
        checkValue()
    end
    countInput.Value = ToVec4(1)
    checkValue()
    countInput.OnChange = function()
        checkValue()
    end
    increButton.OnClick = function()
        countInput.Value = ToVec4(countInput.Value[1] + 1)
        checkValue()
    end
    incre5Button.OnClick = function()
        countInput.Value = ToVec4(countInput.Value[1] + 5)
        checkValue()
    end
end

function ItemIconBrowser.Add(Lib, DisplayName)
    local instance = ItemIconBrowser.new(Lib, DisplayName)
    return instance
end