--- @enum LSXTableValueType
LSXTableValueType = {
    FixedString = "FixedString",
    LSString = "LSString",
    bool = "bool",
    uint8 = "uint8",
    int8 = "int8",
    uint32 = "uint32",
    int32 = "int32",
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

local function serializeNonStringValue(value)
    if type(value) == "number" then
        return tostring(value)
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    elseif type(value) == "table" then
        return table.concat(value, " ")
    end
end

local function validateStringifyOptions(opts)
    local validOpts = {}
    if type(opts) ~= "table" then
        return validOpts
    end
    if opts.Indent and type(opts.Indent) == "number" and opts.Indent >= 0 then
        validOpts.Indent = opts.Indent
    end
    if opts.IncludeComments ~= nil and type(opts.IncludeComments) == "boolean" then
        validOpts.IncludeComments = opts.IncludeComments
    end
    return DeepCopy(validOpts)
end

--- @class LSXTableStringfiyOptions
--- @field Indent number
--- @field IncludeComments boolean

--- @class LSXTableNode
--- @field __key string
--- @field __value table<string, any>
--- @field __children LSXTableNode[]|nil
--- @field __comments string[]|nil
--- @field Stringify fun(self: LSXTableNode, stringifyOpts?: LSXTableStringfiyOptions): string
--- @field AppendChild fun(self: LSXTableNode, child: LSXTableNode|table?):LSXTableNode
--- @field GetChild fun(self: LSXTableNode, predicate: fun(child: LSXTableNode):boolean): LSXTableNode?
--- @field GetChildren fun(self: LSXTableNode): LSXTableNode[]
--- @field RemoveChild fun(self: LSXTableNode, predicate: fun(child: LSXTableNode):boolean)
--- @field RemoveChildren fun(self: LSXTableNode, predicate: fun(child: LSXTableNode):boolean)
--- @field AddComment fun(self: LSXTableNode, comment: string)
--- @field new fun(key: string, value: table<string, any>?, children: LSXTableNode[]?, comments: string[]?): LSXTableNode
--- @field FromTable fun(t: table, rootKey: string): LSXTableNode?
LSXTableNode = {}

function LSXTableNode.__index(self, key)
    -- check instance raw fields first
    local v = rawget(self, key)
    if v ~= nil then return v end
    -- then check methods defined on LSXTableNode (the metatable)
    local m = rawget(LSXTableNode, key)
    if m ~= nil then return m end
    -- finally fallback to stored attributes
    if self.__value then
        return self.__value[key]
    end
    return nil
end

function LSXTableNode:__newindex(key, value)
    if type(key) == "string" and key:sub(1, 2) == "__" then
        rawset(self, key, value)
    else
        rawset(self.__value, key, value)
    end
end

function LSXTableNode:Stringify(stringifyOpts)
    stringifyOpts = validateStringifyOptions(stringifyOpts or {})
    stringifyOpts.Indent = stringifyOpts.Indent or 4
    stringifyOpts.IncludeComments = stringifyOpts.IncludeComments ~= false
    local content = self:__stringify(stringifyOpts, 0)

    return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" .. content
end

function LSXTableNode:__stringify(stringifyOpts)
    local indentStep = stringifyOpts.Indent
    local lines = {}

    -- iterative DFS using explicit stack. Each frame: { node = <LSXTableNode>, state = 'enter'|'exit', indent = number }
    local function buildAttrStr(node)
        local attrs = {}
        for k, v in pairs(node.__value or {}) do
            local valueStr
            if type(v) == 'string' then
                valueStr = escapeXML(v)
            else
                valueStr = serializeNonStringValue(v)
            end
            table.insert(attrs, string.format('%s="%s"', k, valueStr or ''))
        end
        if #attrs == 0 then return '' end
        return ' ' .. table.concat(attrs, ' ')
    end

    local stack = { { node = self, state = 'enter', indent = 0 } }
    while #stack > 0 do
        local frame = table.remove(stack) -- pop
        local node = frame.node
        local curIndent = frame.indent or 0
        local pad = string.rep(' ', curIndent)

        if frame.state == 'enter' then
            -- comments
            if node.__comments and stringifyOpts.IncludeComments then
                for _, comment in ipairs(node.__comments) do
                    table.insert(lines, pad .. '<!-- ' .. escapeXML(comment) .. ' -->')
                end
            end

            local attrStr = buildAttrStr(node)
            local children = node.__children or {}
            if #children > 0 then
                table.insert(lines, pad .. string.format('<%s%s>', node.__key or 'Node', attrStr))
                -- push exit frame
                table.insert(stack, { node = node, state = 'exit', indent = curIndent })
                -- push children in reverse so they are processed in order
                for i = #children, 1, -1 do
                    table.insert(stack, { node = children[i], state = 'enter', indent = curIndent + indentStep })
                end
            else
                table.insert(lines, pad .. string.format('<%s%s/>', node.__key or 'Node', attrStr))
            end

        else -- 'exit'
            table.insert(lines, pad .. string.format('</%s>', node.__key or 'Node'))
        end
    end

    return table.concat(lines, '\n')
end

function LSXTableNode:AppendChild(child)
    if not self.__children then
        self.__children = {}
    end
    if not getmetatable(child) or getmetatable(child) ~= LSXTableNode then
        child = LSXTableNode.FromTable(child)
    end

    if not child then
        Error("LSXTableNode:AppendChild: Invalid child node")
        return self
    end
    table.insert(self.__children, child)

    return self
end


--- @param predicate fun(child: LSXTableNode):boolean
--- @return LSXTableNode?
function LSXTableNode:GetChild(predicate)
    for _, child in ipairs(self.__children or {}) do
        if predicate(child) then
            return child
        end
    end
    return nil
end

function LSXTableNode:GetChildren()
    return self.__children or {}
end

function LSXTableNode:RemoveChild(predicate)
    if not self.__children then
        return
    end
    for i = #self.__children, 1, -1 do
        if predicate(self.__children[i]) then
            table.remove(self.__children, i)
            return
        end
    end
end

function LSXTableNode:RemoveChildren(predicate)
    if not self.__children then
        return
    end
    for i = #self.__children, 1, -1 do
        if predicate(self.__children[i]) then
            table.remove(self.__children, i)
        end
    end
end

function LSXTableNode:AddComment(comment)
    if not self.__comments then
        self.__comments = {}
    end
    table.insert(self.__comments, comment)
end

function LSXTableNode.new(key, value, children, comments)
    local obj = {}

    obj.__key = key
    obj.__value = value or {}
    obj.__children = children
    obj.__comments = comments

    setmetatable(obj, LSXTableNode)
    return obj
end

function LSXTableNode.FromTable(t, rootKey)
    if type(t) ~= "table" then
        Error("LSXTableNode.FromTable: Expected table, got " .. type(t))
        return nil
    end
    
    local newObj = LSXTableNode.new(rootKey or "Node")

    for k, v in pairs(t) do
        if type(v) == "table" then
            if k == "__children" then
                for i = 1, #v do
                    newObj:AppendChild(LSXTableNode.FromTable(v[i]))
                end
            elseif k == "__comments" then
                for i = 1, #v do
                    newObj:AddComment(v[i])
                end
            else
                newObj:AppendChild(LSXTableNode.FromTable(v, k))
            end
        else
            newObj[k] = v
        end
    end

    return newObj
end
LSXTable = {}

---@return LSXTableNode?
function LSXTable.new()
    local save = {
        version = {
            major = 4,
            minor = 8,
            revision = 0,
            build = 400,
            lslib_meta = "v1,bswap_guids,lsf_keys_adjacency"
        },
    }

    local newLsxTable = LSXTableNode.FromTable(save, "save")
    if not newLsxTable then
        Error("LSXTable.new: Failed to create LSXTableNode from default save table")
        return nil
    end

    newLsxTable:AddComment("This file was generated Script Extender")

    return newLsxTable
end

--- @param parent LSXTableNode
--- @return LSXTableNode
function LSXTable.ChildrenWrapper(parent)
    local childrenNode = LSXTableNode.new("children")
    parent:AppendChild(childrenNode)
    return childrenNode
end

if Ext.IsClient() then
    -- test
    local testTable = {
        name = "Test",
        count = 5,
        isActive = true,
        position = {1.0, 2.0, 3.0},
        rotation = {0.0, 0.0, 0.0, 1.0},
        guid = "123e4567-e89b-12d3-a456-426614174000",
        __comments = {
            "This is a test LSXTableNode",
            "Generated by Script Extender"
        },
        __children = {
            {
                name = "Child1",
                value = 10,
                __comments = {"First child node"}
            },
            {
                name = "Child2",
                value = 20,
                __children = {
                    {
                        name = "GrandChild",
                        value = 30
                    }
                }
            }
        }
    }

    local rootNode = LSXTableNode.FromTable(testTable, "Root")
    if rootNode then
        local xmlString = rootNode:Stringify({Indent=4, IncludeComments=true})
        print(xmlString)
    else
        Error("Failed to create LSXTableNode from test table")
    end

end