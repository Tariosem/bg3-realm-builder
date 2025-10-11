--- @class PropsMenu
PropsMenu = _Class("PropMenu")

function PropsMenu:__init(parent)
    self.parent = parent
    
    self.isAttach = true

    self.store = PropStore

    self.panel = nil
    self.isVisible = false
    self.isWindow = false
    self.isValid = true
    self.selectedGuids = {}

    self.iconBrowser = ItemIconBrowser:Add(LOP_ItemManager, GetLoca("Items"))
    self.iconBrowser.panel.Open = false
    self.propTabs = {}
end

function PropsMenu:NewPropAdded(guids)
    local list = NormalizeGuidList(guids)

    for _, guid in ipairs(list) do
        local prop = PropStore:GetProp(guid)
        if prop and not self.propTabs[guid] then
            local opts = {}
            table.insert(opts, "IsAttach")
            self.propTabs[guid] = self:CreatePropTab(prop, opts)    
        end
    end
    self:UpdateList()
end

function PropsMenu:PropDeleted(guids)
    local list = NormalizeGuidList(guids)
    for _, guid in ipairs(list) do
        if guid ~= nil and guid ~= "" then
            if self.propTabs[guid] then
                self.propTabs[guid]:Destroy()
                self.propTabs[guid] = nil
            end
            
        end
    end
    self:UpdateList()
end


function PropsMenu:Render()

    if self.isAttach and self.parent then
        self.panel = self.parent:AddTabItem("Props")
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

function PropsMenu:RenderMenu()
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
                Post("BF_DeleteAll")
            end,
            nil
        )
    end

    self.bruteForceDeleteAllButton = AddMenuButton(self.debugMenu, GetLoca("Deletes all props, ignoring filters or protections."), bfDeleteAllOpe, self.isWindow)
    ApplyDangerSelectableStyle(self.bruteForceDeleteAllButton)
end

