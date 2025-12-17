---@alias TimerID integer
---@class Timer
Timer = {
    _active = {},
    _serverClientCallbacks = {}
}

---@param ms integer
---@param callback fun(timerID:integer)
---@return TimerID integer
---@return function cancelFunction
function Timer:After(ms, callback)
    local startTime = Ext.Utils.MonotonicTime()
    local id
    id = Ext.Events.Tick:Subscribe(function()
        if Ext.Utils.MonotonicTime() - startTime >= ms then
            if Timer._active[id] then
                Timer:Cancel(id)
                callback(id)
            end
        end
    end)
    Timer._active[id] = true
    local cancelFunction = function()
        Timer:Cancel(id)
    end
    return id, cancelFunction
end

---@param ticks integer
---@param callback fun(timerID:integer)
function Timer:Ticks(ticks, callback)
    local count = 0
    local id
    id = Ext.Events.Tick:Subscribe(function()
        count = count + 1
        if count >= ticks then
            if Timer._active[id] then
                Timer:Cancel(id)
                callback(id)
            end
        end
    end)
    Timer._active[id] = true
    return id
end

---@param ms integer
---@param ticks integer
---@param callback fun(timerID:integer)
function Timer:AfterOrTicks(ms, ticks, callback)
    local start = Ext.Utils.MonotonicTime()
    local count = 0
    local id
    id = Ext.Events.Tick:Subscribe(function()
        count = count + 1
        if Ext.Utils.MonotonicTime() - start >= ms or count >= ticks then
            if Timer._active[id] then
                Timer:Cancel(id)
                callback(id)
            end
        end
    end)
    Timer._active[id] = true
    return id
end

---@param callback fun(timerID:integer):UNSUBSCRIBE_SYMBOL|nil
---@return TimerID integer
---@return function cancelFunction
function Timer:EveryFrame(callback)
    local id
    id = Ext.Events.Tick:Subscribe(function()
        if Timer._active[id] then
            local result = callback(id)

            if result == UNSUBSCRIBE_SYMBOL then
                Timer:Cancel(id)
                return
            end

            --[[local ok, err = pcall(callback)
            if not ok then
                Ext.Utils.PrintError("Timer:EveryFrame callback error: " .. tostring(err))
                Timer:Cancel(id)
            end]]
        end
    end)
    Timer._active[id] = true
    local cancelFunction = function()
        Timer:Cancel(id)
    end
    return id, cancelFunction
end

function Timer:EveryTicks(ticks, callback)
    local count = 0
    local id
    id = Ext.Events.Tick:Subscribe(function()
        count = count + 1
        if count >= ticks then
            count = 0
            if Timer._active[id] then
                local result = callback(id)

                if result == UNSUBSCRIBE_SYMBOL then
                    Timer:Cancel(id)
                    return
                end

                --[[local ok, err = pcall(callback)
                if not ok then
                    Ext.Utils.PrintError("Timer:EveryTicks callback error: " .. tostring(err))
                    Timer:Cancel(id)
                end]]
            end
        end
    end)
    Timer._active[id] = true
    local cancelFunction = function()
        Timer:Cancel(id)
    end
    return id, cancelFunction
end

--- @param ms number
--- @param callback fun(timerID:integer):UNSUBSCRIBE_SYMBOL|nil
--- @return TimerID integer
--- @return function
function Timer:Every(ms, callback)
    local lastTime = Ext.Utils.MonotonicTime()
    local id
    id = Ext.Events.Tick:Subscribe(function()
        local now = Ext.Utils.MonotonicTime()
        if now - lastTime >= ms then
            lastTime = now
            local result = callback(id)

            if result == UNSUBSCRIBE_SYMBOL then
                Timer:Cancel(id)
                return
            end
            
            --[[local ok, err = pcall(callback)
            if not ok then
                Ext.Utils.PrintError("Timer:Every callback error: " .. tostring(err))
                Timer:Cancel(id)
            end]]
        end
    end)
    Timer._active[id] = true
    local cancelFunction = function()
        Timer:Cancel(id)
    end
    return id, cancelFunction
end

---@param id integer?
function Timer:Cancel(id)
    if not id then return end
    if id and Timer._active[id] then
        Ext.Events.Tick:Unsubscribe(id)
    end
    if Timer._active[id] then
        Timer._active[id] = nil
    end
end

function Timer:CancelAll()
    for id, _ in pairs(Timer._active) do
        Ext.Events.Tick:Unsubscribe(id)
    end
    Timer._active = {}
end

local clientTimerId = 0
function Timer:ClientOnTicks(ticks, callback, user)
    if Ext.IsClient() then
        return self:Ticks(ticks, callback)
    end
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