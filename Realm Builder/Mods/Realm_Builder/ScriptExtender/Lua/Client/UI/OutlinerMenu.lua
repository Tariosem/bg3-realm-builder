--- @class OutlinerMenu
--- @field entityTabs table<string, EntityTab>
--- @field focus string -- currently focused tab guid
--- @field hotKeySubs table<string, RBSubscription>
--- @field hoveringKey string|nil
--- @field CollectionPopup ExtuiPopup
--- @field EntityPopup ExtuiPopup
OutlinerMenu = _Class("EntityMenu")

function OutlinerMenu:__init(parent)
    self.parent = parent
    
    self.isAttach = true

    self.store = EntityStore

    self.panel = nil
    self.isVisible = false
    self.isWindow = false
    self.isValid = true
    self.hoveringKey = nil
    self.hotKeySubs = {}
    self.selectedGuids = {}

    self.entityTabs = {}
end

function OutlinerMenu:NewEntityAdded(guids)
    local list = NormalizeGuidList(guids)

    for _, guid in ipairs(list) do
        local ent = EntityStore:GetStoredData(guid)
        if ent and not self.entityTabs[guid] then
            local opts = {}
            table.insert(opts, "IsAttach")
            self.entityTabs[guid] = self:CreateEntityTab(ent, opts)    
        end
    end
    self:UpdateList()
end

function OutlinerMenu:EntityDeleted(guids)
    local list = NormalizeGuidList(guids)
    for _, guid in ipairs(list) do
        if guid ~= nil and guid ~= "" then
            if self.entityTabs[guid] then
                self.entityTabs[guid]:Destroy()
                self.entityTabs[guid] = nil
            end
            
        end
    end
    self:UpdateList()
end

function OutlinerMenu:Render()
    if self.isAttach and self.parent then
        self.panel = self.parent:AddTabItem(GetLoca("Outliner"))
        self.isWindow = false
    else
        self.panel = RegisterWindow("generic", "Outliner", "Outliner", self)
        self.panel.Closeable = true
        self.panel.OnClose = function()
            self:ToggleDetach()
        end
        self.isWindow = true
    end

    self:RenderMenu()
    self:RenderSideBar()
    self:RenderMainArea()
end

function OutlinerMenu:ToggleDetach()
    self.isAttach = not self.isAttach
    self.imageRefs = {}

    for _,sub in pairs(self.hotKeySubs) do
        sub:Unsubscribe()
    end
    self.hoveringKey = nil

    self:Collapse()
    self:Render()

    for guid,tab in pairs(self.entityTabs) do
        tab.parent = self.mainArea
        if self.focus == guid then
            tab:Refresh()
        end
    end
end

function OutlinerMenu:RenderMenu()
    if self.isWindow then
        self.mainMenu = self.panel:AddMainMenu()
        self.debugMenu = self.mainMenu:AddMenu(GetLoca("Debug"))
        self.detachButton = self.mainMenu:AddMenu(GetLoca("Detach"))
    else
        local menuTable = self.panel:AddTable("PropsMenuMainMenuTable", 6)
        local menuRow = menuTable:AddRow()
        local debugCell = menuRow:AddCell()
        local detachCell = menuRow:AddCell()

        local debugOpenButton = debugCell:AddSelectable(GetLoca("Debug"))
        local detachButton = detachCell:AddSelectable(GetLoca("Detach"))

        self.debugMenu = debugCell:AddPopup("DebugMenu") --[[@as ExtuiPopup]]
        self.detachButton = detachButton
        debugOpenButton.OnClick = function()
            --- @diagnostic disable-next-line: param-type-mismatch
            self.debugMenu:Open()
            debugOpenButton.Selected = false
        end
    end

    self.detachButton.OnClick = function()
        self:ToggleDetach()
    end

    local bfDeleteAllOpe = function()
        ConfirmPopup:DangerConfirm(
            GetLoca("Are you sure?"),
            function()
                NetChannel.ManageEntity:SendToServer({
                    Action = "BFDA",
                })
            end,
            nil
        )
    end

    self.bruteForceDeleteAllButton = AddMenuButton(self.debugMenu, GetLoca("Deletes all props, ignoring filters or protections."), bfDeleteAllOpe, self.isWindow)
    ApplyDangerSelectableStyle(self.bruteForceDeleteAllButton)
end

