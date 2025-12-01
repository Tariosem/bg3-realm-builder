--- @class RB_TextureResource
--- @field SourceFile string


--- @class TextureManager
--- @field TextureResources table<GUIDSTRING, RB_TextureResource>
--- @field TextureResourcesReverse table<string, GUIDSTRING>
--- @field CachedTextureTrie table<string, any>
TextureResourceManager = {
    TextureResources = {},
    TextureResourcesReverse = {},
    CachedTextureTrie = {},

    VirtualTextureResources = {},
    VirtualTextureResourcesReverse = {},
}

function TextureResourceManager:PopulateTextureResource(id)
    local res = Ext.Resource.Get(id, "Texture") --[[@as ResourceTextureResource]]
    if not res then return nil end

    local s = LSXHelpers.GetPathAfterData(res.SourceFile or "")
    local fileName = GetLastPath(s)
    local paths = SplitByString(s, "/")

    local trieNode = self.CachedTextureTrie
    for i=1, #paths do
        local part = paths[i]
        trieNode.__children = trieNode.__children or {}
        trieNode.__children[part] = trieNode.__children[part] or {}
        trieNode = trieNode.__children[part]

        trieNode.__all = trieNode.__all or {}
        trieNode.__all[id] = true

        if i == #paths then
            trieNode.__resources = trieNode.__resources or {}
            trieNode.__resources[id] = true
        end
    end

    self.TextureResources[id] = {
        SourceFile = fileName,
        Path = s,
    }
    self.TextureResourcesReverse[s] = id

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


--- @param pathPrefix any
--- @return {Path:string, ResourceUUID:string, SourceFile:string}[]
function TextureResourceManager:GetAllTextureResourceUnderPath(pathPrefix, precise)
    local paths = SplitByString(pathPrefix, "/")
    local lastFileName = paths[#paths]:lower()
    if #paths == 0 then return {} end
    precise = precise or false
    local trieNode = self.CachedTextureTrie
    for depth = 1, #paths do
        trieNode = trieNode.__children and trieNode.__children[paths[depth]]
        if not trieNode then
            return {}
        end
    end

    local results = {}
    local fetchField = precise and "__resources" or "__all"
    local maxSize = 100
    for id,_ in pairs(trieNode[fetchField] or {}) do
        if #results >= maxSize then break end
        local fileName = self.TextureResources[id].SourceFile
        if not fileName:find(lastFileName) then
            goto continue
        end
        table.insert(results, { Path = self.TextureResources[id].Path, ResourceUUID = id, SourceFile = fileName })
        ::continue::
    end

    return results
end

function TextureResourceManager:GetTextureResourceByPath(path)
    return self.TextureResourcesReverse[path]
end

function TextureResourceManager:PopulateVirtualTextureResource(id)
    local res = Ext.Resource.Get(id, "VirtualTexture") --[[@as ResourceVirtualTextureResource]]

    if res then
        local s = LSXHelpers.GetPathAfterData(res.RootPath or "")
        self.VirtualTextureResources[id] = {
            SourceFile = s,
            TileSetFileName = res.TileSetFileName or "",
            RootPath = res.RootPath or ""
        }
        self.VirtualTextureResourcesReverse[s] = id
    end
end

function TextureResourceManager:PopulateAllTextureResources()
    local textureResources = Ext.Resource.GetAll("Texture")
    local now = Ext.Timer.MonotonicTime()
    RPrintPurple("TextureResourceManager: Populating texture resources... (Found " .. #textureResources .. " resources)")
    for _, res in pairs(textureResources) do
        self:PopulateTextureResource(res)
    end
    RPrintPurple("TextureResourceManager: Populated " .. #textureResources .. " texture resources in " .. string.format("%.2f", Ext.Timer.MonotonicTime() - now) .. " ms.")
end

TextureResourceManager:PopulateAllTextureResources()