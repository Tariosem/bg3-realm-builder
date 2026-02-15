--- @class RB_TextureResource
--- @field SourceFile string

--- @class TextureTrieNode
--- @field __children table<string, TextureTrieNode>
--- @field __resources table<GUIDSTRING, boolean>

--- @class TextureManager
--- @field TextureResources table<GUIDSTRING, RB_TextureResource>
--- @field TextureResourcesReverse table<string, GUIDSTRING>
--- @field CachedTextureTrie table<string, TextureTrieNode>
TextureResourceManager = {
    TextureResources = {},
    CachedTextureTrie = {},

    VirtualTextureResources = {},
    VirtualTextureResourcesReverse = {},
}

function TextureResourceManager:PopulateTextureResource(id)
    local res = Ext.Resource.Get(id, "Texture") --[[@as ResourceTextureResource]]
    if not res then return nil end

    local s = RBStringUtils.GetPathAfterData(res.SourceFile or "")
    local paths = RBStringUtils.SplitByString(s, "/")

    local trieNode = self.CachedTextureTrie
    local pathCnt = #paths
    for i=1, pathCnt - 1 do
        local subFolderName = paths[i]
        trieNode.__children = trieNode.__children or {}
        trieNode.__children[subFolderName] = trieNode.__children[subFolderName] or {}
        trieNode = trieNode.__children[subFolderName]

        if i == pathCnt - 1 then
            trieNode.__resources = trieNode.__resources or {}
            trieNode.__resources[id] = true
        end
    end

    self.TextureResources[id] = {}

    return res
end

--- @param pathParts string[]
--- @return string[]
function TextureResourceManager:ValidateTextureResourcePath(pathParts)
    local trieNode = self.CachedTextureTrie
    local validPath = {}
    for _, part in ipairs(pathParts) do
        if trieNode.__children and trieNode.__children[part] then
            table.insert(validPath, part)
            trieNode = trieNode.__children[part]
        else
            break
        end
    end
    return validPath
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
    local uuid_blacklist = RESOUCE_UUID_BLACKLIST or {}
    RBPrintPurple("[Realm Builder] Populating Texture Resources...")
    for _, res in pairs(textureResources) do
        if uuid_blacklist[res] then goto continue end
        self:PopulateTextureResource(res)
        ::continue::
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