function OutlinerMenu:RenderSideBar()
    local panel = self.panel:AddGroup("OutlinerTreeView")
    local tree = EntityStore.Tree

    local treeList = self.propTreeList or TreeList.new(panel, "Outliner", tree)
    treeList.parent = panel
    self.imageRefs = {}

    treeList.OnSelect = function(sel, selected)
        local arr = {}
        local proxies = {}
        for guid, _ in pairs(selected) do
            table.insert(arr, guid)
            table.insert(proxies, MovableProxy.CreateByGuid(guid))
        end
        RB_GLOBALS.TransformEditor:Select(proxies)
        self.selectedGuids = arr
    end

    treeList.OnDragDrop = function(sel, from, target)
        self:GroupLogic(from, target)
    end

    treeList.RenderLeaf = function(sel, key, node)
        local propData = EntityStore:GetStoredData(key)
        if not propData then
            Warning("Prop data missing for key: " .. key)
            return node:AddSelectable(key .. " (Missing)") --[[@as ExtuiSelectable]]
        end

        local displayName = propData and propData.DisplayName or key

        local icon = GetIcon(propData.Guid)

        local image = node:AddImageButton(propData.Guid, icon, {36, 36}) --[[@as ExtuiImageButton]]
        image.SameLine = true

        local selectable = node:AddSelectable(displayName .. "##" .. key) --[[@as ExtuiSelectable]]
        self:SetupLeaf(selectable, key, node)

        selectable.OnHoverEnter = function()
            self.hoveringKey = key
        end

        selectable.OnHoverLeave = function()
            self.hoveringKey = nil
        end
    
        self.imageRefs[key] = image
        image.Tint = propData.IconTintColor or {1,1,1,1}
        image:SetColor("Button", ToVec4(0))
        image.OnClick = function()
            NetChannel.SetAttributes:SendToServer({
                Guid = propData.Guid,
                Attributes = {
                    Visible = not propData.Visible
                }
            })
            propData.Visible = not propData.Visible
            SetAlphaByBool(image, propData.Visible)
            SetAlphaByBool(selectable, propData.Visible)
        end
        SetAlphaByBool(image, propData.Visible)
        SetAlphaByBool(selectable, propData.Visible)

        local function updateImageAlpha()
            propData = EntityStore:GetStoredData(key)
            if not propData then return end
            SetAlphaByBool(image, propData.Visible)
            SetAlphaByBool(selectable, propData.Visible)
        end

        image.UserData = {
            UpdateAlpha = updateImageAlpha
        }

        return selectable
    end

    treeList.RenderTree = function (sel, key, node)
        local treeSelectable = node:AddSelectable(key) --[[@as ExtuiSelectable]]

        local popup = node:AddPopup("TreeRightClickPopup" .. key)

        treeSelectable.OnHoverEnter = function()
            self.hoveringKey = key
        end

        treeSelectable.OnHoverLeave = function()
            self.hoveringKey = nil
        end

        self:SetupTree(treeSelectable, key, node)

        return treeSelectable
    end

    treeList.FilterFunc = function(sel, key, keywords)
        local words = SplitBySpace(keywords)
        local propData = EntityStore:GetStoredData(key)
        if not propData then
            if not tree:IsLeaf(key) then
                for _, word in ipairs(words) do
                    if string.find(string.lower(key), word) then return true end
                end
            end
            return false
        end

        for _, word in ipairs(words) do
            if string.find(string.lower(propData.DisplayName or ""), word) then return true end
        end

        return false
    end

    treeList.RenderOrder = function(aKey, bKey)
        if aKey == bKey then return false end
        if not aKey or not bKey then return false end
        
        local aName = tree:IsLeaf(aKey) and (EntityStore:GetStoredData(aKey) and EntityStore:GetStoredData(aKey).DisplayName or aKey) or aKey
        local bName = tree:IsLeaf(bKey) and (EntityStore:GetStoredData(bKey) and EntityStore:GetStoredData(bKey).DisplayName or bKey) or bKey

        --- always prefer trees over leaves
        if not tree:IsLeaf(aKey) and tree:IsLeaf(bKey) then
            return true
        elseif tree:IsLeaf(aKey) and not tree:IsLeaf(bKey) then
            return false
        end

        return string.lower(aName) < string.lower(bName)
    end

    treeList.OnRenameInput = function(sel, key, newName, selectable)
        local isEntity = EntityStore:GetStoredData(key)
        local oriName = isEntity and (isEntity.DisplayName or key) or key
        if oriName == newName then return end

        if isEntity then
            local originalDisplayName = isEntity.DisplayName
            local actualName = EntityStore:RegisterDisplayName(newName, key, originalDisplayName)
            selectable.Label = actualName
        else
            tree:Rename(key, newName)
        end
    end

    treeList:Render()

    self.propTreeList = treeList

    self:SetupSelectablePopup()
    self:SetupCollectionSelectablePopup()
