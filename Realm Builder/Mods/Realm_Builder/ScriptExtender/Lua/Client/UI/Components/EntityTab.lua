local ENTTAB_WIDTH = 1000 * SCALE_FACTOR
local ENTTAB_HEIGHT = 1200 * SCALE_FACTOR

EntityTab = _Class("ItemTab")

---@class EntityTab
---@field guid string
---@field templateId string
---@field templateName string
---@field displayName string
---@field isVisible boolean
---@field parent ExtuiTabBar|nil
---@field panel ExtuiWindowBase|ExtuiTabItem
---@field isAttach boolean
---@field isWindow boolean
---@field persistent boolean

---@param guid string
---@param templateId string
---@param parent ExtuiTabBar|nil
---@param initAttach boolean?
function EntityTab:__init(guid, templateId, parent, initAttach)
    self.guid = guid
    self.templateId = templateId
    self.templateName = TrimTail(templateId, 37)
    if self.templateName == "" then
        self.templateName = templateId
    end

    self.displayName = EntityStore[guid] and EntityStore[guid].DisplayName or "Unknown"

    self.parent = parent or nil
    self.panel = nil
    local _,visualtab = CheckWindowExists(self.guid, "VisualTab")
    self.visualTab = visualtab or VisualTab.new(self.guid, self.displayName, nil, self.templateName)

    self.isAttach = initAttach or false
    self.isVisible = false
    self.isWindow = not self.isAttach
    self.isValid = true

    self.deleteAction = function()
        if self.persistent then
            return
        end
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure you want to delete") .. " " .. self.displayName .. "?",
            function()
                NetChannel.Delete:SendToServer({ Guid = self.guid })
            end,
            nil
        )
    end


end

function EntityTab:Render()
    self.isVisible = true

    self.panel = nil

    self.displayName = GetDisplayNameFromGuid(self.guid) or self.displayName

    if self.parent and self.isAttach then
        self.panel = self.parent:AddChildWindow(self.guid)
        self.isWindow = false
        self:OnAttach()
    else
        self.panel = RegisterWindow(self.guid, self.displayName, "Prop Tab", self, self.lastPosition, self.lastSize or {ENTTAB_WIDTH, ENTTAB_HEIGHT})
        self.panel.Closeable = true
        self.isWindow = true
        self:OnDetach()
    end

    self:RenderProfile()
    self:RenderMainEditor()
    self:RenderTabBar()
    self:RenderMonitorTab()
    self:RenderFilterTab()
    self:RenderVisualTab()
end

function EntityTab:RenderProfile()

    local profileHeader = self.panel

    self.profile = AddLeftAlignTable(profileHeader)
    self.profile.ColumnDefs[1] = { WidthFixed = true, Width = 168 * SCALE_FACTOR }

    self.profileRow = self.profile:AddRow()
    self.IconContainer = self.profileRow:AddCell()
    self.Icon = self.IconContainer:AddImageButton(self.guid, GetIcon(self.guid), Vec2.new(168, 168) * SCALE_FACTOR)
    self.Icon:SetColor("Button", ToVec4(0))
    self.Icon.Tint = EntityStore[self.guid] and EntityStore[self.guid].IconTintColor or {1,1,1,1}

    self.IdsContainer = self.profileRow:AddCell()

    local topRightTable = AddRightAlighTable(self.IdsContainer)
    local row = topRightTable:AddRow()
    local left = row:AddCell()
    local right = row:AddCell()

    self.displayNameButton = left:AddButton(GetLoca("Display Name"))
    self.displayNameButton:Tooltip():AddText(GetLoca("Change how this prop's name is displayed in the UI"))

    self.displayNameInput = left:AddInputText("", self.displayName)
    self.displayNameInput.SameLine = true

    self.displayNameInputKeySub = SubscribeKeyInput({ Key = "RETURN" }, function()
        if self.displayNameButton and IsFocused(self.displayNameInput) then
            self.displayNameButton:OnClick()
        end
    end)

    self.displayNameButton.OnClick = function(Input)
        local text = self.displayNameInput.Text
        if text and text ~= "" then
            self.displayName = EntityStore:RegisterDisplayName(text, self.guid, self.displayName)
            self.displayNameInput.Text = self.displayName
            self.visualTab.displayName = self.displayName
            if not self.isWindow then
                self.panel.Label = self.displayName
            end
            EntityStore[self.guid].DisplayName = self.displayName
            self:RequestUpdate()
            self:Refresh()
            if self.visualTab.isWindow then
                self.visualTab:Refresh()
            end
            self:Focus()
        else
            self.displayNameInput.Text = self.displayName
        end
    end


    self.detachButton = nil

    if self.parent and self.isAttach then
        self.detachButton = right:AddButton(GetLoca("Detach"))
    else
        self.detachButton = right:AddButton(GetLoca("Attach"))
    end

    self.detachButton.OnClick = function()
        self.isAttach = not self.isAttach
        self.isVisible = true
        self:Refresh()
    end
    
    if self.isWindow then
        self.panel.OnClose = self.detachButton.OnClick
    end

    self.detachButton:Tooltip():AddText(GetLoca("Right click to collapse the tab"))

    self.detachButton.OnRightClick = function()
        self:Collapsed()
    end
