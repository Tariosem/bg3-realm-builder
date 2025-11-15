--- @class OutlinerMenu
--- @field entityTabs table<string, EntityTab>
--- @field focus string -- currently focused tab guid
--- @field hotKeySubs table<string, RBSubscription>
--- @field hoveringKey string|nil
--- @field propTreeList TreeList
--- @field CollectionContextMenu ExtuiPopup
--- @field EntityContextMenu ExtuiPopup
OutlinerMenu = _Class("EntityMenu")

function OutlinerMenu:__init(parent)
    self.parent = parent
    
    self.isAttach = true

    self.store = EntityStore

    self.panel = nil
    self.isVisible = false
    self.isWindow = false
    self.isValid = true
    self.hotKeySubs = {}
    self.selectedGuids = {}

    setmetatable(self, {
        __index = function(t, k)
            if k == "hoveringKey" then
                if self.propTreeList then
                    return self.propTreeList.hoveringKey
                else
                    return nil
                end
            elseif rawget(t, k) ~= nil then
                return rawget(t, k)
            else
                return OutlinerMenu[k]
            end
        end
    })

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
    self:RenderTreeList()
    self:RenderMainArea()
end

function OutlinerMenu:ToggleDetach()
    self.isAttach = not self.isAttach
    self.imageRefs = {}

    for _,sub in pairs(self.hotKeySubs) do
        sub:Unsubscribe()
    end

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

    self.bruteForceDeleteAllButton = AddMenuButton(self.debugMenu, GetLoca("Deletes all props, can't undo"), bfDeleteAllOpe, self.isWindow)
    ApplyDangerSelectableStyle(self.bruteForceDeleteAllButton)
end

local function setupEyeHover(image, icon)
    if icon == RB_ICONS.Eye then
        image.OnHoverEnter = function()
            image.Tint = {1,1,1,1}
        end
        image.OnHoverLeave = function()
            image.Tint = {0.9,0.9,0.9,1}
        end
        image.Tint = {0.9,0.9,0.9,1}
    else
        image.OnHoverEnter = function()
            image.Tint = {0.6,0.6,0.6,1}
        end
        image.OnHoverLeave = function()
            image.Tint = {0.5,0.5,0.5,1}
        end
        image.Tint = {0.5,0.5,0.5,1}
    end
    image:SetColor("Button", ToVec4(0))
    image:SetColor("ButtonHovered", ToVec4(0))
    image:SetColor("ButtonActive", ToVec4(0))
    ClearAllBorders(image)
end

