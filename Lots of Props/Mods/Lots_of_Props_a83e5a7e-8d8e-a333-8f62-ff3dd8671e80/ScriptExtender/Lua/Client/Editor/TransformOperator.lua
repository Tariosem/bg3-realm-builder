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
--- @field Mode 'Translate' | 'Rotate' | 'Scale'
--- @field Space 'World' | 'Local' | 'View' | 'Parent'
--- @field Num string
--- @field Axis table<'X'|'Y'|'Z', boolean>
--- @field new fun(targets: GUIDSTRING[]|GUIDSTRING): TransformOperator
TransformOperator = _Class("TransformOperator")

--- @param guid GUIDSTRING
--- @param mode "World"|"Local"|"View"|"Parent"
--- @return table<'X'|'Y'|'Z', Vec3>
function TransformOperator:GetAxesBySpace(guid, mode)
    if not self.AxesCache[guid] then self.AxesCache[guid] = {} end
    if self.AxesCache[guid][mode] then
        return self.AxesCache[guid][mode]
    end

    local rot = self.StartTransforms[guid] and self.StartTransforms[guid].RotationQuat or {CGetRotation(guid)}
    if mode == "World" then
        return {
            X = GLOBAL_COORDINATE.X,
            Y = GLOBAL_COORDINATE.Y,
            Z = GLOBAL_COORDINATE.Z,
        }
    elseif mode == "Local" then
        local x = Ext.Math.QuatRotate(rot, GLOBAL_COORDINATE.X)
        local y = Ext.Math.QuatRotate(rot, GLOBAL_COORDINATE.Y)
        local z = Ext.Math.QuatRotate(rot, GLOBAL_COORDINATE.Z)
        self.AxesCache[guid][mode] = { X = x, Y = y, Z = z }
    elseif mode == "View" then
        local camRot = self.StartCameraTransform and self.StartCameraTransform.RotationQuat or {GetCameraRotation()}
        local x = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.X)
        local y = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.Y)
        local z = Ext.Math.QuatRotate(camRot, GLOBAL_COORDINATE.Z)
        self.AxesCache[guid][mode] = { X = x, Y = y, Z = z }
    elseif mode == "Parent" then
        local parent = PropStore:GetBindParent(guid)
        if parent and EntityExists(parent) then
            local parentRot = self.StartTransforms[parent] and self.StartTransforms[parent].RotationQuat or {CGetRotation(parent)}
            local x = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.X)
            local y = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.Y)
            local z = Ext.Math.QuatRotate(parentRot, GLOBAL_COORDINATE.Z)
            self.AxesCache[guid][mode] = { X = x, Y = y, Z = z }
        else
            Warning("Entity does not have a valid parent: "..tostring(guid))
            self.AxesCache[guid][mode] = {
                X = GLOBAL_COORDINATE.X,
                Y = GLOBAL_COORDINATE.Y,
                Z = GLOBAL_COORDINATE.Z,
            }
        end
    else
        Warning("Invalid mode: "..tostring(mode))
        return {
            X = GLOBAL_COORDINATE.X,
            Y = GLOBAL_COORDINATE.Y,
            Z = GLOBAL_COORDINATE.Z,
        }
    end

    return self.AxesCache[guid][mode]
end

function TransformOperator:__init(targets)
    self.Targets = NormalizeGuidList(targets)
    self.AxesCache = {}
    self:InitStartTransforms()

    self.Mode = 'Translate'
    self.Space = 'World'
    self.Num = "0"
    self.Negative = false

    self.Axis = { X = true }
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
        self.Visualizations[self.Targets[cnt]] = guids[1]
        Debug("Received visualization for ".. self.Targets[cnt]..": "..tostring(guids[1]))
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
            Color = GizmoVisualizer.DefaultColor[next(self.Axis)] or {1,1,0,1},
            Duration = -1,
        })
    end
end

function TransformOperator:ChangeVisualization()
    local transforms = {}
    local visualizations = {}
    for _, guid in pairs(self.Targets) do
        local viz = self.Visualizations[guid]
        table.insert(visualizations, viz)
        SetLineFxColor(viz, GizmoVisualizer.DefaultColor[next(self.Axis)] or {1,1,0,1})
        local axis = self:GetAxesBySpace(guid, self.Space)[next(self.Axis)]
        local ray = Ray.new(self.StartTransforms[guid].Translate, axis)
        local pos = ray:At(-100)
        local dir = DirectionToQuat( axis * -1 )
        local newTransform = {
            Translate = pos,
            RotationQuat = dir,
        }
        transforms[self.Visualizations[guid]] = newTransform
    end

    Debug("Updating visualizations")
    Debug(visualizations)
    Debug(transforms)
    Commands.SetTransformCommand(visualizations, transforms, true)
end

function TransformOperator:SetAxis(axis)
    self.Axis = { [axis] = true }
    self:Visualize()
end

function TransformOperator:ExcludeAxis(axis)
    self.Axis = { X = true, Y = true, Z = true }
    self.Axis[axis] = nil
    self:Visualize()
end

function TransformOperator:SetSpace(space)
    self.Space = space
    self:Visualize()
end

--- @param e SimplifiedInputEvent
function TransformOperator:ParseInput(e)
    Debug(e)
    if e.Event ~= "KeyDown" then return end
    if GLOBAL_COORDINATE[e.Key] then
        if e.Modifiers == "LShift" or e.Modifiers == "RShift" then
            self:ExcludeAxis(e.Key)
        else
            self:SetAxis(e.Key)
        end
        Debug("Operator axis set to ", self.Axis)
    elseif keyToMode[e.Key] then
        self.Mode = keyToMode[e.Key]
        Debug("Operator mode set to "..self.Mode)
        if self.Mode == 'Scale' then
            self.Axis = { X = true, Y = true, Z = true }
            self:SetSpace("Local")
        end
    elseif keyToSpace[e.Key] then
        self:SetSpace(keyToSpace[e.Key])
        Debug("Operator space set to "..self.Space)

    elseif KeybindHelper.ParseInputToCharInput(e) then
        local char = KeybindHelper.ParseInputToCharInput(e)
        if char == "." or char == "," then
            if not self.Num:find("%.") then
                self.Num = self.Num .. "."
            end
        elseif char == "-" and table.find(e.Modifiers or {}, "LShift") then
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
        Debug("Operator num set to "..self.Num)
    end


    self:Apply()
end

function TransformOperator:__tostring()
    local verb = keyToVerb[self.Mode] or "Transforming"

    local axes = {}
    for k,v in pairs(self.Axis) do
        if v then table.insert(axes, k) end
    end
    local axisStr = self.Mode == "Scale" and table.concat(axes, "") or next(self.Axis) or "None"
    local unit = keyToUnit[self.Mode] or "unit"
    local numberStr = self.Negative and ("- (" .. self.Num .. ")") or self.Num
    local spaceStr = GetLoca(self.Space)

    return string.format("%s %s%s along %s axis in %s space for %d target(s)", verb, numberStr, unit, axisStr, spaceStr, #self.Targets)
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
    local dir = axes[next(self.Axis)]
    if not dir then
        return {CGetPosition(guid)}
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
    local rotQuat = Ext.Math.QuatRotateAxisAngle(Quat.Identity, axis, angle)
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
