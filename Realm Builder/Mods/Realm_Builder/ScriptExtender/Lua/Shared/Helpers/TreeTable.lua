--- @class TreeTable
--- @field _table table
--- @field _nodeRefs table<any, any> -- maps key to node (table or leaf value)
--- @field _parentRefs table<any, any> -- maps child key to parent key
--- @field _leafRefs table<any, boolean> -- maps which keys are leaves, so leaf can have table value
--- @field _ancestorDepthCache table<any, number>
--- @field _ancestorUpCache table<any, table<number, any>>
--- @field _ancestorDirty boolean
--- @field new fun():TreeTable
--- @field GetRootKey fun():string
--- @field AddTree fun(self:TreeTable, key:any, parent?:any):table|nil
--- @field AddLeaf fun(self:TreeTable, key:any, value:any, parent?:any):any|nil
--- @field AddPath fun(self:TreeTable, path:any[]):boolean
--- @field Find fun(self:TreeTable, key:any):any|nil
--- @field GetPath fun(self:TreeTable, key:any, excludeSelf?:boolean, excludeRoot?:boolean):any[]
--- @field Remove fun(self:TreeTable, key:any):boolean
--- @field RemoveButKeepChildren fun(self:TreeTable, key:any):boolean
--- @field Reparent fun(self:TreeTable, key:any, newParent?:any):boolean
--- @field Rename fun(self:TreeTable, oldKey:any, newKey:any):boolean
--- @field SortTreesByDepth fun(self:TreeTable, order?:any, candidates?:table, ignoreRoot?:boolean):table<{Key:any, Depth:integer}>
--- @field SortNodesByDepth fun(self:TreeTable, order?:any, candidates?:table, ignoreRoot?:boolean):table<{Key:any, Node:any, Depth:integer, IsLeaf:boolean}>
--- @field GetDepth fun(self:TreeTable, key:any):number|nil
--- @field GetSiblings fun(self:TreeTable, key:any):table|nil
--- @field IsLeaf fun(self:TreeTable, key:any):boolean
--- @field IsAncestor fun(self:TreeTable, ancestorKey:any, descendantKey:any):boolean
--- @field AreSiblings fun(self:TreeTable, key1:any, key2:any):boolean
--- @field GetParent fun(self:TreeTable, key:any):any|nil
--- @field GetParentKey fun(self:TreeTable, key:any):any|nil
--- @field BuildAncestorCache fun(self:TreeTable)
--- @field _LCA fun(self:TreeTable, key1:any, key2:any):any|nil
--- @field _LCA_Binary fun(self:TreeTable, key1:any, key2:any):any|nil
--- @field FindLCA fun(self:TreeTable, keys:any[]):any|nil
--- @field _Swap fun(self:TreeTable, key1:any, key2:any):boolean
--- @field ToTable fun(self:TreeTable):table
--- @field FromTable fun(self:TreeTable, tbl:table)
--- @field FromTableStatic fun(tbl:table):TreeTable
TreeTable = {}
TreeTable.__index = TreeTable

local ROOT = "__root__"

---@return TreeTable
function TreeTable.new()
    local instance = {
        _table = {},
        _nodeRefs = {},
        _parentRefs = {},
        _leafRefs = {},
        _ancestorDepthCache = {},
        _ancestorUpCache = {},
        _ancestorDirty = true,
    }

    instance._nodeRefs[ROOT] = instance._table
    
    ---@param t TreeTable
    ---@param k any
    ---@param v any
    ---@param parentKey any
    local function setKey(t, k, v, parentKey)
        --Debug("Setting key '" .. k .. "' (" .. type(k) .. ") to " .. tostring(v) .. " (" .. type(v) .. "))")

        if rawget(t, k) ~= nil then
            --Debug("Cannot overwrite method or property '" .. k .. "'.")
            return
        end

        if t._nodeRefs[k] then
            --Debug("Key '" .. k .. "' already exists. Overwriting it.")
            if k == "MusicalInstrument" then Info("Here") end
            t:Remove(k)
        end

        if type(v) == "table" then
            local node = t:AddTree(k, parentKey)
            if node then
                for ck, cv in pairs(v) do
                    setKey(t, ck, cv, k)
                end
            end
        else
            t:AddLeaf(k, v, parentKey)
        end
    end

    setmetatable(instance, {
        __index = function(t, k)
            --Debug("Accessing key '" .. k .. "'")
            local method = rawget(TreeTable, k)
            if method then return method end

            local val = rawget(t, k)
            if val ~= nil then return val end

            return t._table[k]
        end,

        __newindex = function(t, k, v)
            setKey(t, k, v)
        end,

        __pairs = function(t)
            return pairs(t._table)
        end,

        __ipairs = function(t)
            return ipairs(t._table)
        end,
    })

    return instance
