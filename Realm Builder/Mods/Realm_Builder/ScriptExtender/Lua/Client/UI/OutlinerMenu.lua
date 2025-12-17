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
    self:UpdateList()
end

function OutlinerMenu:EntityDeleted(guids)
    local list = RBUtils.NormalizeGuidList(guids)
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
        self.panel = WindowManager.RegisterWindow("generic", "Outliner", "Outliner", self)
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

    self.bruteForceDeleteAllButton = ImguiElements.AddMenuButton(self.debugMenu, GetLoca("Deletes all props, can't undo"), bfDeleteAllOpe, self.isWindow)
    StyleHelpers.ApplyDangerSelectableStyle(self.bruteForceDeleteAllButton)
end

local eyeSlashUV = RB_ICON_UV01[RB_ICONS.Eye_Slash]
local eyeUV = RB_ICON_UV01[RB_ICONS.Eye]

local function setupEyeHover(image, hidden)
    if not hidden then
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
    image:SetColor("Button", RBUtils.ToVec4(0))
    image:SetColor("ButtonHovered", RBUtils.ToVec4(0))
    image:SetColor("ButtonActive", RBUtils.ToVec4(0))
    StyleHelpers.ClearAllBorders(image)
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

        local icon = RBGetIcon(propData.Guid)
        local image = node:AddImageButton(propData.Guid, icon, IMAGESIZE.ROW) --[[@as ExtuiImageButton]]
        local selectable = node:AddSelectable(displayName .. "##" .. key) --[[@as ExtuiSelectable]]
        self:SetupLeaf(selectable, key, node)
        selectable.SameLine = true
    
        self.imageRefs[key] = image
        image.Tint = propData.IconTintColor or {1,1,1,1}
        image:SetColor("Button", RBUtils.ToVec4(0))
        image.OnClick = function()
            RB_GLOBALS.TransformEditor:Select({MovableProxy.CreateByGuid(propData.Guid)})
        end

        local eyeIcon = propData.Visible and RB_ICONS.Eye or RB_ICONS.Eye_Slash
        local eyeImage = fixedCell:AddImageButton("EyeButton##" .. key, eyeIcon, IMAGESIZE.ROW) --[[@as ExtuiImageButton]]
        self.eyeImageRefs[key] = eyeImage
        setupEyeHover(eyeImage, not propData.Visible)
        local toggleVisible
        local function toggleEye()
            eyeImage = self.eyeImageRefs[key]
            if not eyeImage then return end
            eyeImage.Image = propData.Visible and eyeUV or eyeSlashUV
            eyeImage.Tint = propData.Visible and {0.9,0.9,0.9,1} or {0.5,0.5,0.5,1}
            setupEyeHover(eyeImage, not propData.Visible)
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
                Description = "Toggle Visibility"
            })
        end

        eyeImage.UserData = {
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
        self.eyeImageRefs[key] = eyeImage
        setupEyeHover(eyeImage, self.hiddenRoots[key])

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
                Description = "Toggle Collection Visibility"
            })            
        end
        function updateEye()
            eyeImage = self.eyeImageRefs[key]
            if not eyeImage then return end
            eyeImage.Image = self.hiddenRoots[key] and eyeSlashUV or eyeUV
            eyeImage.Tint = self.hiddenRoots[key] and {0.5,0.5,0.5,1} or {0.9,0.9,0.9,1}
            setupEyeHover(eyeImage, self.hiddenRoots[key])
        end
        eyeImage.OnClick = function ()
            toggleHidden()
        end
        eyeImage.UserData = {
            UpdateEye = updateEye,
        }
        self.replaceFuncs[key] = function(newKey)
            self.replaceFuncs[key] = nil
            key = newKey
        end
        return treeSelectable
    end

    treeList.OnRenderComplete = function ()
    end

    treeList.FilterFunc = function(sel, key, keywords)
        local words = RBStringUtils.SplitBySpace(keywords)
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

    treeList.UpdateSortCache = function (sel)
        for key, ent in pairs(EntityStore:GetAllStored()) do
            local name = ent.DisplayName and ent.DisplayName or key
            sel.SortCache[key] = {
                TypeOrder = 1,
                Key = name
            }
        end
        for _,key in pairs(treeList.tree:GetAllTreeKeys()) do
            if not sel.SortCache[key] then
                sel.SortCache[key] = {
                    TypeOrder = 0,
                    Key = key
                }
            end
        end
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

    selectable.OnRightClick = function()
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

