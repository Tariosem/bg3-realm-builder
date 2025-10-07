--- @class TreeList : Class
--- @field parent ExtuiTreeParent
--- @field panel ExtuiWindowBase|ExtuiWindow
--- @field tree TreeTable
--- @field isVisible boolean
--- @field label string
--- @field items any[]
--- @field keyField string
--- @field RenderLeaf fun(self:TreeList, key:any, node:ExtuiTableCell):ExtuiSelectable
--- @field RenderTree fun(self:TreeList, key:any, node:ExtuiTableCell):ExtuiSelectable
--- @field SetUpLeaf fun(self:TreeList, selectable:ExtuiSelectable, key:any, item:any)
--- @field SetUpTree fun(self:TreeList, tree:ExtuiSelectable, key:any, item:any)
--- @field RenderOrder fun(aKey:any, bKey:any):boolean
--- @field FilterFunc fun(self:TreeList, key:any, keyword:string):boolean
--- @field ShowAndShowPath fun(self:TreeList, key:any)
--- @field ClearSelection fun(self:TreeList)
--- @field ClearList fun(self:TreeList)
--- @field OnSelect fun(self:TreeList, selectedItems:table<key, boolean>)
--- @field OnDragStart fun(self:TreeList, dragKey:any)
--- @field OnDragDrop fun(self:TreeList, from:any, to:any)
--- @field OnDragEnd fun(self:TreeList, dragKey:any)
--- @field OnAttach fun(self:TreeList)
--- @field OnDetach fun(self:TreeList)
--- @field MultiSelect boolean
--- @field GroupSelect boolean
--- @field new fun(parent:ExtuiTreeParent, label:string, tree:TreeTable, keyField:string, opts:table?):TreeList
TreeList = _Class("TreeList")

function TreeList:__init(parent, label, tree)
    self.parent = parent --[[@as ExtuiTreeParent]]

    self.panel = nil
    self.isVisible = false
    self.isAttach = false
    self.isWindow = false
    self.isValid = true
    self.label = label

    self.selectedItems = {}
    self.tree = tree

    self.treeRefs = {} -- save tree tables for collections
    self.leafRefs = {} -- save leaf selectables for items
    self.nodeRefs = {} -- save all cells for nodes
    self.collapsedTree = {}

    self:SetupKeyListeners()
end

function TreeList:SetupKeyListeners()
    self.selectModeKeySub = SubscribeKeyInput({}, function(e)
        if e.Repeat then return end
        if e.Key == "LCTRL" or e.Key == "RCTRL" then
            if e.Event == "KeyDown" then
                self.MultiSelect = true
                self.GroupSelect = false
                self.lastSelectedKey = nil
            elseif e.Event == "KeyUp" then
                self.MultiSelect = false
            end
        elseif e.Key == "LSHIFT" or e.Key == "RSHIFT" then
            if e.Event == "KeyDown" then
                self.GroupSelect = true
                self.MultiSelect = false
            elseif e.Event == "KeyUp" then
                self.GroupSelect = false
                self.lastSelectedKey = nil
            end
        end
    end)
end

function TreeList:Render()

    if self.parent and not self.isAttach then 
        self:OnAttach()
        self.panel = self.parent:AddChildWindow("TreeList" .. self.label)
        self.isWindow = false
    else
        self:OnDetach()
        self.panel = RegisterWindow("generic", self.label, "Tree List##", self)
        self.isWindow = true
        self.panel.Closeable = true
        self.panel.OnClose = function()
            self.detachButton:OnClick()
        end
    end

    self:RenderTopBar()
    self:RenderList()
end

function TreeList:Collapsed()
    if self.panel and self.isWindow then
        DeleteWindow(self.panel)
        self.panel = nil
    else
        self.panel:Destroy()
        self.panel = nil
    end

    self.rootTable = nil
    self.leafRefs = {}
    self.indexRefs = {}
    self.indexRefsReverse = {}
    self.treeRefs = {}
    self.nodeRefs = {}
end

function TreeList:Destroy()
    if not self.isValid then return end

    self:Collapsed()
    self.isValid = false
end

function TreeList:RenderTopBar()
    self.OtherPanel = self.panel:AddTree("Others")
    self:RenderCustomTopBar(self.OtherPanel)
    local rightA, leftA = AddRightAlignCell(self.panel)

    local searchInput = leftA:AddInputText("") --[[@as ExtuiInputText]]
    searchInput.IDContext = "TreeList" .. self.label .. "Search"

    local detachButton = rightA:AddSelectable(self.isWindow and "Attach" or "Detach")
    detachButton.OnClick = function()
        self.isAttach = not self.isAttach
        detachButton.Selected = false
        self:Collapsed()
        self:Render()
    end
    self.detachButton = detachButton

    local debounceTimer = nil

    searchInput.Hint = "Search..."
    searchInput.Text = self.SearchKeyword or ""
    searchInput.OnChange = function()
        self.SearchKeyword = searchInput.Text
        if debounceTimer then
            Timer:Cancel(debounceTimer)
            debounceTimer = nil
        end

        debounceTimer = Timer:After(50, function()
            self:Hide(searchInput.Text)
        end)
    end
