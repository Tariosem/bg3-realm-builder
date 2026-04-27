---@alias TimerID integer
---@class Timer
GL_GLOBALS = GL_GLOBALS or {}
GL_GLOBALS.TimerScheduler = GL_GLOBALS.TimerScheduler or {
    Active = {},
    NextId = 0,
    ServerClientCallbacks = {},
    TickSubscription = nil,
    ShutdownSubscription = nil,
}

local scheduler = GL_GLOBALS.TimerScheduler

Timer = {
    _active = scheduler.Active,
    _serverClientCallbacks = scheduler.ServerClientCallbacks,
    _scheduler = scheduler,
}

local function buildCancelFunction(id)
    return function()
        Timer:Cancel(id)
    end
end

function Timer:_NextId()
    self._scheduler.NextId = self._scheduler.NextId + 1
    return self._scheduler.NextId
end

function Timer:_CreateRecord(record)
    local id = self:_NextId()
    record.Id = id
    self._active[id] = record
    self:_EnsureScheduler()
    return id
end

function Timer:_RemoveRecord(id)
    if not id then return nil end

    local record = self._active[id]
    if record then
        self._active[id] = nil
    end

    return record
end

function Timer:_EnsureScheduler()
    if not self._scheduler.TickSubscription then
        self._scheduler.TickSubscription = Ext.Events.Tick:Subscribe(function()
            Timer:_OnTick()
        end)
    end

    if not self._scheduler.ShutdownSubscription then
        self._scheduler.ShutdownSubscription = Ext.Events.Shutdown:Subscribe(function()
            Timer:CancelAll()
        end)
    end
end

function Timer:_OnTick()
    local now = Ext.Utils.MonotonicTime()
    local activeIds = {}

    for id in pairs(self._active) do
        activeIds[#activeIds + 1] = id
    end

    for _, id in ipairs(activeIds) do
        local record = self._active[id]
        if record then
            record.TickCount = (record.TickCount or 0) + 1

            local shouldRun = false
            if record.Kind == "After" then
                shouldRun = now - record.StartTime >= record.DelayMS
            elseif record.Kind == "Ticks" then
                shouldRun = record.TickCount >= record.TargetTicks
            elseif record.Kind == "AfterOrTicks" then
                shouldRun = now - record.StartTime >= record.DelayMS or record.TickCount >= record.TargetTicks
            elseif record.Kind == "EveryFrame" then
                shouldRun = true
            elseif record.Kind == "EveryTicks" then
                shouldRun = record.TickCount >= record.IntervalTicks
            elseif record.Kind == "Every" then
                shouldRun = now - record.LastRunTime >= record.IntervalMS
            end

            if shouldRun then
                if record.Kind == "After" or record.Kind == "Ticks" or record.Kind == "AfterOrTicks" then
                    self:_RemoveRecord(id)
                    record.Callback(id)
                else
                    if record.Kind == "EveryTicks" then
                        record.TickCount = 0
                    elseif record.Kind == "Every" then
                        record.LastRunTime = now
                    end

                    local result = record.Callback(id)
                    if result == UNSUBSCRIBE_SYMBOL then
                        self:Cancel(id)
                    end
                end
            end
        end
    end
end

---@param ms integer
---@param callback fun(timerID:integer)
---@return TimerID integer
---@return function cancelFunction
function Timer:After(ms, callback)
    local id = self:_CreateRecord({
        Kind = "After",
        Callback = callback,
        DelayMS = ms,
        StartTime = Ext.Utils.MonotonicTime(),
        TickCount = 0,
    })
    return id, buildCancelFunction(id)
end

---@param ticks integer
---@param callback fun(timerID:integer)
function Timer:Ticks(ticks, callback)
    return self:_CreateRecord({
        Kind = "Ticks",
        Callback = callback,
        TargetTicks = ticks,
        TickCount = 0,
    })
end

---@param ms integer
---@param ticks integer
---@param callback fun(timerID:integer)
function Timer:AfterOrTicks(ms, ticks, callback)
    return self:_CreateRecord({
        Kind = "AfterOrTicks",
        Callback = callback,
        DelayMS = ms,
        TargetTicks = ticks,
        StartTime = Ext.Utils.MonotonicTime(),
        TickCount = 0,
    })
end

---@param callback fun(timerID:integer):UNSUBSCRIBE_SYMBOL|nil
---@return TimerID integer
---@return function cancelFunction
function Timer:EveryFrame(callback)
    local id = self:_CreateRecord({
        Kind = "EveryFrame",
        Callback = callback,
        TickCount = 0,
    })
    return id, buildCancelFunction(id)
end

function Timer:EveryTicks(ticks, callback)
    local id = self:_CreateRecord({
        Kind = "EveryTicks",
        Callback = callback,
        IntervalTicks = ticks,
        TickCount = 0,
    })
    return id, buildCancelFunction(id)
end

--- @param ms number
--- @param callback fun(timerID:integer):UNSUBSCRIBE_SYMBOL|nil
--- @return TimerID integer
--- @return function
function Timer:Every(ms, callback)
    local id = self:_CreateRecord({
        Kind = "Every",
        Callback = callback,
        IntervalMS = ms,
        LastRunTime = Ext.Utils.MonotonicTime(),
        TickCount = 0,
    })
    return id, buildCancelFunction(id)
end

---@param callback fun(timerID:integer)
---@return TimerID integer
---@return function cancelFunction
function Timer:Second(callback)
    return self:After(1000, callback)
end

---@param id integer?
function Timer:Cancel(id)
    self:_RemoveRecord(id)
end

function Timer:CancelAll()
    for id in pairs(self._active) do
        self._active[id] = nil
    end
end

local clientTimerId = 0
function Timer:ClientOnTicks(ticks, callback, user)
    if Ext.IsClient() then
        return self:Ticks(ticks, callback)
    end
    user = user or 1
    clientTimerId = clientTimerId + 1
    local timerID = clientTimerId
    self._serverClientCallbacks[timerID] = callback
    NetChannel.ClientTimer:SendToClient({ TimerID = timerID, Ticks = ticks }, user)
    return timerID
end

function Timer:ClientAfter(ms, callback, user)
    if Ext.IsClient() then
        return self:After(ms, callback)
    end
    user = user or 1
    clientTimerId = clientTimerId + 1
    local timerID = clientTimerId
    self._serverClientCallbacks[timerID] = callback
    NetChannel.ClientTimer:SendToClient({ TimerID = timerID, MS = ms }, user)
    return timerID
end

function Timer:ReceiveClientTimer(timerID)
    local callback = self._serverClientCallbacks[timerID]
    if callback then
        callback(timerID)
    else
        Warning("Timer:ReceiveClientTick - No callback found for timerID: " .. tostring(timerID))
    end
    self._serverClientCallbacks[timerID] = nil
end