function PropsMenu:RenderSideBar()
    local panel = self.mainPanel.SideBar
    local tree = PropStore.Tree

    local treeList = TreeList.new(panel, "PropsTree", tree, "Guid") --[[@as TreeList]]

    local rightClickPopup = panel:AddPopup("PropRightClickPopup") --[[@as ExtuiPopup]]
    self.imageRefs = {}

    treeList.OnDetach = function()
        self.mainPanel.SetSideBarWidth(0)
    end

    treeList.OnAttach = function()
        self.mainPanel.SetSideBarWidth(200 * SCALE_FACTOR)
    end

    treeList.OnSelect = function(sel, selected)
        --- @diagnostic disable-next-line: param-type-mismatch
        TransformEditor:Select(selected)
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
        local propData = PropStore:GetProp(key)
        if not propData then
            Warning("Prop data missing for key: " .. key)
            return node:AddSelectable(key .. " (Missing)") --[[@as ExtuiSelectable]]
        end

        local displayName = propData and propData.DisplayName or key

        local icon = GetIconForTemplateId(propData and propData.TemplateId)

        local imageGroup = node:AddGroup("Images" .. propData.Guid) --[[@as ExtuiGroup]]
        local image = imageGroup:AddImageButton(propData.Guid, icon, IMAGESIZE.TINY) --[[@as ExtuiImageButton]]

        local selectable = node:AddSelectable(displayName) --[[@as ExtuiSelectable]]
        selectable.SameLine = true
        selectable.SpanAllColumns = false
    
        self.imageRefs[key] = image
        image.Tint = propData.IconTintColor or {1,1,1,1}
        image:SetColor("Button", ToVec4(0))
        image.OnClick = function()
            Post("SetAttributes", {Guid = propData.Guid, Visible = not propData.Visible})
            propData.Visible = not propData.Visible
            SetAlphaByBool(image, propData.Visible)
            SetAlphaByBool(selectable, propData.Visible)
        end

        selectable.OnRightClick = function()
            if not TableContains(self.selectedGuids, propData.Guid) then
                table.insert(self.selectedGuids, propData.Guid)
            end
            Debug(self.selectedGuids)
            self:SetupSelectablePopup(rightClickPopup)
            rightClickPopup:Open()
        end

        selectable.OnClick = function()
            self:FocusPropTab(key)
        end

        selectable.UserData = {
            Others = {
                image,
            }
        }
        SetAlphaByBool(image, propData.Visible)
        SetAlphaByBool(selectable, propData.Visible)

        return selectable
    end

    treeList.RenderTree = function (sel, key, node)
        local treeSelectable = node:AddSelectable(key) --[[@as ExtuiSelectable]]

        local popup = node:AddPopup("TreeRightClickPopup" .. key) --[[@as ExtuiPopup]]

        treeSelectable.OnRightClick = function()
            popup:Open()
        end

        popup.UserData = {
            Others = {}
        }

        local renameInput = popup:AddInputText("") --[[@as ExtuiInputText]]
        renameInput.IDContext  = "RenameGroupInput" .. key
        renameInput.Hint = GetLoca("Enter new group name, or leave empty to ungroup")
        
        local renameSub = SubscribeKeyInput({ Key = "RETURN" }, function (e)
            local ok, focused = pcall(IsFocused, renameInput)
            if not ok then return UNSUBSCRIBE_SYMBOL end

            if focused then
                local newName = renameInput.Text
                if newName == "" then
                    tree:RemoveButKeepChildren(key)
                    self.propTreeList:ClearSelection()
                    self.selectedGuids = {}
                    self:UpdateList()
                    return UNSUBSCRIBE_SYMBOL
                end
                if newName and newName ~= key then
                    if tree:Find(newName) then
                        Warning("Group with name '" .. newName .. "' already exists.")
                    else
                        tree:Rename(key, newName)
                        if sel.collapsedTree[key] then
                            sel.collapsedTree[newName] = sel.collapsedTree[key]
                            sel.collapsedTree[key] = nil
                        end

                        self.propTreeList:ClearSelection()
                        self.selectedGuids = {}
                        self:UpdateList()
                    end
                end

                return UNSUBSCRIBE_SYMBOL
            end

        end)

        return treeSelectable
    end

    treeList.FilterFunc = function(sel, key, keywords)
        local words = SplitBySpace(keywords)
        local propData = PropStore:GetProp(key)
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
        local aName = tree:IsLeaf(aKey) and (PropStore:GetProp(aKey) and PropStore:GetProp(aKey).DisplayName or aKey) or aKey
        local bName = tree:IsLeaf(bKey) and (PropStore:GetProp(bKey) and PropStore:GetProp(bKey).DisplayName or bKey) or bKey
        return string.lower(aName) < string.lower(bName)
    end

    treeList:Render()

    self.propTreeList = treeList   
end

function PropsMenu:GroupLogic(from, target)
    if not from or not target or from == target then
        return
    end

    local tree = PropStore.Tree

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

local function deleteHandler(guids)
    Post("Delete", { Guid = guids })
end