function OutlinerMenu:RenderTreeList()
    local panel = self.panel
    local tree = EntityStore.Tree

    local treeList = self.propTreeList or TreeList.new(panel, "Outliner", tree)
    treeList.parent = panel
    self.hiddenRoots = self.hiddenRoots or {}
    self.replaceFuncs = self.replaceFuncs or {}
    self.imageRefs = {}
    self.eyeImageRefs = {}

    treeList.OnSelect = function(sel, selected)
        local arr = {}
        for guid, _ in pairs(selected) do
            if not tree:IsLeaf(guid) then goto continue end
            table.insert(arr, guid)
            ::continue::
        end
        self.selectedGuids = arr
    end

    treeList.OnDragDrop = function(sel, from, target)
        self:GroupLogic(from, target)
    end

    treeList.RenderLeaf = function(sel, key, node, fixedCell)
        local propData = EntityStore:GetStoredData(key)
        if not propData then
            return node:AddSelectable(key .. " (Missing)") --[[@as ExtuiSelectable]]
        end
        local displayName = propData and propData.DisplayName or key

        local icon = GetIcon(propData.Guid)
        local image = node:AddImageButton(propData.Guid, icon, {36, 36}) --[[@as ExtuiImageButton]]
        local selectable = node:AddSelectable(displayName .. "##" .. key) --[[@as ExtuiSelectable]]
        self:SetupLeaf(selectable, key, node)
        selectable.SameLine = true
    
        self.imageRefs[key] = image
        image.Tint = propData.IconTintColor or {1,1,1,1}
        image:SetColor("Button", ToVec4(0))
        image.OnClick = function()
            RB_GLOBALS.TransformEditor:Select({MovableProxy.CreateByGuid(propData.Guid)})
        end

        local eyeIcon = propData.Visible and RB_ICONS.Eye or RB_ICONS.Eye_Slash
        local eyeImage = fixedCell:AddImageButton("EyeButton##" .. key, eyeIcon, {36, 36}) --[[@as ExtuiImageButton]]
        self.eyeImageRefs[key] = fixedCell
        setupEyeHover(eyeImage, eyeIcon)
        local toggleVisible
        local function toggleEye()
            fixedCell = self.eyeImageRefs[key]
            if not fixedCell then return end
            DestroyAllChildren(fixedCell)
            local newEyeIcon = propData.Visible and RB_ICONS.Eye or RB_ICONS.Eye_Slash
            eyeImage = fixedCell:AddImageButton("EyeButton##" .. key, newEyeIcon, {36, 36}) --[[@as ExtuiImageButton]]
            setupEyeHover(eyeImage, newEyeIcon)
            eyeImage.OnClick = toggleVisible
        end

        function toggleVisible()
            propData = EntityStore:GetStoredData(key)
            if not propData then return end

            local orginState = propData.Visible

            if not propData then return end
            local data = {
                Guid = propData.Guid,
                Attributes = {
                    Visible = not propData.Visible
                }
            }
            NetChannel.SetAttributes:SendToServer(data)
            propData.Visible = data.Attributes.Visible
            toggleEye()

            HistoryManager:PushCommand({
                Redo = function()
                    local redoData = {
                        Guid = propData.Guid,
                        Attributes = {
                            Visible = not orginState
                        }
                    }
                    NetChannel.SetAttributes:SendToServer(redoData)
                    propData.Visible = redoData.Attributes.Visible
                    toggleEye()
                end,
                Undo = function()
                    local undoData = {
                        Guid = propData.Guid,
                        Attributes = {
                            Visible = orginState
                        }
                    }
                    NetChannel.SetAttributes:SendToServer(undoData)
                    propData.Visible = undoData.Attributes.Visible
                    toggleEye()
                end,
            })
        end

        fixedCell.UserData = {
            UpdateEye = toggleEye
        }
        eyeImage.OnClick = toggleVisible

        return selectable
    end

    treeList.RenderTree = function (sel, key, node, fixedCell)
        local treeSelectable = node:AddSelectable(key) --[[@as ExtuiSelectable]]

        self:SetupTree(treeSelectable, key, node)
        local eyeIcon = self.hiddenRoots[key] and RB_ICONS.Eye_Slash or RB_ICONS.Eye
        local eyeImage = fixedCell:AddImageButton("EyeButton##" .. key, eyeIcon, IMAGESIZE.ROW) --[[@as ExtuiImageButton]]
        self.eyeImageRefs[key] = fixedCell
        setupEyeHover(eyeImage, eyeIcon)

        local toggleHidden
        local updateEye
        function toggleHidden(dontPush)
            local orginState = self.hiddenRoots[key] or false
            local children = tree:CollectChildren(key)
            for _, childKey in pairs(children) do
                if not tree:IsLeaf(childKey) then -- for collection we update it to the same state
                    self.hiddenRoots[childKey] = not self.hiddenRoots[key]
                    self.eyeImageRefs[childKey].UserData.UpdateEye()
                    goto continue
                end
                local prop = EntityStore:GetStoredData(childKey)
                if not prop then goto continue end

                local data = {
                    Guid = prop.Guid,
                    Attributes = {
                        Visible = self.hiddenRoots[key] or false
                    }
                }
                NetChannel.SetAttributes:SendToServer(data)
                prop.Visible = data.Attributes.Visible
                ::continue::
            end

            if self.hiddenRoots[key] then
                self.hiddenRoots[key] = nil
            else
                self.hiddenRoots[key] = true
            end

            updateEye()
            if dontPush then return end

            HistoryManager:PushCommand({
                Redo = function()
                    self.hiddenRoots[key] = orginState
                    toggleHidden(true)
                end,
                Undo = function()
                    self.hiddenRoots[key] = not orginState
                    toggleHidden(true)
                end,
            })            
        end
        function updateEye()
            fixedCell = self.eyeImageRefs[key] --[[@as ExtuiTableCell]]
            if not fixedCell then return end
            DestroyAllChildren(fixedCell)
            local newEyeIcon = self.hiddenRoots[key] and RB_ICONS.Eye_Slash or RB_ICONS.Eye
            eyeImage = fixedCell:AddImageButton("EyeButton##" .. key, newEyeIcon, IMAGESIZE.ROW) --[[@as ExtuiImageButton]]
            setupEyeHover(eyeImage, newEyeIcon)
            eyeImage.OnClick = function ()
                toggleHidden()
            end
        end
        eyeImage.OnClick = function ()
            toggleHidden()
        end
        fixedCell.UserData = {
            UpdateEye = updateEye,
        }
        self.replaceFuncs[key] = function(newKey)
            self.replaceFuncs[key] = nil
            key = newKey
        end
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

    selectable.OnRightClick = function()
        self:SetupCollectionSelectablePopup(key)
    end