end

--- return true to show the item
function TreeList:FilterFunc(key, keyword)
    return true
end

--- @param aKey any
--- @param bKey any
--- @return boolean
function TreeList.RenderOrder(aKey, bKey)
    return tostring(aKey) < tostring(bKey)
end

function TreeList:Hide(keyword)
    for _,node in pairs(self.nodeRefs) do
        node.Visible = false
    end

    if keyword == nil or keyword == "" then
        self:RecursiveShow(TreeTable.GetRootKey())
        return
    end

    local lowerKeyword = string.lower(keyword)
    for key, node in pairs(self.nodeRefs) do
        if self:FilterFunc(key, lowerKeyword) then
            node.Visible = true
            local path = self.tree:GetPath(key)
            for _,parentKey in pairs(path) do
                self.nodeRefs[parentKey].Visible = true
            end
        else
        end
    end
end

function TreeList:ShowAndShowPath(key)
    if not self.nodeRefs[key] then return end
    self.nodeRefs[key].Visible = true
    local path = self.tree:GetPath(key)
    for _,parentKey in pairs(path) do
        self.nodeRefs[parentKey].Visible = true
    end
end

-- Depth-first
--- @param func fun(key:any, node:any)
function TreeList:TraverseAllNodes(func)
    local stack = {TreeTable.GetRootKey()}
    while #stack > 0 do
        local current = table.remove(stack)
        local node = self.tree:Find(current)
        local nodeCell = self.nodeRefs[current]
        if node and nodeCell then
            func(current, nodeCell)
            if not self.tree:IsLeaf(current) then
                for childKey,_ in pairs(node) do
                    table.insert(stack, childKey)
                end
            end
        end
    end
end

function TreeList:RecursiveHide(key)
    local node = self.tree:Find(key)
    if node and not self.tree:IsLeaf(key) then
        for childKey,_ in pairs(node) do
            if self.nodeRefs[childKey] then
                self.nodeRefs[childKey].Visible = false
            end
            self:RecursiveHide(childKey)
        end
    end
end

function TreeList:RecursiveShow(key)
    local node = self.tree:Find(key)
    if node then
        self.nodeRefs[key].Visible = true
        if not self.collapsedTree[key] and not self.tree:IsLeaf(key) then
            for childKey,_ in pairs(node) do
                self:RecursiveShow(childKey)
            end
        end
    end
end

function TreeList:IterativeHide(key)
    local stack = {key}
    while #stack > 0 do
        local current = table.remove(stack)
        local node = self.tree:Find(current)
        if node and not self.tree:IsLeaf(current) then
            for childKey,_ in pairs(node) do
                if self.nodeRefs[childKey] then
                    self.nodeRefs[childKey].Visible = false
                end
                table.insert(stack, childKey)
            end
        end
    end
end

function TreeList:IterativeShow(key)
    local stack = {key}
    while #stack > 0 do
        local current = table.remove(stack)
        local node = self.tree:Find(current)
        if node then
            self.nodeRefs[current].Visible = true
            if not self.collapsedTree[current] and not self.tree:IsLeaf(current) then
                for childKey,_ in pairs(node) do
                    table.insert(stack, childKey)
                end
            end
        end
    end
end

---@param tbl ExtuiTable
function TreeList:ApplyTreeTableStyle(tbl)
    tbl.RowBg = true
    tbl.BordersH = true
end