end

function EntityTab:RenderMainEditor()

    self.mainEditor = self.IdsContainer

    self.persistentCheck = self.mainEditor:AddCheckbox(GetLoca("Lock"), self.persistent or false)
    self.persistentCheck:Tooltip():AddText(GetLoca("Won't be deleted when delete all."))
    self.persistentCheck.OnChange = function()
        local data = {
            Guid = self.guid,
            Attributes = {
                Persistent = self.persistentCheck.Checked
            }
        }
        NetChannel.SetAttributes:SendToServer(data)
        self.deleteButton.Disabled = data.Attributes.Persistent
        self.persistent = self.persistentCheck.Checked
    end
    
    self.deleteButton = self.mainEditor:AddButton(GetLoca("Delete"))
    ApplyDangerButtonStyle(self.deleteButton)
    self.deleteButton.OnClick = function()
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure you want to delete") .. " " .. self.displayName .. "?",
            function()
                Commands.DeleteCommand(self.guid)
            end)
    end

    if self.persistent then
        self.deleteButton.Disabled = true
    end


    self.duplicateButton = self.mainEditor:AddButton(GetLoca("Duplicate"))
    self.duplicateButton.OnClick = function()
        Commands.DuplicateCommand(self.guid)
    end

    self.addToFavoritesButton = self.mainEditor:AddButton(GetLoca("Add to Favorites"))
    self.addToFavoritesButton:Tooltip():AddText(GetLoca("Add a 'Favorite' tag to its template"))
    self.addToFavoritesButton.OnClick = function()
        local uuid = GetTemplateId(self.guid)
        if uuid and uuid ~= "" then
            RB_ItemManager:AddTagToData(uuid, "Favorite")
        else
            Warning("[EntityTab] Cannot add to favorites, no template ID found for GUID: " .. self.guid)
        end
        self:OnChange(true)
    end

    self.duplicateButton.SameLine = true
    self.addToFavoritesButton.SameLine = true
end

function EntityTab:RenderTabBar()
    self.lowerTab = self.panel:AddChildWindow("EntityTabLower")
    self.tabBar = self.lowerTab:AddTabBar("EntityTabTabBar")
end