end

function OutlinerMenu:GroupLogic(from, target)
    if not from or not target or from == target then
        return
    end

    local tree = EntityStore.Tree

    local isFromTree = not tree:IsLeaf(from)
    local isTargetTree = not tree:IsLeaf(target)
    local selectedItems = self.propTreeList.selectedItems

    local toReparent = {}
    local selected = {}
    for key, _ in pairs(selectedItems) do
        table.insert(selected, key)
    end
    local lca = tree:FindLCA(selected)

    for key,_ in pairs(tree:Find(lca) or {}) do
        if selectedItems[key] then
            toReparent[key] = true
        end
    end

    for key,_ in pairs(self.propTreeList.selectedItems) do
        if toReparent[key] == nil and not selectedItems[tree:GetParentKey(key)] then
            toReparent[key] = true
        end
    end

    local groupReparent = function(tar)
        for key,_ in pairs(toReparent) do
            tree:Reparent(key, tar)
        end
    end

    if isTargetTree then
        groupReparent(target)
    elseif not isTargetTree then
        local parent = tree:GetParentKey(target)
        if parent then
            groupReparent(parent)
        else
            groupReparent(nil)
        end
    else
        
    end

    self.propTreeList:ClearSelection()
    self.selectedGuids = {}
    self:UpdateList()
end

function OutlinerMenu:DecideSelectedKeys()
    local selected = {}
    for key, _ in pairs(self.propTreeList.selectedItems) do
        table.insert(selected, key)
    end
    if #selected == 0 and self.propTreeList.hoveringKey then
        selected = {self.propTreeList.hoveringKey}
    end
    return selected
end

