--- @class TreeList
--- @field parent ExtuiTreeParent
--- @field panel ExtuiWindowBase|ExtuiWindow
--- @field selectedItems table<any, boolean>
--- @field treeRefs table<any, ExtuiSelectable>
--- @field leafRefs table<any, ExtuiSelectable>
--- @field nodeRefs table<any, ExtuiTableCell>
--- @field indexRefs table<any, number>
--- @field indexRefsReverse table<number, any>
--- @field rootTable ExtuiTable
--- @field tree TreeTable
--- @field isVisible boolean
--- @field label string
--- @field items any[]
--- @field keyField string
--- @field ExpandAll fun(self:TreeList, key:any)
--- @field CollapseAll fun(self:TreeList, key:any)
--- @field RenderLeaf fun(self:TreeList, key:any, node:ExtuiTableCell):ExtuiSelectable
--- @field RenderTree fun(self:TreeList, key:any, node:ExtuiTableCell):ExtuiSelectable
--- @field SetUpLeaf fun(self:TreeList, selectable:ExtuiSelectable, key:any, item:any)
--- @field SetUpTree fun(self:TreeList, tree:ExtuiSelectable, key:any, item:any)
--- @field RenderOrder fun(aKey:any, bKey:any):boolean
--- @field FilterFunc fun(self:TreeList, key:any, keyword:string):boolean
--- @field ShowAndShowPath fun(self:TreeList, key:any)
--- @field ClearSelection fun(self:TreeList)
--- @field ClearList fun(self:TreeList)
--- @field OnSelect fun(self:TreeList, selectedItems:table<any, boolean>)
--- @field OnDragStart fun(self:TreeList, dragKey:any)
--- @field OnDragDrop fun(self:TreeList, from:any, to:any)
--- @field OnDragEnd fun(self:TreeList, dragKey:any)
--- @field OnAttach fun(self:TreeList)
--- @field OnDetach fun(self:TreeList)
--- @field MultiSelect boolean
--- @field GroupSelect boolean
--- @field new fun(parent:ExtuiTreeParent, label:string, tree:TreeTable, opts:table?):TreeList
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

    self.treeRefs = {} -- save tree selectables
    self.leafRefs = {} -- save leaf selectables for items
    self.nodeRefs = {} -- save all cells for nodes, userdata is the indent container
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
            elseif e.Event == "KeyUp" then
                self.MultiSelect = false
            end
        elseif e.Key == "LSHIFT" or e.Key == "RSHIFT" then
            if e.Event == "KeyDown" then
                self.GroupSelect = true
                self.MultiSelect = false
            elseif e.Event == "KeyUp" then
                self.GroupSelect = false
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
    searchInput.OnChange = Debounce(50, function()
        self.SearchKeyword = searchInput.Text
        self:Hide(searchInput.Text)
    end)
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
--- @param func fun(key:any, node:ExtuiTableCell)
function TreeList:TraverseAllNodes(func)
    local stack = {}
    local root = self.tree:Find(TreeTable.GetRootKey())
    for childKey,_ in pairs(root) do
        table.insert(stack, childKey)
    end
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

    self.arrowRefs = {}
    self.treeRefs = {}
    self.leafRefs = {}
    self.nodeRefs = {}
    self.indexRefs = {}
    self.indexRefsReverse = {}
    setmetatable(self.nodeRefs, {
        __index = function(t, k)
            if k == TreeTable.GetRootKey() then
                return row
            end
            return rawget(t, k)
        end
    })
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
            local cell = row:AddCell()
            local indent = depthIndent(key, cell)
            cell.UserData = indent
            if self.tree:IsLeaf(key) then
                local ele = self:RenderLeaf(key, indent)
                self.leafRefs[key] = ele
                self.nodeRefs[key] = cell
                self.indexRefs[key] = leafCnt
                self.indexRefsReverse[leafCnt] = key
                leafCnt = leafCnt + 1
                cell.Visible = false
            else
                local arrowReserved = indent:AddGroup("##ArrowReserved")
                arrowReserved.IDContext = "TreeList" .. self.label .. "ArrowReserved" .. tostring(key)
                local icon = self.collapsedTree[key] and RB_ICONS.Tree_Collapsed or RB_ICONS.Tree_Expanded
                local arrowImage = arrowReserved:AddImage(icon, IMAGESIZE.TINY)
                local ele = self:RenderTree(key, indent)
                ele.SameLine = true
                self.arrowRefs[key] = arrowReserved
                self.treeRefs[key] = ele
                self.nodeRefs[key] = cell
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
    for key,arrow in pairs(self.arrowRefs) do
        self:SetupArrow(arrow, key)
    end

    self:IterativeShow(TreeTable.GetRootKey())
