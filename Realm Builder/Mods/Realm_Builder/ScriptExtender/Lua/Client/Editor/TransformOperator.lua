local keyToVerb = {
    Translate = "Moving",
    Rotate = "Rotating",
    Scale = "Scaling",
}

local keyToUnit = {
    Translate = "m",
    Rotate = "'",
    Scale = "",
}

local keyToMode = {
    G = "Translate",
    R = "Rotate",
    S = "Scale",
}

local keyToSpace = {
    F1 = "World",
    F2 = "Local",
    F3 = "View",
    F4 = "Parent",
}

--- @class TransformOperator
--- @field Targets RB_MovableProxy[]
--- @field Mode TransformEditorMode
--- @field Space TransformEditorSpace
--- @field Num string
--- @field Axis table<'X'|'Y'|'Z', boolean>
--- @field new fun(targets: GUIDSTRING[]|GUIDSTRING, space:TransformEditorSpace?, mode:TransformEditorMode?, axis:table<'X'|'Y'|'Z', boolean>?): TransformOperator
TransformOperator = _Class("TransformOperator")

--- @param proxy RB_MovableProxy
--- @param space TransformEditorSpace
--- @return table<'X'|'Y'|'Z', Vec3>
function TransformOperator:GetAxesBySpace(proxy, space)
    if not self.AxesCache[proxy] then self.AxesCache[proxy] = {} end
    if self.AxesCache[proxy][space] then
        return self.AxesCache[proxy][space]
    end

    local rot = proxy:GetSavedTransform().RotationQuat
    if space == "World" then
        return {
            X = GLOBAL_COORDINATE.X,
            Y = GLOBAL_COORDINATE.Y,
            Z = GLOBAL_COORDINATE.Z,
        }
    elseif space == "Local" then
        local x = Ext.Math.QuatRotate(rot, GLOBAL_COORDINATE.X)
        local y = Ext.Math.QuatRotate(rot, GLOBAL_COORDINATE.Y)
        local z = Ext.Math.QuatRotate(rot, GLOBAL_COORDINATE.Z)
        self.AxesCache[proxy][space] = { X = x, Y = y, Z = z }
    elseif space == "View" then
        local camRot = self.StartCameraTransform and self.StartCameraTransform.RotationQuat or {GetCameraRotation()}
        local x = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.X)
        local y = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.Y)
        local z = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.Z)
        self.AxesCache[proxy][space] = { X = x, Y = y, Z = z }
    elseif space == "Parent" then
        local parent = proxy:GetParent()
        if parent and EntityExists(parent) then
            local parentRot = parent:GetSavedTransform().RotationQuat
            local x = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.X)
            local y = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.Y)
            local z = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.Z)
            self.AxesCache[proxy][space] = { X = x, Y = y, Z = z }
        else
            Warning("Entity does not have a valid parent: "..tostring(proxy))
            self.AxesCache[proxy][space] = {
                X = GLOBAL_COORDINATE.X,
                Y = GLOBAL_COORDINATE.Y,
                Z = GLOBAL_COORDINATE.Z,
            }
        end
    else
        Warning("Invalid mode: "..tostring(space))
        return {
            X = GLOBAL_COORDINATE.X,
            Y = GLOBAL_COORDINATE.Y,
            Z = GLOBAL_COORDINATE.Z,
        }
    end

    return self.AxesCache[proxy][space]
end

function TransformOperator:__init(targets, space, mode, axis, ifInitStartTransforms)
    self.Targets = targets
    self.Visualizer = GizmoVisualizer.new()
    self.Visualizer:UpdateScale(self.Targets[1])
    self.AxesCache = {}
    self:InitStartTransforms(ifInitStartTransforms)

    self.Mode = mode or "Translate"
    self.Space = space or "Local"
    self.Num = "0"
    self.Negative = false

    self.Axis = axis or { X = true }

    if self.Mode ~= "Scale" and CountMap(self.Axis) > 1 then
        self.Axis = { [next(self.Axis)] = true }
    end

    self.Visualizations = {}
    self:Visualize()
end

function TransformOperator:InitStartTransforms(ifInit)
    if not ifInit then return end
    
    for _,proxy in pairs(self.Targets) do
        proxy:SaveTransform()
    end

    self.StartCameraTransform = {
        RotationQuat = {GetCameraRotation()},
    }
    for _,proxy in pairs(self.Targets) do
        local parent = proxy:GetParent()
        if parent then
            parent:SaveTransform()
        end
    end
end

