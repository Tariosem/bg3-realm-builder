local debug_time = 5 * 1000
local debug = false

local eml = Ext.Math
local Ray = Ray
local screenToWorldRay = ScreenToWorldRay
local getCamera = RBGetCamera
local getScreenSize = UIHelpers.GetScreenSize
local getCursorPos = PickingUtils.GetCursorPos

local add = eml.Add
local sub = eml.Sub
local mul = eml.Mul
local dot = eml.Dot
local cross = eml.Cross
local normalize = eml.Normalize
local min = math.min
local max = math.max

--- @alias AABB AABound

--- @param aabb AABB
--- @return vec3[]
local function collectAABBCorners(aabb)
    local min = aabb.Min
    local max = aabb.Max
    return {
        { min[1], min[2], min[3]},
        { max[1], min[2], min[3]},
        { min[1], max[2], min[3]},
        { max[1], max[2], min[3]},
        { min[1], min[2], max[3]},
        { max[1], min[2], max[3]},
        { min[1], max[2], max[3]},
        { max[1], max[2], max[3]},
    }
end

--- @param points vec3[]
--- @return vec3
local function avgPoint(points)
    local sum = {0,0,0}
    local count = #points
    for _, point in ipairs(points) do
        sum[1] = sum[1] + point[1]
        sum[2] = sum[2] + point[2]
        sum[3] = sum[3] + point[3]
    end
    return { sum[1]/count, sum[2]/count, sum[3]/count }
end

--- @class Plane
--- @field normal Vec3
--- @field point Vec3

--- @class Frustrum
--- @field planes Plane[] -- normal facing outwards
--- @field rayOrigins Vec3[]
--- @field nearPoints Vec3[]
--- @field farPoints Vec3[]

--- @param point Vec3
--- @param planeNormal Vec3
--- @param planePoint Vec3
--- @return boolean
local function isPointBehindPlane(point, planeNormal, planePoint)
    local toPoint = sub(point, planePoint)
    return dot(toPoint, planeNormal) < 0
end

--- cross(1->2, 1->3)
--- @param points3 vec3[]
--- @return Plane
local function makePlane(points3)
    local edge1 = sub(points3[2], points3[1])
    local edge2 = sub(points3[3], points3[1])
    local normal = normalize(cross(edge1, edge2))

    return {
        normal = normal,
        point = points3[1]
    }
end

