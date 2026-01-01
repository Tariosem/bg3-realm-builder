local ENTTAB_WIDTH = 1000 * SCALE_FACTOR
local ENTTAB_HEIGHT = 1200 * SCALE_FACTOR

---@class EntityTab
---@field guid string
---@field templateId string
---@field templateName string
---@field displayName string
---@field isVisible boolean
---@field parent ExtuiTreeParent?
---@field panel ExtuiWindowBase|ExtuiTabItem
---@field isAttach boolean
---@field isWindow boolean
---@field isValid boolean
---@field tabBar ExtuiTabBar
---@field monitorTab ExtuiTabItem
---@field new fun(guid:string, templateId:string?, parent:ExtuiTreeParent|nil, initAttach:boolean?):EntityTab
EntityTab = _Class("EntityTab")

local copiedTransform = {
}

---@param guid string
---@param templateId string?
---@param parent ExtuiTreeParent?
---@param initAttach boolean?
function EntityTab:__init(guid, templateId, parent, initAttach)
    self.guid = guid
    if templateId then
        self.templateId = templateId
        self.templateName = RBStringUtils.TrimTail(templateId, 37)
        if self.templateName == "" then
            self.templateName = templateId
        end
    else
        NetChannel.GetTemplate:RequestToServer({ Guid = guid }, function (data)
            if data and data.GuidToTemplateId[guid] then
                self.templateId = data.GuidToTemplateId[guid]
                self.templateName = RBStringUtils.TrimTail(self.templateId, 37)
                if self.templateName == "" then
                    self.templateName = data.TemplateId
                end
                if self.attrTable then
                    self.attrTable:SetValue("TemplateId", self.templateId)
                    self.attrTable:SetValue("TemplateName", self.templateName)
                end
                local templateObj = Ext.Template.GetTemplate(RBUtils.TakeTailTemplate(self.templateId))
                if templateObj.TemplateType == "character" then
                    self:RenderCharacterTab()
                elseif templateObj.TemplateType == "item" then
                    self:RenderItemTab()
                end
            end
        end)
    end

    self.displayName = RBGetName(guid) or ("Entity " .. tostring(guid))

    self.parent = parent or nil
    self.panel = nil
    self.visualTab = VisualTab.new(self.guid, self.displayName, nil, self.templateName) --[[@as VisualTab]]

    self.isAttach = initAttach or false
    self.isVisible = false
    self.isWindow = not self.isAttach
    self.isValid = true
end

function EntityTab:Render()
    self.isVisible = true

    self.panel = nil

    self.displayName = RBGetName(self.guid) or self.displayName

    if self.parent and self.isAttach then
        self.panel = self.parent:AddChildWindow(self.guid)
        self.isWindow = false
        self:OnAttach()
    else
        self.panel = WindowManager.RegisterWindow(self.guid, self.displayName, self.lastPosition, self.lastSize or {ENTTAB_WIDTH, ENTTAB_HEIGHT})
        self.panel.Closeable = true
        self.isWindow = true
        self:OnDetach()
    end

    self:RenderTabBar()
    self:RenderMonitorTab()
    self:RenderFilterTab()
    self:RenderVisualTab()

    local selfTemplate = Ext.Template.GetTemplate(RBUtils.TakeTailTemplate(self.templateId))
    if not selfTemplate then return end

    if selfTemplate.TemplateType == "character" then
        self:RenderCharacterTab()
    elseif selfTemplate.TemplateType == "item" then
        self:RenderItemTab()
    end
end

function EntityTab:RenderTabBar()
    self.tabBar = self.panel:AddTabBar("EntityTabTabBar")
end

local function debugEntity(guid)
    local template = EntityStore:GetStoredData(guid).TemplateId
    local templateObj = Ext.Template.GetTemplate(RBUtils.TakeTailTemplate(template))

    local visualTemplate = templateObj and templateObj.VisualTemplate or nil

    if visualTemplate then
        _D(Ext.Resource.Get(visualTemplate, "Effect"))
    else
        Warning("No visual template found for entity with GUID: " .. guid)
    end

end