function TransformOperator:Visualize()
    if next(self.Visualizations) then
        self:ChangeVisualization()
        return
    end

    local color = self.Visualizer.AxisLineColor[next(self.Axis)] or {1,1,0,1}

    for _,proxy in pairs(self.Targets) do
        local axis = self:GetAxesBySpace(proxy, self.Space)[next(self.Axis)]
        local ray = Ray.new(proxy:GetSavedTransform().Translate, axis)

        NetChannel.Visualize:RequestToServer({
            Type = "Line",
            Position = ray:At(-100),
            EndPosition = ray:At(100),
            Width = self.Visualizer.Scale[1] * 0.3,
            Duration = -1,
        }, function (response)
            local viz = response[1]
            local tryCnt = 0
            Timer:EveryFrame(function()
                if tryCnt > 300 then
                    Warning("GizmoVisualizer: Failed to get visual for line gizmo")
                    return UNSUBSCRIBE_SYMBOL
                end
                if not VisualHelpers.GetEntityVisual(viz) then tryCnt = tryCnt + 1 return end
                self.Visualizer:SetLineFxColor(viz, color)
                self.Visualizer:SetLineLength(viz, 20)
                return UNSUBSCRIBE_SYMBOL
            end)
            table.insert(self.Visualizations, viz)
        end)
    end
end

function TransformOperator:ChangeVisualization()
    local transforms = {}
    local visualizations = {}
    local cnt = #self.Targets
    for _, viz in pairs(self.Visualizations) do
        local proxy = self.Targets[cnt]
        cnt = cnt - 1
        table.insert(visualizations, viz)
        self.Visualizer:SetLineFxColor(viz, self.Visualizer.AxisLineColor[next(self.Axis)] or {1,1,0,1})
        self.Visualizer:SetLineLength(viz, 20)
        local axis = self:GetAxesBySpace(proxy, self.Space)[next(self.Axis)]
        local ray = Ray.new(proxy:GetSavedTransform().Translate, axis)
        local pos = ray:At(-100)
        local dir = DirectionToQuat( axis * -1 )
        local newTransform = {
            Translate = pos,
            RotationQuat = dir,
        }
        transforms[viz] = newTransform
    end

    local vizProxies = {}
    for _,viz in pairs(visualizations) do
        local proxy = MovableProxy.CreateByGuid(viz)
        if proxy then
            table.insert(vizProxies, proxy)
        end
    end

    Commands.SetTransform(vizProxies, transforms, true)
end

function TransformOperator:SetAxis(axis, shiftDown)
    if self.Mode ~= "Scale" then
        if self.Axis and CountMap(self.Axis) == 1 and self.Axis[axis] then
            return -- same axis, do nothing
        else
            self.Axis = { [axis] = true }
        end
        self:Visualize()
        return
    end

    if self.Axis and CountMap(self.Axis) == 1 and self.Axis[axis] then
        self.Axis = { X = true, Y = true, Z = true }
    elseif shiftDown then
        self.Axis = { X = true, Y = true, Z = true }
        self.Axis[axis] = nil
    else
        self.Axis = { [axis] = true }
    end
    self:Visualize()
end

function TransformOperator:SetSpace(space)
    self.Space = space
    self:Visualize()
end