function TreeList:RenderList()
    if self.oldTree then
        self:ClearList()
    end

    -- validate renderOrder
    local ok, err = pcall(self.RenderOrder, "a", "b")
    if not ok then
        Error("RenderOrder function error: " .. tostring(err) .. ". Using default order.")
        self.RenderOrder = function(aKey, bKey)
            return tostring(aKey) < tostring(bKey)
        end
    end
    if type(err) ~= "boolean" then
        Error("RenderOrder function must return boolean. Using default order.")
        self.RenderOrder = function(aKey, bKey)
            return tostring(aKey) < tostring(bKey)
        end
    end

    --- @type ExtuiTable
    self.rootTable = self.rootTable or self.panel:AddTable(self.label .. "##Root", 1)
    self.rootTable.UserData = self.rootTable.UserData or {}
    if self.rootTable.UserData.Row then
        self.rootTable.UserData.Row:Destroy()
        self.rootTable.UserData.Row = nil
    end
    local row = self.rootTable:AddRow()
    self.rootTable.UserData.Row = row
    self:ApplyTreeTableStyle(self.rootTable)

    self.treeRefs = {}
    self.leafRefs = {}
    self.nodeRefs = {}
    self.indexRefs = {}
    self.indexRefsReverse = {}
    self.nodeRefs[TreeTable.GetRootKey()] = row
    local leafCnt = 1

    local function collectChilds(key)
        local collector = {}
        local node = self.tree:Find(key)
        for childKey,_ in pairs(node or {}) do
            table.insert(collector, childKey)
        end
        table.sort(collector, self.RenderOrder)
        return collector
    end

    local depthIndent = function(key, node)
        local depth = self.tree:GetDepth(key)
        if depth and depth > 1 then
            return AddIndent(node, 10 + (depth - 2) * 30 * SCALE_FACTOR)
        end
        return node
    end

    local stack = {}
    local rootChilds = collectChilds(TreeTable.GetRootKey())
    for i = #rootChilds, 1, -1 do
        table.insert(stack, { key = rootChilds[i], depth = 1 })
    end

    while #stack > 0 do
        local item = table.remove(stack)
        local key, depth = item.key, item.depth
        local node = self.tree:Find(key)
        if node then
            if self.tree:IsLeaf(key) then
                local cell = row:AddCell()
                local indent = depthIndent(key, cell)
                local ele = self:RenderLeaf(key, indent)
                self.leafRefs[key] = ele
                self.nodeRefs[key] = cell
                self.indexRefs[key] = leafCnt
                self.indexRefsReverse[leafCnt] = key
                leafCnt = leafCnt + 1
                cell.UserData = ele
                cell.Visible = false
            else
                local cell = row:AddCell()
                local indent = depthIndent(key, cell)
                local ele = self:RenderTree(key, indent)
                self.treeRefs[key] = ele
                self.nodeRefs[key] = cell
                cell.UserData = ele
                cell.Visible = false

                local childs = collectChilds(key)
                for i = #childs, 1, -1 do
                    table.insert(stack, { key = childs[i], depth = depth + 1 })
                end
            end
        end
    end

    for key,ele in pairs(self.treeRefs) do
        self:SetUpTree(ele, key, self.tree:Find(key))
    end
    for key,ele in pairs(self.leafRefs) do
        self:SetUpLeaf(ele, key, self.tree:Find(key))
    end

    self:IterativeShow(TreeTable.GetRootKey())
end

function TreeList:ClearList()
    self:ClearSelection()
    self.leafRefs = {}
    self.treeRefs = {}
    self.indexRefs = {}
    self.indexRefsReverse = {}
    self.nodeRefs = {}
    if self.rootTable and self.rootTable.UserData and self.rootTable.UserData.Row then
        self.rootTable.UserData.Row:Destroy()
        self.rootTable.UserData.Row = nil
    end
end

---@param key any
---@param node ExtuiTableCell
---@return ExtuiSelectable return the selectable
function TreeList:RenderLeaf(key, node)
    local selectable = node:AddSelectable(key) --[[@as ExtuiSelectable]]
    return selectable
end

---@param key any
---@param node ExtuiTableCell
---@return ExtuiSelectable return the selectable
function TreeList:RenderTree(key, node)
    local tree = node:AddSelectable(key) --[[@as ExtuiSelectable]]
    return tree
end

function TreeList:ToggleSelected(key, selected)
    local ref = self.leafRefs[key]
    if ref then
        ref.Selected = selected
        if selected then
            self.selectedItems[key] = true
        else
            self.selectedItems[key] = nil
        end
    end
end

function TreeList:ClearSelection()
    for k, v in pairs(self.selectedItems) do
        self:ToggleSelected(k, false)
    end
    for k, ele in pairs(self.leafRefs) do
        ele.Selected = false
    end
    self.selectedItems = {}
    self:OnSelect(self.selectedItems)
end