function EntityTab:RenderMonitorTab()
    local monitorTab = self.tabBar:AddTabItem("Monitor")

    local debugBtn = monitorTab:AddButton(GetLoca("Debug Entity"))
    debugBtn.OnClick = function()
        debugEntity(self.guid)
    end

    local attrs = {
        TemplateId = self.templateId,
        Guid = self.guid,
        TemplateName = self.templateName,
    }

    local attrTable = ImguiElements.AddReadOnlyAttrTable(monitorTab, attrs)
    self.attrTable = attrTable

    local levelLine = attrTable:AddNewLine("Level :")
    local levelTextMonitor = levelLine:AddInputText("") --[[@as ExtuiInputText]]
    levelTextMonitor.ReadOnly = true
    levelTextMonitor.AutoSelectAll = true
    levelTextMonitor.Text = self.LastLevel or "N/A"

    local levelTimer = Timer:Every(2000, function(timerID)
        if not self.isValid then
            return UNSUBSCRIBE_SYMBOL
        end

        local entity = Ext.Entity.Get(self.guid)

        if not entity then
            return UNSUBSCRIBE_SYMBOL
        end

        local level = entity and entity.Level and entity.Level.LevelName or nil
        if level then
            levelTextMonitor.Text = level
            self.LastLevel = level
        else
            levelTextMonitor.Text = self.LastLevel or "N/A"
        end
    end)


    local posLine = attrTable:AddNewLine("Position :")
    local positionMonitor = posLine:AddInputScalar("")
    positionMonitor.IDContext = self.guid .. "_PositionMonitor"
    positionMonitor.Components = 3
    positionMonitor.Value = self.LastTranslation or {0,0,0,0}

    local copyPosBtn = posLine:AddImageButton("##CopyPosBtn", RB_ICONS.Copy, IMAGESIZE.ROW)
    local pastePosBtn = posLine:AddImageButton("##PastePosBtn", RB_ICONS.Clipboard, IMAGESIZE.ROW)
    copyPosBtn.SameLine = true
    pastePosBtn.SameLine = true
    copyPosBtn:Tooltip():AddText(GetLoca("Copy Position"))
    pastePosBtn:Tooltip():AddText(GetLoca("Paste Position"))
    copyPosBtn:SetColor("Button", {0,0,0,0})
    pastePosBtn:SetColor("Button", {0,0,0,0})
    copyPosBtn.OnClick = function()
        local pos = {RBGetPosition(self.guid)}
        if pos and #pos == 3 then
            copiedTransform.Translate = {pos[1], pos[2], pos[3]}
        end
    end
    pastePosBtn.OnClick = function()
        if copiedTransform.Translate then
            Commands.SetTransform({MovableProxy.CreateByGuid(self.guid)}, { Translate = copiedTransform.Translate })
        end
    end

    positionMonitor.OnChange = function(sel)
        local newPos = {sel.Value[1], sel.Value[2], sel.Value[3]}
        Commands.SetTransform({MovableProxy.CreateByGuid(self.guid)}, { Translate = newPos })
    end
    local positionTimer = Timer:Every(1000, function(timerId)
        if not self.isValid then
            Timer:Cancel(timerId)
            return
        end

        local xp, yp, zp = RBGetPosition(self.guid)
        
        if not xp or not yp or not zp then
            positionMonitor.Value = self.LastTranslation or {0, 0, 0, 0}
            return
        end

        local x = RBStringUtils.FormatDecimal(xp, 2)
        local y = RBStringUtils.FormatDecimal(yp, 2)
        local z = RBStringUtils.FormatDecimal(zp, 2)

        if x and y and z then
            positionMonitor.Value = {x, y, z, 0}
            self.LastTranslation = {xp, yp, zp, 0}
        else
            positionMonitor.Value = {0, 0, 0, 0}
        end
    end)

    local quatLine = attrTable:AddNewLine("Rotation :")
    local rotationMonitor = quatLine:AddInputScalar("")
    rotationMonitor.IDContext = self.guid .. "_RotationMonitor"
    rotationMonitor.Components = 3
    rotationMonitor.Value = self.LastRotation or {0,0,0,0}

    local copyRotBtn = quatLine:AddImageButton("##CopyRotationBtn", RB_ICONS.Copy, IMAGESIZE.ROW)
    local pasteRotBtn = quatLine:AddImageButton("##PasteRotationBtn", RB_ICONS.Clipboard, IMAGESIZE.ROW)
    copyRotBtn.SameLine = true
    pasteRotBtn.SameLine = true
    copyRotBtn:Tooltip():AddText(GetLoca("Copy Rotation"))
    pasteRotBtn:Tooltip():AddText(GetLoca("Paste Rotation"))
    copyRotBtn:SetColor("Button", {0,0,0,0})
    pasteRotBtn:SetColor("Button", {0,0,0,0})
    copyRotBtn.OnClick = function()
        local quat = {EntityHelpers.GetQuatRotation(self.guid)}
        if quat and #quat == 4 then
            copiedTransform.RotationQuat = {quat[1], quat[2], quat[3], quat[4]}
        end
    end
    pasteRotBtn.OnClick = function()
        if copiedTransform.RotationQuat then
            Commands.SetTransform({MovableProxy.CreateByGuid(self.guid)}, { RotationQuat = copiedTransform.RotationQuat })
        end
    end

    rotationMonitor.OnChange = function(sel)
        local delta = {sel.Value[1], sel.Value[2], sel.Value[3]}
        for i=1,3 do
            if self.LastRotation then
                delta[i] = math.rad(delta[i] - self.LastRotation[i])
            end
        end
        local deltaQuat = Ext.Math.QuatFromEuler(delta)
        local finalQuat = Ext.Math.QuatMul(self.LastQuatRotation, deltaQuat)
        Commands.SetTransform({MovableProxy.CreateByGuid(self.guid)}, { RotationQuat = finalQuat })
    end

    local rotationTimer = Timer:Every(1000, function(timerId)
        if not self.isValid then
            return UNSUBSCRIBE_SYMBOL
        end
        if not EntityHelpers.EntityExists(self.guid) then
            rotationMonitor.Value = self.LastRotation or {0, 0, 0, 0}
            return
        end
        if ImguiHelpers.IsFocused(rotationMonitor) then
            return
        end

        local quat = {EntityHelpers.GetQuatRotation(self.guid)}
        if not quat or #quat ~= 4 then
            rotationMonitor.Value = self.LastRotation or {0, 0, 0, 0}
            return
        end
        local RADs = MathUtils.QuatToEuler(quat)
        for i=1,3 do
            RADs[i] = math.deg(RADs[i])
        end

        local rx, ry, rz = RADs[1], RADs[2], RADs[3]
        if not ry or not rx or not rz then
            rotationMonitor.Value = self.LastRotation or {0, 0, 0, 0}
            return
        end

        local xf = RBStringUtils.FormatDecimal(rx, 2)
        local yf = RBStringUtils.FormatDecimal(ry, 2)
        local zf = RBStringUtils.FormatDecimal(rz, 2)
        if xf and yf and zf then
            rotationMonitor.Value = {xf, yf, zf, 0}
            self.LastRotation = {xf, yf, zf, 0}
            self.LastQuatRotation = {quat[1], quat[2], quat[3], quat[4]}
        else
            rotationMonitor.Value = self.LastRotation or {0, 0, 0, 0}
        end

    end)

    local scaleLine = attrTable:AddNewLine("Scale :")
    local scaleTextMonitor = scaleLine:AddInputScalar("") --[[@as ExtuiInputScalar]]
    scaleTextMonitor.IDContext = self.guid .. "_ScaleMonitor"
    scaleTextMonitor.Value = self.LastScale or {1,1,1,0}
    scaleTextMonitor.Components = 3

    scaleTextMonitor.OnChange = function(sel)
        local newScale = {sel.Value[1], sel.Value[2], sel.Value[3]}
        Commands.SetTransform({MovableProxy.CreateByGuid(self.guid)}, { Scale = newScale })
    end

    local scaleTimer = Timer:Every(2000, function (timerID)
        if not self.isValid then
            return UNSUBSCRIBE_SYMBOL
        end

        local sx, sy, sz = RBGetScale(self.guid)

        if not sx or not sy or not sz then
            scaleTextMonitor.Value = self.LastScale or {1, 1, 1, 0}
            return
        end

        local x = RBStringUtils.FormatDecimal(sx, 2)
        local y = RBStringUtils.FormatDecimal(sy, 2)
        local z = RBStringUtils.FormatDecimal(sz, 2)

        if x and y and z then
            scaleTextMonitor.Value = {x, y, z, 0}
            self.LastScale = {sx, sy, sz, 0}
        else
            scaleTextMonitor.Value = {1, 1, 1, 0}
        end
    end)

    self.monitorTimers = { positionTimer, rotationTimer, levelTimer, scaleTimer }