end

function TreeTable.GetRootKey()
    return ROOT
end

---@param node table
---@param collector table
function TreeTable:_collectChildNodes(node, collector)
    if type(node) ~= "table" then return end
    for childKey, childValue in pairs(node) do
        if self._nodeRefs[childKey] then
            table.insert(collector, childKey)
            if type(childValue) == "table" then
                self:_collectChildNodes(childValue, collector)
            end
        end
    end
end

--- @param node table
--- @param parentKey any
function TreeTable:_wrapNode(node, parentKey)
    --- @type TreeTable
    local self_ref = self


    local function setNodeKey(k, v)
        if self_ref._nodeRefs[k] then
            --Debug("Key '" .. k .. "' already exists. Overwriting it.")
            self_ref:Remove(k)
        end
        if type(v) == "table" then
            local node = self_ref:AddTree(k, parentKey)
            if node then
                for ck, cv in pairs(v) do
                    setNodeKey(ck, cv)
                end
            end
        else
            self_ref:AddLeaf(k, v, parentKey)
        end
    end

    setmetatable(node, {
        __newindex = function(t, k, v)
            setNodeKey(k, v)
        end,
    })
end

---@param key any
---@param parent? any default to root
---@return table|nil
function TreeTable:AddTree(key, parent)
    if rawget(TreeTable, key) then
        --Debug("Cannot use method name '" .. key .. "' as a table key.")
        return nil
    end

    if key == ROOT then
        --Debug("Cannot use reserved key '" .. ROOT .. "'.")
        return nil
    end

    local parentNode = parent and self._nodeRefs[parent] or self._table
    if not parentNode then
        --Debug("Parent '" .. tostring(parent) .. "' not found.")
        return nil
    end
    if parentNode == self._table then
        parent = ROOT
    end
    if type(parentNode) ~= "table" or self:IsLeaf(parent) then
        --Debug("Trying to index a leaf. Cannot add child '" .. tostring(key) .. "'.")
        return nil
    end 

    if self._nodeRefs[key] then
        --Debug("Key '" .. key .. "' already exists.")
        return nil
    end
    if key == parent then
        --Debug("Cannot add a node as its own child")
        return nil
    end

    local node = {}
    rawset(parentNode, key, node)
    self._nodeRefs[key] = node
    self._parentRefs[key] = parent
    self._leafRefs[key] = nil
    self:_wrapNode(node, key)
    self._ancestorDirty = true
    return node
end

function TreeTable:AddPath(path)
    if #path <= 1 and path[1] == ROOT then
        return false
    end

    local currentParent = ROOT

    for _, segment in ipairs(path) do
        if segment == currentParent and segment ~= ROOT then
            return false
        end

        local existingNode = self:Find(segment)

        if existingNode then
            local parent = self:GetParentKey(segment)
            if parent ~= currentParent then
                return false
            end

        else
            local newNode = self:AddTree(segment, currentParent)
            if not newNode then
                return false
            end
        end
        currentParent = segment
    end

    return true
end
--- @param key any
--- @param parent? any
--- @return table|nil
function TreeTable:ForceAddTree(key, parent)
    if self:Find(key) and not self:IsLeaf(key) then
        if parent ~= nil and parent ~= self:GetParentKey(key) then
            self:Reparent(key, parent)
        end
        return self:Find(key)
    end

    parent = parent or self:GetParentKey(key) or ROOT
    self:RemoveButKeepChildren(key)
    return self:AddTree(key, parent)
end