local function debugEntity(guid)
    local template = EntityStore:GetStoredData(guid).TemplateId
    local templateObj = Ext.Template.GetTemplate(TakeTailTemplate(template))

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

    local templateIdText = AddReadOnlyInput(monitorTab, "TemplateId" .. ": ", TakeTailTemplate(self.templateId), true)

    if #self.templateId > 36 then
        local templateNameText = AddReadOnlyInput(monitorTab, GetLoca("Template Name") .. ": ", self.templateName, true)
    end

    self.guidText = AddReadOnlyInput(monitorTab, "Guid" .. ": ", self.guid, true)

    self.levelTextMonitor = AddReadOnlyInput(monitorTab, GetLoca("Level") .. ": ", "N/A", true)

    self.levelTimer = Timer:Every(2000, function()
        if not self.isValid then
            if self.levelTimer then
                Timer:Cancel(self.levelTimer)
            end
            self.levelTimer = nil
            return UNSUBSCRIBE_SYMBOL
        end

        local entity = Ext.Entity.Get(self.guid)

        if not entity then
            return UNSUBSCRIBE_SYMBOL
        end

        local level = entity and entity.Level and entity.Level.LevelName or nil
        if level then
            self.levelTextMonitor.Text = level
            self.LastLevel = level
        else
            self.levelTextMonitor.Text = self.LastLevel or "N/A"
        end
    end)

    local positionMonitor = monitorTab:AddInputScalar(GetLoca("Position"))
    positionMonitor.Components = 3

    positionMonitor.OnChange = function(sel)
        local newPos = {sel.Value[1], sel.Value[2], sel.Value[3]}

        Commands.SetTransform(MovableProxy.CreateByGuid(self.guid), { Translate = newPos })
    end
    self.positionTimer = Timer:Every(1000, function()
        if not self.isValid then
            if self.positionTimer then
                Timer:Cancel(self.positionTimer)
            end
            self.positionTimer = nil
            return
        end

        local xp, yp, zp = CGetPosition(self.guid)
        
        if not xp or not yp or not zp then
            positionMonitor.Value = self.LastTranslation or {0, 0, 0, 0}
            return
        end

        local x = FormatDecimal(xp, 2)
        local y = FormatDecimal(yp, 2)
        local z = FormatDecimal(zp, 2)

        if x and y and z then
            positionMonitor.Value = {x, y, z, 0}
            self.LastTranslation = {xp, yp, zp, 0}
        else
            positionMonitor.Value = {0, 0, 0, 0}
        end
    end)

    local rotationMonitor = monitorTab:AddInputScalar(GetLoca("Rotation"))
    rotationMonitor.Components = 3

    rotationMonitor.OnChange = function(sel)
        local delta = {sel.Value[1], sel.Value[2], sel.Value[3]}
        for i=1,3 do
            if self.LastRotation then
                delta[i] = math.rad(delta[i] - self.LastRotation[i])
            end
        end
        local deltaQuat = Ext.Math.QuatFromEuler(delta)
        local finalQuat = Ext.Math.QuatMul(self.LastQuatRotation, deltaQuat)
        Commands.SetTransform(MovableProxy.CreateByGuid(self.guid), { RotationQuat = finalQuat })
    end

    self.rotationTimer = Timer:Every(1000, function()
        if not self.isValid then
            if self.rotationTimer then
                Timer:Cancel(self.rotationTimer)
            end
            self.rotationTimer = nil
            return
        end
        if not EntityExists(self.guid) then
            rotationMonitor.Value = self.LastRotation or {0, 0, 0, 0}
            return
        end
        if IsFocused(rotationMonitor) then
            return
        end

        local quat = {GetQuatRotation(self.guid)}
        if not quat or #quat ~= 4 then
            rotationMonitor.Value = self.LastRotation or {0, 0, 0, 0}
            return
        end
        local RADs = QuatToEuler(quat)
        for i=1,3 do
            RADs[i] = math.deg(RADs[i])
        end

        local rx, ry, rz = RADs[1], RADs[2], RADs[3]
        if not ry or not rx or not rz then
            rotationMonitor.Value = self.LastRotation or {0, 0, 0, 0}
            return
        end

        local xf = FormatDecimal(rx, 2)
        local yf = FormatDecimal(ry, 2)
        local zf = FormatDecimal(rz, 2)
        if xf and yf and zf then
            rotationMonitor.Value = {xf, yf, zf, 0}
            self.LastRotation = {xf, yf, zf, 0}
            self.LastQuatRotation = {quat[1], quat[2], quat[3], quat[4]}
        else
            rotationMonitor.Value = self.LastRotation or {0, 0, 0, 0}
        end

    end)

    self.monitorTimers = { self.positionTimer, self.rotationTimer, self.levelTimer }

    local releasePropBtn = monitorTab:AddButton(GetLoca("Release Prop"))
    releasePropBtn:Tooltip():AddText(GetLoca("Release the prop so it won't be tracked by Realm Builder anymore."))
    releasePropBtn.SameLine = true

    releasePropBtn.OnClick = function()
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure you want to release") .. " " .. self.displayName .. "?",
            function()
                NetChannel.ManageEntity:SendToServer({
                    Action = "Remove",
                    Guid = self.guid,
                })
                self:Destroy()
                EntityStore:RemoveProp(self.guid)
                DeleteWindowsByGuid(self.guid)
            end,
            nil
        )
    end
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
            SetImguiDisabled(self.tagsAddButton, true)
            SetImguiDisabled(self.tagsRemoveButton, true)
        else
            SetImguiDisabled(self.tagsAddButton, false)
            SetImguiDisabled(self.tagsRemoveButton, false)
        end
    end

    self.tagsAddButton.OnClick = function()
        local tag = self.tagsInput.Text
        if tag and tag ~= "" then
            if not entInfo.Tags then
                entInfo.Tags = {}
            end
            if TableContains(entInfo.Tags, tag) then
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
            if TableContains(entInfo.Tags, tag) then
                ToggleEntry(entInfo.Tags, tag)
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
    self.Icon.Tint = tintColor

    if self.visualTab and self.visualTab.isVisible and self.visualTab.isWindow then
        self.visualTab.symbol.Tint = tintColor
    end

    local tags = entInfo.Tags or {}
    local tagStr = table.concat(tags, ", ")
    self.allTags.Label = tagStr