end

function OutlinerMenu:SetupLeaf(sel, key, node)
    local selectable = sel

    selectable.SameLine = true

    local propData = EntityStore:GetStoredData(key) --[[@as EntityData]]
    selectable.OnRightClick = function()
        if not TableContains(self.selectedGuids, propData.Guid) and #self.selectedGuids < 2 then
            self.selectedGuids = { propData.Guid }
        end
        self:SetupSelectablePopup()
    end
    selectable.OnClick = function()
        self:FocusTab(key)
    end
end

function OutlinerMenu:SetupTree(sel, key, node)
    local selectable = sel

    selectable.SameLine = true

    selectable.OnRightClick = function()
        self.selectedTree = key
        self:SetupCollectionSelectablePopup()
    end
end

function OutlinerMenu:GroupLogic(from, target)
    if not from or not target or from == target then
        return
    end

    local tree = EntityStore.Tree

    local isFromTree = not tree:IsLeaf(from)
    local isTargetTree = not tree:IsLeaf(target)

    local groupReparent = function(target)
        for _, guid in ipairs(self.selectedGuids or {}) do
            tree:Reparent(guid, target)
        end
    end

    if isTargetTree then
        tree:Reparent(from, target)
        groupReparent(target)
    elseif not isTargetTree then
        local parent = tree:GetParentKey(target)
        if parent then
            tree:Reparent(from, parent)
            groupReparent(parent)
        else
            tree:Reparent(from)
            groupReparent(nil)
        end
    else
        
    end

    self.propTreeList:ClearSelection()
    self.selectedGuids = {}
    self:UpdateList()
end