--- @param key any
--- @param value any
function TreeTable:AddLeaf(key, value, parent)
    --Warning("Adding leaf " .. key .. " with value " .. tostring(value) .. " under parent " .. tostring(parent))
    if key == ROOT then
        return nil
    end

    local parentNode = parent and self._nodeRefs[parent] or self._table
    if not parentNode then
        return nil
    end

    if parentNode == self._table then
        parent = ROOT
    end

    if self._nodeRefs[key] then
        return nil
    end

    if self:IsLeaf(parent) then
        return nil
    end

    if key == parent then
        return nil
    end

    rawset(parentNode, key, value)
    self._nodeRefs[key] = value
    self._parentRefs[key] = parent
    self._leafRefs[key] = true
    self._ancestorDirty = true

    --Debug("Added leaf '" .. tostring(key) .. "' with value " .. tostring(value) .. " under parent '" .. tostring(parent) .. "'.")

    return value
end

--- @param key any
--- @param value any
--- @param parent? any
--- @return table|nil
function TreeTable:ForceAddLeaf(key, value, parent)
    self:Remove(key)
    return self:AddLeaf(key, value, parent)
end

--- @param key any
function TreeTable:Find(key)
    return self._nodeRefs[key]
end

function TreeTable:SetLeafValue(key, value)
    if not self._leafRefs[key] then
        --Debug("Key '" .. tostring(key) .. "' is not a leaf.")
        return false
    end
    local parentNode = self:GetParent(key)
    if not parentNode then
        --Debug("Cannot find parent of '" .. tostring(key) .. "'.")
        return false
    end
    rawset(parentNode, key, value)
    return true
end

function TreeTable:GetParent(key)
    local parentKey = self._parentRefs[key]
    return self._nodeRefs[parentKey]
end

function TreeTable:GetParentKey(key)
    return self._parentRefs[key]
end

function TreeTable:IsLeaf(key)
    local yes = self._leafRefs[key]
    return yes and true or false
end

--- @param key any
--- @return any[]
function TreeTable:CollectChildren(key)
    local node = self._nodeRefs[key]
    if not node then
        --Debug("Key '" .. tostring(key) .. "' not found.")
        return {}
    end

    local children = {}
    local stack = {node}
    while #stack > 0 do
        local currentNode = table.remove(stack)
        for childKey, childValue in pairs(currentNode) do
            table.insert(children, childKey)
            if type(childValue) == "table" and (not self:IsLeaf(childKey)) then
                table.insert(stack, childValue)
            end
        end
    end
    
    return children
end

function TreeTable:IsAncestor(ancestorKey, descendantKey)
    local currentKey = descendantKey
    local visited = {}
    while currentKey do
        if visited[currentKey] then
            --Debug("Cycle detected when checking ancestor relationship between '" .. tostring(ancestorKey) .. "' and '" .. tostring(descendantKey) .. "'.")
            return false
        end

        if currentKey == ancestorKey then
            return true
        end

        visited[currentKey] = true

        currentKey = self._parentRefs[currentKey]
    end
    return false
end

function TreeTable:IsDescendant(descendantKey, ancestorKey)
    return self:IsAncestor(ancestorKey, descendantKey)
end

--- return a list of keys from root to the specified key
function TreeTable:GetPath(key, excludeSelf, excludeRoot)
    if not self:Find(key) then
        --Debug("Key '" .. tostring(key) .. "' not found.")
        return {}
    end
    local path = {}
    local currentKey = key
    local visited = {}
    while currentKey do
        if visited[currentKey] then
            Debug("Cycle detected when getting path for key '" .. tostring(key) .. "'. Aborting.")
            return {}
        end
        table.insert(path, 1, currentKey)
        visited[currentKey] = true
        currentKey = self._parentRefs[currentKey]
    end
    if excludeSelf then
        table.remove(path)
    end
    if excludeRoot and path[1] == ROOT then
        table.remove(path, 1)
    end
    return path
end

function TreeTable:AreSiblings(key1, key2)
    local parent1 = self._parentRefs[key1]
    local parent2 = self._parentRefs[key2]
    return parent1 ~= nil and parent1 == parent2
end

function TreeTable:GetSiblings(key)
    local parentKey = self._parentRefs[key]
    if not parentKey then return {} end
    local parentNode = self._nodeRefs[parentKey]
    if not parentNode then return {} end

    local siblings = {}
    for childKey, _ in pairs(parentNode) do
        if childKey ~= key and self._nodeRefs[childKey] then
            table.insert(siblings, childKey)
        end
    end
    return siblings
end

