--- @enum LSXValueType
LSXValueType = {
    TranslatedString = "TranslatedString",
    FixedString = "FixedString",
    LSString = "LSString",
    bool = "bool",
    uint8 = "uint8",
    int8 = "int8",
    uint32 = "uint32",
    int32 = "int32",
    uint64 = "uint64",
    int64 = "int64",
    float = "float",
    fvec3 = "fvec3",
    fvec4 = "fvec4",
    guid = "guid",
}

local function escapeXML(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub("\"", "&quot;")
    s = s:gsub("'", "&apos;")
    return s
end

--- @param value any
--- @return string
local function serializeNonStringAttributes(value)
    if type(value) == "number" then
        return tostring(value)
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    elseif type(value) == "table" then
        return table.concat(value, " ")
    end

    -- fallback: stringify and escape
    return escapeXML(tostring(value))
end

local defaultStringifyOptions = {
    Indent = 4,
    IncludeComments = true,
    MaxDepth = 100,
    InlcudeHeader = true,
}

local function validateStringifyOptions(opts)
    local validOpts = DeepCopy(defaultStringifyOptions)
    if type(opts) ~= "table" then
        return validOpts
    end
    if opts.Indent and type(opts.Indent) == "number" and opts.Indent >= 0 then
        validOpts.Indent = opts.Indent
    end
    if opts.IncludeComments ~= nil and type(opts.IncludeComments) == "boolean" then
        validOpts.IncludeComments = opts.IncludeComments
    end
    if opts.MaxDepth and type(opts.MaxDepth) == "number" and opts.MaxDepth >= 0 then
        validOpts.MaxDepth = opts.MaxDepth
    end
    if opts.InlcudeHeader ~= nil and type(opts.InlcudeHeader) == "boolean" then
        validOpts.InlcudeHeader = opts.InlcudeHeader
    end

    return validOpts
end

--- @class LSXStringfiyOptions
--- @field Indent number
--- @field IncludeComments boolean
--- @field IncludeHeader boolean -- whether to include the XML declaration
--- @field MaxDepth number

--- @class LSXNode
--- @field __name string
--- @field __attributes table<string, any>
--- @field __children LSXNode[]
--- @field __parent LSXNode|nil
--- @field __comments string[]
--- @field __innerText string|nil
--- @field __attrOrder string[]|nil
--- @field Stringify fun(self: LSXNode, stringifyOpts?: LSXStringfiyOptions): string
--- @field SetInnerText fun(self: LSXNode, text: string): LSXNode -- returns self
--- @field SetName fun(self: LSXNode, name: string): LSXNode -- returns self
--- @field SetAttribute fun(self: LSXNode, key: string, value: any): LSXNode -- returns self
--- @field GetAttribute fun(self: LSXNode, key: string): any 
--- @field SetAttrOrder fun(self: LSXNode, attrOrder: string[]): LSXNode -- returns self
--- @field AppendChild fun(self: LSXNode, child: LSXNode|table?):LSXNode -- returns child
--- @field AppendChildren fun(self: LSXNode, children: LSXNode[]|table[]):LSXNode -- returns self
--- @field InsertChild fun(self: LSXNode, index: number, child: LSXNode|table?):LSXNode -- returns self
--- @field GetChild fun(self: LSXNode, index: number): LSXNode?
--- @field GetChildren fun(self: LSXNode): LSXNode[] 
--- @field SortChildren fun(self: LSXNode, comparator: fun(a: LSXNode, b: LSXNode):boolean)
--- @field RemoveChild fun(self: LSXNode, index: number)
--- @field RemoveChildren fun(self: LSXNode, predicate: fun(child: LSXNode):boolean)
--- @field AddComment fun(self: LSXNode, comment: string): LSXNode return self
--- @field new fun(key: string, value: table<string, any>?, children: LSXNode[]?, comments: string[]|string?): LSXNode
--- @field FromTable fun(t: table, rootKey: string): LSXNode?
LSXNode = {}
LSXNode.__index = LSXNode

local function validateInit(name, attrs, children, comments)
    if not name then
        name = "Node"
    elseif type(name) ~= "string" then
        name = "Node"
    end
    if type(attrs) ~= "table" then
        attrs = {}
    end
    if type(children) ~= "table" then
        children = {}
    end
    for i=#children,1,-1 do
        local child = children[i]
        if not getmetatable(child) or getmetatable(child) ~= LSXNode then
            Error("LSXTableNode: Invalid child node, must be LSXNode, skipping")
            table.remove(children, i)
        end
    end
    if type(comments) ~= "table" then
        if type(comments) == "string" then
            comments = {comments}
        else
            comments = {}
        end
    end

    return name, attrs or {}, children or {}, comments or {}
end

---@param name string
---@param attrs table<string, any>
---@param children LSXNode[]
---@param comments string[]
---@return LSXNode
function LSXNode.new(name, attrs, children, comments)
    name, attrs, children, comments = validateInit(name, attrs, children, comments)

    local obj = {}

    obj.__name = name
    obj.__attributes = attrs
    obj.__children = children
    obj.__parent = nil
    obj.__comments = comments
    obj.__innerText = nil

    return setmetatable(obj, LSXNode)
end


function LSXNode:Stringify(stringifyOpts)
    stringifyOpts = validateStringifyOptions(stringifyOpts or {})
    stringifyOpts.Indent = stringifyOpts.Indent or 4
    stringifyOpts.IncludeComments = stringifyOpts.IncludeComments ~= false
    local content = self:__stringify(stringifyOpts)

    return   content
end

function LSXNode:__stringify(stringifyOpts)
    local indentStep = stringifyOpts.Indent
    local lines = {}

    if stringifyOpts.InlcudeHeader then
        table.insert(lines, '<?xml version="1.0" encoding="utf-8"?>')
    end

    -- iterative DFS using stack. Each frame: { node = <LSXTableNode>, state = 'enter'|'exit', depth = number }
    -- maybe use my own treetable to avoid recursion?
    local function buildAttrStr(node)
        local attrs = {}
        local seen = {}

        for _, key in ipairs(node.__attrOrder or {}) do
            local value = node.__attributes and node.__attributes[key]
            if value ~= nil then
                if type(value) == "string" then
                    table.insert(attrs, string.format('%s="%s"', key, escapeXML(value)))
                else
                    table.insert(attrs, string.format('%s="%s"', key, serializeNonStringAttributes(value)))
                end
                seen[key] = true
            end
        end
        -- For determinism, sort remaining keys so output is stable across runs
        local remainingKeys = {}
        for key, _ in pairs(node.__attributes or {}) do
            if not seen[key] then
                table.insert(remainingKeys, key)
            end
        end
        table.sort(remainingKeys)
        for _, key in ipairs(remainingKeys) do
            local value = (node.__attributes or {})[key]
            if value ~= nil then
                if type(value) == "string" then
                    table.insert(attrs, string.format('%s="%s"', key, escapeXML(value)))
                else
                    table.insert(attrs, string.format('%s="%s"', key, serializeNonStringAttributes(value)))
                end
            end
        end
        
        if #attrs == 0 then return '' end
        return ' ' .. table.concat(attrs, ' ')
    end

    local seen = {}
    local stack = { { node = self, state = 'enter', depth = 0 } }
    while #stack > 0 do
        local frame = table.remove(stack) -- pop
        local node = frame.node
        local curDepth = frame.depth
        local pad = string.rep(' ', curDepth * indentStep)

        if frame.state == 'enter' then
            if seen[node] then
                table.insert(lines, pad .. string.format('<!-- Error: Recursive reference to "%s" skipped -->', tostring(node.__name or 'Node')))
                goto continue
            end
            if curDepth > stringifyOpts.MaxDepth then
                table.insert(lines, pad .. string.format('<!-- Warning: Max depth exceeded at "%s" -->', tostring(node.__name or 'Node')))
                goto continue
            end

            if node.__comments and stringifyOpts.IncludeComments then
                for _, comment in ipairs(node.__comments) do
                    table.insert(lines, pad .. '<!-- ' .. escapeXML(comment) .. ' -->')
                end
            end

            local attrStr = buildAttrStr(node)
            local children = node.__children or {}
            if #children > 0 then
                table.insert(lines, pad .. string.format('<%s%s>', node.__name or 'Node', attrStr))
                -- push exit frame
                table.insert(stack, { node = node, state = 'exit', depth = curDepth })
                -- push children in reverse so they are processed in order
                for i = #children, 1, -1 do
                    table.insert(stack, { node = children[i], state = 'enter', depth = curDepth + 1 })
                end
            elseif node.__innerText and type(node.__innerText) == "string" and node.__innerText ~= "" then
                local innerText = escapeXML(node.__innerText)
                table.insert(lines, pad .. string.format('<%s%s>%s</%s>', node.__name or 'Node', attrStr, innerText, node.__name or 'Node'))
            else
                table.insert(lines, pad .. string.format('<%s%s/>', node.__name or 'Node', attrStr))
            end

            seen[node] = true
            ::continue::
        else -- 'exit'
            table.insert(lines, pad .. string.format('</%s>', node.__name or 'Node'))
        end
    end

    return table.concat(lines, '\n')
end

function LSXNode:SetInnerText(text)
    if type(text) ~= "string" then
        Error("LSXTableNode:SetInnerText: Expected string, got " .. type(text))
        return self
    end
    self.__innerText = text

    if next(self.__children or {}) ~= nil then
        self:ClearChildren()
        Info("LSXTableNode:SetInnerText: Cleared children as inner text is set")
    end

    return self
end

function LSXNode:SetName(name)
    if type(name) ~= "string" then
        Error("LSXTableNode:SetName: Expected string, got " .. type(name))
        return self
    end
    self.__name = name

    return self
end

function LSXNode:SetAttribute(key, value)
    if type(key) ~= "string" then
        Error("LSXTableNode:SetAttribute: Expected string key, got " .. type(key))
        return self
    end
    self.__attributes = self.__attributes or {}
    self.__attributes[key] = value

    return self
end

function LSXNode:GetAttribute(key)
    if type(key) ~= "string" then
        Error("LSXTableNode:GetAttribute: Expected string key, got " .. type(key))
        return nil
    end
    return (self.__attributes or {})[key]
end

function LSXNode:SetAttrOrder(attrOrder)
    if type(attrOrder) ~= "table" then
        Error("LSXTableNode:SetAttrOrder: Expected table, got " .. type(attrOrder))
        return self
    end
    self.__attrOrder = attrOrder

    return self
end

function LSXNode:AppendChild(child)
    if not self.__children then
        self.__children = {}
    end
    if not getmetatable(child) or getmetatable(child) ~= LSXNode then
        Error("LSXTableNode:AppendChild: Invalid child node, must be LSXNode")
        return self
    end

    if not child then
        Error("LSXTableNode:AppendChild: Invalid child node")
        return self
    end
    child.__parent = self
    table.insert(self.__children, child)

    return child
end

function LSXNode:AppendChildren(children)
    if not self.__children then
        self.__children = {}
    end
    for _, child in ipairs(children or {}) do
        if not getmetatable(child) or getmetatable(child) ~= LSXNode then
            Error("LSXTableNode:AppendChildren: Invalid child node, skipping")
            return self
        end

        if child then
            child.__parent = self
            table.insert(self.__children, child)
        else
            Warning("LSXTableNode:AppendChildren: Invalid child node, skipping")
        end
    end

    return self
end

function LSXNode:InsertChild(index, child)
    if not self.__children then
        self.__children = {}
    end
    if not getmetatable(child) or getmetatable(child) ~= LSXNode then
        Error("LSXTableNode:InsertChild: Invalid child node, must be LSXNode")
        return self
    end

    if not child then
        Error("LSXTableNode:InsertChild: Invalid child node")
        return self
    end
    child.__parent = self
    table.insert(self.__children, index, child)

    return self
end


--- @param index number
--- @return LSXNode?
function LSXNode:GetChild(index)
    return (self.__children or {})[index]
end

function LSXNode:SearchChild(predicate)
    if not self.__children then
        return nil
    end
    for _, child in ipairs(self.__children) do
        if predicate(child) then
            return child
        end
    end
    return nil
end

function LSXNode:GetChildren()
    return self.__children or {}
end

function LSXNode:ClearChildren()
    for _, child in ipairs(self.__children or {}) do
        child.__parent = nil
    end

    self.__children = {}
end

function LSXNode:Clear()
    self:ClearChildren()
    self.__attributes = {}
    self.__innerText = nil
    self.__comments = {}
end

function LSXNode:RemoveChild(index)
    if not self.__children then
        return
    end
    local child = self.__children[index]
    if child then
        table.remove(self.__children, index)
        child.__parent = nil
    end
end

function LSXNode:RemoveChildren(predicate)
    if not self.__children then
        return
    end
    for i = #self.__children, 1, -1 do
        if predicate(self.__children[i]) then
            self.__children[i].__parent = nil
            table.remove(self.__children, i)
        end
    end
end

--- @param comparator fun(a: LSXNode, b: LSXNode):boolean
function LSXNode:SortChildren(comparator)
    if not self.__children then
        return
    end
    table.sort(self.__children, comparator)
end

function LSXNode:AddComment(comment)
    if not self.__comments then
        self.__comments = {}
    end
    table.insert(self.__comments, comment)

    return self
end

function LSXNode:ClearComments()
    self.__comments = {}
end