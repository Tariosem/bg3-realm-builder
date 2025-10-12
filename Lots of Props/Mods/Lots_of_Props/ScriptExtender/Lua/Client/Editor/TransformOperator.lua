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
--- @field Targets GUIDSTRING[]
--- @field Mode TransformEditorMode
--- @field Space TransformEditorSpace
--- @field Num string
--- @field Axis table<'X'|'Y'|'Z', boolean>
--- @field new fun(targets: GUIDSTRING[]|GUIDSTRING, space:TransformEditorSpace?, mode:TransformEditorMode?, axis:table<'X'|'Y'|'Z', boolean>?): TransformOperator
TransformOperator = _Class("TransformOperator")

--- @param guid GUIDSTRING
--- @param space TransformEditorSpace
--- @return table<'X'|'Y'|'Z', Vec3>
function TransformOperator:GetAxesBySpace(guid, space)
    if not self.AxesCache[guid] then self.AxesCache[guid] = {} end
    if self.AxesCache[guid][space] then
        return self.AxesCache[guid][space]
    end

    local rot = self.StartTransforms[guid] and self.StartTransforms[guid].RotationQuat or {CGetRotation(guid)}
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
        self.AxesCache[guid][space] = { X = x, Y = y, Z = z }
    elseif space == "View" then
        local camRot = self.StartCameraTransform and self.StartCameraTransform.RotationQuat or {GetCameraRotation()}
        local x = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.X)
        local y = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.Y)
        local z = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.Z)
        self.AxesCache[guid][space] = { X = x, Y = y, Z = z }
    elseif space == "Parent" then
        local parent = PropStore:GetBindParent(guid)
        if parent and EntityExists(parent) then
            local parentRot = self.StartTransforms[parent] and self.StartTransforms[parent].RotationQuat or {CGetRotation(parent)}
            local x = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.X)
            local y = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.Y)
            local z = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.Z)
            self.AxesCache[guid][space] = { X = x, Y = y, Z = z }
        else
            Warning("Entity does not have a valid parent: "..tostring(guid))
            self.AxesCache[guid][space] = {
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

    return self.AxesCache[guid][space]
end

function TransformOperator:__init(targets, space, mode, axis)
    self.Targets = NormalizeGuidList(targets)
    self.AxesCache = {}
    self:InitStartTransforms()

    self.Mode = mode or "Translate"
    self.Space = space or "Local"
    self.Num = "0"
    self.Negative = false

    self.Axis = axis or { X = true }
    self.Visualizations = {}
    self:Visualize()
end

function TransformOperator:InitStartTransforms()
    self.StartTransforms = {}
    for _,guid in pairs(self.Targets) do
        if EntityExists(guid) then
            self.StartTransforms[guid] = {
                Translate = {CGetPosition(guid)},
                RotationQuat = {CGetRotation(guid)},
                Scale = {CGetScale(guid)},
            }
        end
    end
    self.StartCameraTransform = {
        RotationQuat = {GetCameraRotation()},
    }
    for _,guid in pairs(self.Targets) do
        local parent = PropStore:GetBindParent(guid)
        if parent and EntityExists(parent) then
            self.StartTransforms[parent] = {
                Translate = {CGetPosition(parent)},
                RotationQuat = {CGetRotation(parent)},
                Scale = {CGetScale(parent)},
            }
        end
    end
end

function TransformOperator:Visualize()
    if next(self.Visualizations) then
        self:ChangeVisualization()
        return
    end

    local requests = #self.Targets
    local cnt = 0
    local receive = ClientSubscribe(NetMessage.Visualization, function (data)
        local guids = NormalizeGuidList(data.Guid)
        cnt = cnt + 1
        self.Visualizations[cnt] = guids[1]
        if cnt > requests then
            Debug("All visualizations received")
            return UNSUBSCRIBE_SYMBOL
        end
    end)

    for _,guid in pairs(self.Targets) do
        local axis = self:GetAxesBySpace(guid, self.Space)[next(self.Axis)]
        local ray = Ray.new({CGetPosition(guid)}, axis)
        Post(NetChannel.Visualize, {
            Type = "Line",
            Position = ray:At(-100),
            EndPosition = ray:At(100),
            Color = GizmoVisualizer.AxisLineColor[next(self.Axis)] or {1,1,0,1},
            Duration = -1,
        })
    end
end

function TransformOperator:ChangeVisualization()
    local transforms = {}
    local visualizations = {}
    local cnt = #self.Targets
    for _, viz in pairs(self.Visualizations) do
        local guid = self.Targets[cnt]
        cnt = cnt - 1
        table.insert(visualizations, viz)
        GizmoVisualizer.SetLineFxColor(viz, GizmoVisualizer.AxisLineColor[next(self.Axis)] or {1,1,0,1})
        local axis = self:GetAxesBySpace(guid, self.Space)[next(self.Axis)]
        local ray = Ray.new(self.StartTransforms[guid].Translate, axis)
        local pos = ray:At(-100)
        local dir = DirectionToQuat( axis * -1 )
        local newTransform = {
            Translate = pos,
            RotationQuat = dir,
        }
        transforms[viz] = newTransform
    end
    Commands.SetTransformCommand(visualizations, transforms, true)
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

--- @param e SimplifiedInputEvent
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
        local char = KeybindHelpers.ParseInputToCharInput(e)
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
    for _,guid in pairs(self.Targets) do
        if not EntityExists(guid) then
            Warning("Entity does not exist: "..tostring(guid))
        else
            local transform = {
                Translate = self:ApplyTranslate(guid, num),
                RotationQuat = self:ApplyRotate(guid, num),
                Scale = self:ApplyScale(guid, num),
            }
            transforms[guid] = transform
        end
    end
    Commands.SetTransformCommand(self.Targets, transforms, true)
end

function TransformOperator:ApplyTranslate(guid, num)
    if self.Mode ~= "Translate" then return self.StartTransforms[guid] and self.StartTransforms[guid].Translate or {CGetPosition(guid)} end
    local axes = self:GetAxesBySpace(guid, self.Space)
    local dir = Vec3.new(0,0,0)
    for k,v in pairs(self.Axis) do
        if v and axes[k] then
            dir = dir + axes[k]
        end
    end
    dir = Ext.Math.Normalize(dir)
    local moveVec = Ext.Math.Mul(dir, num)
    local startPos = self.StartTransforms[guid] and self.StartTransforms[guid].Translate or {CGetPosition(guid)}
    return Ext.Math.Add(startPos, moveVec)
end

function TransformOperator:ApplyRotate(guid, num)
    if self.Mode ~= "Rotate" then return self.StartTransforms[guid] and self.StartTransforms[guid].RotationQuat or {CGetRotation(guid)} end
    local axes = self:GetAxesBySpace(guid, self.Space)
    local axis = axes[next(self.Axis)]
    if not axis then
        Warning("No valid axis selected for rotation")
        return {CGetRotation(guid)}
    end
    local angle = math.rad(num)
    local rotQuat = Ext.Math.QuatRotateAxisAngle(Quat.Identity(), axis, angle)
    local startRot = self.StartTransforms[guid] and self.StartTransforms[guid].RotationQuat or {CGetRotation(guid)}
    local newRot = Ext.Math.QuatMul(rotQuat, startRot)
    return Ext.Math.QuatNormalize(newRot)
end

function TransformOperator:ApplyScale(guid, num)
    if self.Mode ~= "Scale" then return self.StartTransforms[guid] and self.StartTransforms[guid].Scale or {CGetScale(guid)} end
    local scaleFactor = num
    local startScale = self.StartTransforms[guid] and self.StartTransforms[guid].Scale or {CGetScale(guid)}
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
    for _,guid in pairs(self.Targets) do
        if EntityExists(guid) then
            currentTransforms[guid] = {
                Translate = {CGetPosition(guid)},
                RotationQuat = {CGetRotation(guid)},
                Scale = {CGetScale(guid)},
            }
        end
    end
    local currenrTargets = NormalizeGuidList(self.Targets)
    
    HistoryManager:PushCommand({
        Undo = function()
            Commands.SetTransformCommand(currenrTargets, self.StartTransforms, true)
        end,
        Redo = function()
            Commands.SetTransformCommand(currenrTargets, currentTransforms, true)
        end
    })
    Post(NetChannel.Visualize, { Type = "Clear" })
end

function TransformOperator:Cancel()
    Commands.SetTransformCommand(self.Targets, self.StartTransforms, true)
    Post(NetChannel.Visualize, { Type = "Clear" })
end