function TreeTable:AreCousins(key1, key2)
    local parent1 = self._parentRefs[key1]
    local parent2 = self._parentRefs[key2]
    if not parent1 or not parent2 or parent1 == parent2 then
        return false
    end
    local grandParent1 = self._parentRefs[parent1]
    local grandParent2 = self._parentRefs[parent2]
    return grandParent1 ~= nil and grandParent1 == grandParent2
end

function TreeTable:__detectCycle()
    for key,_ in pairs(self._nodeRefs) do
        local slow = key
        local fast = key
        for _ = 1, 1000 do
            slow = self._parentRefs[slow]
            if not slow then break end
            fast = self._parentRefs[fast]
            if not fast then break end
            fast = self._parentRefs[fast]
            if not fast then break end
            if slow == fast then
                --Debug("Cycle detected at key '" .. tostring(key) .. "'.")
                return true
            end
        end
    end
    return false
end

function TreeTable:__CheckIfAnyDuplicateKey()
    local seen = {}
    local duplicateKeys = {}
    
    local function traverseTable(tbl, path)
        for k, v in pairs(tbl) do
            local fullPath = path .. "." .. tostring(k)
            if seen[k] then
                table.insert(duplicateKeys, {
                    key = k,
                    firstPath = seen[k],
                    secondPath = fullPath,
                    inNodeRefs = self._nodeRefs[k] ~= nil
                })
                --Debug("Duplicate key detected: '" .. tostring(k) .. "' at " .. seen[k] .. " and " .. fullPath)
                --Debug("  - Key in _nodeRefs: " .. tostring(self._nodeRefs[k] ~= nil))
                return true
            end
            seen[k] = fullPath
            if type(v) == "table" and not self._leafRefs[k] then
                if traverseTable(v, fullPath) then
                    return true
                end
            end
        end
        return false
    end
    
    if traverseTable(self._table, "root") then
        Error("Duplicate keys detected in the tree structure.")
        Error("Duplicate details:", duplicateKeys)
    else
        --Debug("No duplicate keys detected.")
    end
end

function TreeTable:BuildAncestorTable()
    self._ancestorDepthCache = {}
    self._ancestorUpCache = {}
    self._ancestorDirty = false

    local keySortByDepth = {}

    for key,_ in pairs(self._nodeRefs) do
        local depth = 0
        local currentKey = key
        self._ancestorUpCache[key] = {}
        while self._nodeRefs[currentKey] do
            currentKey = self._parentRefs[currentKey]
            depth = depth + 1
            if depth > 1000 then
                Debug("Possible cycle detected when calculating depth for key '" .. tostring(key) .. "'. Aborting.")
                break
            end
        end

        self._ancestorDepthCache[key] = depth - 1

        if not keySortByDepth[depth] then
            keySortByDepth[depth] = {}
        end

        table.insert(keySortByDepth[depth], key)
    end

    for depth = 1, #keySortByDepth do
        local keysAtDepth = keySortByDepth[depth]
        if keysAtDepth then
            for _, key in ipairs(keysAtDepth) do
                local parentKey = self._parentRefs[key]
                if parentKey and self._ancestorUpCache[parentKey] then
                    self._ancestorUpCache[key][0] = parentKey
                    local j = 1
                    while self._ancestorUpCache[parentKey][j - 1] do
                        self._ancestorUpCache[key][j] = self._ancestorUpCache[self._ancestorUpCache[key][j - 1]][j - 1]
                        j = j + 1
                    end
                end
            end
        end
    end

end

-- Don't know why I even wrote this
function TreeTable:_LCA_Binary(key1, key2)
    if self._ancestorDirty then
        self:BuildAncestorTable()
    end
    if not self._ancestorDepthCache[key1] or not self._ancestorDepthCache[key2] then
        --Debug("One or both keys not found in ancestor table.")
        return nil
    end

    if self._ancestorDepthCache[key1] < self._ancestorDepthCache[key2] then
        key1, key2 = key2, key1
    end

    local depthDiff = self._ancestorDepthCache[key1] - self._ancestorDepthCache[key2]

    local diff = depthDiff
    local j = 0
    while diff > 0 do
        if diff & 1 == 1 then
            key1 = self._ancestorUpCache[key1][j]
        end
        diff = diff >> 1
        j = j + 1
    end
    
    if key1 == key2 then
        return key1
    end
    local maxJ = 0
    while self._ancestorUpCache[key1][maxJ] do
        maxJ = maxJ + 1
    end

    for j = maxJ - 1, 0, -1 do
        if self._ancestorUpCache[key1][j] and self._ancestorUpCache[key1][j] ~= self._ancestorUpCache[key2][j] then
            key1 = self._ancestorUpCache[key1][j]
            key2 = self._ancestorUpCache[key2][j]
        end
    end

    --Debug("LCA of [" .. key1 .. "] and [" .. key2 .. "] is [", self._ancestorUpCache[key1][0] ,"] Using binary lifting")
    return self._ancestorUpCache[key1][0]