--- @param screenPoints Vec2[] -- counter-clockwise order
--- @param near number
--- @param far number
--- @return Frustrum?
local function makeFrustrum(screenPoints, near, far)
    --- @type Plane[]
    local planes = {}

    --- @type vec3[]
    local rayOrigins = {}

    local cameraHandle = getCamera()
    if not cameraHandle then return end
    local screenW, screenH = getScreenSize()
    --- @type vec3[]
    local nearPoints = {}

    --- @type vec3[]
    local farPoints = {}
    
    local aabb = {
        Min = {0,0,0},
        Max = {0,0,0}
    }
    for i=1,3 do
        aabb.Min[i] = math.huge
        aabb.Max[i] = -math.huge
    end

    local function toRay(screenX, screenY)
        return screenToWorldRay(cameraHandle, screenX, screenY, screenW, screenH)
    end

    local pointCnt = 4

    for i=1,pointCnt do
        local sp = screenPoints[i]
        local ray = toRay(sp[1], sp[2])
        local ro = ray.Origin
        local rd = ray.Direction
        nearPoints[i] = add(ro, mul(rd, near))
        farPoints[i] = add(ro, mul(rd, far))
        rayOrigins[i] = ray.Origin
        aabb.Min[1] = min(aabb.Min[1], nearPoints[i][1], farPoints[i][1])
        aabb.Min[2] = min(aabb.Min[2], nearPoints[i][2], farPoints[i][2])
        aabb.Min[3] = min(aabb.Min[3], nearPoints[i][3], farPoints[i][3])
        aabb.Max[1] = max(aabb.Max[1], nearPoints[i][1], farPoints[i][1])
        aabb.Max[2] = max(aabb.Max[2], nearPoints[i][2], farPoints[i][2])
        aabb.Max[3] = max(aabb.Max[3], nearPoints[i][3], farPoints[i][3])
    end

    local function visualizeNearFar()
        local lines = {
            nearPoints[1], farPoints[1],
            nearPoints[2], farPoints[2],
            nearPoints[3], farPoints[3],
            nearPoints[4], farPoints[4],
            nearPoints[1], nearPoints[2],
            nearPoints[2], nearPoints[3],
            nearPoints[3], nearPoints[4],
            nearPoints[4], nearPoints[1],
            farPoints[1], farPoints[2],
            farPoints[2], farPoints[3],
            farPoints[3], farPoints[4],
            farPoints[4], farPoints[1],
        }
        local colors = {
            {1,0,0,1},
            {0,1,0,1},
            {0,0,1,1},
            {1,1,0,1},
        }
        for i=1,#lines,2 do
            NetChannel.Visualize:RequestToServer({
                Type = "Line",
                Position = lines[i],
                EndPosition = lines[i+1],
                Duration = debug_time
            }, function (response)
                RBUtils.SetGizmoColor(response[1], colors[math.ceil(i/2)] or {1,1,1,0.8})
            end)
        end
    end

    if debug then
        visualizeNearFar()
    end

    for i=1,pointCnt do
        local nextIndex = i % pointCnt + 1
        -- use two farpoints and one near point to ensure correct normal direction even if the frustrum is very thin
        planes[i] = makePlane({ nearPoints[i], farPoints[i], farPoints[nextIndex] })
    end
    planes[5] = makePlane({ farPoints[3], farPoints[2], farPoints[1] }) -- far plane
    if near > 0 then -- near plane is a point when near == 0
        planes[6] = {
            point = nearPoints[1],
            normal = mul(planes[5].normal, -1) 
        }
    end

    local function visualizePlaneNormals()
        local colors = {
            {1,0,0,1},
            {0,1,0,1},
            {0,0,1,1},
            {1,1,0,1},
            {1,0,1,1},
            {0,1,1,1},
        }
        for i, plane in ipairs(planes) do
            local color = colors[i] or {1,1,1,0.8}
            NetChannel.Visualize:RequestToServer({
                Type = "Line",
                Position = plane.point,
                EndPosition = add(plane.point, mul(plane.normal, 5)),
                Duration = debug_time
            }, function (response)
                RBUtils.SetGizmoColor(response[1], color)
            end)
        end
    end

    if debug then
        visualizePlaneNormals()
    end

    return {
        planes = planes,
        rayOrigins = rayOrigins,
        nearPoints = nearPoints,
        farPoints = farPoints,
        aabb = aabb
    }
end

--- @param frustrum Frustrum
--- @param aabb AABB
local function frustrumIntersectsAABB(frustrum, aabb)
    local corners = collectAABBCorners(aabb)
    for _, plane in ipairs(frustrum.planes) do
        local allOutside = true
        
        for _, corner in ipairs(corners) do
            if isPointBehindPlane(corner, plane.normal, plane.point) then
                allOutside = false
                break
            end
        end

        if allOutside then
            return false
        end
    end

    return true
end

local function initBoxSelectWindow(windowHandle)
    windowHandle.Visible = false
    windowHandle:SetSize({ 0, 0 })
    windowHandle:SetPos({ 0, 0 })
    windowHandle.NoTitleBar = true
    windowHandle.NoResize = true
    windowHandle.NoMove = true
    windowHandle:SetStyle("WindowBorderSize", 3 * SCALE_FACTOR)
    windowHandle:SetStyle("WindowRounding", 0)
    windowHandle:SetColor("Border", { 0.8, 0.8, 0.3, 0.8 })
    windowHandle:SetColor("WindowBg", { 0.1, 0.1, 0.1, 0.1 })
end

--- @class BoxSelectorConfig
--- @field Near number > 0
--- @field Far number
--- @field OnSelect fun(bs:BoxSelector)
--- @field OnUpdate fun(bs:BoxSelector)
--- @field OnEnd fun(bs:BoxSelector)
--- @field GetCandidates fun(frustrumAABB:AABB):EntityHandle[]

local PhysicsGroupFlags = Ext.Enums.PhysicsGroupFlags
local PhysicsType = Ext.Enums.PhysicsType

local include = 0
for k,v in pairs(PhysicsGroupFlags) do
    include = include | v
end

local allPhyType = PhysicsType.Dynamic | PhysicsType.Static
local contextInt = -1