--- @param e SimplifiedInputEvent|string
function TransformOperator:ParseInput(e)
    if e.Event ~= "KeyDown" then return end

    local shiftDown = table.find(e.Modifiers or {}, "LShift") or table.find(e.Modifiers or {}, "RShift")

    if GLOBAL_COORDINATE[e.Key] then
        self:SetAxis(e.Key, shiftDown)
    elseif keyToMode[e.Key] then
        self.Mode = keyToMode[e.Key]
        if self.Mode == 'Scale' then
            self.Axis = { X = true, Y = true, Z = true }
            self:SetSpace("Local")
        elseif CountMap(self.Axis) > 1 then
            self.Axis = { [next(self.Axis)] = true }
        end
    elseif keyToSpace[e.Key] then
        -- only supports scale in local space
        if self.Mode == "Scale" then return end
        self:SetSpace(keyToSpace[e.Key])

    elseif KeybindHelpers.ParseInputToCharInput(e) then
        local char = KeybindHelpers.ParseInputToCharInput(e) --[[@as string ]]
        if char == "." or char == "," then
            if not self.Num:find("%.") then
                self.Num = self.Num .. "."
            end
        elseif (e.Key == "MINUS" or e.Key == "KP_MINUS") and shiftDown then
            self.Negative = not self.Negative
        elseif char == "BACKSPACE" then
            if #self.Num > 1 then
                self.Num = self.Num:sub(1, #self.Num - 1)
            else
                self.Num = "0"
            end
        elseif GLOBAL_AVAILABLE_OPERATORS[char] then
            if self.Num:sub(-1) ~= " " then
                self.Num = self.Num .. char
            end
        elseif tonumber(char) then
            if self.Num == "0" then
                self.Num = char
            else
                self.Num = self.Num .. char
            end
        end
    end

    self:Apply()
end

function TransformOperator:__tostring()
    local verb = keyToVerb[self.Mode] or "Transforming"

    local axes = {}
    for k,v in pairs(self.Axis) do
        if v then table.insert(axes, k) end
    end
    table.sort(axes)
    local axisStr = table.concat(axes, "/")
    local unit = keyToUnit[self.Mode] or "unit"
    local numberStr = self.Negative and ("- (" .. self.Num .. ")") or self.Num
    local spaceStr = GetLoca(self.Space)

    return string.format("%s [%s%s] along %s axis in %s space for %d target(s)", verb, numberStr, unit, axisStr, spaceStr, #self.Targets)
end

function TransformOperator:Apply()
    if #self.Targets == 0 then return end
    local transforms = {}
    local num = tonumber(self.Num) or EvalExpression(self.Num)
    if not num then return end
    if self.Negative then num = -num end
    for _,proxy in pairs(self.Targets) do
        local transform = {
            Translate = self:ApplyTranslate(proxy, num),
            RotationQuat = self:ApplyRotate(proxy, num),
            Scale = self:ApplyScale(proxy, num),
        }
        proxy:SetTransform(transform)
    end
end


---@param proxy any
---@param num any
---@return Vec3
function TransformOperator:ApplyTranslate(proxy, num)
    if self.Mode ~= "Translate" then return proxy:GetSavedTransform().Translate end
    local axes = self:GetAxesBySpace(proxy, self.Space)
    local dir = Vec3.new(0,0,0)
    for k,v in pairs(self.Axis) do
        if v and axes[k] then
            dir = dir + axes[k]
        end
    end
    dir = Ext.Math.Normalize(dir)
    local moveVec = Ext.Math.Mul(dir, num)
    local startPos = proxy:GetSavedTransform().Translate
    return Ext.Math.Add(startPos, moveVec) --[[@as Vec3]]
end

---@param proxy any
---@param num any
---@return Quat
function TransformOperator:ApplyRotate(proxy, num)
    if self.Mode ~= "Rotate" then return proxy:GetSavedTransform().RotationQuat end
    local axes = self:GetAxesBySpace(proxy, self.Space)
    local axis = axes[next(self.Axis)]
    if not axis then
        Warning("No valid axis selected for rotation")
        return proxy:GetSavedTransform().RotationQuat
    end
    local angle = math.rad(num)
    local rotQuat = Ext.Math.QuatRotateAxisAngle(Quat.Identity(), axis, angle)
    local startRot = proxy:GetSavedTransform().RotationQuat
    local newRot = Ext.Math.QuatMul(rotQuat, startRot)
    return Ext.Math.QuatNormalize(newRot)
end

--- @param proxy any
--- @param num any
--- @return Vec3
function TransformOperator:ApplyScale(proxy, num)
    if self.Mode ~= "Scale" then return proxy:GetSavedTransform().Scale end
    local scaleFactor = num
    local startScale = proxy:GetSavedTransform().Scale
    local newScale = {}
    for i=1,3 do
        if self.Axis[({"X","Y","Z"})[i]] then
            newScale[i] = startScale[i] * scaleFactor
        else
            newScale[i] = startScale[i]
        end
    end
    return newScale
end

function TransformOperator:Confirm()
    local currentTransforms = {}
    for _,proxy in pairs(self.Targets) do
        currentTransforms[proxy] = proxy:GetTransform()
    end
    local startTransforms = {}
    for _,proxy in pairs(self.Targets) do
        startTransforms[proxy] = proxy:GetSavedTransform()
    end
    
    HistoryManager:PushCommand({
        Undo = function()
            for proxy, transform in pairs(startTransforms) do
                proxy:SetTransform(transform)
            end
        end,
        Redo = function()
            for proxy, transform in pairs(currentTransforms) do
                proxy:SetTransform(transform)
            end
        end
    })
    NetChannel.Delete:SendToServer({ Guid = self.Visualizations }, function(response) end)
end

function TransformOperator:Cancel()
    for _,proxy in pairs(self.Targets) do
        proxy:RestoreTransform()
    end
    NetChannel.Delete:SendToServer({ Guid = self.Visualizations }, function(response) end)
end
