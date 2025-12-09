local Debug = Debug or print
local Error = Error or print
local Warning = Warning or print
local RealmPath = RealmPath or {}

--- @enum LSValueType
LSValueType = {
    TranslatedString = "TranslatedString",
    FixedString = "FixedString",
    LSString = "LSString",
    LSWString = "LSWString",
    bool = "bool",
    uint8 = "uint8",
    int8 = "int8",
    uint32 = "uint32",
    int32 = "int32",
    uint64 = "uint64",
    int64 = "int64",
    float = "float",
    double = "double",
    fvec2 = "fvec2",
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

    return escapeXML(tostring(value))
end

--- @type XMLStringifyOptions
local defaultStringifyOptions = {
    Indent = 4,
    IncludeComments = true,
    MaxDepth = 64,
    IncludeHeader = true,
    AutoFindRoot = false,
    AvoidRecursion = true,
}

local function validateStringifyOptions(opts)
    local validOpts = RBUtils.DeepCopy(defaultStringifyOptions)
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
    if opts.IncludeHeader ~= nil and type(opts.IncludeHeader) == "boolean" then
        validOpts.IncludeHeader = opts.IncludeHeader
    end
    if opts.AutoFindRoot ~= nil and type(opts.AutoFindRoot) == "boolean" then
        validOpts.AutoFindRoot = opts.AutoFindRoot
    end
    if opts.AvoidRecursion ~= nil and type(opts.AvoidRecursion) == "boolean" then
        validOpts.AvoidRecursion = opts.AvoidRecursion
    end

    return validOpts
end

--- @class XMLStringifyOptions
--- @field Indent number number of spaces to use for indentation (default: 4)
--- @field IncludeComments boolean (default: true)
--- @field IncludeHeader boolean -- whether to include the XML declaration (default: true)
--- @field MaxDepth number (default: 64)
--- @field AutoFindRoot boolean -- whether to automatically find the root node by traversing parent references (default: false)
--- @field AvoidRecursion boolean (default: true)

--- @class XMLNode
--- @field private __name string
--- @field private __attributes table<string, any>
--- @field private __children XMLNode[]
--- @field private __parent XMLNode|nil
--- @field private __comments string[]
--- @field private __innerText string|nil
--- @field private __attrOrder string[]|nil
--- @field private __stringify fun(self: XMLNode, stringifyOpts: XMLStringifyOptions): string
--- @field Stringify fun(self: XMLNode, stringifyOpts?: XMLStringifyOptions, co?:thread): string
--- @field Unserialize fun(xmlString: string): XMLNode|nil, string|nil -- returns XMLNode or nil and error message
--- @field SetInnerText fun(self: XMLNode, text: string): XMLNode -- returns self
--- @field GetInnerText fun(self: XMLNode): string|nil
--- @field GetName fun(self: XMLNode): string
--- @field SetName fun(self: XMLNode, name: string): XMLNode -- returns self
--- @field SetAttribute fun(self: XMLNode, key: string, value: any): XMLNode -- returns self
--- @field GetAttribute fun(self: XMLNode, key: string): any
--- @field SetAttrOrder fun(self: XMLNode, attrOrder: string[]): XMLNode -- returns self
--- @field AppendChild fun(self: XMLNode, child: XMLNode|table?):XMLNode -- returns child
--- @field AppendChildren fun(self: XMLNode, children: XMLNode[]|table[]):XMLNode -- returns self
--- @field InsertChild fun(self: XMLNode, child: XMLNode, index: number): XMLNode -- returns child
--- @field GetChild fun(self: XMLNode, index: number): XMLNode?
--- @field GetParent fun(self: XMLNode): XMLNode?
--- @field SearchChild fun(self: XMLNode, predicate: fun(child: XMLNode):boolean): XMLNode?
--- @field MatchChild fun(self: XMLNode, name:string, attrs?:table<string, any>): XMLNode?
--- @field GetChildren fun(self: XMLNode): XMLNode[]
--- @field CountChildren fun(self: XMLNode): number
--- @field SortChildren fun(self: XMLNode, comparator: fun(a: XMLNode, b: XMLNode):boolean)
--- @field RemoveChild fun(self: XMLNode, index: number): XMLNode? -- returns removed child
--- @field RemoveChildren fun(self: XMLNode, predicate: fun(child: XMLNode):boolean): XMLNode[] -- returns removed children
--- @field Clear fun(self: XMLNode)
--- @field ClearChildren fun(self: XMLNode)
--- @field AddComment fun(self: XMLNode, comment: string): XMLNode return self
--- @field ClearComments fun(self: XMLNode)
--- @field new fun(name: string, attributes: table<string, any>?, children: XMLNode[]?, comments: string[]|string?): XMLNode
XMLNode = {}
XMLNode.__index = XMLNode

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
    for i = #children, 1, -1 do
        local child = children[i]
        if not getmetatable(child) or getmetatable(child) ~= XMLNode then
            Error("LSXTableNode: Invalid child node, must be XMLNode, skipping")
            table.remove(children, i)
        end
    end
    if type(comments) ~= "table" then
        if type(comments) == "string" then
            comments = { comments }
        else
            comments = {}
        end
    end

    return name, attrs or {}, children or {}, comments or {}
end

---@param name string
---@param attrs table<string, any>
---@param children XMLNode[]
---@param comments string[]
---@return XMLNode
function XMLNode.new(name, attrs, children, comments)
    name, attrs, children, comments = validateInit(name, attrs, children, comments)

    local obj = {}

    obj.__name = name
    obj.__attributes = attrs
    --obj.__attrCache = ""
    obj.__children = children
    obj.__parent = nil
    obj.__comments = comments
    obj.__innerText = nil

    return setmetatable(obj, XMLNode)
end

function XMLNode:Stringify(opts, co)
    opts = validateStringifyOptions(opts or {})

    if not opts.AutoFindRoot then
        return self:__stringify(opts)
    end

    if co and (type(co) ~= "thread" or coroutine.status(co) == "dead") then
        co = nil
        Warning("XMLNode:Stringify: Coroutine is invalid.")
    end

    local seen = {}
    local cur = self
    while cur do
        if seen[cur] then
            Error("XMLNode:Stringify: Recursive parent reference detected, aborting AutoFindRoot")
            return self:__stringify(opts, co)
        end
        seen[cur] = true

        if not cur.__parent then
            return cur:__stringify(opts, co)
        end
        cur = cur.__parent
    end

    Warning("XMLNode:Stringify: AutoFindRoot failed, falling back to self") -- should not reach here
    return self:__stringify(opts, co)
end

XMLNode.__tostring = XMLNode.Stringify

local function throwXMLStringifyError(node, message)
    local errLog = {
        Time = Ext.Timer.ClockTime(),
        Message = message,
        Stack = debug.traceback(),
        Node = node,
    }
    Ext.IO.SaveFile(RealmPath.GetXMLErrorLogPath(RBUtils.GetFormatTime()),
        Ext.Json.Stringify(errLog,
            {
                Beautify = true,
                AvoidRecursion = true,
                StringifyInternalTypes = true,
            }))
end

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
    local remainingKeys = {}
    for key, _ in pairs(node.__attributes or {}) do
        if not seen[key] then
            table.insert(remainingKeys, key)
        end
    end
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

local indentCache = {}
function XMLNode:__stringify(stringifyOpts, co)
    local indentStep = stringifyOpts.Indent
    local lines = {}

    if stringifyOpts.IncludeHeader then -- currently simple fixed header
        table.insert(lines, '<?xml version="1.0" encoding="utf-8"?>')
    end

    -- Each frame: { node<XMLNode>, state<true[enter]/false[exit]>, depth<number> }
    local isInCoroutine = co and true or false
    local lastYieldTime = isInCoroutine and Ext.Timer.MicrosecTime() or 0
    local seen = {}
    local stack = { { self, true, 0 } }
    local top = 1
    while #stack > 0 do
        local frame = stack[top]
        stack[top] = nil -- pop
        top = top - 1
        local node = frame[1]
        local curDepth = frame[3]
        local pad = ""
        if indentStep > 0 then
            if not indentCache[curDepth] then
                indentCache[curDepth] = string.rep(" ", indentStep * curDepth)
            end
            pad = indentCache[curDepth]
        end

        if frame[2] then -- 'enter'
            if seen[node] and stringifyOpts.AvoidRecursion then
                table.insert(lines,
                    pad ..
                    string.format('<!-- Info: Recursive reference to "%s" skipped -->', tostring(node.__name or 'Node')))
                goto continue
            end
            seen[node] = true

            if stringifyOpts.IncludeComments and node.__comments then
                for _, comment in ipairs(node.__comments) do
                    table.insert(lines, pad .. '<!-- ' .. escapeXML(comment) .. ' -->')
                end
            end

            local attrStr = buildAttrStr(node)
            local children = node.__children or {}
            if #children > 0 then
                table.insert(lines, pad .. string.format('<%s%s>', node.__name or 'Node', attrStr))
                -- push exit frame
                top = top + 1
                stack[top] = { node, false, curDepth }
                
                -- push children in reverse so they are processed in order
                for i = #children, 1, -1 do
                    if curDepth + 1 > stringifyOpts.MaxDepth then
                        table.insert(lines,
                            pad ..
                            string.format('<!-- Info: MaxDepth (%d) exceeded at node "%s", skipping. -->',
                                stringifyOpts.MaxDepth, tostring(children[i].__name or 'Node')))
                        goto skipChild
                    end

                    top = top + 1
                    stack[top] = { children[i], true, curDepth + 1 }
                    ::skipChild::
                end
            elseif node.__innerText and type(node.__innerText) == "string" and node.__innerText ~= "" then
                local innerText = escapeXML(node.__innerText)
                table.insert(lines,
                    pad ..
                    string.format('<%s%s>%s</%s>', node.__name or 'Node', attrStr, innerText, node.__name or 'Node'))
            else
                table.insert(lines, pad .. string.format('<%s%s/>', node.__name or 'Node', attrStr))
            end
            ::continue::
        else -- 'exit'
            table.insert(lines, pad .. string.format('</%s>', node.__name or 'Node'))
        end

        
        if isInCoroutine then
            local now = Ext.Timer.MicrosecTime()
            if now - lastYieldTime >= 1 then
                Ext.OnNextTick(function()
                    local ok, err
                    if co and coroutine.status(co) == "suspended" then
                        ok, err = coroutine.resume(co)
                        if ok then return end
                    end
                    throwXMLStringifyError(self, 
                        "XMLNode:Stringify coroutine resume failed: " .. tostring(err or "unknown error"))
                end)
                lastYieldTime = now
                coroutine.yield()
            end
        end
    end

    return table.concat(lines, '\n')
end

local function parseAttributes(attrStr)
    local attrs, order = {}, {}
    if not attrStr or attrStr == "" then
        return attrs, order
    end
    for key, val in attrStr:gmatch("([%w_:%-]+)%s*=%s*\"(.-)\"") do
        table.insert(order, key)
        attrs[key] = val:gsub("&lt;", "<")
            :gsub("&gt;", ">")
            :gsub("&quot;", "\"")
            :gsub("&apos;", "'")
            :gsub("&amp;", "&")
    end
    return attrs, order
end

function XMLNode.Unserialize(xmlString)
    xmlString = xmlString:gsub("<%?xml.-%?>", "") -- remove XML declaration
    xmlString = xmlString:gsub("\r", "")          -- normalize newlines

    local stack = {}
    local root = nil
    local i = 1
    local len = #xmlString

    while i <= len do
        local commentStart, commentEnd, commentText = xmlString:find("<!--(.-)-->", i)
        local tagStart, tagEnd, tagText = xmlString:find("<([^>]+)>", i)

        -- no more tags
        if not tagStart then break end

        -- capture comments before the tag to attach to parent
        if commentStart and commentStart < tagStart then
            local comments = {}
            while commentStart and commentStart < tagStart do
                table.insert(comments, commentText:gsub("^%s+", ""):gsub("%s+$", ""))
                commentStart, commentEnd, commentText = xmlString:find("<!--(.-)-->", commentEnd + 1)
            end
            if #stack > 0 then
                local top = stack[#stack]
                top.__comments = top.__comments or {}
                for _, c in ipairs(comments) do
                    table.insert(top.__comments, c)
                end
            end
        end

        -- capture inner text between tags
        local text = xmlString:sub(i, tagStart - 1)
        text = text:gsub("^[%s\n\t]+", ""):gsub("[%s\n\t]+$", "")
        if #text > 0 and #stack > 0 then
            local top = stack[#stack]
            if not top.__innerText then
                top.__innerText = text
            else
                top.__innerText = top.__innerText .. text
            end
        end

        local tag = tagText
        local inside = tag
        inside = inside:match("^%s*(.-)%s*$") -- trim
        if inside:sub(-1) == "/" then
            -- comment , ignore
        elseif tag:sub(1, 1) == "/" then
            -- closing tag
            local name = tag:match("^/(%S+)")
            local node = table.remove(stack)
            if not node then
                Error("Unexpected closing tag </" .. (name or "?") .. ">")
                return nil, "Unexpected closing tag"
            end
            if node.__name ~= name then
                Error(string.format("Mismatched tag: <%s> ... </%s>", node.__name, name))
                return nil, "Mismatched tag"
            end

            if #stack == 0 then
                root = node
            else
                local parent = stack[#stack]
                parent:AppendChild(node)
            end
        elseif inside:sub(-1) == "/" then
            -- self-closing
            inside = inside:sub(1, -2):match("^%s*(.-)%s*$")
            local name, attrStr = inside:match("^(%S+)%s*(.*)$")
            local node = XMLNode.new(name)
            node.__attributes, node.__attrOrder = parseAttributes(attrStr)

            if #stack == 0 then
                root = node
            else
                local parent = stack[#stack]
                parent:AppendChild(node)
            end
        else
            -- opening tags
            local name, attrStr = tag:match("^(%S+)%s*(.*)$")
            local node = XMLNode.new(name)
            node.__attributes, node.__attrOrder = parseAttributes(attrStr)
            table.insert(stack, node)
        end

        i = tagEnd + 1
    end

    return root
end

function XMLNode:SetInnerText(text)
    if type(text) ~= "string" then
        Error("LSXTableNode:SetInnerText: Expected string, got " .. type(text))
        return self
    end
    self.__innerText = text

    return self
end

function XMLNode:GetInnerText()
    return self.__innerText
end

function XMLNode:SetName(name)
    if type(name) ~= "string" then
        Error("LSXTableNode:SetName: Expected string, got " .. type(name))
        return self
    end
    self.__name = name

    return self
end

function XMLNode:GetName()
    return self.__name
end

function XMLNode:SetAttribute(key, value)
    if type(key) ~= "string" then
        Error("LSXTableNode:SetAttribute: Expected string key, got " .. type(key))
        return self
    end
    self.__attributes = self.__attributes or {}
    self.__attributes[key] = value


    return self
end

function XMLNode:GetAttribute(key)
    if type(key) ~= "string" then
        Error("LSXTableNode:GetAttribute: Expected string key, got " .. type(key))
        return nil
    end
    return (self.__attributes or {})[key]
end

function XMLNode:SetAttrOrder(attrOrder)
    if type(attrOrder) ~= "table" then
        Error("LSXTableNode:SetAttrOrder: Expected table, got " .. type(attrOrder))
        return self
    end
    self.__attrOrder = attrOrder

    return self
end

function XMLNode:AppendChild(child)
    if not self.__children then
        self.__children = {}
    end
    if not getmetatable(child) or getmetatable(child) ~= XMLNode then
        Error("LSXTableNode:AppendChild: Invalid child node, must be XMLNode")
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

function XMLNode:AppendChildren(children)
    if not self.__children then
        self.__children = {}
    end
    for _, child in ipairs(children or {}) do
        if not getmetatable(child) or getmetatable(child) ~= XMLNode then
            Error("LSXTableNode:AppendChildren: Invalid child node, skipping")
            goto continue
        end

        if child then
            child.__parent = self
            table.insert(self.__children, child)
        else
            Warning("LSXTableNode:AppendChildren: Invalid child node, skipping")
        end
        ::continue::
    end

    return self
end

function XMLNode:InsertChild(child, index)
    if not self.__children then
        self.__children = {}
    end
    if not getmetatable(child) or getmetatable(child) ~= XMLNode then
        Error("LSXTableNode:InsertChild: Invalid child node, must be XMLNode")
        return self
    end

    if not child then
        Error("LSXTableNode:InsertChild: Invalid child node")
        return self
    end
    child.__parent = self
    table.insert(self.__children, index, child)

    return child
end

--- @param index number
--- @return XMLNode?
function XMLNode:GetChild(index)
    return (self.__children or {})[index]
end

function XMLNode:SearchChild(predicate)
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

function XMLNode:MatchChild(name, attrs)
    if not self.__children then
        return nil
    end
    for _, child in ipairs(self.__children) do
        if child.__name == name then
            local match = true
            if attrs then
                for k, v in pairs(attrs) do
                    if child.__attributes[k] ~= v then
                        match = false
                        break
                    end
                end
            end
            if match then
                return child
            end
        end
    end
    return nil
end

function XMLNode:GetChildren()
    return self.__children or {}
end

function XMLNode:GetParent()
    return self.__parent
end

function XMLNode:CountChildren()
    return #(self.__children or {})
end

function XMLNode:ClearChildren()
    for _, child in ipairs(self.__children or {}) do
        child.__parent = nil
    end

    self.__children = {}
end

function XMLNode:Clear()
    self:ClearChildren()
    self.__attributes = {}
    self.__innerText = nil
    self.__comments = {}
end

function XMLNode:RemoveChild(index)
    if not self.__children then
        return
    end
    local child = self.__children[index]
    if child then
        table.remove(self.__children, index)
        child.__parent = nil
    end

    return child
end

function XMLNode:RemoveChildren(predicate)
    if not self.__children then
        return {}
    end

    local removed = {}
    for i = #self.__children, 1, -1 do
        if predicate(self.__children[i]) then
            self.__children[i].__parent = nil
            table.insert(removed, table.remove(self.__children, i))
        end
    end
    return removed
end

--- @param comparator fun(a: XMLNode, b: XMLNode):boolean
function XMLNode:SortChildren(comparator)
    if not self.__children then
        return
    end
    table.sort(self.__children, comparator)
end

function XMLNode:AddComment(comment)
    if not self.__comments then
        self.__comments = {}
    end
    table.insert(self.__comments, comment)

    return self
end

function XMLNode:ClearComments()
    self.__comments = {}
end
