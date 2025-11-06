--- @class SceneMenu
--- @field entityTabs table<string, EntityTab>
--- @field CollectionPopup ExtuiPopup
--- @field EntityPopup ExtuiPopup
SceneMenu = _Class("EntityMenu")

function SceneMenu:__init(parent)
    self.parent = parent
    
    self.isAttach = true

    self.store = EntityStore

    self.panel = nil
    self.isVisible = false
    self.isWindow = false
    self.isValid = true
    self.selectedGuids = {}

    self.entityTabs = {}
end

function SceneMenu:NewEntityAdded(guids)
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

function SceneMenu:EntityDeleted(guids)
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

function SceneMenu:Render()

    if self.isAttach and self.parent then
        self.panel = self.parent:AddTabItem(GetLoca("Scene"))
        self.isWindow = false
    else
        self.panel = RegisterWindow("generic", "", "Props Menu", self)
        self.isWindow = true
    end

    self:RenderMenu()

    self.mainPanel = AddCollapsingTable(self.panel)
    self.mainPanel.ToggleButton.Visible = false
    self.mainPanel.Table.BordersInnerV = true

    self:RenderSideBar()
    self:RenderMainArea()
end

function SceneMenu:RenderMenu()
    if self.isWindow then
        self.mainMenu = self.panel:AddMainMenu()
        self.debugMenu = self.mainMenu:AddMenu(GetLoca("Debug"))
    else
        local menuTable = self.panel:AddTable("PropsMenuMainMenuTable", 6)
        local menuRow = menuTable:AddRow()
        local debugCell = menuRow:AddCell()

        local debugOpenButton = debugCell:AddSelectable(GetLoca("Debug"))

        self.debugMenu = debugCell:AddPopup("DebugMenu") --[[@as ExtuiPopup]]

        debugOpenButton.OnClick = function()
            --- @diagnostic disable-next-line: param-type-mismatch
            self.debugMenu:Open()
            debugOpenButton.Selected = false
        end
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

function SceneMenu:RenderSideBar()
    local panel = self.mainPanel.SideBar
    local tree = EntityStore.Tree

    local treeList = TreeList.new(panel, "PropsTree", tree, "Guid") --[[@as TreeList]]

    self.imageRefs = {}

    treeList.OnDetach = function()
        self.CollectionPopup = nil
        self.EntityPopup = nil
        self.mainPanel.SetSideBarWidth(0)
    end

    treeList.OnAttach = function()
        self.CollectionPopup = nil
        self.EntityPopup = nil
        self.mainPanel.SetSideBarWidth(200 * SCALE_FACTOR)
    end

    treeList.OnSelect = function(sel, selected)
        local arr = {}

        for guid, _ in pairs(selected) do
            table.insert(arr, guid)
        end
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

        local icon = GetIconForTemplateId(propData and propData.TemplateId)

        local image = node:AddImageButton(propData.Guid, icon, {36, 36}) --[[@as ExtuiImageButton]]

        local selectable = node:AddSelectable(displayName .. "##" .. key) --[[@as ExtuiSelectable]]
        self:SetupLeaf(selectable, key, node)
    
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
            if self.entityTabs[key] then
                local tab = self.entityTabs[key]
                if tab.isVisible then
                    tab:Refresh()
                end
            end
        else
            tree:Rename(key, newName)
        end
    end

    treeList:Render()

    self.propTreeList = treeList   
end

function SceneMenu:SetupLeaf(sel, key, node)
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

function SceneMenu:SetupTree(sel, key, node)
    local selectable = sel

    selectable.SameLine = true

    selectable.OnRightClick = function()
        self.selectedTree = key
        self:SetupCollectionSelectablePopup()
    end
end

function SceneMenu:GroupLogic(from, target)
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

function SceneMenu:SetupSelectablePopup()
    if self.EntityPopup then self.EntityPopup:Open() return end

    self.EntityPopup = self.propTreeList.panel:AddPopup("PropRightClickPopup") --[[@as ExtuiPopup]]
    local tree = EntityStore.Tree

    local ttable = self.EntityPopup:AddTable("PropRightClickPopupTable", 1) --[[@as ExtuiTable]]
    ttable.BordersInnerH = true

    local row = ttable:AddRow() --[[@as ExtuiTableRow]]

    local selectInTransformEditor = AddSelectableButton(row:AddCell(), GetLoca("Select"), function()
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
    end)

    local deleteButton = AddSelectableButton(row:AddCell(), GetLoca("Delete"), function()
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
    end)
    ApplyDangerSelectableStyle(deleteButton)

    local hideButton = AddSelectableButton(row:AddCell(), GetLoca("Hide/Show"), function()
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
        self:UpdateList()
    end)

    local groupButton = AddSelectableButton(row:AddCell(), GetLoca("Group"), function()
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
    
    end)

    self.EntityPopup:Open()