end

function EntityTab:RenderVisualTab()

    self.detachButton.Disabled = true

    if not self.visualTab then
        Timer:After(500, function ()
            self.visualTab = VisualTab:Add(self.guid, self.displayName, self.tabBar, self.templateName)
            self.detachButton.Disabled = false
        end)
    elseif self.visualTab and self.visualTab.isWindow then
        self.visualTab.parent = self.tabBar
        if self.visualTab.panel then
            self.visualTab.panel.Open = true
        end
        self.detachButton.Disabled = false
    elseif self.visualTab then
        self.visualTab.parent = self.tabBar
        self.visualTab:Refresh()
        self.detachButton.Disabled = false
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

    if self.positionTimer then
        Timer:Cancel(self.positionTimer)
        self.positionTimer = nil
    end

    if self.rotationTimer then
        Timer:Cancel(self.rotationTimer)
        self.rotationTimer = nil
    end

    if self.levelTimer then
        Timer:Cancel(self.levelTimer)
        self.levelTimer = nil
    end

    if self.displayNameInputKeySub then
        self.displayNameInputKeySub:Unsubscribe()
        self.displayNameInputKeySub = nil
    end

    if not self.isWindow and self.panel then
        self.panel:Destroy()
        self.panel = nil
    else
        DeleteWindow(self.panel)
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

    self.Tags = {}
    self.Group = ""
    self.Note = ""

    if self.replaceSub then
        self.replaceSub:Unsubscribe()
        self.replaceSub = nil
    end

    if self.presisSub then
        self.persisSub:Unsubscribe()
        self.persisSub = nil
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
        FocusWindow(self.panel)
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
    local initAttach = TableContains(opts or {}, "IsAttach")

    local EntityTab = EntityTab.new(guid, templateId, parent, initAttach)
    EntityTab.IconTintColor = iconTintColor or {1,1,1,1}
    EntityTab:Render()
    return EntityTab
end

function EntityTab:OnChange() end
function EntityTab:RequestUpdate() end

function EntityTab:OnAttach() end
function EntityTab:OnDetach() end