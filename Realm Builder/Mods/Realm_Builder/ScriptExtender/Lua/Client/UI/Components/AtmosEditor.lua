AtmosEditor = {}
AtmosEditor.__index = AtmosEditor

LightingEditor = { __index = AtmosEditor}

local atmosEditorCache = {}

local readOnlyFields = {
    "GUID",
    "Guid"
}

local preassignSettings = {
    
}

function AtmosEditor.new(resourceID, displayName)
    local res = Ext.Resource.Get(resourceID, "Atmosphere") --[[@as ResourceAtmosphereResource]]

    local obj = {
        Resource = res,
    }

    setmetatable(obj, AtmosEditor)

    return obj
end

function LightingEditor.new(resourceID, displayName)
    local res = Ext.Resource.Get(resourceID, "Lighting") --[[@as ResourceLightingResource]]

    local obj = {
        Resource = res,
    }

    setmetatable(obj, LightingEditor)

    obj:SaveInitialState()

    return obj
end

function AtmosEditor:SaveInitialState()
    self.InitialState = DeepCopy(self.Resource)
end

function AtmosEditor:RenderNumberField(fieldName, setter, getter)


end

function AtmosEditor:InitWindow()

end

function AtmosEditor:RenderEditor(obj)

    


end