local function defaultGetCandidates(frustrumAABB)
    local position = mul(add(frustrumAABB.Min, frustrumAABB.Max), 0.5)
    local extents = mul(sub(frustrumAABB.Max, frustrumAABB.Min), 0.5)
    local offset = {0,0,0.1}

    --- @diagnostic disable-next-line
    --local allIntersects = Ext.Level.TestBox(position, extents, allPhyType, include, 0)
    --RainbowDumpTable(allIntersects)

    --- @diagnostic disable-next-line
    local allIntersects = Ext.Level.SweepBoxAll(frustrumAABB.Min, frustrumAABB.Max, extents, allPhyType, include, 0, contextInt)

    local returns = {}
    for _,phyObj in pairs(allIntersects and allIntersects.Shapes or {}) do
        if phyObj.PhysicsObject and phyObj.PhysicsObject.Entity then
            table.insert(returns, phyObj.PhysicsObject.Entity)
        end
    end

    return returns
end

--- @param frustrumAABB AABB 
local function bruteForceGetCandidates(frustrumAABB)
    local position = mul(add(frustrumAABB.Min, frustrumAABB.Max), 0.5)
    local extents = mul(sub(frustrumAABB.Max, frustrumAABB.Min), 0.5)
    local radius = eml.Length(extents)
    local allItemAndCharacters = Ext.Entity.GetEntitiesAroundPosition(position, radius)

    local returns = {}
    for _, ent in pairs(allItemAndCharacters) do
        table.insert(returns, ent)
    end

    local allScenery = Ext.Entity.GetAllEntitiesWithComponent("Scenery")
    for _, ent in pairs(allScenery) do
        if not ent.Visual or not ent.Visual.Visual or not ent.Visual.Visual.WorldBound then goto continue end
        if not ent.Transform or not ent.Transform.Transform then goto continue end
        local dis = eml.Length(sub(position, ent.Transform.Transform.Translate))
        if dis < radius then
            table.insert(returns, ent)
        end

        ::continue::
    end

    return returns
end

local default_box_selector_config = {
    Near = 1,
    Far = 20,
    OnSelect = function() end,
    OnUpdate = function() end,
    OnEnd = function() end,
    GetCandidates = bruteForceGetCandidates
}

--- @class BoxSelector : BoxSelectorConfig
--- @field Start fun(self:BoxSelector)
--- @field Update fun(self:BoxSelector)
--- @field End fun(self:BoxSelector):EntityHandle[] -- Returns the entities that were selected
--- @field Init fun(self:BoxSelector, config: BoxSelectorConfig?)
--- @field GetFarPoints fun(self:BoxSelector):Vec3[] -- for debug purposes
--- @field ResetConfig fun(self:BoxSelector)
--- @field private windowFrame ExtuiWindow
--- @field private startScreenPos Vec2
--- @field private currentScreenPos Vec2
--- @field private timerID integer
local BoxSelector = {}

local windowFrame = nil
local startScreenPos = nil --[[@as Vec2 ]]
local currentScreenPos = nil --[[@as Vec2 ]]
local timerID = nil

local function stopTimer()
    if not timerID then return end
    Ext.Events.Tick:Unsubscribe(timerID)
    timerID = nil
end

local function startTimer(fn)
    if timerID then
        stopTimer()
    end

    timerID = Ext.Events.Tick:Subscribe(fn)
end

function BoxSelector:Init(config)
    local default = default_box_selector_config
    config = config or default
    self.Near = config.Near or default.Near
    self.Far = config.Far or default.Far
    self.OnSelect = config.OnSelect or function() end
    self.OnUpdate = config.OnUpdate or function() end
    self.OnEnd = config.OnEnd or function() end
    self.GetCandidates = config.GetCandidates or default.GetCandidates

    windowFrame = Ext.IMGUI.NewWindow("RB_BoxSelectFrame")
    initBoxSelectWindow(windowFrame)
end

function BoxSelector:ResetConfig()
    local default = default_box_selector_config
    self.Near = default.Near
    self.Far = default.Far
    self.OnSelect = function() end
    self.OnUpdate = function() end
    self.OnEnd = function() end
    self.GetCandidates = defaultGetCandidates

    if windowFrame then
        windowFrame.Visible = false
    end
end

function BoxSelector:Update()
    local start = startScreenPos
    local current = {getCursorPos()}
    if not next(current) then return end
    currentScreenPos = current

    if not start or not current then return end

    local x1 = min(start[1], current[1])
    local y1 = min(start[2], current[2])
    local x2 = max(start[1], current[1])
    local y2 = max(start[2], current[2])

    if not windowFrame then return end
    windowFrame:SetPos({ x1, y1 })
    windowFrame:SetSize({ x2 - x1 - 10 , y2 - y1 - 10 }) -- -10 to avoid mouse cursor being on the border which causes issues with mouse events
    windowFrame.Visible = true

    if self.OnUpdate then
        self:OnUpdate()
    end