end

function EntityTab:RenderFilterTab()
    self.filterTab = self.tabBar:AddTabItem(GetLoca("Filters"))

    local entInfo = EntityStore[self.guid] or {}

    self.iconTintColorEdit = self.filterTab:AddColorEdit(GetLoca("Icon Tint Color"))
    self.iconTintColorEdit.Color = entInfo.IconTintColor or {1,1,1,1}
    self.iconTintColorEdit.AlphaBar = true
    self.iconTintColorEdit.OnChange = function(color)
        entInfo.IconTintColor = color.Color
        self:UpdateFilterTab()
        self:OnChange()
    end

    self.noteInput = self.filterTab:AddInputText(GetLoca("Note"), entInfo.Note or "")

    self.noteInput.OnChange = function(text)
        entInfo.Note = text.Text
        self:OnChange()
    end

    self.groupInput = self.filterTab:AddInputText(GetLoca("Group"), entInfo.Group or "")

    self.groupInput.OnChange = function(text)
        entInfo.Group = text.Text
        self:OnChange()
    end

    self.tagsInput = self.filterTab:AddInputText(GetLoca("Tags"))

    self.tagsAddButton = self.filterTab:AddButton("+")
    self.tagsRemoveButton = self.filterTab:AddButton(" - ")

    self.tagsAddTooltip = self.tagsAddButton:Tooltip()
    self.tagsAddTooltip:AddText(GetLoca("Add Tag"))
    self.tagsRemoveTooltip = self.tagsRemoveButton:Tooltip()
    self.tagsRemoveTooltip:AddText(GetLoca("Remove Tag"))

    self.tagsPrefix = self.filterTab:AddText(GetLoca("Tags") .. ":")
    self.allTags = self.filterTab:AddText(">")

    self.tagsPrefix.SameLine = true
    self.tagsRemoveButton.SameLine = true
    self.allTags.SameLine = true

    local function updateTags()
        local tags = entInfo.Tags or {}
        local tagStr = table.concat(tags, ", ")
        self.allTags.Label = tagStr
    end

    self.tagsInput.OnChange = function(text)
        if text.Text == "" then
            ImguiHelpers.SetImguiDisabled(self.tagsAddButton, true)
            ImguiHelpers.SetImguiDisabled(self.tagsRemoveButton, true)
        else
            ImguiHelpers.SetImguiDisabled(self.tagsAddButton, false)
            ImguiHelpers.SetImguiDisabled(self.tagsRemoveButton, false)
        end
    end

    self.tagsAddButton.OnClick = function()
        local tag = self.tagsInput.Text
        if tag and tag ~= "" then
            if not entInfo.Tags then
                entInfo.Tags = {}
            end
            if table.find(entInfo.Tags, tag) then
                Warning("[EntityTab] Cannot add duplicate tag: " .. tag .. " for GUID: " .. self.guid)
                return
            end
            table.insert(entInfo.Tags, tag)
            self.tagsInput.Text = ""
            self.tagsAddButton.Disabled = true
            self.tagsRemoveButton.Disabled = true
            updateTags()
            self:OnChange()
        else
            Warning("[EntityTab] Cannot add empty tag for GUID: " .. self.guid)
        end
    end

    self.tagsRemoveButton.OnClick = function()
        local tag = self.tagsInput.Text
        if tag and tag ~= "" then
            if table.find(entInfo.Tags, tag) then
                RBTableUtils.ToggleEntry(entInfo.Tags, tag)
            else
                Warning("[EntityTab] Cannot remove tag that doesn't exist: " .. tag .. " for GUID: " .. self.guid)
                return
            end
            self.tagsInput.Text = ""
            self.tagsAddButton.Disabled = true
            self.tagsRemoveButton.Disabled = true
            updateTags()
            self:OnChange()
        else
            Warning("[EntityTab] Cannot remove empty tag for GUID: " .. self.guid)
        end
    end

    updateTags()

    self.tagsAddButton.Disabled = true
    self.tagsRemoveButton.Disabled = true