end

function TreeTable:_LCA(key1, key2)
    if self._ancestorDirty then
        self:BuildAncestorTable()
    end

    local path1 = self:GetPath(key1)
    local path2 = self:GetPath(key2)

    local lca = nil
    local minLength = math.min(#path1, #path2)
    for i = 1, minLength do
        if path1[i] == path2[i] then
            lca = path1[i]
        else
            break
        end
    end

    return lca
end

function TreeTable:FindLCA(keys)
    if #keys < 2 then
        return self:GetParentKey(keys[1])
    end

    local lca = keys[1]
    for i = 2, #keys do
        lca = self:_LCA_Binary(lca, keys[i])
        if not lca then
            return nil
        end
    end

    if table.find(keys, lca) then
        lca = self._parentRefs[lca]
    end

    return lca
end

--- @param key any
--- @return any|nil removed node
function TreeTable:Remove(key)
    --Warning("Removing key " .. key)
    if key == ROOT then
        --Debug("Cannot remove the root node.")
        return nil
    end

    local node = self._nodeRefs[key]
    if not node then
        --Debug("Key '" .. tostring(key) .. "' not found.")
        return nil
    end

    local nodesToRemove = {key}
    if type(node) == "table" and not self:IsLeaf(key) then
        self:_collectChildNodes(node, nodesToRemove)
    end

    local parentKey = self._parentRefs[key]
    local parentNode = parentKey and self._nodeRefs[parentKey] or self._table
    if not parentNode then
        --Debug("Parent of '" .. tostring(key) .. "' not found.")
        return nil
    end

    rawset(parentNode, key, nil)

    if rawget(parentNode, key) ~= nil then
        --Debug("Failed to remove key '" .. tostring(key) .. "' from parent.")
        return nil
    end

    for _, nodeKey in ipairs(nodesToRemove) do
        rawset(self._nodeRefs, nodeKey, nil)
        self._parentRefs[nodeKey] = nil
        self._leafRefs[nodeKey] = nil
    end

    --Debug("Removed '" .. tostring(key) .. "' and " .. (#nodesToRemove - 1) .. " child nodes.")

    self._ancestorDirty = true
    self:__CheckIfAnyDuplicateKey()
    return node
end

function TreeTable:RemoveButKeepChildren(key)
    --Warning("Removing key but keep children " .. key)
    if key == ROOT then
        --Debug("Cannot remove the root node.")
        return false
    end

    local node = self._nodeRefs[key]
    if not node then
        --Debug("Key '" .. tostring(key) .. "' not found.")
        return false
    end

    if self:IsLeaf(key) then
        --Debug("Key '" .. tostring(key) .. "' is a leaf, cannot keep children.")
        return self:Remove(key)
    end

    local parentKey = self._parentRefs[key] 
    local parentNode = parentKey and self._nodeRefs[parentKey] or self._table

    for childKey, childValue in pairs(node) do
        if self._nodeRefs[childKey] then
            if rawget(parentNode, childKey) then
                --Debug("Cannot move child '" .. tostring(childKey) .. "' - key already exists in parent.")
            else
                rawset(parentNode, childKey, childValue)
                self._parentRefs[childKey] = parentKey
                --Debug("Moved child '" .. tostring(childKey) .. "' to parent.")
            end
        end
    end

    rawset(parentNode, key, nil)

    rawset(self._nodeRefs, key, nil)
    self._parentRefs[key] = nil
    self._leafRefs[key] = nil

    --Debug("Removed '" .. tostring(key) .. "' but kept its children.")
    self._ancestorDirty = true
    --self:__CheckIsAnyDuplicateKey()
    return true
end

function TreeTable:Reparent(key, newParent)
    if key == ROOT then
        --Debug("Cannot reparent the root node.")
        return false
    end

    local node = self._nodeRefs[key]
    if not node then
        --Debug("Key '" .. tostring(key) .. "' not found.")
        return false
    end

    local newParentNode
    if newParent then
        newParentNode = self._nodeRefs[newParent]
        if not newParentNode then
            --Debug("New parent '" .. tostring(newParent) .. "' Not Found.")
            return false
        end
        if self:IsLeaf(newParent) then
            --Debug("New parent '" .. tostring(newParent) .. "' is a leaf, cannot reparent to it.")
            return false
        end

        if self:IsAncestor(key, newParent) then
            --Debug("Cannot reparent '" .. tostring(key) .. "' to its descendant '" .. tostring(newParent) .. "'.")
            return false
        end
    else
        newParentNode = self._table
        newParent = ROOT
    end

    local oriParentNode = self:GetParent(key)
    if oriParentNode == newParentNode then
        --Debug("Node '" .. tostring(key) .. "' is already under the specified parent.")
        return false
    end

    if oriParentNode then
        rawset(oriParentNode, key, nil)
    end

    self._parentRefs[key] = newParent
    rawset(newParentNode, key, node)
    
    --Debug("Reparented '" .. tostring(key) .. "' to '" .. tostring(newParent or "root") .. "'.")
    self._ancestorDirty = true
    self:__CheckIfAnyDuplicateKey()
    return true
end

function TreeTable:Rename(oldKey, newKey)
    if oldKey == ROOT or newKey == ROOT then
        --Debug("Cannot rename to or from reserved key '" .. ROOT .. "'.")
        return false
    end

    if oldKey == newKey then
        --Debug("Old key and new key are the same. No action taken.")
        return false
    end

    local node = self._nodeRefs[oldKey]
    if not node then
        --Debug("Key '" .. tostring(oldKey) .. "' not found.")
        return false
    end

    if self._nodeRefs[newKey] then
        --Debug("New key '" .. tostring(newKey) .. "' already exists.")
        return false
    end

    local oldParent = self._parentRefs[oldKey]
    local parentNode = self._nodeRefs[oldParent] or self._table
    if not parentNode then
        --Debug("Parent of '" .. tostring(oldKey) .. "' not found.")
        return false
    end

    rawset(parentNode, oldKey, nil)
    rawset(parentNode, newKey, node)

    self._nodeRefs[newKey] = node
    self._nodeRefs[oldKey] = nil

    self._parentRefs[newKey] = oldParent
    self._parentRefs[oldKey] = nil

    if self._leafRefs[oldKey] then
        self._leafRefs[newKey] = true
        self._leafRefs[oldKey] = nil
    else
        self._leafRefs[newKey] = nil
    end

    if type(node) == "table" and not self:IsLeaf(newKey) then
        for childKey, _ in pairs(node) do
            if self._parentRefs[childKey] == oldKey then
                self._parentRefs[childKey] = newKey
            end
        end
    end

    --Debug("Renamed '" .. tostring(oldKey) .. "' to '" .. tostring(newKey) .. "'.")
    self._ancestorDirty = true
    return true
end

function TreeTable:_Swap(key1, key2)
    if key1 == ROOT or key2 == ROOT then
        --Debug("Cannot swap the root node.")
        return false
    end

    local node1 = self._nodeRefs[key1]
    local node2 = self._nodeRefs[key2]
    if not node1 or not node2 then
        --Debug("One or both keys not found.")
        return false
    end

    local parent1 = self._parentRefs[key1]
    local parent2 = self._parentRefs[key2]
    local parentNode1 = self._nodeRefs[parent1] or self._table
    local parentNode2 = self._nodeRefs[parent2] or self._table
    if not parentNode1 or not parentNode2 then
        --Debug("One or both parents not found.")
        return false
    end

    rawset(parentNode1, key1, nil)
    rawset(parentNode2, key2, nil)

    rawset(parentNode1, key2, node2)
    rawset(parentNode2, key1, node1)

    self._parentRefs[key1] = parent2
    self._parentRefs[key2] = parent1

    --Debug("Swapped '" .. tostring(key1) .. "' and '" .. tostring(key2) .. "'.")
    self._ancestorDirty = true
    return true
end

function TreeTable:GetDepth(key)
    if self._ancestorDirty then
        self:BuildAncestorTable()
    end
    if not self._ancestorDepthCache[key] then
        --Debug("Key '" .. tostring(key) .. "' not found. Rebuilding ancestor table and retrying.")
        self:BuildAncestorTable()
        if not self._ancestorDepthCache[key] then
            --Debug("Key '" .. tostring(key) .. "' still not found after rebuilding ancestor table.")
            return nil
        end
    end
    return self._ancestorDepthCache[key]
end

--- default order = "asc"
--- @param order "asc"|"desc"
--- @return table<{Key:any, Depth:integer}>|nil
function TreeTable:SortTreesByDepth(order, candidates, ignoreRoot)
    if self._ancestorDirty then
        self:BuildAncestorTable()
    end

    order = order or "asc"
    if order ~= "asc" and order ~= "desc" then
        --Debug("Invalid order '" .. tostring(order) .. "'. Use 'asc' or 'desc'.")
        return nil
    end

    local trees = {}
    for key, node in pairs(self._nodeRefs) do
        if ignoreRoot and key == ROOT then
            goto continue
        end
        if type(node) == "table" and not self:IsLeaf(key) then
            if not candidates or TableContains(candidates, key) then
                table.insert(trees, { Key = key, Depth = self:GetDepth(key) })
            end
        end
        ::continue::
    end

    local mul = order == "asc" and 1 or -1
    table.sort(trees, function(a, b)
        if a.Depth == b.Depth then
            return a.Key < b.Key
        end
        return (a.Depth - b.Depth) * mul < 0
    end)
    return trees
end

--- default ascending
--- @return table<{Key:any, Node:any, Depth:integer, IsLeaf:boolean}>|nil
function TreeTable:SortNodesByDepth(order, candidates, ignoreRoot)
    if self._ancestorDirty then
        self:BuildAncestorTable()
    end

    order = order or "asc"
    if order ~= "asc" and order ~= "desc" then
        --Debug("Invalid order '" .. tostring(order) .. "'. Use 'asc' or 'desc'.")
        return nil
    end

    local nodes = {}
    for key, node in pairs(self._nodeRefs) do
        if ignoreRoot and key == ROOT then
            goto continue
        end
        if not candidates or TableContains(candidates, key) then
            table.insert(nodes, { Key = key, Node = node, Depth = self:GetDepth(key), IsLeaf = self:IsLeaf(key) })
        end
        ::continue::
    end

    local mul = order == "asc" and 1 or -1
    table.sort(nodes, function(a, b)
        if a.Depth == b.Depth then
            return a.Key < b.Key
        end

        return (a.Depth - b.Depth) * mul < 0
    end)
    return nodes
end

function TreeTable:SaveAllLeaves()
    local leaves = {}
    for key, _ in pairs(self._leafRefs) do
        leaves[key] = self._nodeRefs[key]
    end
    return leaves
end

--- return a copy of the internal table
function TreeTable:ToTable()
    return DeepCopy(self._table)
end

function TreeTable:FromTable(tbl)
    local function recursiveAdd(t, parentKey)
        for k, v in pairs(t) do
            if type(v) == "table" then
                local newNode = self:AddTree(k, parentKey)
                if newNode then
                    recursiveAdd(v, k)
                end
            else
                self:AddLeaf(k, v, parentKey)
            end
        end
    end
    self:Clear()
    recursiveAdd(tbl, nil)
end

function TreeTable.FromTableStatic(tbl)
    local tree = TreeTable.new()
    tree:FromTable(tbl or {})
    return tree
end

function TreeTable:Clear()
    self._table = {}
    self._nodeRefs = {}
    self._parentRefs = {}
    self._leafRefs = {}
    self._ancestorDepthCache = {}
    self._ancestorUpCache = {}
    self._ancestorDirty = true

    self._nodeRefs[ROOT] = self._table
end

local function TreeTableTest()
    local now = Ext.Timer.MonotonicTime()
    local tree = TreeTable.new()
    tree:AddTree("A") -- == tree.A = {}
    tree:AddTree("B", "A") -- == tree.A.B = {}
    tree:AddTree("C", "B") -- == tree.A.B.C = {}
    tree:AddLeaf("D", "ValueD", "C") -- == tree.A.B.C.D = "ValueD"
    tree:AddLeaf("E", "ValueE", "A") -- == tree.A.E = "ValueE"
    --Debug("Initial Tree:")
    --Debug(tree:ToTable())

    --Debug("\nRemoving 'B' (should remove B, C, D):")
    tree:Remove("B")
    --Debug(tree:ToTable())

    tree:AddTree("B", "A") -- == tree.A.B = {}
    tree:AddTree("C", "B") -- == tree.A.B.C = {}
    tree:AddLeaf("D", "ValueD", "C") -- == tree.A.B.C.D = "ValueD"
    --Debug("\nRe-added B, C, D:")
    --Debug(tree:ToTable())

    --Debug("\nRemoving 'B' but keeping children (should move C and D under A):")
    tree:RemoveButKeepChildren("B")
    --Debug(tree:ToTable())

    --Debug("\nReparenting 'C' to root:")
    tree:Reparent("C")
    --Debug(tree:ToTable())

    --Debug("\nTable syntax test:")
    tree.F = {}
    tree.F.G = {}
    tree.F.G.H = "ValueH"
    --Debug(tree:ToTable())
    --Debug("Finding 'H':", tree:Find("H"))
    --Debug("Finding 'NonExistent':", tree:Find("NonExistent"))

    tree:Remove("F")
    --Debug("\nAfter removing 'F':")
    tree.F = { F = { I = "ValueI" } }
    tree.F.F = { I = "ValueI", F = { LOL = "ValueJ" }, LOL = { K = "ValueK" } }
    --Debug("\nAfter adding more nodes:")
    --Debug(tree:ToTable())

    --Debug("\nRenaming 'LOL' to 'LMAO':")
    tree:Rename("LOL", "LMAO")
    --Debug(tree:ToTable())

    tree:AddLeaf("X", { Nested = { Deep = "ValueDeep" } }, "A")
    tree:AddLeaf("S", { Nested = { Deep = "ValueDeep" } }, "A")
    --Debug("\nAfter adding leaves with nested tables:")
    --Debug(tree:ToTable())
    --Debug(tree._nodeRefs)

    tree:Remove("X")
    --Debug("\nAfter removing 'X':")
    --Debug(tree:ToTable())


    tree:FromTable({
        A = {
            E = "ValueE",
            S = { Nested = { Deep = "ValueDeep" } },
            F = {
                F = {
                    I = "ValueI",
                    F = { LMAO = "ValueJ" },
                    LMAO = { K = "ValueK" }
                },
                I = "ValueI",
                LMAO = { K = "ValueK" }
            },
            C = {
                D = "ValueD"
            }
        },
        B = {
            C = {
                D = "ValueD"
            }
        }
    })

    --Debug("\nLowest Common Ancestor of 'D' and 'E':", tree:_LCA("D", "E"))
    --Debug("Lowest Common Ancestor of 'D' and 'K':", tree:_LCA("D", "K"))
    --Debug("Lowest Common Ancestor of 'I' and 'K':", tree:_LCA("I", "K"))
    --Debug("Lowest Common Ancestor of 'D' and 'NonExistent':", tree:_LCA("D", "NonExistent"))
    --Debug("Lowest Common Ancestor of 'NonExistent1' and 'NonExistent2':", tree:_LCA("NonExistent1", "NonExistent2"))
    --Debug("Lowest Common Ancestor Binary of 'D' and 'E':", tree:_LCA_Binary("D", "E"))
    --Debug("Lowest Common Ancestor Binary of 'D' and 'B' :", tree:_LCA_Binary("D", "B"))
    --Debug("\nTrees by hierarchy (asc):")
    local treesAsc = tree:GetTreesByHierarchy("asc")
    for _, entry in ipairs(treesAsc) do
        --Debug("Key: " .. entry.Key .. ", Depth: " .. entry.Depth)
    end
    --Debug("\nTrees by hierarchy (desc):")
    local treesDesc = tree:GetTreesByHierarchy("desc")
    for _, entry in ipairs(treesDesc) do
        --Debug("Key: " .. entry.Key .. ", Depth: " .. entry.Depth)
    end


    local fromTable = TreeTable.FromTableStatic(tree:ToTable())
    --Debug("\nTree reconstructed from table:")
    --Debug(fromTable:ToTable())
    print("test completed in " .. (Ext.Timer.MonotonicTime() - now) .. " ms.")
end

--TreeTableTest()