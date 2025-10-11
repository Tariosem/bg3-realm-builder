GizmoVisualizer = {
    GizmoScale = 0.1,
    Scale = {
        1.0,
        1.0,
        1.0,
    },
    ScaleMultiplier = {
        1.0,
        1.0,
        1.0,
    },
    DefaultColor = {
        X = HexToRGBA("9AAA3333"),
        Y = HexToRGBA("9A33AA33"),
        Z = HexToRGBA("9A3333AA"),
    },
    HighlightColor = {
        X = HexToRGBA("E6FFC1C1"),
        Y = HexToRGBA("E6BBFFBB"),
        Z = HexToRGBA("E6A6A6FF"),
    },
    HoveredColor = {
        X = HexToRGBA("EEEE4444"),
        Y = HexToRGBA("EE44EE44"),
        Z = HexToRGBA("EE4444EE"),
    },
}
GizmoVisualizer.AxisLineColor = GizmoVisualizer.HoveredColor

local function GetHighlightColor(axis)
    return GizmoVisualizer.HighlightColor[axis] or {0.9, 0.9, 0.9, 0.8}
end

local function GetHoveredColor(axis)
    return GizmoVisualizer.HoveredColor[axis] or {0.9, 0.9, 0.9, 0.8}
end

local function GetDefaultColor(axis)
    return GizmoVisualizer.DefaultColor[axis] or {0.6, 0.6, 0.6, 0.6}
end

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
    visual.VisualFlags = Ext.Enums.VisualFlags.DisableLOD | visual.VisualFlags

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

function GizmoVisualizer.ScaleGizmo(axis, guid, renderable)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local rend = renderable
    local scale = GizmoVisualizer.Scale[AxisIndexMap[axis]] or 1.0
    local toScale = ToVec3(scale)
    toScale[AxisIndexMap[axis]] = toScale[AxisIndexMap[axis]] * (GizmoVisualizer.ScaleMultiplier[AxisIndexMap[axis]] or 1.0)
    for _,r in ipairs(rend or {}) do
        r:SetWorldScale(toScale)
    end
end

function GizmoVisualizer.HideGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local visual = VisualHelpers.GetEntityVisual(UuidToHandle(guid))
    if not visual then return end
    local objs = visual.ObjectDescs or {}
    if #objs == 0 then return end

    local rend = {}
    for _,obj in ipairs(objs) do
        if obj.Renderable and obj.Renderable.ActiveMaterial and obj.Renderable.ActiveMaterial.MaterialName == GIZMO_TEXTURE[axis] then
            table.insert(rend, obj.Renderable)
        end
    end

    for _,r in ipairs(rend or {}) do
        r:SetWorldScale(ToVec3(0))
    end
end

function GizmoVisualizer.HighLightGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, GetHighlightColor(axis))
    GizmoVisualizer.ScaleGizmo(axis, guid, rend)
end

function GizmoVisualizer.HoverGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, GetHoveredColor(axis))
    GizmoVisualizer.ScaleGizmo(axis, guid, rend)
end

function GizmoVisualizer.ResetGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, GetDefaultColor(axis))
    GizmoVisualizer.ScaleGizmo(axis, guid, rend)
end

function GizmoVisualizer:VisualizeRotateSymbol(guid, axis)
    local rotateScale = GizmoVisualizer.Scale[AxisIndexMap[axis]] or 1.0
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

--- update internal scale based on camera distance
--- @param guid GUIDSTRING
function GizmoVisualizer:UpdateScale(guid)
    local k = self.GizmoScale or 0.1
    local position = Vec3.new({CGetPosition(guid)})
    local cam = GetCamera()
    if not cam then return 1.0 end
    local camPos = Vec3.new(cam.Transform.Transform.Translate)
    local dist = Ext.Math.Distance(position, camPos)
    local scale = dist * k

    self.Scale = {scale, scale, scale}

    return scale
end

function GizmoVisualizer.SetLineFxColor(guid, color)
    if not color or #color ~= 4 then
        --Warning("SetLineFxColor: Invalid color provided")
        return
    end

    local entity = Ext.Entity.Get(guid)
    if not entity then return end

    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual then return end

    for _,obj in pairs(visual.ObjectDescs) do
        local renderable = obj.Renderable
        renderable.ActiveMaterial.Material:SetVector4("Color", color)
    end
    --Debug("SetLineFxColor: Set color of "..tostring(guid).." to "..table.concat(color, ", "))
end