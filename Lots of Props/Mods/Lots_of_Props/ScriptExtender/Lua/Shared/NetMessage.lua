NetMessage = NetMessage or {}

NetMessageName = {
    ServerProps = "ServerProps",
    DeletedProps = "DeletedProps",
    ApplyVisualPreset = "ApplyVisualPreset",
    SetVisualTransform = "SetVisualTransform",
    AttributeChanged = "AttributeChanged",
    ServerGizmo = "ServerGizmo",
    BindProps = "BindProps",
    SetLineColor = "SetLineColor",
    Visualization = "Visualization",
}

setmetatable(NetMessage, {
    __newindex = function (t, k, v)
        rawset(t, k, NetMessageName[k])
    end
})

---@param Props ServerPropData[] data
NetMessage.ServerProps = function(Props) end

---@param Guids GUIDSTRING[] data
NetMessage.DeletedProps = function(Guids) end

---@param Guid GUIDSTRING
---@param TemplateName string
---@param PresetName string
NetMessage.ApplyVisualPreset = function(Guid, TemplateName, PresetName) end

---@param Guid GUIDSTRING|GUIDSTRING[]
---@param Transforms table<GUIDSTRING, Transform>
NetMessage.SetVisualTransform = function(Guid, Transforms) end

--- @param Guid GUIDSTRING
--- @param Color Vec4
NetMessage.SetLineColor = function (Guid, Color) end

---@param Guid GUIDSTRING|GUIDSTRING[]
---@param Visible boolean|nil
---@param Gravity boolean|nil
---@param CanInteract boolean|nil
---@param Moveable boolean|nil
---@param Persistent boolean|nil
NetMessage.AttributeChanged = function(Guid, Visible, Gravity, CanInteract, Moveable, Persistent) end

---@param Guid GUIDSTRING
---@param Clear boolean
NetMessage.ServerGizmo = function(Guid, Clear) end

---@param BindInfos {Guid: GUIDSTRING, BindParent: GUIDSTRING|nil, KeepLookingAt: boolean|nil, NotFollowParent: boolean|nil}[]
---@param Type "Bind"|"Unbind"
NetMessage.BindProps = function(BindInfos, Type) end

--- @param Guid GUIDSTRING|GUIDSTRING[]
--- @param RequestId any?
NetMessage.Visualization = function (Guid, RequestId) end