function OutlinerMenu:SetupSelectablePopup()
    if self.EntityPopup then self.EntityPopup:Open() return end

    self.EntityPopup = self.propTreeList.panel:AddPopup("PropRightClickPopup") --[[@as ExtuiPopup]]
    local tree = EntityStore.Tree

    local contextMenu = StyleHelpers.AddContextMenu(self.EntityPopup)

    local function select()
        if not(self.selectedGuids and #self.selectedGuids > 0) then return end

        local map = {}
        for _, guid in ipairs(self.selectedGuids) do
            map[guid] = true
        end

        local proxies = {}
        for guid,_ in pairs(map) do
            table.insert(proxies, MovableProxy.CreateByGuid(guid))
        end
        
        RB_GLOBALS.TransformEditor:Select(proxies)
    end

    local function delete()
        if not(self.selectedGuids and #self.selectedGuids > 0) then return end
        
        local deleteMes = ""
        local guids = NormalizeGuidList(self.selectedGuids)
        for i=#guids,1,-1 do
            local guid = guids[i]
            local prop = EntityStore:GetStoredData(guid)
            if not prop then
                table.remove(guids, i)
            end
        end
        if #guids == 1 then
            deleteMes = string.format(GetLoca("Are you sure you want to delete '%s'?"), EntityStore[guids[1]].DisplayName or guids[1])
        else
            deleteMes = string.format(GetLoca("Are you sure you want to delete these %d props?"), #guids)
        end
        ConfirmPopup:DangerConfirm(
            deleteMes,
            function()
                NetChannel.Delete:SendToServer({ Guid = guids })
            end
        )
    end

    local function hideAndShow()
        if not(self.selectedGuids and #self.selectedGuids > 0) then return end

        for _, guid in ipairs(self.selectedGuids) do
            local prop = EntityStore:GetStoredData(guid)
            if not prop then goto continue end

            local data = {
                Guid = prop.Guid,
                Attributes = {
                    Visible = not prop.Visible
                }
            }
            NetChannel.SetAttributes:SendToServer(data)
            prop.Visible = not prop.Visible
            ::continue::
        end
        for _, guid in ipairs(self.selectedGuids) do
            if self.imageRefs and self.imageRefs[guid] and self.imageRefs[guid].UserData and self.imageRefs[guid].UserData.UpdateAlpha then
                self.imageRefs[guid].UserData.UpdateAlpha()
            end
        end
    end

    local function group()
        if not(self.selectedGuids and #self.selectedGuids > 0) then return end
        local baseName = GetLoca("New Collection")
        local name = baseName
        local cnt = 1
        while tree:Find(name) do
            cnt = cnt + 1
            name = baseName .. " ( " .. cnt .. " )"
        end
        local newTree = tree:ForceAddTree(name, tree:FindLCA(self.selectedGuids))
        for _, guid in ipairs(self.selectedGuids) do
            tree:Reparent(guid, name)
        end
        self.propTreeList:ClearSelection()
        self.selectedGuids = {}
        self:UpdateList()
    end

    --- @type RB_ContextItem[]
    local context = {
        {
            Label = GetLoca("Select"),
            OnClick = select,
            Hint = "Enter",
            HotKey = {
                Key = "RETURN",
            }
        },
        {
            Label = GetLoca("Hide/Show"),
            OnClick = hideAndShow,
            Hint = "Ctrl H",
            HotKey = {
                Key = "H",
                Modifiers = {"CTRL"}
            }
        },
        {
            Label = GetLoca("Group into Collection"),
            OnClick = group,
            Hint = "Ctrl G",
            HotKey = {
                Key = "G",
                Modifiers = {"CTRL"}
            }
        },
        {
            Label = GetLoca("Delete"),
            OnClick = delete,
            Hint = "Del",
            Danger = true,
            HotKey = {
                Key = "DEL",
            }
        },
    }

    for _, item in ipairs(context) do
        local selectable = contextMenu:AddItem(item.Label, item.OnClick, item.Hint)
        if item.Danger then
            ApplyDangerSelectableStyle(selectable)
        end

        if item.HotKey then
            self.hotKeySubs[item.Label] = SubscribeKeyAndMouse(function (e)
                local focus = self.hoveringKey ~= nil
                if not focus then return end
                if not e.Pressed then return end

                item.OnClick(selectable)
            end, item.HotKey)
        end
    end
end

function OutlinerMenu:SetupCollectionSelectablePopup()
    if self.CollectionPopup then self.CollectionPopup:Open() return end

    self.CollectionPopup = self.propTreeList.panel:AddPopup("CollectionRightClickPopup") --[[@as ExtuiPopup]]
    local tree = EntityStore.Tree

    local contextMenu = StyleHelpers.AddContextMenu(self.CollectionPopup)

    local function collectChildGuids(node, guids)
        if not node then return guids end
        for childKey,v in pairs(node) do
            if tree:IsLeaf(childKey) then
                table.insert(guids, childKey)
            else
                local childNode = tree:Find(childKey)
                if childNode then
                    collectChildGuids(childNode, guids)
                end
            end
        end
        return guids
    end

    local function hideAndShow()
        local targetKey = self.selectedTree or self.hoveringKey
        if not targetKey or tree:IsLeaf(targetKey) then return end

        local root = tree:Find(targetKey)
        local guids = collectChildGuids(root, {})
        for _, guid in ipairs(guids) do
            local prop = EntityStore:GetStoredData(guid)
            if not prop then goto continue end

            local data = {
                Guid = prop.Guid,
                Attributes = {
                    Visible = not prop.Visible
                }
            }
            NetChannel.SetAttributes:SendToServer(data)
            prop.Visible = not prop.Visible
            ::continue::
        end
        self.propTreeList:ClearSelection()
        self.selectedGuids = {}
        self:UpdateList()
    end

    local function deleteCollection()
        -- Deleting a collection only deletes the grouping, not the entities within
        local targetKey = self.selectedTree or self.hoveringKey
        if not targetKey or tree:IsLeaf(targetKey) then return end

        tree:RemoveButKeepChildren(targetKey)

        self.propTreeList:ClearSelection()
        self.selectedGuids = {}
        self:UpdateList()
    end

    local function openExportMenu()
        local targetKey = self.selectedTree or self.hoveringKey
        if not targetKey or tree:IsLeaf(targetKey) then return end

        local childs = tree:Find(targetKey)
        local guids = collectChildGuids(childs, {})

        local copy = EntityStore:GetExportCopy(guids)
        TemplateExportMenu.new(copy)
    end

    --- @type RB_ContextItem[]
    local context = {
        {
            Label = GetLoca("Hide/Show All in Collection"),
            OnClick = hideAndShow,
            Hint = "Ctrl H",
            HotKey = {
                Key = "H",
                Modifiers = {"CTRL"}
            }
        },
        {
            Label = GetLoca("Delete Collection"),
            OnClick = deleteCollection,
            Hint = "Del",
            Danger = true,
            HotKey = {
                Key = "DEL",
            }
        },
        {
            Label = GetLoca("Export Collection"),
            OnClick = openExportMenu,
        },
    }

    for _, item in ipairs(context) do
        local selectable = contextMenu:AddItem(item.Label, item.OnClick, item.Hint)
        if item.Danger then
            ApplyDangerSelectableStyle(selectable)
        end

        if item.HotKey then
            self.hotKeySubs[item.Label] = SubscribeKeyAndMouse(function (e)
                local focus = self.hoveringKey ~= nil
                if not focus then return end
                if not e.Pressed then return end

                item.OnClick(selectable)
            end, item.HotKey)
        end
    end
end

function OutlinerMenu:RenderMainArea()
    local panel = self.panel:AddGroup("OutlinerMainArea")

    self.mainArea = panel
end

function OutlinerMenu:CreateEntityTab(ent, opts)
    --self.props[prop.Guid] = prop

    local entityTab = nil

    if TableContains(opts, "Add") then
        entityTab = EntityTab:Add(ent.Guid, ent.TemplateId, self.mainArea, opts, ent.IconTintColor)
    else
        entityTab = EntityTab.new(ent.Guid, ent.TemplateId, self.mainArea, opts)
    end

    if entityTab then
        entityTab.OnChange = function()
            if not entityTab.isValid then return end

            if self.imageRefs and self.imageRefs[ent.Guid] then
                self.imageRefs[ent.Guid].Tint = EntityStore[ent.Guid].IconTintColor or {1,1,1,1}
            end            
        end

        entityTab.OnAttach = function()
            if self.focus and self.focus ~= ent.Guid and self.entityTabs[self.focus] then
                local tab = self.entityTabs[self.focus]
                tab.isAttach = false
                if not tab.isWindow then
                    tab:Collapsed()
                end
            end
        end
            
        return entityTab
    end

    Error("[PropsMenu] Failed to create entityTab for guid: " .. ent.Guid)
    return nil
end

function OutlinerMenu:FocusTab(guid, doDetach)
    local entityTab = self.entityTabs[guid]
    if guid == self.focus and entityTab.isVisible == false then
        self.focus = nil
    end
    if guid == self.focus and not doDetach then
        return
    end
    if self.focus and self.entityTabs[self.focus] then
        local tab = self.entityTabs[self.focus]
        tab.isAttach = false
        if not tab.isWindow then
            tab:Collapsed()
        end
    end

    local entityTab = self.entityTabs[guid]
    if entityTab and entityTab.isValid then
        entityTab.isAttach = not doDetach
        if entityTab.isWindow then
            FocusWindow(entityTab.panel)
        else
            entityTab:Refresh()
        end
        self.focus = guid
    end
end

function OutlinerMenu:FocusEntityVisualTab(guid)
    local entityTab = self.entityTabs[guid]
    if entityTab and entityTab.isValid then

        if entityTab.visualTab.isWindow and entityTab.visualTab.isVisible then
            FocusWindow(entityTab.visualTab.panel)
        else
            entityTab.visualTab.isAttach = false
            entityTab.visualTab:Refresh()
            FocusWindow(entityTab.visualTab.panel)
        end
        return true
    end
end

function OutlinerMenu:UpdateList()
    self.imageRefs = {}
    self.propTreeList:RenderList()
end

function OutlinerMenu:UpdateSelectableAlpha(guid)
    if self.imageRefs and self.imageRefs[guid] then
        local image = self.imageRefs[guid]
        image.UserData.UpdateAlpha()
    end
end

function OutlinerMenu:Collapse()
    if self.propTreeList then
        self.propTreeList:Collapsed()
    end

    if self.focus and self.entityTabs[self.focus] then
        local tab = self.entityTabs[self.focus]
        if not tab.isWindow then
            tab:Collapsed()
        end
    end

    if self.isWindow and self.panel then
        DeleteWindow(self.panel)
        self.panel = nil
        self.isVisible = false
    elseif self.panel then
        self.panel:Destroy()
        self.panel = nil
        self.isVisible = false
    end

end

function OutlinerMenu:Add(parent)
    local menu = OutlinerMenu.new(parent)
    menu:Render()
    return menu
end