function PropsMenu:SetupSelectablePopup(popup)
    if popup and popup.UserData then
        for _, obj in pairs(popup.UserData.Others) do
            obj:Destroy()
        end
    end
    local tree = PropStore.Tree

    local deleteButton = AddSelectableButton(popup, GetLoca("Delete"), function()
        if self.selectedGuids and #self.selectedGuids > 0 then
            local deleteMes = ""
            local guids = {}
            for _, guid in ipairs(self.selectedGuids) do
                table.insert(guids, guid)
            end
            if #guids == 0 then
                return
            end
            if #guids == 1 then
                deleteMes = string.format(GetLoca("Are you sure you want to delete '%s'?"), PropStore[guids[1]].DisplayName or guids[1])
            else
                deleteMes = string.format(GetLoca("Are you sure you want to delete these %d props?"), #guids)
            end
            ConfirmPopup:DangerConfirm(
                deleteMes,
                function()
                    deleteHandler(guids)
                end
            )
        end
    end)
    ApplyDangerSelectableStyle(deleteButton)

    local hideButton = AddSelectableButton(popup, GetLoca("Hide/Show"), function()
        if self.selectedGuids and #self.selectedGuids > 0 then
            for _, guid in ipairs(self.selectedGuids) do
                local prop = PropStore:GetProp(guid)
                if prop then
                    Post("SetAttributes", {Guid = prop.Guid, Visible = not prop.Visible})
                    prop.Visible = not prop.Visible
                end
            end
            self:UpdateList()
        end
    end)

    local groupButton = AddSelectableButton(popup, GetLoca("Group"), function()
        if self.selectedGuids and #self.selectedGuids > 0 then
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
    end)

    popup.UserData = {
        Others = {
            deleteButton,
            groupButton,
            hideButton,
        }
    }
end

function PropsMenu:RenderMainArea()
    local panel = self.mainPanel.MainArea

    self.mainArea = panel
end

function PropsMenu:CreatePropTab(prop, opts)
    --self.props[prop.Guid] = prop

    local propTab = nil

    if TableContains(opts, "Add") then
        propTab = PropTab:Add(prop.Guid, prop.TemplateId, self.mainArea, opts, prop.IconTintColor)
    else
        propTab = PropTab.new(prop.Guid, prop.TemplateId, self.mainArea, opts)
    end

    if propTab then
        propTab.OnChange = function(changeLib)
            if not propTab.isValid then return end

            if self.iconBrowser and changeLib then
                if self.iconBrowser.updateTagsFn and self.iconBrowser.updateTagsFn[TakeTailTemplate(propTab.templateId)] then
                    self.iconBrowser.updateTagsFn[TakeTailTemplate(propTab.templateId)]()
                end
                self.iconBrowser:AddTagsFilter()
            end

            if self.imageRefs and self.imageRefs[prop.Guid] then
                self.imageRefs[prop.Guid].Tint = PropStore[prop.Guid].IconTintColor or {1,1,1,1}
            end            
        end

        propTab.OnAttach = function()
            if self.presentingProp and self.presentingProp ~= prop.Guid and self.propTabs[self.presentingProp] then
                local tab = self.propTabs[self.presentingProp]
                tab.isAttach = false
                if not tab.isWindow then
                    tab:Collapsed()
                end
            end
        end
            
        return propTab
    end

    Error("[PropsMenu] Failed to create PropTab for guid: " .. prop.Guid)
    return nil
end

function PropsMenu:FocusPropTab(guid, doDetach)
    local propTab = self.propTabs[guid]
    if guid == self.presentingProp and propTab.isVisible == false then
        self.presentingProp = nil
    end
    if guid == self.presentingProp and not doDetach then
        return
    end
    if self.presentingProp and self.propTabs[self.presentingProp] then
        local tab = self.propTabs[self.presentingProp]
        tab.isAttach = false
        if not tab.isWindow then
            tab:Collapsed()
        end
    end

    local propTab = self.propTabs[guid]
    if propTab and propTab.isValid then
        propTab.isAttach = not doDetach
        propTab:Refresh()
        if propTab.isWindow then
            FocusWindow(propTab.panel)
        end
        self.presentingProp = guid
    end
end

function PropsMenu:FocusPropVisualTab(guid)
    local propTab = self.propTabs[guid]
    if propTab and propTab.isValid then

        if propTab.visualTab.isWindow and propTab.visualTab.isVisible then
            FocusWindow(propTab.visualTab.panel)
        else
            propTab.visualTab.isAttach = false
            propTab.visualTab:Refresh()
            FocusWindow(propTab.visualTab.panel)
        end
        return true
    end
end

function PropsMenu:UpdateList()
    self.propTreeList:RenderList()
end

function PropsMenu:Add(parent)
    local menu = PropsMenu.new(parent)
    menu:Render()
    return menu
end