--- @return RB_ContextItem[]
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
        self:UpdateList(function()
            self.propTreeList:SetupRenameInput(name, name)
        end)
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
            Description = "Toggle Visibility In Context Menu"
        })
        doCommand(false)
    end

    local function delete()
        local target = self:DecideSelectedKeys()
        local tree = EntityStore.Tree

        -- map of selected keys for quick ancestor checks
        local selectedMap = {}
        for _, k in ipairs(target) do selectedMap[k] = true end

        local collectionsToRemove = {}
        local entitiesSet = {}

        local function collectLeafGuids(node)
            if not node then return end
            for childKey, _ in pairs(node) do
                if tree:IsLeaf(childKey) then
                    entitiesSet[childKey] = true
                else
                    local childNode = tree:Find(childKey)
                    if childNode then
                        collectLeafGuids(childNode)
                    end
                end
            end
        end

        for _, key in ipairs(target) do
            if tree:IsLeaf(key) then
                entitiesSet[key] = true
            else
                -- skip traversal if any ancestor of this collection is also selected
                local parent = tree:GetParentKey(key)
                local skip = false
                while parent do
                    if selectedMap[parent] then
                        skip = true
                        break
                    end
                    parent = tree:GetParentKey(parent)
                end

                if not skip then
                    table.insert(collectionsToRemove, key)
                    local node = tree:Find(key)
                    collectLeafGuids(node)
                end
            end
        end

        local entities = {}
        for guid, _ in pairs(entitiesSet) do
            table.insert(entities, guid)
        end

        if #entities > 0 then
            Commands.DeleteCommand(entities)
        end

        for _, colKey in ipairs(collectionsToRemove) do
            tree:Remove(colKey)
        end

        self.propTreeList:ClearSelection()
        self.selectedGuids = {}
        self:UpdateList()
    end

    local function selectAll()
        self.propTreeList:SelectAll()
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
            Label = GetLoca("Group"),
            OnClick = group,
            Hint = "Ctrl G",
            HotKey = {
                Key = "G",
                Modifiers = {"CTRL"}
            }
        },
        {
            Label = GetLoca("Select All"),
            OnClick = selectAll,
            Hint = "Ctrl A",
            HotKey = {
                Key = "A",
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

    local contextMenu = ImguiElements.AddContextMenu(self.EntityContextMenu, "Object")

    local function select()
        local target = self:DecideSelectedKeys()
        if #target == 0 then return end

        local map = {}
        for _, guid in ipairs(target) do
            map[guid] = true
        end

        local proxies = {}
        for guid,_ in pairs(map) do
            table.insert(proxies, MovableProxy.CreateByGuid(guid))
        end

        RB_GLOBALS.TransformEditor:Select(proxies)
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

    local isFocus = function ()
        return self.propTreeList and (self.propTreeList.hoveringKey ~= nil and true or false) or false
    end

    contextMenu:AddItems(context, isFocus)
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

    local contextMenu = ImguiElements.AddContextMenu(self.CollectionContextMenu, "Collection")

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
        if not next(copy) then
            return
        end
        TemplateExportMenu.new(copy)
    end

    local prefabNotif = Notification.new("Prefab Saved!")
    prefabNotif.ClickToDismiss = true
    local function saveAsPrefab()
        if not self.selectedTree or #self.selectedTree == 0 then return end

        local treeKey = self.selectedTree[1]
        local childs = {}
        local childArr = {}
        local childTemplateArr = {}
        local childWorldTransforms = {}
        local childRelativeTransforms = {}
        local node = tree:Find(treeKey)
        collectChildGuids(node, childs)
        local pivtoTransform = {
            Translate = Vec3.new(0,0,0),
            RotationQuat = Quat.Identity(),
            Scale = {1,1,1},
        }
        for guid,_ in pairs(childs) do
            local storedData = EntityStore:GetStoredData(guid)
            if not storedData or not Ext.Template.GetTemplate(RBUtils.TakeTailTemplate(storedData.TemplateId)) then
                --Warning("Invalid TemplateId for guid: " .. guid .. ", skipping...")
                goto continue
            else
                table.insert(childArr, guid)
                table.insert(childTemplateArr, storedData.TemplateId)
            end
            local pos = Vec3.new(RBGetPosition(guid))
            pivtoTransform.Translate = pivtoTransform.Translate + pos
            table.insert(childWorldTransforms, {
                Translate = pos,
                RotationQuat = {RBGetRotation(guid)},
                Scale = {RBGetScale(guid)},
            })
            ::continue::
        end

        if #childArr == 0 then
            Warning("No valid children found in collection: " .. treeKey .. ", aborting prefab save.")
            prefabNotif:Show("Nothing to save!", "No valid children found in collection: " .. treeKey .. ", aborting prefab save.", RB_ICONS.Warning)
            return
        end

        pivtoTransform.Translate = pivtoTransform.Translate / #childArr
        for i, guid in ipairs(childArr) do
            local childPos, childRot, childScale = childWorldTransforms[i].Translate, childWorldTransforms[i].RotationQuat, childWorldTransforms[i].Scale
            local relativeTransform = MathUtils.SaveLocalRelativeTransform(pivtoTransform, childPos, childRot, childScale)
            childRelativeTransforms[i] = relativeTransform
        end

        local generated = RBUtils.Uuid_v4()
        local internalName = RBUtils.ValidateFolderName(treeKey)

        local xmlNode = LSXHelpers.BuildPrefabTemplate(generated, internalName, childTemplateArr, childRelativeTransforms)

        local filePath = FilePath.GetPrefabPath(internalName, generated)
        
        local ok, err = Ext.IO.SaveFile(filePath, xmlNode:Stringify({ AutoFindRoot = true }))
        if not ok then
            Error("Failed to save prefab file: " .. err)
            return
        else
            prefabNotif:Show("Prefab Saved!", "Prefab '" .. internalName .. "' has been saved at " .. filePath)
        end
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
            Label = GetLoca("Save as Prefab"),
            OnClick = saveAsPrefab,
            Warning = "Won't save visual changes, only the original templates are saved.",
        },
        {
            Label = GetLoca("Export Collection"),
            OnClick = openExportMenu,
            Icon = RB_ICONS.Export,
        },
    }

    local commonContext = self:CommonContext()
    for _, item in ipairs(commonContext) do
        item.HotKey = nil -- hotkey has been registered in entity context menu
        table.insert(context, 1, item)
    end

    local focusFunc = function()
        local hovering = self.propTreeList.hoveringKey
        return hovering and not tree:IsLeaf(hovering)
    end

    contextMenu:AddItems(context, focusFunc)