end

function TreeList:ClearList()
    --self:ClearSelection()
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

---@param key any
function TreeList:ToggleSelected(key)
    local ref = self.leafRefs[key]
    if ref then
        ref.Selected = not ref.Selected
        if ref.Selected then
            self.selectedItems[key] = true
        else
            self.selectedItems[key] = nil
        end
    end
end

function TreeList:SetSelected(key, selected)
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

function TreeList:ClearSelection(notCallback)
    for k, v in pairs(self.selectedItems) do
        self:ToggleSelected(k, false)
    end
    for k, ele in pairs(self.leafRefs) do
        ele.Selected = false
    end
    self.selectedItems = {}
    if not notCallback then
        self:OnSelect(self.selectedItems)
    end
end

local emptyFunc = function() end
---@param selectable ExtuiSelectable
---@param key any
function TreeList:SetUpLeaf(selectable, key)
    selectable.CanDrag = true
    selectable.DragDropType = "TreeList" .. self.label

    selectable.SpanAllColumns = true

    selectable.UserData = selectable.UserData or {}
    selectable.UserData.Key = key
    selectable.UserData.IsLeaf = true

    local parent = self.tree:GetParentKey(key)

    if self.selectedItems[key] then
        selectable.Selected = true
    else
        selectable.Selected = false
    end

    local userOnDragStart = selectable.OnDragStart or emptyFunc
    selectable.OnDragStart = function(sel)
        if not self.MultiSelect and not self.GroupSelect then
            self:ClearSelection()
        end

        self:ToggleSelected(key, true)
        local previewTable = selectable.DragPreview:AddTable("##DragPreview", 1)
        self:ApplyTreeTableStyle(previewTable)
        local row = previewTable:AddRow()
        for ikey, iitem in pairs(self.selectedItems) do
            self:RenderLeaf(ikey, row:AddCell())
        end
        self:OnDragStart(key)
        userOnDragStart(sel)
    end

    local userOnDragDrop = selectable.OnDragDrop or emptyFunc
    selectable.OnDragDrop = function(sel, drop)
        local dropped = drop.UserData or {}
        if dropped.Key then
            self:OnDragDrop(dropped.Key, key)
        end
        userOnDragDrop(sel, drop)
    end

    local userOnClick = selectable.OnClick or emptyFunc
    local userLabel = selectable.Label

    local setNewLabel = function()
        userLabel = selectable.Label
    end

    local delayTimer = nil
    local doubleClickThreshold = 400 -- ms
    
    --- @param sel ExtuiSelectable
    selectable.OnClick = function(sel)
        sel.Selected = not sel.Selected
        if delayTimer then
            Timer:Cancel(delayTimer)
            delayTimer = nil
            self:SetupRenameInput(key, userLabel)
            return
        end

        if self.MultiSelect then
            self:ToggleSelected(key)
        elseif self.GroupSelect then
            if self.lastSelectedKey and self.indexRefs and self.leafRefs[self.lastSelectedKey] then
                local lastSelectedKey = self.lastSelectedKey
                local startIdx = self.indexRefs[lastSelectedKey]
                local endIdx = self.indexRefs[key]

                if startIdx and endIdx then
                    if startIdx > endIdx then
                        startIdx, endIdx = endIdx, startIdx
                    end

                    self:SetSelected(lastSelectedKey, true)
                    for i = startIdx + 1, endIdx do
                        local indexkey = self.indexRefsReverse[i]
                        self:ToggleSelected(indexkey)
                    end
                else
                    Warning("Failed to determine range for group select")
                    self:ToggleSelected(key)
                end
            else
                self:ToggleSelected(key)
            end
        else
            local wasSelected = self.selectedItems[key] ~= nil
            self:ClearSelection(true)
            self:SetSelected(key, not wasSelected)
        end

        self.lastSelectedKey = key
        self:OnSelect(self.selectedItems)

        userOnClick(sel)

        delayTimer = Timer:After(doubleClickThreshold, function()
            if not delayTimer then return end
            delayTimer = nil
        end)
    end

    selectable.UserData.SetLabel = setNewLabel
