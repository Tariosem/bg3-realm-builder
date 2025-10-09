ItemIconBrowser = _Class("ItemIconBrowser", IconBrowser)

function ItemIconBrowser:GetConfig()
    return CONFIG.ItemsBrowser or {}
end

function ItemIconBrowser:SaveToConfig()
    CONFIG.ItemsBrowser.IconWidth = self.iconWidth
    CONFIG.ItemsBrowser.IconPerColumn = self.iconPC
    CONFIG.ItemsBrowser.ButtonBgColor = self.iconButtonBgColor
    CONFIG.ItemsBrowser.BackgroundColor = self.browserBackgroundColor
    CONFIG.ItemsBrowser.IconPerRow = self.iconPR
    CONFIG.ItemsBrowser.CellsPadding = self.cellsPadding
    CONFIG.ItemsBrowser.StickToRight = self.stickToRight
    CONFIG.ItemsBrowser.LastPosition = self.lastPosition
    CONFIG.ItemsBrowser.LastSize = self.lastSize
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

---@param entry LOPItem
---@param cell ExtuiTableCell
---@return ExtuiImageButton|ExtuiStyledRenderable?
function ItemIconBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[ItemIconBrowser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field.")
        Debug(entry)
        return nil
    end

    local popup = cell:AddPopup("IconPopup")
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

    --local previewCancelSub = nil
    --local previewItem = nil
    --local previewTimer = nil
    --local previewConfirmSub = nil
    --local previewRotateSub = nil
    --local previewRotateOffset = Quat.Identity

    iconImage.OnDragStart = function()
        iconImage.DragPreview:AddImage(entry.Icon, IMAGESIZE.MEDIUM)
        --[[ClientSubscribe("PreviewProp", function (data)
            previewItem = data.Guid
            return UNSUBSCRIBE_SYMBOL
        end)

        local postData = {TemplateId = entry.TemplateId}
        postData.Position, postData.Rotation = GetCursorPosAndRot()
        Post("Preview", postData)

        local function cancel()
            local postData = { Guid = previewItem }
            if previewTimer then
                Timer:Cancel(previewTimer)
                previewTimer = nil
            end
            if previewConfirmSub then
                previewConfirmSub:Unsubscribe()
                previewConfirmSub = nil
            end
            if previewRotateSub then
                previewRotateSub:Unsubscribe()
                previewRotateSub = nil
            end
            if previewCancelSub then
                previewCancelSub:Unsubscribe()
                previewCancelSub = nil
            end
            Post("Delete", postData)
            previewItem = nil
            return UNSUBSCRIBE_SYMBOL
        end

        previewCancelSub = SubscribeKeyInput({}, function (e)
            if e.Key == "BACKSPACE" and e.Pressed then
                cancel()
            end
        end)

        previewConfirmSub = SubscribeMouseInput({}, function (e)
            if e.Button == 1 and e.Pressed then
                if previewItem then
                    local data = {
                        Guid = entry.Uuid,
                        TemplateId = entry.TemplateId,
                        Type = "Spawn",
                        Position = {CGetPosition(previewItem)},
                        Rotation = {CGetRotation(previewItem)}
                    }
                    Post(NetChannel.Spawn, data)
                end
            end
        end)

        previewRotateSub = SubscribeMouseWheel({}, function (e)
            if e.ScrollX == 0 and e.ScrollY == 0 or not previewItem then return end
            if not CGetRotation(previewItem) then return end
            local up = QuatToDirection({CGetRotation(previewItem)}, "Y")
            if e.ScrollY > 0 then
                previewRotateOffset = previewRotateOffset * Quat.new(Ext.Math.QuatRotateAxisAngle(Quat.Identity, up, math.rad(-15)))
            elseif e.ScrollY < 0 then
                previewRotateOffset = previewRotateOffset * Quat.new(Ext.Math.QuatRotateAxisAngle(Quat.Identity, up, math.rad(15)))
            end
        end)

        previewTimer = Timer:EveryFrame(function()
            if not previewItem or not EntityExists(previewItem) then
                cancel()
                return UNSUBSCRIBE_SYMBOL
            end
            local position, rotation = nil, nil
            if GetPickingGuid() == previewItem then
                local mouseRay = ScreenToWorldRay()
                local hit = mouseRay:IntersectPlane({CGetPosition(previewItem)}, QuatToDirection({CGetRotation(previewItem)}, "Y"))
                position = hit.Position
                rotation = Quat.Identity
            else
                position, rotation = GetCursorPosAndRot()
            end
            local postData = {
                Guid = previewItem,
                Transforms = {
                    [previewItem] = {
                        Translate = position,
                        RotationQuat = rotation * previewRotateOffset
                    }
                }}
            Post(NetChannel.SetTransform, postData)
        end)]]
    end

    iconImage.OnDragEnd = function()
        Timer:Ticks(20, function (timerID)
            local cursorPos, cursorRot = GetCursorPosAndRot()
            if not cursorPos or not cursorRot then
                local host = CGetHostCharacter()
                cursorPos = {CGetPosition(host)}
                cursorRot = {CGetRotation(host)}
            end
            Commands.SpawnCommand(entry.TemplateId, cursorPos, cursorRot)
        end)
    end

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

    iconImage.OnClick = function()
        self:RenderInfoPopup(popup, entry)
        popup:Open()
    end
        
    addSepaDescs(entry.Description, GetLoca("Description"))
    addSepaDescs(entry.ShortDescription, GetLoca("Short Description"))

    if entry.DefaultBoosts or entry.Passives or entry.Boosts or entry.BoostsOnEquipMainHand or entry.BoostsOnEquipOffHand then
        self:RenderAttrPopup(iconImage, cell, entry, popup)
    end

    return iconImage
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
                Guid = entry.Uuid,
                TemplateId = entry.TemplateId,
                Type = "Preview",
                Position = {CGetPosition(self.selectedGuid)},
                Rotation = {CGetRotation(self.selectedGuid)}
            }
            Post(NetChannel.Spawn, data)
        else
            Commands.SpawnCommand(entry.TemplateId, {CGetPosition(self.selectedGuid)}, {CGetRotation(self.selectedGuid)})
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

                Post("AddItem", data)
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

function ItemIconBrowser:Add(Lib, searchData, DisplayName)
    local instance = ItemIconBrowser.new(Lib, searchData, DisplayName)
    instance:Render()
    return instance
end