end

function OutlinerMenu:RenderMainArea()
    local panel = self.panel:AddGroup("OutlinerMainArea")

    self.mainArea = panel
end

function OutlinerMenu:CreateEntityTab(ent, opts)
    local entityTab = nil

    if opts and opts.Add then
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
    --- @type EntityTab?
    local entityTab = self.entityTabs[guid] 
    if not entityTab then
        entityTab = self:CreateEntityTab(EntityStore:GetStoredData(guid), { Add = true, IsAttach = not doDetach })
        self.entityTabs[guid] = entityTab
    end
    if not (entityTab and entityTab.isValid) then
        return
    end

     -- if the tab is already focused and it's not visible, we clear the focus
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
            ImguiHelpers.FocusWindow(entityTab.panel)
        else
            entityTab:Refresh()
        end
        self.focus = guid
    end
end

function OutlinerMenu:FocusEntityVisualTab(guid)
    local entityTab = self.entityTabs[guid]
    if not (entityTab and entityTab.isValid and entityTab.visualTab) then
        return false
    end

    if entityTab.visualTab.isWindow and entityTab.visualTab.isVisible then
        ImguiHelpers.FocusWindow(entityTab.visualTab.panel)
    else
        entityTab.visualTab.isAttach = false
        entityTab.visualTab:Refresh()
        ImguiHelpers.FocusWindow(entityTab.visualTab.panel)
    end
    return true
end

function OutlinerMenu:UpdateList(onComplete)
    self.imageRefs = {}
    self.eyeImageRefs = {}
    self.propTreeList:RenderList(onComplete)
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
    self.eyeImageRefs = {}
    self.imageRefs = {}

    self.EntityContextMenu = nil
    self.CollectionContextMenu = nil

    if self.focus and self.entityTabs[self.focus] then
        local tab = self.entityTabs[self.focus]
        if not tab.isWindow then
            tab:Collapsed()
        end
    end

    if self.isWindow and self.panel then
        WindowManager.DeleteWindow(self.panel)
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