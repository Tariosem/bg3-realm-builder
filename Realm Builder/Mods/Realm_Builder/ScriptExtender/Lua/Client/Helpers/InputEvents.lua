--- @class InputEvents
--- @field SubscribeKeyInput fun(key:EclLuaKeyInputEvent?, callback:fun(e:EclLuaKeyInputEvent):any):RBSubscription
--- @field SubscribeMouseInput fun(key:EclLuaMouseButtonEvent?, callback:fun(e:EclLuaMouseButtonEvent):any):RBSubscription
--- @field SubscribeMouseWheel fun(key:EclLuaMouseWheelEvent?, callback:fun(e:EclLuaMouseWheelEvent):any):RBSubscription
--- @field SubscribeKeyAndMouse fun(callback:fun(e:SimplifiedInputEvent):any, filterKey:Keybinding?):RBSubscription
InputEvents = InputEvents or {}

---@param key EclLuaKeyInputEvent?
---@param callback fun(e:EclLuaKeyInputEvent): any
---@return RBSubscription
function InputEvents.SubscribeKeyInput(key, callback)
    key = key or {}
    local SubscribeStartTime = Ext.Timer.MonotonicTime()
    local lastCallTime = 0
    local id = 0
    local unsubscribed = false
    local unsub = function()
        if id ~= -1 then
            unsubscribed = true
            Ext.Events.KeyInput:Unsubscribe(id)
            id = -1
        end
    end

    --- @param e EclLuaKeyInputEvent
    id = Ext.Events.KeyInput:Subscribe(function(e)
        if unsubscribed then
            return
        end

        if key.Key and e.Key ~= key.Key then return end
        if key.Pressed and e.Pressed ~= key.Pressed then return end
        if key.Event and e.Event ~= key.Event then return end
        if key.Modifiers and e.Modifiers ~= key.Modifiers then return end
        if key.Repeat and e.Repeat ~= key.Repeat then return end
        local elapsed = Ext.Timer.MonotonicTime() - SubscribeStartTime

        local returnValue = callback(e)

        if returnValue == UNSUBSCRIBE_SYMBOL then
            unsub()
        end
    end)

    local sub = { Unsubscribe = unsub, ID = id} --[[@as RBSubscription]]

    return sub
end

---@param key EclLuaMouseButtonEvent?
---@param callback fun(e:EclLuaMouseButtonEvent): any
---@return RBSubscription
function InputEvents.SubscribeMouseInput(key, callback)
    key = key or {}
    local SubscribeStartTime = Ext.Timer.MonotonicTime()
    local lastCallTime = 0
    local id = 0
    local unsubscribed = false
    local unsub = function()
        if id ~= -1 then
            unsubscribed = true
            Ext.Events.MouseButtonInput:Unsubscribe(id)
            id = -1
        end
    end

    --- @param e EclLuaMouseButtonEvent
    id = Ext.Events.MouseButtonInput:Subscribe(function(e)
        if unsubscribed then
            return
        end

        if key.Button and e.Button ~= key.Button then return end
        if key.Pressed and e.Pressed ~= key.Pressed then return end

        local elapsed = Ext.Timer.MonotonicTime() - SubscribeStartTime

        local returnValue = callback(e)

        if returnValue == UNSUBSCRIBE_SYMBOL then
            unsub()
        end
    end)

    return { Unsubscribe = unsub, ID = id}


end

---@param key EclLuaMouseWheelEvent?
---@param callback fun(e:EclLuaMouseWheelEvent): any
---@return RBSubscription
function InputEvents.SubscribeMouseWheel(key, callback)
    key = key or {}
    local SubscribeStartTime = Ext.Timer.MonotonicTime()
    local id = 0
    local unsubscribed = false
    local unsub = function()
        if id ~= -1 then
            unsubscribed = true
            Ext.Events.MouseWheelInput:Unsubscribe(id)
            id = -1
        end
    end

    --- @param e EclLuaMouseWheelEvent
    id = Ext.Events.MouseWheelInput:Subscribe(function(e)
        if unsubscribed then return end

        local elapsed = Ext.Timer.MonotonicTime() - SubscribeStartTime

        local returnValue = callback(e)

        if returnValue == UNSUBSCRIBE_SYMBOL then
            unsub()
        end
    end)

    return { Unsubscribe = unsub, ID = id}
end

--- @class SimplifiedInputEvent
--- @field Event "KeyDown"|"KeyUp"
--- @field Key  SimplifiedInputCode
--- @field Pressed boolean
--- @field Repeat boolean
--- @field Modifiers? SimplifiedModfier[]
--- @field Clicks? integer

local MouseToCode = {
    [1] = "LMB",
    [2] = "MMB",
    [3] = "RMB",
}

local Enums = Enums
local simplifiedModfierEnum = Enums.SimplifiedModfier
local function excludeModfiers(modifs)
    for i = #modifs, 1, -1 do
        local simplified = simplifiedModfierEnum[tostring(modifs[i]):upper()]
        if not simplifiedModfierEnum[simplified] then
            table.remove(modifs, i)
        else
            modifs[i] = simplified
        end
    end
end

--- @param callback fun(e: SimplifiedInputEvent): any
--- @param filterKey Keybinding?
--- @return RBSubscription
function InputEvents.SubscribeKeyAndMouse(callback, filterKey)
    local isCalling = false
    local subs = {}
    local lastModifiers = {}
    local filterIdentifier = nil
    if filterKey then
        filterIdentifier = Keybinding.new(filterKey.Key, filterKey.Modifiers or {}):CreateIdentifier()
    end

    local function checkKeyBinding(e)
        if not filterKey then
            return true
        end
        local eventIdentifier = Keybinding.new(e.Key, e.Modifiers or {}):CreateIdentifier()
        return eventIdentifier == filterIdentifier
    end

    local function unsub()
        for subEvent, sub in pairs(subs) do
            Ext.Events[subEvent]:Unsubscribe(sub)
        end
    end

    subs.KeyInput = Ext.Events.KeyInput:Subscribe(function(e)
        if isCalling then return end
        isCalling = true
        local modifs = RBUtils.LightCToArray(e.Modifiers)
        excludeModfiers(modifs)
        local event = {
            Event = e.Event,
            Key = tostring(e.Key):upper(),
            Pressed = e.Pressed,
            Modifiers = modifs,
            Repeat = e.Repeat,
        }
        if not checkKeyBinding(event) then
            isCalling = false
            return
        end
        lastModifiers = modifs

        local returnValue = callback(event)
        isCalling = false
        if returnValue == UNSUBSCRIBE_SYMBOL then
            unsub()
        end
    end)

    subs.MouseButtonInput = Ext.Events.MouseButtonInput:Subscribe(function(e)
        if isCalling then return end
        isCalling = true

        local event = {
            Event = e.Pressed and "KeyDown" or "KeyUp",
            Modifiers = lastModifiers,
            Key = MouseToCode[e.Button],
            Pressed = e.Pressed,
            Repeat = e.Clicks > 1,
        }
        if not checkKeyBinding(event) then
            isCalling = false
            return
        end
        local returnValue = callback(event)
        isCalling = false
        if returnValue == UNSUBSCRIBE_SYMBOL then
            unsub()
        end
    end)

    return { Unsubscribe = unsub }
end