end

function EntityTab:UpdateFilterTab()
    if not self.isValid or not self.isVisible then
        return
    end

    if not self.filterTab then
        return
    end

    local entInfo = EntityStore[self.guid] or {}

    self.iconTintColorEdit.Color = entInfo.IconTintColor or {1,1,1,1}
    self.noteInput.Text = entInfo.Note or ""
    self.groupInput.Text = entInfo.Group or ""

    self.iconTintColorEdit.Color = entInfo.IconTintColor or {1,1,1,1}
    local tintColor = entInfo.IconTintColor or {1,1,1,1}

    if self.visualTab and self.visualTab.isVisible and self.visualTab.isWindow then
        self.visualTab.symbol.Tint = tintColor
    end

    local tags = entInfo.Tags or {}
    local tagStr = table.concat(tags, ", ")
    self.allTags.Label = tagStr
end

function EntityTab:RenderVisualTab()

    local vT = self.visualTab
    if not vT then
        self.visualTab = VisualTab:Add(self.guid, self.displayName, self.tabBar, self.templateName) --[[@as VisualTab]]
    elseif vT and vT.isWindow then
        vT.parent = self.tabBar
        if vT.panel then
            vT.panel.Open = true
        end
    elseif vT then
        vT.parent = self.tabBar
        vT:Refresh()
    end

    self.visualTab.OnDetach = function()
        if self.visualTabPlaceHolder then
            self.visualTabPlaceHolder:Destroy()
            self.visualTabPlaceHolder = nil
        end

        self.visualTabPlaceHolder = self.tabBar:AddTabItem(GetLoca("Visual"))
        self.visualTabPlaceHolder:AddButton("Attach").OnClick = function()
            if self.visualTab and self.visualTab.isWindow then
                self.visualTabPlaceHolder:Destroy()
                self.visualTabPlaceHolder = nil
                self.visualTab.parent = self.tabBar
                self.visualTab.isAttach = true
                self.visualTab:Refresh()
            end
        end
    end

    self.visualTab.OnAttach = function()
        if self.visualTabPlaceHolder then
            self.visualTabPlaceHolder:Destroy()
            self.visualTabPlaceHolder = nil
        end
    end

    if self.visualTab and self.visualTab.isWindow then
        self.visualTab:OnDetach()
    end