end

---@param tree ExtuiSelectable
---@param key any
function TreeList:SetUpTree(tree, key)

    tree.CanDrag = true
    tree.DragDropType = "TreeList" .. self.label

    tree.UserData = tree.UserData or {}
    tree.UserData.Key = key
    tree.UserData.IsTree = true

    tree.SpanAllColumns = true

    local parent = self.tree:GetParentKey(key)

    local userOnDragStart = tree.OnDragStart or emptyFunc

    tree.OnDragStart = function(sel)
        local previewTable = tree.DragPreview:AddTable("##DragPreview", 1)
        self:ApplyTreeTableStyle(previewTable)
        local row = previewTable:AddRow()
        self:RenderTree(key, row:AddCell())
        userOnDragStart(sel)
    end

    local userDragDrop = tree.OnDragDrop or emptyFunc
    tree.OnDragDrop = function(sel, drop)
        local dropped = drop.UserData or {}
        if dropped.Key then
            self:OnDragDrop(dropped.Key, key)
        end
        userDragDrop(sel, drop)
    end

    local userLabel = tree.Label
    local toggleLabel = function()
        local reserved = self.arrowRefs[key]
        DestroyAllChilds(reserved)
        local icon = self.collapsedTree[key] and RB_ICONS.Tree_Collapsed or RB_ICONS.Tree_Expanded
        local arrowImage = reserved:AddImage(icon, IMAGESIZE.SMALL)
        arrowImage:SetColor("Button", {0,0,0,0})
    end

    local updateLabel = function()
        userLabel = tree.Label:gsub("^%[%+%]%s+", ""):gsub("^%[%-%]%s+", "")
        toggleLabel()
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

    local userOnClick = tree.OnClick or emptyFunc

    local delayTimer = nil
    local doubleClickThreshold = 300 -- ms

    tree.OnClick = function(sel)
        sel.Selected = false
        if delayTimer then
            Timer:Cancel(delayTimer)
            delayTimer = nil
            self:SetupRenameInput(key, userLabel)
            return
        end

        local function recurSel(pparent)
            local parentNode = self.tree:Find(pparent)
            if parentNode then
                for ikey, cont in pairs(parentNode) do
                    if self.leafRefs[ikey] then
                        self:ToggleSelected(ikey)
                    else
                        recurSel(ikey)
                    end
                end
            end
        end

        if self.GroupSelect then
            self:ClearSelection()
            recurSel(key)
            self:OnSelect(self.selectedItems)
        else
            toggleFunc()
        end

        userOnClick(sel)

        delayTimer = Timer:After(doubleClickThreshold, function()
            if not delayTimer then return end
            delayTimer = nil
        end)
    end

    toggleLabel()

    local function collapse()
        self.collapsedTree[key] = true
        self:IterativeHide(key)
        toggleLabel()
    end

    local function expand()
        self.collapsedTree[key] = nil
        self:IterativeShow(key)
        toggleLabel()
    end

    tree.UserData.Collapse = collapse
    tree.UserData.Expand = expand
    tree.UserData.UpdateLabel = toggleLabel
    tree.UserData.SetLabel = updateLabel

    setmetatable(tree.UserData, {
        __index = function(t, k)
            if k == "IsCollapsed" then
                return self.collapsedTree[key] == true
            end
            return nil
        end,
        __newindex = function(t, k, v)
            if k == "IsCollapsed" then
                if v == true then
                    self.collapsedTree[key] = true
                    self:IterativeHide(key)
                else
                    self.collapsedTree[key] = nil
                    self:IterativeShow(key)
                end
                toggleLabel()
            else
                rawset(t, k, v)
            end
        end
    })
