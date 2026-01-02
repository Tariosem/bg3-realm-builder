--- @class EffectBrowser : IconBrowser
--- @field SaveToConfig fun(self:EffectBrowser)
EffectBrowser = _Class("EffectBrowser", IconBrowser)

function EffectBrowser:SubclassInit()
    self.iconTooltipName = "EffectName"
    self.tooltipNameOptions = {
        "EffectName",
        "SpellName",
        "Uuid",
    }
    self.selectedFields = {
        EffectName = true,
        SpellName = true,
        Uuid = true,
    }
end

local function previewEffect(guid, entry)
    --- @type RB_EffectPlayData[]
    local effectsData = {} 
    local FxNames = entry.FxNames or {}
    if #FxNames == 0 then
        return
    end
    for _, fxName in ipairs(FxNames) do
        local fxData = RB_GLOBALS.MultiEffectManager.Data[fxName] or {}

        --- @type RB_EffectPlayData
        local effectData = {
            Object = guid,
            Target = guid,
            FxName = fxName,
            TargetBone = fxData.TargetBone or "",
            SourceBone = fxData.SourceBone or "",
            Flags = {
                PlayBeamEffect = fxData.isBeam or false,
            }
        }
        
        local loopEffectData = RBUtils.DeepCopy(effectData)
        loopEffectData.Flags.PlayLoop = true
        loopEffectData.Duration = 5000

        
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

    local iconSize = { self.iconWidth, self.iconWidth }
    if not self.iconToName then
        iconImage = cell:AddImageButton(entry.Uuid, entry.Icon)
        if iconImage.Image.Icon == "" then
           iconImage:Destroy()
           iconImage = cell:AddImageButton(entry.Uuid, "Item_Unknown")
        end

        if self.iconButtonBgColor then
            iconImage.Background = self.iconButtonBgColor
        end
        iconImage.Image.Size = iconSize
    else
        local image = cell:AddImage(entry.Icon, iconSize)
        iconImage = cell:AddSelectable(entry[self.iconTooltipName] or "Unknown")
        iconImage.SameLine = true
    end
    
    iconImage.OnClick = function()
        if not popup then
            popup = cell:AddPopup("IconPopup")
            popup.IDContext = entry.Uuid .. "Popup" .. RBUtils.Uuid_v4()

            local attrs = {
                Uuid = entry.Uuid,
                EffectName = entry.EffectName,
                Icon = entry.Icon,
            }

            ImguiElements.AddReadOnlyAttrTable(popup, attrs)
        end
        popup:Open()

        if self.iconToName then
            iconImage.Selected = false
        end
    end

    iconImage.OnHoverEnter = function ()
        if rPopup then return end
        rPopup = cell:AddPopup("SpawnPopup")
        rPopup.IDContext = entry.Uuid .. "SpawnPopup" .. RBUtils.Uuid_v4()
        
        self:RenderCustomizationTab(rPopup, entry)
        self:RenderPlayEffectPopup(function() return rPopup end, entry, iconImage)
    end

    iconImage.OnRightClick = function()
        if not rPopup then
            rPopup = cell:AddPopup("SpawnPopup")
            rPopup.IDContext = entry.Uuid .. "SpawnPopup" .. RBUtils.Uuid_v4()
            
            self:RenderCustomizationTab(rPopup, entry)
            self:RenderPlayEffectPopup(function() return rPopup end, entry, iconImage)
        end
        rPopup:Open()
    end

    popup = popup or nil
    rPopup = rPopup or nil

    iconImage.CanDrag = true
    iconImage.DragDropType = EffectDragDropFlag

    iconImage.UserData = {}

    iconImage.OnDragStart = function()
        iconSize = { self.iconWidth, self.iconWidth }
        iconImage.UserData.Effect = RBEffectUtils.CreateEffectDragDropDataFromEffect(entry)
        iconImage.DragPreview:AddImage(entry.Icon, iconSize)
        iconImage.DragPreview:AddText(entry[self.iconTooltipName] or "Unknown").SameLine = true
    end

    iconImage.OnDragEnd = function()
        Timer:Ticks(10, function (timerID)
            local pick = PickingUtils.GetPickingGuid()
            if not pick or pick == "" then
                pick = self.selectedGuid or RBGetHostCharacter()
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

    local function addTooltipNote()
        if entry.Note and entry.Note ~= "" then
            table.insert(noteElement, iconTooltip:AddSeparatorText(GetLoca("Note")))

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

    StyleHelpers.ApplyConfirmButtonStyle(playEffectButton)
    StyleHelpers.ApplyInfoButtonStyle(infoButton)

    playEffectButton.OnClick = function()
        previewEffect(self.selectedGuid or RBGetHostCharacter(), entry)
    end

    infoButton.OnClick = function()
        RBEffectTab.Add(entry.Uuid)
    end
end

function EffectBrowser.Add(dataManager, searchData)
    local instance = EffectBrowser.new(dataManager, searchData)
    return instance
end