end

function SceneMenu:SetupCollectionSelectablePopup()
    if self.CollectionPopup then self.CollectionPopup:Open() return end

    self.CollectionPopup = self.propTreeList.panel:AddPopup("CollectionRightClickPopup") --[[@as ExtuiPopup]]
    local tree = EntityStore.Tree

    local ttable = self.CollectionPopup:AddTable("CollectionRightClickPopupTable", 1) --[[@as ExtuiTable]]
    ttable.BordersInnerH = true

    local row = ttable:AddRow() --[[@as ExtuiTableRow]]

    local function collectChildGuids(node, guids)
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

    local hideShowBtn = AddSelectableButton(row:AddCell(), GetLoca("Hide/Show Collection"), function()
        local targetKey = self.selectedTree
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
    end)

    local deleteButton = AddSelectableButton(row:AddCell(), GetLoca("Delete Collection"), function()
        -- Deleting a collection only deletes the grouping, not the entities within
        local targetKey = self.selectedTree
        if not targetKey or tree:IsLeaf(targetKey) then return end

        tree:RemoveButKeepChildren(targetKey)

        self.propTreeList:ClearSelection()
        self.selectedGuids = {}
        self:UpdateList()
    end)
    ApplyDangerSelectableStyle(deleteButton)

    local exportBtn = AddSelectableButton(row:AddCell(), GetLoca("Export Collection LSX"), function()
        local targetKey = self.selectedTree
        if not targetKey or tree:IsLeaf(targetKey) then return end

        local childs = tree:Find(targetKey)
        local guids = collectChildGuids(childs, {})

        local copy = EntityStore:GetExportCopy(guids)
        TemplateExportMenu.new(copy)
    end)

    self.CollectionPopup:Open()
end

function SceneMenu:RenderMainArea()
    local panel = self.mainPanel.MainArea

    self.mainArea = panel
end

function SceneMenu:CreateEntityTab(ent, opts)
    --self.props[prop.Guid] = prop

    local entityTab = nil

    if TableContains(opts, "Add") then
        entityTab = EntityTab:Add(ent.Guid, ent.TemplateId, self.mainArea, opts, ent.IconTintColor)
    else
        entityTab = EntityTab.new(ent.Guid, ent.TemplateId, self.mainArea, opts)
    end

    if entityTab then
        entityTab.RequestUpdate = function()
            self:UpdateList()
        end

        entityTab.OnChange = function()
            if not entityTab.isValid then return end

            if self.imageRefs and self.imageRefs[ent.Guid] then
                self.imageRefs[ent.Guid].Tint = EntityStore[ent.Guid].IconTintColor or {1,1,1,1}
            end            
        end

        entityTab.OnAttach = function()
            if self.presentingProp and self.presentingProp ~= ent.Guid and self.entityTabs[self.presentingProp] then
                local tab = self.entityTabs[self.presentingProp]
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

function SceneMenu:FocusTab(guid, doDetach)
    local entityTab = self.entityTabs[guid]
    if guid == self.presentingProp and entityTab.isVisible == false then
        self.presentingProp = nil
    end
    if guid == self.presentingProp and not doDetach then
        return
    end
    if self.presentingProp and self.entityTabs[self.presentingProp] then
        local tab = self.entityTabs[self.presentingProp]
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
        self.presentingProp = guid
    end
end

function SceneMenu:FocusEntityVisualTab(guid)
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

function SceneMenu:UpdateList()
    self.propTreeList:RenderList()
end

function SceneMenu:UpdateSelectableAlpha(guid)
    if self.imageRefs and self.imageRefs[guid] then
        local image = self.imageRefs[guid]
        image.UserData.UpdateAlpha()
    end
end

function SceneMenu:Add(parent)
    local menu = SceneMenu.new(parent)
    menu:Render()
    return menu
end