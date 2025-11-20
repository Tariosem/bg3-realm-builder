--- @class GizmoVisualizer
--- @field GizmoScale number
--- @field Scale number[]
--- @field ScaleMultiplier number[]
--- @field DefaultColor table<string, number[]>
--- @field HighlightColor table<string, number[]>
--- @field HoveredColor table<string, number[]>
--- @field AxisLineColor table<string, number[]>
--- @field ResetToDefault fun(self: GizmoVisualizer)
--- @field GetHighlightColor fun(self: GizmoVisualizer, axis: string): number[]
--- @field GetHoveredColor fun(self: GizmoVisualizer, axis: string): number[]
--- @field GetDefaultColor fun(self: GizmoVisualizer, axis: string): number[]
--- @field ScaleGizmo fun(self: GizmoVisualizer, axis: string, renderable: RenderableObject[]?)
--- @field HideGizmoAxis fun(self: GizmoVisualizer, axis: string, guid: GUIDSTRING)
--- @field HideGizmo fun(self: GizmoVisualizer, guid: GUIDSTRING)
--- @field HighLightGizmoAxis fun(self: GizmoVisualizer, axis: string, guid: GUIDSTRING)
--- @field HoverGizmoAxis fun(self: GizmoVisualizer, axis: string, guid: GUIDSTRING)
--- @field ResetGizmoAxis fun(self: GizmoVisualizer, axis: string, guid: GUIDSTRING)
--- @field VisualizeRotatePointer fun(self: GizmoVisualizer, guid: GUIDSTRING, axis: string)
--- @field UpdateScale fun(self: GizmoVisualizer, position: vec3): number
--- @field SetLineFxColor fun(self: GizmoVisualizer, guid: GUIDSTRING, color: number[])
--- @field SetLineLength fun(self: GizmoVisualizer, guid: GUIDSTRING, length: number, width: number?)
--- @field new fun(): GizmoVisualizer
GizmoVisualizer = _Class("GizmoVisualizer")

local GIZMO_VISUALIZER_CONFIG = {
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
        X = HexToRGBA("FFDC4444"),
        Y = HexToRGBA("FF58C458"), 
        Z = HexToRGBA("FF4A7DFF"),
    },
    HighlightColor = {
        X = HexToRGBA("FFFFB3B3"),
        Y = HexToRGBA("FFB7FFB7"),
        Z = HexToRGBA("FFB6C8FF"),
    },
    HoveredColor = {
        X = HexToRGBA("FFFFA4A4"),
        Y = HexToRGBA("FFBFFFBF"),
        Z = HexToRGBA("FFBBBBFF"),
    },
    AxisLineColor = {
        X = HexToRGBA("FFFF0000"),
        Y = HexToRGBA("FF00FF00"),
        Z = HexToRGBA("FF0000FF"),
    }
}

function GizmoVisualizer:__init()
    self.GizmoScale = 0.1
    self.Scale = {1.0, 1.0, 1.0}
    self.ScaleMultiplier = {1.0, 1.0, 1.0}
    self.DefaultColor = DeepCopy(GIZMO_VISUALIZER_CONFIG.DefaultColor)
    self.HighlightColor = DeepCopy(GIZMO_VISUALIZER_CONFIG.HighlightColor)
    self.HoveredColor = DeepCopy(GIZMO_VISUALIZER_CONFIG.HoveredColor)
    self.AxisLineColor = DeepCopy(GIZMO_VISUALIZER_CONFIG.AxisLineColor)
end

function GizmoVisualizer:ResetToDefault()
    self.GizmoScale = GIZMO_VISUALIZER_CONFIG.GizmoScale
    self.Scale = DeepCopy(GIZMO_VISUALIZER_CONFIG.Scale)
    self.ScaleMultiplier = DeepCopy(GIZMO_VISUALIZER_CONFIG.ScaleMultiplier)
    self.DefaultColor = DeepCopy(GIZMO_VISUALIZER_CONFIG.DefaultColor)
    self.HighlightColor = DeepCopy(GIZMO_VISUALIZER_CONFIG.HighlightColor)
    self.HoveredColor = DeepCopy(GIZMO_VISUALIZER_CONFIG.HoveredColor)
    self.AxisLineColor = DeepCopy(GIZMO_VISUALIZER_CONFIG.AxisLineColor)
end

function GizmoVisualizer:GetHighlightColor(axis)
    return self.HighlightColor[axis] or {0.9, 0.9, 0.9, 0.8}
end

function GizmoVisualizer:GetHoveredColor(axis)
    return self.HoveredColor[axis] or {0.9, 0.9, 0.9, 0.8}
end

function GizmoVisualizer:GetDefaultColor(axis)
    return self.DefaultColor[axis] or {0.6, 0.6, 0.6, 0.6}
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

function GizmoVisualizer:ScaleGizmo(axis, renderable)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local rend = renderable
    local scale = self.Scale[AxisIndexMap[axis]] or 1.0
    local toScale = ToVec3(scale)
    toScale[AxisIndexMap[axis]] = toScale[AxisIndexMap[axis]] * (self.ScaleMultiplier[AxisIndexMap[axis]] or 1.0)
    for _,r in ipairs(rend or {}) do
        r:SetWorldScale(toScale)
    end