end

function BoxSelector:Start()
    startScreenPos = {getCursorPos()}
    if not next(startScreenPos) then
        _P("BoxSelector:Start failed to get cursor position.")
        return
    end
    startTimer(function ()
        self:Update()
    end)
end

function BoxSelector:IsSelecting()
    return startScreenPos ~= nil
end

--- @param entity EntityHandle
--- @return AABB|nil
local function getEntityAABB(entity)
    local visual = entity.Visual
    if not visual then return nil end

    if not visual.Visual or not visual.Visual.WorldBound then
        return nil
    end
    local aabb = visual.Visual.WorldBound

    return {
        Min = aabb.Min,
        Max = aabb.Max
    }
end

--- @param aabb AABB
local function visualizeAABB(aabb, color)
    NetChannel.Visualize:RequestToServer({
        Type = "Box",
        Min = aabb.Min,
        Max = aabb.Max,
        Duration = debug_time,
    }, function (response)
        for i, handle in ipairs(response) do
            RBUtils.SetGizmoColor(handle, color or {1,0,0,0.8})
        end
    end)    
end

function BoxSelector:End()
    stopTimer()

    windowFrame.Visible = false

    local startPoint = startScreenPos
    local endPoint = currentScreenPos
    if not startPoint or not endPoint then
        return {}
    end

    local minPoint = {
        min(startPoint[1], endPoint[1]),
        min(startPoint[2], endPoint[2])
    }
    local maxPoint = {
        max(startPoint[1], endPoint[1]),
        max(startPoint[2], endPoint[2])
    }

    local points = {
        { minPoint[1], minPoint[2] },
        { maxPoint[1], minPoint[2] },
        { maxPoint[1], maxPoint[2] },
        { minPoint[1], maxPoint[2] }
    }
    local near = self.Near
    local far = self.Far

    if not near or not far then
        local default = default_box_selector_config
        near = default.Near
        far = default.Far
    end

    local frustrum = makeFrustrum(
        points,
        near,
        far
    )
    if not frustrum then
        _P("Failed to create frustrum for box selection.")
        return {}
    end

    if debug then
        visualizeAABB(frustrum.aabb)
    end

    local candidates = self.GetCandidates(frustrum.aabb)

    --- @class aabbEntry
    --- @field Entity EntityHandle
    --- @field AABB AABB

    --- @type aabbEntry[]
    local aabbs = {} --[[@as aabbEntry[] ]]
    for _,entity in pairs(candidates) do
        local aabb = getEntityAABB(entity)
        if aabb then
            table.insert(aabbs, { Entity = entity, AABB = aabb })
        end
    end

    local selected = {}
    for _, entry in pairs(aabbs) do
        if frustrumIntersectsAABB(frustrum, entry.AABB) then
            table.insert(selected, entry.Entity)
            if debug then 
                visualizeAABB(entry.AABB)
            end
        elseif debug then
            visualizeAABB(entry.AABB, {0,1,0,0.8})
        end
    end

    self.OnSelect(selected)

    startScreenPos = nil
    currentScreenPos = nil

    return selected
end

function BoxSelector:GetFarPoints()
    if not currentScreenPos then return {} end
    if not startScreenPos then return {} end

    local points = {
        { currentScreenPos[1], startScreenPos[2] },
        { currentScreenPos[1], currentScreenPos[2] },
        { startScreenPos[1], currentScreenPos[2] },
        { startScreenPos[1], startScreenPos[2] }
    }
    local near = self.Near or default_box_selector_config.Near
    local far = self.Far or default_box_selector_config.Far

    local cameraHandle = getCamera()
    if not cameraHandle then return {} end

    local screenW, screenH = getScreenSize()
    if not screenW or not screenH then return {} end

    --- @param screenX number
    --- @param screenY number
    --- @return Ray?
    local function toRay(screenX, screenY)
        return screenToWorldRay(cameraHandle, screenX, screenY, screenW, screenH)
    end

    local farPoints = {}
    for i=1,4 do
        local sp = points[i]
        local ray = toRay(sp[1], sp[2])
        if not ray then return {} end
        local ro = ray.Origin
        local rd = ray.Direction
        farPoints[i] = add(ro, mul(rd, far))
    end
    
    return farPoints
end

function BoxSelector:ToggleDebug()
    debug = not debug
    return debug
end

return BoxSelector