---@param selectable ExtuiSelectable
---@param key any
---@param item any
function TreeList:SetUpLeaf(selectable, key, item)

    selectable.CanDrag = true
    selectable.DragDropType = "TreeList" .. self.label

    selectable.UserData = selectable.UserData or {}
    selectable.UserData.Item = item
    selectable.UserData.Key = key
    selectable.UserData.IsLeaf = true

    local parent = self.tree:GetParentKey(key)

    if self.selectedItems[key] then
        selectable.Selected = true
    else
        selectable.Selected = false
    end

    selectable.OnDragStart = function()
        if not self.MultiSelect and not self.GroupSelect then
            self:ClearSelection()
        end

        self:ToggleSelected(key, true)
        local previewTable = selectable.DragPreview:AddTable("##DragPreview", 1)
        self:ApplyTreeTableStyle(previewTable)
        local row = previewTable:AddRow()
        for key, item in pairs(self.selectedItems) do
            self:RenderLeaf(key, row:AddCell())
        end
        self:OnDragStart(key)
    end

    selectable.OnDragEnd = function()
    end

    selectable.OnDragDrop = function(sel, drop)
        local dropped = drop.UserData or {}
        self:OnDragDrop(dropped.Key, key)
        self:RenderList()
    end

    local userOnClick = selectable.OnClick

    selectable.OnClick = function(sel)
        if self.MultiSelect then
            self:ToggleSelected(key, not self.selectedItems[key])
        elseif self.GroupSelect then
            if self.lastSelectedKey and self.indexRefs and self.leafRefs[self.lastSelectedKey] then
                local lastSelectedKey = self.lastSelectedKey
                local startIdx = self.indexRefs[lastSelectedKey]
                local endIdx = self.indexRefs[key]
                Debug("Group select from", lastSelectedKey, "to", key)

                if startIdx and endIdx then
                    if startIdx > endIdx then
                        startIdx, endIdx = endIdx, startIdx
                    end

                    self:ClearSelection()

                    for i = startIdx, endIdx do
                        local indexkey = self.indexRefsReverse[i]
                        self:ToggleSelected(indexkey, true)
                    end
                else
                    Warning("Failed to determine range for group select")
                    self:ToggleSelected(key, true)
                end
            else
                self:ToggleSelected(key, true)
            end
            self.lastSelectedKey = key
            Debug("Last selected key set to", self.lastSelectedKey)
        else
            local oriStatus = self.selectedItems[key]
            self:ClearSelection()
            self:ToggleSelected(key, not oriStatus)
        end

        self:OnSelect(self.selectedItems)

        if userOnClick then
            userOnClick(sel)
        end
    end

end

---@param tree ExtuiSelectable
---@param key any
---@param item any
function TreeList:SetUpTree(tree, key, item)

    tree.CanDrag = true
    tree.DragDropType = "TreeList" .. self.label

    tree.UserData = tree.UserData or {}
    tree.UserData.Item = item
    tree.UserData.Key = key
    tree.UserData.IsTree = true

    local parent = self.tree:GetParentKey(key)

    tree.OnDragStart = function()
        local previewTable = tree.DragPreview:AddTable("##DragPreview", 1)
        self:ApplyTreeTableStyle(previewTable)
        local row = previewTable:AddRow()
        self:RenderTree(key, row:AddCell())
    end

    tree.OnDragDrop = function(sel, drop)
        local dropped = drop.UserData or {}
        self:OnDragDrop(dropped.Key, key)
        self:RenderList()
    end

    local userLabel = tree.Label
    local toggleLabel = function()
        if self.collapsedTree[key] then
            tree.Label = "[+] " .. userLabel
        else
            tree.Label = "[-] " .. userLabel
        end
    end

    local toggleFunc = function()
        self.collapsedTree[key] = not self.collapsedTree[key]
        if self.collapsedTree[key] then
            self:IterativeHide(key)
        else
            self:IterativeShow(key)
        end
        toggleLabel()
    end

    local userOnClick = tree.OnClick

    tree.OnClick = function(sel)
        sel.Selected = false

        local function recurSel(parent)
            local parentNode = self.tree:Find(parent)
            if parentNode then
                for key, cont in pairs(parentNode) do
                    if self.leafRefs[key] then
                        self:ToggleSelected(key, true)
                    else
                        recurSel(key)
                    end
                end
            end
        end

        if self.GroupSelect then
            self:ClearSelection()
            recurSel(key)
        else
            toggleFunc()
        end

        if userOnClick then
            userOnClick(sel)
        end

        self:OnSelect(self.selectedItems)
    end

    toggleLabel()

    tree.UserData = tree.UserData or {}

    tree.UserData.__index = function (t, k)
        if k == "Collapsed" then
            return self.collapsedTree[key] or false
        elseif k == "Toggle" then
            return toggleFunc
        end

        return rawget(t, k)
    end

    tree.UserData.__newindex = function(t, k, v)
        if k == "Collapsed" then
            if v ~= (self.collapsedTree[key] or false) then
                toggleFunc()
            end
        else
            rawset(t, k, v)
        end
    end
end

function TreeList:RenderCustomTopBar(panel)
    panel.Visible = false
end

---@param selectedItems table<key, boolean>
function TreeList:OnSelect(selectedItems) end

function TreeList:OnDragStart(dragKey) end

function TreeList:OnDragDrop(from, to) end

function TreeList:OnDragEnd(dragKey) end

function TreeList:OnAttach() end

function TreeList:OnDetach() end