end

function GizmoVisualizer:Visualize3DCursor(guid, factor)
    local visual = VisualHelpers.GetEntityVisual(guid)
    if not visual then return end

    local objs = visual.ObjectDescs or {}
    if #objs == 0 then return end

    local camera = GetCamera()
    if not camera then return end

    factor = factor or 0.3
    local disatance = Ext.Math.Distance(camera.Transform.Transform.Translate, visual.WorldTransform.Translate)
    local clampedDistance = Ext.Math.Clamp(disatance, 1.0, 100.0)
    local baseScale = (clampedDistance / 10.0)
    local scaleVec = Vec3.new({baseScale * factor, baseScale * factor, baseScale * factor})

    local color = Vec4.new(self.AxisLineColor["X"])
    for _,obj in ipairs(objs) do
        obj.Renderable:SetWorldScale(scaleVec)
        obj.Renderable.ActiveMaterial.Material:SetVector4("Color", color)
    end
end

function GizmoVisualizer:HideGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local visual = VisualHelpers.GetEntityVisual(guid)
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
        r:SetWorldScale({0,0,0})
    end
end

function GizmoVisualizer:HideGizmo(guid)
    local visual = VisualHelpers.GetEntityVisual(guid)
    if not visual then return end

    local objs = visual.ObjectDescs or {}
    if #objs == 0 then return end

    for _,obj in ipairs(objs) do
        obj.Renderable:SetWorldScale({0,0,0})
    end
end

function GizmoVisualizer:HighLightGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, self:GetHighlightColor(axis))
    self:ScaleGizmo(axis, rend)
end

function GizmoVisualizer:HoverGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, self:GetHoveredColor(axis))
    self:ScaleGizmo(axis, rend)
end

function GizmoVisualizer:ResetGizmoAxis(axis, guid)
    if tonumber(axis) then
        axis = IndexAxisMap[axis]
    end
    local rend = SetGizmoAxisTextureColorParam(axis, guid, self:GetDefaultColor(axis))
    self:ScaleGizmo(axis, rend)
end

function GizmoVisualizer:VisualizeRotatePointer(guid, axis)
    local rotateScale = self.Scale[AxisIndexMap[axis]] or 1.0
    local scale = ToVec3((0.6 * rotateScale) / 0.81)

    for _,ax in pairs({"X", "Y", "Z"}) do
        if ax ~= axis then
            self:HideGizmoAxis(ax, guid)
        end
    end

    local visual = VisualHelpers.GetEntityVisual(guid)
    if not visual then return end

    local rend = SetGizmoAxisTextureColorParam(axis, guid, self:GetHighlightColor(axis))
    for _,r in ipairs(rend or {}) do
        r:SetWorldScale(scale)
    end

end

--- update internal scale based on camera distance

--- @param position vec3
--- @return number
function GizmoVisualizer:UpdateScale(position)
    local k = self.GizmoScale or 0.1
    if position == Vec3.new({0,0,0}) then return 1.0 end
    local cam = GetCamera()
    if not cam then return 1.0 end
    local camPos = Vec3.new(cam.Transform.Transform.Translate)
    local dist = Ext.Math.Distance(position, camPos)
    local scale = dist * k

    self.Scale = {scale, scale, scale}

    return scale
end

function GizmoVisualizer:SetLineFxColor(guid, color, width)
    if not color or #color ~= 4 then
        --Warning("SetLineFxColor: Invalid color provided")
        return
    end

    local entity = Ext.Entity.Get(guid)
    if not entity then return end

    if width and type(width) ~= "number" then
        width = self.Scale[1] * 0.15
    end
    if not width then
        width = self.Scale[1] * 0.15
    end

    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual then return end

    for _,obj in pairs(visual.ObjectDescs) do
        local renderable = obj.Renderable
        local oriScale = renderable.WorldTransform.Scale
        local toSet = { width or oriScale[1], width or oriScale[2], oriScale[3] }
        renderable:SetWorldScale(toSet)
        renderable.ActiveMaterial.Material:SetVector4("Color", color)
    end
    --Debug("SetLineFxColor: Set color of "..tostring(guid).." to "..table.concat(color, ", "))
end

function GizmoVisualizer:SetLineLength(guid, length, width)
    if not length or type(length) ~= "number" then
        Warning("SetLineLength: Invalid length provided")
        length = 0
    end
    if width and type(width) ~= "number" then
        width = self.Scale[1] * 0.15
    end
    if not width then
        width = self.Scale[1] * 0.15
    end

    local entity = Ext.Entity.Get(guid)
    if not entity then return end

    local visual = VisualHelpers.GetEntityVisual(entity)
    if not visual then return end

    for _,obj in pairs(visual.ObjectDescs) do
        local renderable = obj.Renderable
        local oriScale = renderable.WorldTransform.Scale
        local toSet = { width or oriScale[1], width or oriScale[2], length }
        renderable:SetWorldScale(toSet)
    end
    --Debug("SetLineLength: Set length of "..tostring(guid).." to "..tostring(length))
end