--- @class ItemBrowser : IconBrowser
ItemBrowser = _Class("ItemBrowser", IconBrowser)

ItemBrowser.tooltipNameOptions = {"DisplayName", "TemplateName", "StatsName"}

function ItemBrowser:OnSelectChange(guid)
    if self.dataManager:CheckHostValidEquipmentVisual(guid) then
        self:RefreshTagFilder()
    end
end

---@param entry RB_Item
---@param cell ExtuiTableCell
---@return ExtuiImageButton|ExtuiStyledRenderable?
function ItemBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[ItemIconBrowser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field.")
        Warning(entry)
        return nil
    end

    local popup = nil
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
            iconImage:SetColor("Border", ColorUtils.AdjustColor(rarityColor, 0.2, 0.2))
        end
    else
        local image = cell:AddImage(entry.Icon, { self.iconWidth, self.iconWidth })
        iconImage = cell:AddSelectable(entry[self.iconTooltipName] or "Unknown")
        iconImage.SameLine = true
    end

    iconImage.CanDrag = true
    iconImage.DragDropType = "ForItemPreview"

    iconImage.UserData = iconImage.UserData or {}

    local spawnRendered = false
    iconImage.OnRightClick = function(sle)
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
        PlacementPreview:StartPreview(entry, entry[self.iconTooltipName])
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
                descText:SetColor("Text", ColorUtils.HexToRGBA("FF939393"))
            end
        end

        addSepaDescs(entry.Description, GetLoca("Description"))
        addSepaDescs(entry.ShortDescription, GetLoca("Short Description"))
        renderedTooltip = true
    end


    iconImage.OnClick = function(sel)
        if not popup then
            popup = cell:AddPopup("IconPopup")
            popup.IDContext = entry.Uuid .. "Popup" .. RBUtils.Uuid_v4()
        end
        if self.iconToName then
            sel.Selected = false
        end
        self:RenderInfoPopup(popup, entry)
        popup:Open()
    end

    if entry.DefaultBoosts or entry.Passives or entry.Boosts or entry.BoostsOnEquipMainHand or entry.BoostsOnEquipOffHand then
        self:RenderAttrPopup(iconImage, cell, entry, function()
            if not popup then
                popup = cell:AddPopup("IconPopup")
                popup.IDContext = entry.Uuid .. "Popup" .. RBUtils.Uuid_v4()
            end
            return popup
        end)
    end

    return iconImage
end


--- @param popup ExtuiPopup
--- @param entry RB_Item
function ItemBrowser:RenderInfoPopup(popup, entry)
    popup.UserData = popup.UserData or {}
    if popup.UserData.InfoRendered then return end

    
    
    local infoFields = {
        Icon = entry.Icon,
        DisplayName = entry.DisplayName,
        TemplateId = entry.TemplateId,
        TemplateName = entry.TemplateName,
        Mod = entry.Mod,
        ModAuthor = entry.ModAuthor,
        StatsName = entry.StatsName,
    }
    if infoFields.Mod == "" then infoFields.Mod = nil end
    if infoFields.ModAuthor == "" then infoFields.ModAuthor = nil end

    local attrTable = ImguiElements.AddReadOnlyAttrTable(popup, infoFields)

    local debugDumpLine = popup:AddButton("Dump Template to Console")
    local dumpStatsLine = popup:AddButton("Dump Stats to Console")
    debugDumpLine.OnClick = function()
        local templateObj = Ext.Template.GetTemplate(entry.Uuid) or {} --[[@as ItemTemplate]]
        if templateObj then
            RainbowDumpTable(templateObj)
        end
    end

    dumpStatsLine.OnClick = function()
        local templateObj = Ext.Template.GetTemplate(entry.Uuid) or {} --[[@as ItemTemplate]]
        if templateObj.Stats then
            RainbowDumpTable(Ext.Stats.Get(templateObj.Stats) or {})
        else
            RBPrintRed("No stats found for item: " .. tostring(entry.Uuid))
        end
    end

    popup.UserData.InfoRendered = true
end

function ItemBrowser:RenderAttrPopup(iconImage, cell, entry, getPopupFunc)
    local popupRendered = false
    local attributePopup = nil

    local function addAttrTitle(text)
        if not attributePopup then return end
        local title = attributePopup:AddText(text)
        title:SetColor("Text", ColorUtils.HexToRGBA("FFFFA743"))
        attributePopup:AddSeparator()
        return title
    end

    local function addAttrSubTitle(text)
        if not attributePopup then return end
        local tab = attributePopup:AddDummy(20, 10)
        local title = attributePopup:AddText(text)
        title.SameLine = true
        title:SetColor("Text", ColorUtils.HexToRGBA("FF6B7B7B"))
        return title
    end

    iconImage.OnClick = function()
        if self.iconToName then
            iconImage.Selected = false
        end

        if popupRendered and attributePopup then
            attributePopup:Open()
            return
        end

        -- Lazy create popup
        local popup = getPopupFunc()
        attributePopup = cell:AddPopup("AttributesPopup##" .. entry.Uuid)

        local popupBtn = attributePopup:AddButton(GetLoca("Infos"))
        popupBtn.OnClick = function()
            self:RenderInfoPopup(popup, entry)
            popup:Open()
        end

        addAttrTitle("Attributes")

        if entry.Damage then
            addAttrTitle("Damage : ")
            local damageText = attributePopup:AddText(entry.Damage)
            local damageColor = DAMAGE_TYPE_COLORS[entry.DamageType] or DAMAGE_TYPE_COLORS["Slashing"]
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
            armorText:SetColor("Text", ColorUtils.HexToRGBA("FFD1C4A9"))
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

        local hasAnyPassive = false
        for _,fieldName in pairs({"PassivesOnEquip", "PassivesMainHand", "PassivesOffHand"}) do
            if entry[fieldName] and entry[fieldName] ~= "" then
                hasAnyPassive = true
                break
            end
        end

        if hasAnyPassive then
            addAttrTitle("Passives")
        end

        if entry.PassivesOnEquip and entry.PassivesOnEquip ~= "" then            
            local passive = entry.PassivesOnEquip
            local renderFunc = StatsParser:ParsePassives(passive)
            if renderFunc then
                attributePopup:AddSeparator()
                for _, render in ipairs(renderFunc) do
                    render(attributePopup)
                end
            end
        end

        if entry.PassivesMainHand and entry.PassivesMainHand ~= "" then
            local passive = entry.PassivesMainHand
            local renderFunc = StatsParser:ParsePassives(passive)
            if renderFunc then
                attributePopup:AddSeparator()
                attributePopup:AddDummy(20, 10)
                addAttrSubTitle("Main Hand :")
                for _, render in ipairs(renderFunc) do
                    render(attributePopup)
                end
            end
        end

        if entry.PassivesOffHand and entry.PassivesOffHand ~= "" then
            local passive = entry.PassivesOffHand
            local renderFunc = StatsParser:ParsePassives(passive)
            if renderFunc then
                attributePopup:AddSeparator()
                attributePopup:AddDummy(20, 10)
                addAttrSubTitle("Off Hand :")
                for _, render in ipairs(renderFunc) do
                    render(attributePopup)
                end
            end
        end

        popupRendered = true
        attributePopup:Open()
    end
end

function ItemBrowser:RenderItemSpawnTab(popup, iconImage, entry)
    local spawnTab = popup
    local spawnButton = spawnTab:AddButton(GetLoca("Spawn"))
    local target = self.selectedGuid or RBGetHostCharacter()

    local function spawnHandle()
        local data = {
            Guid = entry.Uuid,
            TemplateId = entry.TemplateId,
            Type = "Spawn",
            EntInfo = {
                Position = { RBGetPosition(target) },
                Rotation = { RBGetRotation(target) }
            }
        }
        Commands.SpawnCommand(entry.TemplateId, data.EntInfo)
    end

    StyleHelpers.ApplyConfirmButtonStyle(spawnButton)
    spawnButton.OnClick = function() spawnHandle() end

    if not entry.CanBePickedUp then return iconImage end

    local countInput = nil
    local cheatButton = spawnTab:AddButton(GetLoca("Cheat"))
    local warningImage = spawnTab:AddImage(RB_ICONS.Warning) --[[@as ExtuiImage]]
    warningImage.Tint = { 1, 0.5, 0.5, 1 }
    warningImage.SameLine = true
    warningImage.ImageData.Size = { 32 * SCALE_FACTOR, 32 * SCALE_FACTOR }
    warningImage:Tooltip():AddText(GetLoca("Items added to your inventory will not be monitored by this mod."))
    warningImage:Tooltip():AddText(GetLoca("Not all items can be added to the inventory."))
    StyleHelpers.ApplyConfirmButtonStyle(cheatButton)
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
                    Target = self.selectedGuid or RBGetHostCharacter(),
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
            countInput.Value = RBUtils.ToVec4(1)
            decre5Button.Disabled = true
            decreButton.Disabled = true
        else
            decre5Button.Disabled = false
            decreButton.Disabled = false
        end
    end

    decre5Button.OnClick = function()
        countInput.Value = RBUtils.ToVec4(countInput.Value[1] - 5)
        checkValue()
    end
    decreButton.OnClick = function()
        countInput.Value = RBUtils.ToVec4(countInput.Value[1] - 1)
        checkValue()
    end
    countInput.Value = RBUtils.ToVec4(1)
    checkValue()
    countInput.OnChange = function()
        checkValue()
    end
    increButton.OnClick = function()
        countInput.Value = RBUtils.ToVec4(countInput.Value[1] + 1)
        checkValue()
    end
    incre5Button.OnClick = function()
        countInput.Value = RBUtils.ToVec4(countInput.Value[1] + 5)
        checkValue()
    end
end

function ItemBrowser.Add(Lib, DisplayName)
    local instance = ItemBrowser.new(Lib, DisplayName)
    return instance
end