end

function TreeList:SetupArrow(arrow, key)
    local show = false

    if self.collapsedTree[key] then
        show = true
    end

    arrow.OnRightClick = function()
        self.collapsedTree[key] = not self.collapsedTree[key]
        if show then
            self:ExpandAll(key)
        else
            self:CollapseAll(key)
        end

        show = not show
    end
end

function TreeList:OnRenameInput(key, newName) end
function TreeList:OnRenamingInput(key, newName) end

function TreeList:SetupRenameInput(key, userLabel)
    if self.IsRenaming then return end
    local isLeaf = self.leafRefs[key] ~= nil
    local selec = isLeaf and self.leafRefs[key] or self.treeRefs[key]
    if not selec then return end

    self.IsRenaming = true
    selec.Visible = false

    local node = self.nodeRefs[key].UserData

    userLabel = userLabel:gsub("##.*", "") -- remove id suffix
    local input = node:AddInputText("", userLabel) --[[@type ExtuiInputText?]]
    input.IDContext = "TreeList" .. self.label .. "RenameInput"
    input.SameLine = true

    local function rerender()
        selec.Visible = true
        self.IsRenaming = false
    end

    local function rename()
        if not input then return end
        local newName = input.Text
        input:Destroy()
        input = nil
        rerender()
        self.IsRenaming = false
        self:OnRenameInput(key, newName, selec)
        self:RenderList()
    end

    Timer:After(1000, function (timerID)
        local focusTimer = Timer:EveryFrame(function (timerID)
            local ok, focused = pcall(IsFocused, input)
            if not ok then
                pcall(rerender)
                return UNSUBSCRIBE_SYMBOL
            end

            if not focused and input then
                rename()
                return UNSUBSCRIBE_SYMBOL
            end
        end)
    end)

    local enterSub = SubscribeKeyInput({ Key = "RETURN" }, function (e)
        local ok, focused = pcall(IsFocused, input)
        if not ok then return UNSUBSCRIBE_SYMBOL end

        if focused and input then
            rename()
            return UNSUBSCRIBE_SYMBOL
        end
    end)

end

function TreeList:RenderCustomTopBar(panel)
    panel.Visible = false
end

function TreeList:ExpandAll(key)
    key = key or TreeTable.GetRootKey()

    self.collapsedTree = self.collapsedTree or {}

    
    self.collapsedTree[key] = nil
    self.treeRefs[key].UserData.Expand()

    local childStack = {}
    table.insert(childStack, key)
    
    while #childStack > 0 do
        local current = table.remove(childStack)
        local node = self.tree:Find(current)
        if node and not self.tree:IsLeaf(current) then
            for childKey,_ in pairs(node) do
                if not self.tree:IsLeaf(childKey) then
                    table.insert(childStack, childKey)
                    self.treeRefs[childKey].UserData.Expand()
                end
            end
        end
    end
end

function TreeList:CollapseAll(key)
    key = key or TreeTable.GetRootKey()

    self.collapsedTree = self.collapsedTree or {}

    self.collapsedTree[key] = nil
    self.treeRefs[key].UserData.Expand()

    local childStack = {}
    table.insert(childStack, key)

    while #childStack > 0 do
        local current = table.remove(childStack)
        local node = self.tree:Find(current)
        if node and not self.tree:IsLeaf(current) then
            for childKey,_ in pairs(node) do
                if not self.tree:IsLeaf(childKey) then
                    table.insert(childStack, childKey)
                    self.treeRefs[childKey].UserData.Collapse()
                end
            end
        end
    end
end

---@param selectedItems table<any, boolean>
function TreeList:OnSelect(selectedItems) end

function TreeList:OnDragStart(dragKey) end

function TreeList:OnDragDrop(from, to) end

function TreeList:OnDragEnd(dragKey) end

function TreeList:OnAttach() end

function TreeList:OnDetach() end