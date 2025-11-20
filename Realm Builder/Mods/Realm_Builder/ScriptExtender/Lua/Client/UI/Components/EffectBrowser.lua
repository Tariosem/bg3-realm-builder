--- @class EffectBrowser : IconBrowser
--- @field SaveToConfig fun(self:EffectBrowser)
EffectBrowser = _Class("EffectBrowser", IconBrowser)

--- @class EffectIconsBrowser : IconsBrowser
function EffectBrowser:GetConfig()
    return CONFIG.EffectBrowser or {}
end

function EffectBrowser:SaveToConfig()
    self.lastPosition = self.panel.LastPosition
    self.lastSize = self.panel.LastSize
    CONFIG.EffectBrowser.IconWidth = self.iconWidth
    CONFIG.EffectBrowser.IconPerRow = self.iconPR
    CONFIG.EffectBrowser.IconPerColumn = self.iconPC
    CONFIG.EffectBrowser.CellsPadding = self.cellsPadding
    CONFIG.EffectBrowser.AutoSave = self.AutoSave
    CONFIG.EffectBrowser.ButtonBgColor = self.iconButtonBgColor
    CONFIG.EffectBrowser.LastPosition = self.lastPosition
    CONFIG.EffectBrowser.LastSize = self.lastSize
    SaveConfig("EffectsBrowser")
end

function EffectBrowser:TooltipChangeLogic()
    if self.iconTooltipName == "DisplayName" then
        self.iconTooltipName = "TemplateName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Template Name")
    elseif self.iconTooltipName == "TemplateName" then
        self.iconTooltipName = "DisplayName"
        self.tooltipName.Label = GetLoca("Tooltip Name: Display Name")
    end
end

local function previewEffect(guid, entry)
        local effectsData = {}
        local fxNames = entry.fxNames or {}
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

--- @param entry RB_Effect
--- @param cell ExtuiTableCell
function EffectBrowser:RenderIcon(entry, cell)
    if entry.Uuid == nil then
        Warning("[IconsBrowser] Icon with UUID: " .. tostring(entry.Uuid) .. " is missing Uuid field.")
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
        local image = cell:AddImage(entry.Icon, { self.iconWidth, self.iconWidth })
        iconImage = cell:AddSelectable(entry[self.iconTooltipName] or "Unknown")
        iconImage.SameLine = true
    end
    
    iconImage.OnClick = function()
        if not popup then
            popup = cell:AddPopup("IconPopup")
            popup.IDContext = entry.Uuid .. "Popup" .. Uuid_v4()

            local attrs = {
                Uuid = entry.Uuid,
                DisplayName = entry.DisplayName,
                TemplateName = entry.TemplateName,
                Icon = entry.Icon,
            }

            StyleHelpers.AddReadOnlyAttrTable(popup, attrs)
        end
        popup:Open()

        if self.iconToName then
            iconImage.Selected = false
        end
    end

    iconImage.OnHoverEnter = function ()
        if rPopup then return end
        rPopup = cell:AddPopup("SpawnPopup")
        rPopup.IDContext = entry.Uuid .. "SpawnPopup" .. Uuid_v4()
        
        self:RenderCustomizationTab(rPopup, entry)
        self:RenderPlayEffectPopup(function() return rPopup end, entry, iconImage)
    end

    iconImage.OnRightClick = function()
        if not rPopup then
            rPopup = cell:AddPopup("SpawnPopup")
            rPopup.IDContext = entry.Uuid .. "SpawnPopup" .. Uuid_v4()
            
            self:RenderCustomizationTab(rPopup, entry)
            self:RenderPlayEffectPopup(function() return rPopup end, entry, iconImage)
        end
        rPopup:Open()
    end

    popup = popup or nil
    rPopup = rPopup or nil

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
                previewEffect(pick, entry)
            end
        end)
    end

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

    return iconImage
end

function EffectBrowser:RenderPlayEffectPopup(getPopupFunc, entry)
    local initialized = false
    local playEffectButton = nil
    local infoButton = nil

    local popup = getPopupFunc()
    playEffectButton = popup:AddButton(GetLoca("Play"))
    playEffectButton:Tooltip():AddText(GetLoca("For preview, some effects may not play correctly"))
    infoButton = popup:AddButton(GetLoca("Info"))

    infoButton.SameLine = true

    ApplyConfirmButtonStyle(playEffectButton)
    ApplyInfoButtonStyle(infoButton)

    playEffectButton.OnClick = function()
        previewEffect(self.selectedGuid or CGetHostCharacter(), entry)
    end

    infoButton.OnClick = function()
        EffectTab:Add(entry.Uuid, nil, entry.TemplateName)
    end
end

function EffectBrowser.Add(dataManager, searchData)
    local instance = EffectBrowser.new(dataManager, searchData)
    return instance
end