--- @class TextureManager
TextureResourceManager = {
    TextureResources = {},
    TextureResourcesReverse = {},

    VirtualTextureResources = {},
    VirtualTextureResourcesReverse = {},
}

function TextureResourceManager:PopulateTextureResource(id)
    local textureResources = {}
    local res = Ext.Resource.Get(id, "Texture") --[[@as ResourceTextureResource]]

    if res then
        local s = LSXHelpers.GetPathAfterData(res.SourceFile or "")
        self.TextureResources[id] = {
            SourceFile = s
        }
        self.TextureResourcesReverse[s] = id
        _P("TextureResourceManager: Populated texture resource:", id, "->", s)
    end


    self.TextureResources = textureResources

    return res
end

function TextureResourceManager:GetTextureResourcePath(id)
    local res = self.TextureResources[id]
    if res then
        return res.SourceFile
    else
        self:PopulateTextureResources(id)
        res = self.TextureResources[id]
        if res then
            return res.SourceFile
        end
    end
    return nil
end

function TextureResourceManager:GetTextureResourceByPath(path)
    return self.TextureResourcesReverse[path]
end

function TextureResourceManager:PopulateVirtualTextureResource(id)
    local res = Ext.Resource.Get(id, "VirtualTexture") --[[@as ResourceVirtualTextureResource]]

    if res then
        local s = LSXHelpers.GetPathAfterData(res.SourceFile or "")
        self.VirtualTextureResources[id] = {
            SourceFile = s,
            TileSetFileName = res.TileSetFileName or "",
            RootPath = res.RootPath or ""
        }
        self.VirtualTextureResourcesReverse[s] = id
        _P("TextureResourceManager: Populated virtual texture resource:", id, "->", s)
        _P("   TileSetFileName:", res.TileSetFileName)
        _P("   RootPath:", res.RootPath)
    end
end