function OutlinerMenu:CommonContext()
    if self.commonContextItems then
        return self.commonContextItems
    end

    local function group()
        local selected = self:DecideSelectedKeys()

        local lca = EntityStore.Tree:FindLCA(selected)
        if not lca then lca = TreeTable.GetRootKey() end

        local baseName = GetLoca("New Collection")
        local name = baseName
        local cnt = 1
        while EntityStore.Tree:Find(name) do
            cnt = cnt + 1
            name = baseName .. " ( " .. cnt .. " )"
        end
        local newTree = EntityStore.Tree:AddTree(name, lca)

        if not newTree then
            Warning("Failed to create new collection tree. Name: " .. name)
            return
        end

        for _, key in pairs(selected) do
            EntityStore.Tree:Reparent(key, name)
        end
        self.propTreeList:ClearSelection()
        self:UpdateList()

        self.propTreeList:SetupRenameInput(name, name)
    end

    local function paste()
        if not(self.clipboard and #self.clipboard > 0) then return end

        local path = nil
        local hovering = self.propTreeList.hoveringKey
        if hovering then
            if EntityStore.Tree:IsLeaf(hovering) then
                path = EntityStore.Tree:GetParentKey(hovering)
                path = EntityStore.Tree:GetPath(path)
            else
                path = EntityStore.Tree:GetPath(hovering)
            end
        end
        
        if not self.isCropMode then
            Commands.DuplicateCommand(self.clipboard, path)
        else
            local toReparent = {}
            for _,key in pairs(self.clipboard) do
                toReparent[key] = true
            end

            for child,_ in pairs(toReparent) do
                EntityStore.Tree:Reparent(child, hovering)
            end

            self.clipboard = {}
            self.isCropMode = false
            self.propTreeList:ClearSelection()
            self:UpdateList()

        end
    end

    local function hideAndShow()
        local orginStates = {}
        local selected = self:DecideSelectedKeys()

        for key,_ in pairs(self.propTreeList.selectedItems) do
            local prop = EntityStore:GetStoredData(key)
            if not prop then
                orginStates[key] = self.hiddenRoots[key]
            else
                orginStates[key] = prop.Visible
            end
        end

        local function doCommand(isUndo)
            for _, key in pairs(selected) do
                local prop = EntityStore:GetStoredData(key)
                local state = orginStates[key]
                if not prop then -- collection, simple toggle UI
                    if self.eyeImageRefs[key] then
                        if isUndo then
                            self.hiddenRoots[key] = state
                        else
                            self.hiddenRoots[key] = not state
                        end
                        self.eyeImageRefs[key].UserData.UpdateEye()
                    end
                    goto continue
                end

                if not isUndo then
                    state = not state
                end
                local data = {
                    Guid = prop.Guid,
                    Attributes = {
                        Visible = state
                    }
                }
                NetChannel.SetAttributes:SendToServer(data)
                prop.Visible = data.Attributes.Visible
                ::continue::
            end
        end

        HistoryManager:PushCommand({
            Redo = function()
                doCommand(false)
            end,
            Undo = function()
                doCommand(true)
            end,
        })
        doCommand(false)
    end

    local function delete()
        local target = self:DecideSelectedKeys()
        local collections = {}
        local entities = {}

        for _, key in pairs(target) do
            if EntityStore.Tree:IsLeaf(key) then
                table.insert(entities, key)
            else
                table.insert(collections, key)
            end
        end

        Commands.DeleteCommand(entities)

        for _, colKey in pairs(collections) do
            EntityStore.Tree:Remove(colKey)
        end

        self.propTreeList:ClearSelection()
        self.selectedGuids = {}
        self:UpdateList()
    end

    self.commonContextItems = {
        { Separator = true },
        {
            Label = GetLoca("Delete"),
            OnClick = delete,
            Hint = "Del",
            Danger = true,
            HotKey = {
                Key = "DEL",
            }
        },
        {
            Label = GetLoca("Paste"),
            OnClick = paste,
            Hint = "Ctrl V",
            HotKey = {
                Key = "V",
                Modifiers = {"CTRL"}
            }
        },
        {
            Label = GetLoca("Hide/Show"),
            OnClick = hideAndShow,
            Hint = "H",
            HotKey = {
                Key = "H",
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

    }

    return self.commonContextItems
end

function OutlinerMenu:SetupSelectablePopup()
    if self.EntityContextMenu then self.EntityContextMenu:Open() return end

    self.EntityContextMenu = self.propTreeList.panel:AddPopup("PropRightClickPopup") --[[@as ExtuiPopup]]
    local tree = EntityStore.Tree

    local contextMenu = StyleHelpers.AddContextMenu(self.EntityContextMenu, "Object")

    local function select()
        local target = self.selectedGuids
        if not(self.selectedGuids and #self.selectedGuids > 0) then
            target = {self.hoveringKey}
        end

        local map = {}
        for _, guid in ipairs(target) do
            map[guid] = true
        end

        local proxies = {}
        for guid,_ in pairs(map) do
            table.insert(proxies, MovableProxy.CreateByGuid(guid))
        end

        local originStats = RB_GLOBALS.TransformEditor.Target or {}

        RB_GLOBALS.TransformEditor:Select(proxies)

        HistoryManager:PushCommand({
            Redo = function()
                RB_GLOBALS.TransformEditor:Select(proxies)
            end,
            Undo = function()
                RB_GLOBALS.TransformEditor:Select(originStats)
            end,
        })
    end

    local function copy()
        self.clipboard = {}

        for _, guid in ipairs(self.selectedGuids) do -- since group names are unqiue, we only copy guids
            table.insert(self.clipboard, guid)
        end
        self.isCropMode = false
    end

    local function crop()
        self.clipboard = {}

        for guid,_ in pairs(self.propTreeList.selectedItems) do
            table.insert(self.clipboard, guid)
            self.propTreeList.itemRefs[guid]:SetStyle("Alpha", 0.5)
        end
        self.isCropMode = true
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
            Label = GetLoca("Copy"),
            OnClick = copy,
            Hint = "Ctrl C",
            Icon = RB_ICONS.Copy,
            HotKey = {
                Key = "C",
                Modifiers = {"CTRL"}
            }
        },
        {
            Label = GetLoca("Cut"),
            OnClick = crop,
            Hint = "Ctrl X",
            Icon = RB_ICONS.Crop,
            HotKey = {
                Key = "X",
                Modifiers = {"CTRL"}
            }
        },
    }

    local commonContext = self:CommonContext()
    for _, item in ipairs(commonContext) do
        table.insert(context, 1, item)
    end

    for _, item in ipairs(context) do
        if item.Separator then
            contextMenu:AddSeparator()
            goto continue
        end

        local selectable = contextMenu:AddItem(item.Label, item.OnClick, item.Hint, item.Icon)
        if item.Danger then
            ApplyDangerSelectableStyle(selectable)
        end

        if item.HotKey then
            self.hotKeySubs[item.Label] = SubscribeKeyAndMouse(function (e)
                local hovering = self.propTreeList.hoveringKey
                local focus = hovering ~= nil
                if not focus then return end
                if not e.Pressed then return end

                item.OnClick(selectable)
            end, item.HotKey)
        end
        ::continue::
    end
end

function OutlinerMenu:SetupCollectionSelectablePopup(openKey)
    self.selectedTree = {}

    for key,_ in pairs(self.propTreeList.selectedItems) do
        if not EntityStore.Tree:IsLeaf(key) then
            table.insert(self.selectedTree, key)
        end
    end
    if #self.selectedTree == 0 then
        self.selectedTree = {openKey}
    end

    if self.CollectionContextMenu then self.CollectionContextMenu:Open() return end

    self.CollectionContextMenu = self.propTreeList.panel:AddPopup("CollectionRightClickPopup") --[[@as ExtuiPopup]]
    local tree = EntityStore.Tree

    local contextMenu = StyleHelpers.AddContextMenu(self.CollectionContextMenu, "Collection")

    local function collectChildGuids(node, guids)
        if not node then return guids end
        for childKey,v in pairs(node) do
            if tree:IsLeaf(childKey) then
                guids[childKey] = true
            else
                local childNode = tree:Find(childKey)
                if childNode then
                    collectChildGuids(childNode, guids)
                end
            end
        end
        return guids
    end

    local function openExportMenu()
        local hovering = self.propTreeList.hoveringKey
        local targetKey = self.selectedTree or {hovering}
        if not targetKey then return end

        local allGuids = {}
        for _, tk in pairs(targetKey) do
            local children = tree:Find(tk)
            collectChildGuids(children, allGuids)
        end
        local guids = {}
        for guid,_ in pairs(allGuids) do
            table.insert(guids, guid)
        end

        local copy = EntityStore:GetExportCopy(guids)
        TemplateExportMenu.new(copy)
    end

    --- @type RB_ContextItem[]
    local context = {
        {
            Label = GetLoca("Select All in Collection"),
            OnClick = function()
                self.propTreeList:SelectAll(self.selectedTree[1])
            end,
            Hint = "Enter",
            HotKey = {
                Key = "RETURN",
            }
        },
        {
            Label = GetLoca("Save as Scene"),
            OnClick = function()
                if not RB_GLOBALS.SceneMenu then return end
                if not self.selectedTree or #self.selectedTree == 0 then return end

                local treeKey = self.selectedTree[1]
                local childs = {}
                local childArr = {}
                local node = tree:Find(treeKey)
                collectChildGuids(node, childs)
                for guid,_ in pairs(childs) do
                    table.insert(childArr, guid)
                end

                RB_GLOBALS.SceneMenu:SavePreset(treeKey, false, childArr)
            end,
        },
        {
            Label = GetLoca("Export Collection"),
            OnClick = openExportMenu,
            Icon = RB_ICONS.Export,
        },
    }

    local commonContext = self:CommonContext()
    for _, item in ipairs(commonContext) do
        table.insert(context, 1, item)
    end

    local focusFunc = function()
        local focus = self.hoveringKey ~= nil
    end

    contextMenu:AddContext(context, focusFunc)
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
    self.eyeImageRefs = {}
    self.propTreeList:RenderList()
end

function OutlinerMenu:UpdateEyeIcon(guid)
    if self.eyeImageRefs and self.eyeImageRefs[guid] then
        local image = self.eyeImageRefs[guid]
        if image.UserData and image.UserData.UpdateEye then
            image.UserData.UpdateEye()
        end
    end
end

function OutlinerMenu:Collapse()
    if self.propTreeList then
        self.propTreeList:Collapsed()
    end

    self.EntityContextMenu = nil
    self.CollectionContextMenu = nil

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