EffectIconBrowser = _Class("EffectIconBrowser", IconBrowser)

--- @class EffectIconsBrowser : IconsBrowser
function EffectIconBrowser:GetConfig()
    return CONFIG.EffectBrowser or {}
end

function EffectIconBrowser:SaveToConfig()
    self.lastPosition = self.panel.LastPosition
    self.lastSize = self.panel.LastSize
    CONFIG.EffectBrowser.IconWidth = self.iconWidth
    CONFIG.EffectBrowser.IconPerRow = self.iconPR
    CONFIG.EffectBrowser.IconPerColumn = self.iconPC
    CONFIG.EffectBrowser.CellsPadding = self.cellsPadding
    CONFIG.EffectBrowser.autoSave = self.autoSave
    CONFIG.EffectBrowser.ButtonBgColor = self.iconButtonBgColor
    CONFIG.EffectBrowser.BackgroundColor = self.browserBackgroundColor
    CONFIG.EffectBrowser.StickToRight = self.stickToRight
    CONFIG.EffectBrowser.LastPosition = self.lastPosition
    CONFIG.EffectBrowser.LastSize = self.lastSize
    SaveConfig("EffectsBrowser")
end

function EffectIconBrowser:TooltipChangeLogic()
    if self.iconTooltipName == "DisplayName" then
        self.iconTooltipName = "TemplateName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Template Name")
    elseif self.iconTooltipName == "TemplateName" then
        self.iconTooltipName = "DisplayName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Display Name")
    end
end

--- @param entry LOPEffect
--- @param cell ExtuiTableCell
function EffectIconBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[IconsBrowser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field.")
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
        local image = cell:AddImage(entry.Icon, { self.iconWidth, self.iconWidth })
        iconImage = cell:AddSelectable(entry[self.iconTooltipName] or "Unknown")
        iconImage.SameLine = true
    end
    
    iconImage.OnClick = function()
        popup:Open()
    end

    iconImage.OnRightClick = function()
        rPopup:Open()
    end

    popup.IDContext = entry.Uuid .. "Popup" .. Uuid_v4()
    rPopup.IDContext = entry.Uuid .. "SpawnPopup" .. Uuid_v4()
    
    iconImage.UserData = iconImage.UserData or {}
    iconImage.UserData.Popups = { popup, rPopup }

    local iconTooltip = iconImage:Tooltip()
    local tooltipName = entry[self.iconTooltipName] or ""
    if tooltipName == "" then
        tooltipName = entry.TemplateName or "Unknown"
        tooltipName = tooltipName
    end
    if self.iconToName then
        local imageTooltip = iconTooltip:AddImage(entry.Icon, {64 * SCALE_FACTOR, 64 * SCALE_FACTOR})
        imageTooltip.IDContext = entry.Uuid .. "TooltipImage"
    else
        iconTooltip:AddText(tooltipName)
    end

    local iconTooltipNote = nil
    local noteElement = {}

    local addSeparator = function ()
        local sep = iconTooltip:AddSeparator()
        ApplyDefaultSeparatorStyle(sep)
        return sep
    end

    local function addTooltipNote()
        if entry.Note and entry.Note ~= "" then
            table.insert(noteElement, addSeparator())
            table.insert(noteElement, iconTooltip:AddSeparatorText(GetLoca("Note")))
            table.insert(noteElement, addSeparator())

            iconTooltipNote = iconTooltip:AddText(entry.Note or "")
            iconTooltipNote.TextWrapPos = self.browserWidth
        end
    end

    addTooltipNote()

    ----------------------------------------------
    ---------- LEFT CLICK POPUP START ------------
    ----------------------------------------------

     --#region Left Popup

    AddPrefixInput(popup, "Icon" .. " :", entry.Icon, true)
    AddPrefixInput(popup, "Display Name" .. " :", entry.DisplayName, true)
    AddPrefixInput(popup, "TemplateName" .. " :", entry.TemplateName, true)
    AddPrefixInput(popup, "Uuid" .. " :", entry.Uuid, true)

    --#endregion Left Popup

    ----------------------------------------------
    ---------- LEFT CLICK POPUP END --------------
    ----------------------------------------------

    self:RenderCustomizationTab(rPopup, entry)

    self:RenderPlayEffectPopup(rPopup, entry, iconImage)

    return iconImage
end

function EffectIconBrowser:RenderPlayEffectPopup(popup, entry, iconImage)
    local playEffectButton = popup:AddButton(GetLoca("Play"))
    playEffectButton:Tooltip():AddText(GetLoca("For preview, some effects may not play correctly"))
    local infoButton = popup:AddButton(GetLoca("Info"))

    infoButton.SameLine = true

    ApplyConfirmButtonStyle(playEffectButton)

    ApplyInfoButtonStyle(infoButton)

    local function previewEffect(guid)
        local effectsData = {}
        local fxNames = self.searchData[entry.Uuid].fxNames or {}
        if #fxNames == 0 then
            return
        end
        for _, fxName in ipairs(fxNames) do
            local fxData = GetDataFromUuid(fxName) or {}
            local effectData = {
                Object = guid,
                Target = guid,
                FxName = fxName,
                TargetBone = fxData.TargetBone or "",
                SourceBone = fxData.SourceBone or "",
                Tags = {
                    PlayBeamEffect = fxData.isBeam or false,
                }
            }
            
            local loopEffectData = DeepCopy(effectData)
            loopEffectData.Tags.PlayLoop = true
            local stopdata = {
                Type = "FxName",
                FxName = fxName,
            }
            Timer:After(5000, function()
                NetChannel.StopEffect:SendToServer(stopdata)
            end)

            table.insert(effectsData, effectData)
            table.insert(effectsData, loopEffectData)
        end
        local data = effectsData
        NetChannel.PlayEffect:SendToServer(data)

    end

    playEffectButton.OnClick = function()
        previewEffect(self.selectedGuid or CGetHostCharacter())
    end

    iconImage.CanDrag = true
    iconImage.DragDropType = "EffectInfo"
    iconImage.UserData = {
        Uuid = entry.Uuid,
        DisplayName = entry.DisplayName,
        TemplateName = entry.TemplateName,
        isMultiEffect = self.searchData[entry.Uuid].isMultiEffect or false,
        FxName = self.searchData[entry.Uuid].fxNames or {},
        Icon = entry.Icon
    }

    iconImage.OnDragStart = function()
        iconImage.DragPreview:AddImage(entry.Icon)
    end

    iconImage.OnDragEnd = function()
        Timer:Ticks(10, function (timerID)
            local pick = GetPickingGuid()
            if not pick or pick == "" then
                pick = self.selectedGuid or CGetHostCharacter()
            end
            if pick and pick ~= "" then
                previewEffect(pick)
            end
        end)
    end

    infoButton.OnClick = function()
        EffectTab:Add(entry.Uuid, nil, entry.TemplateName)
    end
end

function EffectIconBrowser:Add(dataManager, searchData)
    local instance = EffectIconBrowser.new(dataManager, searchData)
    instance:Render()
    return instance
end