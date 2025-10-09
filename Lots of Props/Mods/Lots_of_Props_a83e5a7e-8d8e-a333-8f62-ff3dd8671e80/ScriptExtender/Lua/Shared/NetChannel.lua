NetChannel = NetChannel or {}
NetChannelName = {
    Visualize = "Visualize",
    SetTransform = "SetTransform",
    SetAttributes = "SetAttributes",
    Duplicate = "Duplicate",
    Spawn = "Spawn",
    Delete = "Delete",
    ManageGizmo = "ManageGizmo",
    Bind = "Bind",
    SpawnPreset = "SpawnPreset",
    OsirisRequest = "OsirisRequest",
    BunchOsirisRequest = "BunchOsirisRequest",
    SetVisualize = "SetVisualize",
}


setmetatable(NetChannel, {
    __newindex = function (t, k, v)
        rawset(t, k, NetChannelName[k])
    end
})

--- scam IDE

--- @param Function any
--- @param Args any
--- @param RequestId any
--- @return any result
NetChannel.OsirisRequest = function(Function, Args, RequestId) return end

---@param Calls table<number, {Function: string, Args: any[]}>
---@param RequestId any
---@return table<number, {Function: string, Result: any}>
NetChannel.BunchOsirisRequest = function(Calls, RequestId) return {} end

---@param Guid GUIDSTRING[]|GUIDSTRING
NetChannel.Duplicate = function(Guid) end

--- @param Guid GUIDSTRING|GUIDSTRING[]
NetChannel.Delete = function(Guid) end

---@param TemplateId string
---@param Target GUIDSTRING?
---@param Position Vec3
---@param Rotation Quat
---@param PropInfo PropData
---@param Type "Preview"?
NetChannel.Spawn = function(TemplateId, Target, Position, Rotation, PropInfo, Type) end

--- @param Type "Point"|"Line"|"Box"|"OBB"|"Clear"
--- @param Position Vec3
--- @param EndPosition Vec3|nil
--- @param Rotation Quat|nil
--- @param HalfSizes Vec3|nil
--- @param Min Vec3|nil
--- @param Max Vec3|nil
NetChannel.Visualize = function(Type, Position, EndPosition, Min, Max, HalfSizes, Rotation) end

--- @param Guid GUIDSTRING|GUIDSTRING[]
--- @param Transforms table<GUIDSTRING, Transform>
NetChannel.SetTransform = function(Guid, Transforms) end

--- @param Guid GUIDSTRING|GUIDSTRING[]
--- @param Visible boolean
--- @param Gravity boolean
--- @param CanInteract boolean
--- @param Moveable boolean
NetChannel.SetAttributes = function(Guid, Visible, Gravity, CanInteract, Moveable) end


--- @param Type "Create"|"Update"|"Delete"|"Clear"|"ClearAll"
--- @param Guid GUIDSTRING gizmo entity
--- @param Target GUIDSTRING[]|GUIDSTRING target entities
--- @param GizmoType "Translate"|"Rotate"|"Scale"
--- @param GizmoSpace "Global"|"Local"|"View"|"Parent"
NetChannel.ManageGizmo = function(Type, Guid, Target, GizmoType, GizmoSpace) end

---@param Type "Bind"|"SetType"|"Unbind"|"UpdateOffset"
---@param Guid GUIDSTRING|GUIDSTRING[]
---@param Parent GUIDSTRING
---@param NotFollowParent boolean
---@param KeepLookingAt boolean
NetChannel.Bind = function(Type, Guid, Parent, NotFollowParent, KeepLookingAt) end

---@param PresetData PropData[]
---@param Parent any
---@param Position any
---@param Rotation any
---@param Type any
NetChannel.SpawnPreset = function(PresetData, Parent, Position, Rotation, Type) end