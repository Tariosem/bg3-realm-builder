--- @class RB_TextureResource
--- @field SourceFile string

--- @class TextureManager
--- @field TextureResources table<GUIDSTRING, RB_TextureResource>
--- @field TextureResourcesReverse table<string, GUIDSTRING>
--- @field CachedTextureTrie table<string, any>
TextureResourceManager = {
    TextureResources = {},
    CachedTextureTrie = {},

    VirtualTextureResources = {},
    VirtualTextureResourcesReverse = {},
}

function TextureResourceManager:PopulateTextureResource(id)
    local res = Ext.Resource.Get(id, "Texture") --[[@as ResourceTextureResource]]
    if not res then return nil end

    local s = LSXHelpers.GetPathAfterData(res.SourceFile or "")
    local fileName = RBStringUtils.GetLastPath(s)
    local paths = RBStringUtils.SplitByString(s, "/")

    local trieNode = self.CachedTextureTrie
    for i=1, #paths do
        local part = paths[i]
        trieNode.__children = trieNode.__children or {}
        trieNode.__children[part] = trieNode.__children[part] or {}
        trieNode = trieNode.__children[part]

        if i == #paths then
            trieNode.__resources = trieNode.__resources or {}
            trieNode.__resources[id] = true
        end
    end

    self.TextureResources[id] = {
        SourceFile = fileName,
        Path = s,
    }

    return res
end

function TextureResourceManager:GetTextureResourcePath(id)
    local res = self.TextureResources[id]
    if res then
    else
        self:PopulateTextureResources(id)
    end

    return self.TextureResources[id].SourceFile
end

--- @param path string
function TextureResourceManager:GetTextureResourceByPath(path)
    local paths = RBStringUtils.SplitByString(path, "/")
    if #paths == 0 then return nil end
    local fileName = paths[#paths]
    local trieNode = self.CachedTextureTrie

    for depth = 1, #paths - 1 do
        trieNode = trieNode.__children and trieNode.__children[paths[depth]]
        if not trieNode then
            return nil
        end
    end
    for resId,_ in pairs(trieNode.__resources or {}) do
        if self.TextureResources[resId].SourceFile == fileName then
            return self.TextureResources[resId]
        end
    end
end

--- @param pathPrefix string
--- @param searchCriteria string|nil
--- @return {Path:string, ResourceUUID:string, SourceFile:string}[], boolean exceedFlag
function TextureResourceManager:GetAllTextureResourceUnderPath(pathPrefix, searchCriteria, precise)
    local paths = RBStringUtils.SplitByString(pathPrefix, "/")

    if pathPrefix:sub(-1) ~= "/" then
        -- Ignore the last element for prefix search
        paths[#paths] = nil
    end
    
    if #paths == 0 then return {}, false end
    
    precise = precise or false
    local curNode = self.CachedTextureTrie
    local allTrieNode = curNode
    for depth = 1, #paths do
        curNode = curNode.__children and curNode.__children[paths[depth]]
    end
    allTrieNode = {curNode}
    local function collectAllChildren(node)
        if not node or not node.__children then return end
        for _,child in pairs(node.__children) do
            table.insert(allTrieNode, child)
            collectAllChildren(child)
        end
    end
    collectAllChildren(curNode)

    local results = {}
    local maxSize = 1000
    local overflowFlag = false

    --for id,_ in pairs(trieNode[fetchField] or {}) do
        --_P("Found texture resource under path: " .. pathPrefix .. " -> " .. self.TextureResources[id].SourceFile)
    --end

    for _,trieNode in pairs(allTrieNode) do
        if #results >= maxSize then overflowFlag = true break end
        for id,_ in pairs(trieNode.__resources or {}) do
            if #results >= maxSize then overflowFlag = true break end
            local fileName = self.TextureResources[id].SourceFile
            if searchCriteria and not fileName:find(searchCriteria, 1, true) then
                goto continue
            end
            table.insert(results, { Path = self.TextureResources[id].Path, ResourceUUID = id, SourceFile = fileName })
            ::continue::
        end
    end

    return results, overflowFlag
end
function TextureResourceManager:PopulateVirtualTextureResource(id)
    local res = Ext.Resource.Get(id, "VirtualTexture") --[[@as ResourceVirtualTextureResource]]

    if res then
        self.VirtualTextureResources[id] = {
        }
    end
end

function TextureResourceManager:PopulateAllTextureResources()
    local textureResources = Ext.Resource.GetAll("Texture")
    local now = Ext.Timer.MonotonicTime()
    RBPrintPurple("[Realm Builder] Populating Texture Resources...")
    for _, res in pairs(textureResources) do
        self:PopulateTextureResource(res)
    end
    RBPrintPurple("[Realm Builder] Populated " .. #textureResources .. " texture resources in " .. string.format("%.2f", Ext.Timer.MonotonicTime() - now) .. " ms.")
end

function TextureResourceManager:HasTextureResource(id)
    return self.TextureResources[id] ~= nil
end

function TextureResourceManager:HasVirtualTextureResource(id)
    return self.VirtualTextureResources[id] ~= nil
end

EventsSubscriber.RegisterOnSessionLoaded(function ()
    TextureResourceManager:PopulateAllTextureResources()
end)