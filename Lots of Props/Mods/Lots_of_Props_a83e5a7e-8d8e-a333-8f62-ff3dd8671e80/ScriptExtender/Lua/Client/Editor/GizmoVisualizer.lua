local function GetHighlightColor(axis)
        if axis == "X" then
        return {1, 0.8, 0.8, 0.6}
    elseif axis == "Y" then
        return {0.8, 1, 0.8, 0.6}
    elseif axis == "Z" then
        return {0.8, 0.8, 1, 0.6}
    else
        return {1, 1, 1, 0.6}
    end
end

local function GetHoveredColor(axis)
    if axis == "X" then
        return {1, 0.5, 0.5, 0.8}
    elseif axis == "Y" then
        return {0.5, 1, 0.5, 0.8}
    elseif axis == "Z" then
        return {0.5, 0.5, 1, 0.8}
    else
        return {0.9, 0.9, 0.9, 0.8}
    end
end

local function GetDefaultColor(axis)
    if axis == "X" then
        return {1, 0.3, 0.3, 0.7}
    elseif axis == "Y" then
        return {0.3, 1, 0.3, 0.7}
    elseif axis == "Z" then
        return {0.3, 0.3, 1, 0.7}
    else
        return {0.8, 0.8, 0.8, 0.5}
    end
end

local GIZMO_INDEX = {
    X = 1,
    Y = 2,
    Z = 3,
    [1] = "X",
    [2] = "Y",
    [3] = "Z",
}

--- @param axis any
--- @param guid any
--- @param Value any
--- @return RenderableObject[]?
local function SetGizmoAxisTextureColorParam(axis, guid, Value)
    if not IsGizmo(guid) then
        --Warning("GetGizmoAxisTextureColorParam: Invalid GUID: " .. tostring(guid))
        return nil
    end

    local liveGizmo = UuidToHandle(guid)
    local visual = liveGizmo and liveGizmo.Visual and liveGizmo.Visual.Visual or nil

    if not visual then
        --Warning("GetGizmoAxisTextureColorParam: Invalid visual for gizmo with GUID: " .. tostring(guid))
        return nil
    end
    visual.VisualFlags = "DisableLOD"

    local objDescs = visual.ObjectDescs

    local corRendrable = {}
    for _,obj in ipairs(objDescs) do
        if not obj.Renderable or not obj.Renderable.ActiveMaterial then
            Warning("GetGizmoAxisTextureColorParam: Invalid renderable or missing active material for gizmo with GUID: " .. tostring(guid))
            return nil
        end
        if obj.Renderable.ActiveMaterial.MaterialName == GIZMO_TEXTURE[axis] then
            local material = obj.Renderable.ActiveMaterial.Material

            material:SetVector4("Color", Value)

            table.insert(corRendrable, obj.Renderable)
        end
    end

    --Warning("GetGizmoAxisTextureColorParam: Gizmo axis texture not found for axis: " .. tostring(axis))
    return corRendrable
end

GizmoVisualizer = {
    GizmoScale = 0.1
}

function GizmoVisualizer.HideGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = GIZMO_INDEX[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, ToVec4(0))
    for _,r in ipairs(rend or {}) do
        r:SetWorldScale({0,0,0})
    end
end

function GizmoVisualizer.HighLightGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = GIZMO_INDEX[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, GetHighlightColor(axis))
    local scale = GizmoVisualizer:UpdateScale(guid)
    for _,r in ipairs(rend or {}) do
        r:SetWorldScale({scale, scale, scale})
    end
end

function GizmoVisualizer.HoverGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = GIZMO_INDEX[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, GetHoveredColor(axis))
    local scale = GizmoVisualizer:UpdateScale(guid)
    for _,r in ipairs(rend or {}) do
        r:SetWorldScale({scale, scale, scale})
    end
end

function GizmoVisualizer.ResetGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = GIZMO_INDEX[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, GetDefaultColor(axis))
    local scale = GizmoVisualizer:UpdateScale(guid)
    for _,r in ipairs(rend or {}) do
        r:SetWorldScale({scale, scale, scale})
    end
end

function GizmoVisualizer:VisualizeRotateSymbol(guid, axis)
    local rotateScale = self:UpdateScale(guid)
    local scale = ToVec3((0.6 * rotateScale) / 0.81)

    for _,ax in pairs({"X", "Y", "Z"}) do
        if ax ~= axis then
            self.HideGizmoAxis(ax, guid)
        end
    end

    local rend = SetGizmoAxisTextureColorParam(axis, guid, GetHighlightColor(axis))
    for _,r in ipairs(rend or {}) do
        r:SetWorldScale(scale)
    end
end

function GizmoVisualizer:UpdateScale(guid)
    local k = self.GizmoScale or 0.1
    local position = Vec3.new({CGetPosition(guid)})
    local cam = GetCamera()
    if not cam then return 1.0 end
    local camPos = Vec3.new(cam.Transform.Transform.Translate)
    local dist = Ext.Math.Distance(position, camPos)
    local scale = dist * k

    return scale
end