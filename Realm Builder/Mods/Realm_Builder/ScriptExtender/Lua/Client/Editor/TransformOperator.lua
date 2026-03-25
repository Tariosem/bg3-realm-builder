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

--- @class TransformOperator
--- @field Num string
--- @field Negative boolean
--- @field Gizmo TransformGizmo
--- @field Listener RBSubscription
--- @field new fun(gizmo: TransformGizmo): TransformOperator
TransformOperator = _Class("TransformOperator")

function TransformOperator:__init(gizmo)
    self.Num = ""
    self.Negative = false
    self.Gizmo = gizmo
    self.Listener = nil
end

function TransformOperator:StartListening()
    if self.Listener then return end

    self.Listener = InputEvents.SubscribeKeyAndMouse(function(e)
        local gizmo = self.Gizmo
        if not gizmo or not gizmo.IsDragging then
            self.IsInputting = false
            return
        end

        if self.IsInputting then
            self:ParseInput(e)
            return
        end

        local c = KeybindHelpers.ParseInputToCharInput(e)
        if tonumber(c) then
            self:StartInputting()
            self:ParseInput(e)
        end
    end)
end

function TransformOperator:StopListening()
    if self.Listener then
        self.Listener:Unsubscribe()
        self.Listener = nil
    end
end

function TransformOperator:StartInputting()
    self.Num = ""
    self.Negative = false
    self.IsInputting = true
end

function TransformOperator:StopInputting()
    self.IsInputting = false
end

local allowedChars = {
    ["+"] = true,
    ["-"] = true,
    ["*"] = true,
    ["/"] = true,
    ["%"] = true,
    ["^"] = true,
    ["."] = true,
    ["p"] = true,
    ["i"] = true,
}

--- @param e SimplifiedInputEvent|string
function TransformOperator:ParseInput(e)
    if e.Event ~= "KeyDown" then return end

    local inputState = InputEvents.GetGlobalInputStatesRef()
    local shiftDown = inputState.Shift

    local numStr = self.Num or ""

    if shiftDown and e.Key == "Minus" then
        self.Negative = not self.Negative
    elseif e.Key == "BACKSPACE" or e.Key == "Delete" then
        numStr = numStr:sub(1, -2)
    else
        local c = KeybindHelpers.ParseInputToCharInput(e) or ""
        --if not tonumber(c) and not allowedChars[c] then return end
        numStr = numStr .. c
    end

    self.Num = numStr

    self:Apply()
end

local loadstringexpr = [[
    _ENV = math

    return %s
]]

--- @param gizmo TransformGizmo
--- @param selectedAxis Vec3
--- @return Vec3
local function calcAvgAxis(gizmo, selectedAxis)
    local gizmoAxes = gizmo.Picker:GetAxes()
    local avgNormal = Vec3.new(0,0,0)
    for axis, selected in pairs(selectedAxis) do
        if selected then
            avgNormal = avgNormal + gizmoAxes[axis]:Normalize()
        end
    end
    return avgNormal
end

--- @param gizmo TransformGizmo
--- @param selectedAxis Vec3
--- @return Vec3
local function selectAxis(gizmo, selectedAxis)
    local gizmoAxes = gizmo.Picker:GetAxes()
    for axis, selected in pairs(selectedAxis) do
        if selected then
            return gizmoAxes[axis]
        end
    end
    return Vec3.new(0,0,0)
end

function TransformOperator:Apply()
    local gizmo = self.Gizmo
    if not gizmo or not gizmo.IsDragging then return end
    gizmo:OnAction(self:ToStirng())

    local num = tonumber(self.Num)
    if not num then
        local func, err = Ext.Utils.LoadString(string.format(loadstringexpr, self.Num))
        if not func then
            --Debug("Invalid expression: " .. err)
            return
        end

        local success, result = pcall(func)
        if not success then
            --Debug("Error evaluating expression: " .. result)
            return
        end

        num = result
    end

    if not num then return end

    if self.Negative then
        num = -num
    end

    local activeMode = gizmo.ActiveMode

    if self.lastMode and self.lastMode ~= activeMode then
        num = 0
        self.Num = ""
    end

    self.lastMode = activeMode
    local selectedAxis = gizmo.SelectedAxis or {}
    local axisCnt = RBTableUtils.CountMap(selectedAxis)
    local cameraForward = gizmo.cachedCameraForward or Vec3.new(0,0,1)

    local delta = {0,0,0,0}
    if activeMode == "Translate" then
        local avgNormal = calcAvgAxis(gizmo, selectedAxis)
        delta = avgNormal * num
    elseif activeMode == "Rotate" then
        local axis = nil
        if axisCnt == 3 then 
            axis = cameraForward
        else
            axis = selectAxis(gizmo, selectedAxis)
        end

        if not axis then return end

        delta = { axis[1], axis[2], axis[3], math.rad(num) }
    else -- Scale
        local scaleVec = Vec3.new(1,1,1)
        for i, _ in ipairs(scaleVec) do
            if selectedAxis[IndexAxisMap[i]] then
                scaleVec[i] = num
            end
        end
        delta = scaleVec 
    end

    gizmo:ApplyDelta(delta)
end

local function round2(num)
    local mult = 100
    local del = num < 0 and -0.5 or 0.5
    return math.floor(num * mult + del) / mult
end

function TransformOperator:ToStirng(delta)
    local gizmo = self.Gizmo
    if not gizmo or not gizmo.IsDragging then return "" end

    local decimatedDelta = {}
    for i,v in ipairs(delta or {}) do
        decimatedDelta[i] = round2(v)
    end

    local mode = gizmo.ActiveMode
    local verb = keyToVerb[mode] or "Operating"

    local axes = {}
    for k,v in pairs(gizmo.SelectedAxis or {}) do
        if v then table.insert(axes, k) end
    end
    table.sort(axes)
    local axisStr = table.concat(axes, "/")
    local unit = keyToUnit[mode] or ""
    local numberStr = ""

    if self.IsInputting then
        numberStr = self.Num
    else
        numberStr = mode == "Rotate" and string.format("%.2f", math.deg(delta[4])) or table.concat(decimatedDelta, ", ")
    end

    return string.format("%s [%s] %s along %s axis", verb, numberStr, unit, axisStr)
end