end

function EntityTab:Collapsed()
    if not self.isValid and not self.isVisible then return end

    if self.visualTab then
        self.visualTab.OnAttach = function () end
        self.visualTab.OnDetach = function () end
    end

    if self.visualTabPlaceHolder then
        self.visualTabPlaceHolder:Destroy()
        self.visualTabPlaceHolder = nil
    end

    if self.visualTab and not self.visualTab.isWindow then
        self.visualTab:Collapsed()
    end

    for _,timer in pairs(self.monitorTimers or {}) do
        if timer then
            Timer:Cancel(timer)
        end
    end

    if self.copySub then
        self.copySub:Unsubscribe()
        self.copySub = nil
    end

    if self.displayNameInputKeySub then
        self.displayNameInputKeySub:Unsubscribe()
        self.displayNameInputKeySub = nil
    end

    if self.tabBar then
        self.tabBar = nil
    end

    if not self.isWindow and self.panel then
        self.panel:Destroy()
        self.panel = nil
    else
        --- @diagnostic disable-next-line
        WindowManager.DeleteWindow(self.panel)
        self.panel = nil
    end

    if self.visualTab then
        self.visualTab.parent = nil
    end

    self.isWindow = false
    self.isVisible = false
end

function EntityTab:Destroy()
    if not self.isValid then
        return
    end

    if self.visualTab and self.visualTab.isValid then
        self.visualTab:Destroy()
        self.visualTab = nil
    end

    if self.panel then
        self:Collapsed()
    end

    self.isValid = false
end

function EntityTab:IsEntityValid()
    if not self.isValid then
        return false
    end

    if Ext.Entity.Get(self.guid) == nil then
        return false
    end

    return true
end

function EntityTab:Refresh()
    if self.isWindow and self.panel then
        self.lastPosition = self.panel.LastPosition
        self.lastSize = self.panel.LastSize
    end
    self:Collapsed()
    self:Render()
end

function EntityTab:Focus()
    if not self.isVisible then
        self:Render()
    end

    if self.parent and not self.isAttach and self.isWindow then
        if self.panel.Open == false then
            self.panel.Open = true 
        end
        ImguiHelpers.FocusWindow(self.panel)
    else
        Timer:After(100, function()
            if self.isWindow then
                return
            end

            if self.panel and self.panel.SetSelected then
                self.panel.SetSelected = false
            end
        end)
    end
end

function EntityTab:Attach(parent)
    self.isAttach = true
    self.parent = parent or self.parent
    self:Refresh()
end

function EntityTab:Add(guid, templateId, parent, opts, iconTintColor)
    local EntityTab = EntityTab.new(guid, templateId, parent, opts.IsAttach)
    EntityTab.IconTintColor = iconTintColor or {1,1,1,1}
    EntityTab:Render()
    return EntityTab
end

function EntityTab:OnChange() end
function EntityTab:OnAttach() end
function EntityTab:OnDetach() end

--- @type EsvItem
local serverItemTemplate = {
    Invisible = false,
    InteractionDisabled = false,
    FreezeGravity = false,
    CanBeMoved = true,
    CanClimbOn = true,
    CanBePickedUp = true,
    CanShootThrough = true,
    Sticky = false,
    Frozen = false,
    UseRemotely = false,
    WalkOn = false,
}

--- @type EsvCharacter
local serverCharacterTemplate = {
    CannotDie = false,
    Invulnerable = false,
    Invisible = false,
    CannotMove = false,
    CannotRun = false,
    CanShootThrough = true,
    SpotSneakers = false,
}

local readOnlyFields = {
    Level = true,
}

function EntityTab:RenderCharacterTab()
    local tabItem = self.tabBar:AddTabItem("Character")

    local alignedTable = ImguiElements.AddAlignedTable(tabItem)

    local leaderCombo = alignedTable:AddCombo("Follower Of")

    local currentLeader = self.__charcter_leader or nil
    local names = {}
    local nameToUuid = {}
    local function refreshParties()
        local allPMs = EntityHelpers.GetAllPartyMembers()
        
        names = { GetLoca("<None>") }
        nameToUuid = {}
        local currentIndex = 0
        for _,uuid in pairs(allPMs) do
            if uuid == self.guid then goto continue end
            local name = RBGetName(uuid) or ("Character " .. tostring(uuid))
            local cnt = 1
            while nameToUuid[name] do
                name = name .. " (" .. tostring(cnt) .. ")"
                cnt = cnt + 1
            end
            names[#names+1] = name
            nameToUuid[name] = uuid
            if currentLeader and uuid == currentLeader then
                currentIndex = #names - 1
            end
            ::continue::
        end

        leaderCombo.Options = names
        leaderCombo.SelectedIndex = currentIndex
    end

    leaderCombo.OnHoverEnter = refreshParties
    leaderCombo.OnChange = function ()
        local selectedName = leaderCombo.Options[leaderCombo.SelectedIndex + 1]
        local selectedUuid = nameToUuid[selectedName] or nil
        if not selectedUuid then
            NetChannel.CallOsiris:SendToServer({ Function = "RemovePartyFollower", Args = { self.guid, currentLeader } })
            currentLeader = nil
        else
            NetChannel.CallOsiris:SendToServer({ Function = "AddPartyFollower", Args = { self.guid, selectedUuid } })
            currentLeader = selectedUuid
        end
        self.__charcter_leader = currentLeader
    end

    --- @type EsvCharacter
    local serverCharacter = RBUtils.DeepCopy(serverCharacterTemplate)
    
    local function setServerCharacter()
        NetChannel.SetServerEntity:SendToServer({ Guid = self.guid, Data = { ServerCharacter = serverCharacter } })
    end

    local function renderEditor()
        ImguiElements.AddGeneralTableEditor(tabItem, serverCharacter, setServerCharacter)
    end

    NetChannel.GetServerEntity:RequestToServer({ Guid = self.guid, Data = { ServerCharacter = serverCharacter } }, function (data)
        serverCharacter = data.Data.ServerCharacter or serverCharacter
        pcall(renderEditor)
    end)
end

function EntityTab:RenderItemTab()
    local tabItem = self.tabBar:AddTabItem("Item")

    local serverItem = RBUtils.DeepCopy(serverItemTemplate)

    local function setServerItem()
        NetChannel.SetServerEntity:SendToServer({ Guid = self.guid, Data = { ServerItem = serverItem } })
    end

    local function renderEditor()
        ImguiElements.AddGeneralTableEditor(tabItem, serverItem, setServerItem)
    end

    NetChannel.GetServerEntity:RequestToServer({ Guid = self.guid, Data = { ServerItem = serverItem } }, function (data)
        serverItem = data.Data.ServerItem or serverItem
        pcall(renderEditor)
    end)
end

