---@param key EclLuaKeyInputEvent?
---@param callback fun(e:EclLuaKeyInputEvent): any
---@return LOPSubscription
function SubscribeKeyInput(key, callback)
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

    return { Unsubscribe = unsub, ID = id}
end

---@param key EclLuaMouseButtonEvent?
---@param callback fun(e:EclLuaMouseButtonEvent): any
function SubscribeMouseInput(key, callback)
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
---@return LOPSubscription
function SubscribeMouseWheel(key, callback)
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
--- @field Key  SDLScanCode|"1"|"2"|"3"
--- @field Pressed boolean
--- @field Repeat boolean
--- @field Modifiers? SDLKeyModifier
--- @field Clicks? integer

local toExclude = {
    Caps = true,
}

local function excludeModfiers(modifs)
    for i = #modifs, 1, -1 do
        if toExclude[modifs[i]] then
            table.remove(modifs, i)
        end
    end
end

--- @param callback fun(e: SimplifiedInputEvent): any
--- @return LOPSubscription
function SubscribeKeyAndMouse(callback)
    local isCalling = false
    local subs = {}
    subs.Key = SubscribeKeyInput({}, function(e)
        if isCalling then return end
        isCalling = true
        local modifs = LightCToArray(e.Modifiers)
        excludeModfiers(modifs)
        local event = {
            Event = e.Event,
            Key = tostring(e.Key),
            Pressed = e.Pressed,
            Modifiers = modifs,
            Repeat = e.Repeat,
        }
        local returnValue = callback(event)
        isCalling = false
        if returnValue == UNSUBSCRIBE_SYMBOL then
            subs.Key.Unsubscribe()
            subs.Mouse.Unsubscribe()
        end
    end)

    subs.Mouse = SubscribeMouseInput({}, function(e)
        if isCalling then return end
        isCalling = true

        local event = {
            Event = e.Pressed and "KeyDown" or "KeyUp",
            Key = tostring(e.Button),
            Pressed = e.Pressed,
            Repeat = e.Clicks > 1,
        }
        local returnValue = callback(event)
        isCalling = false
        if returnValue == UNSUBSCRIBE_SYMBOL then
            subs.Key.Unsubscribe()
            subs.Mouse.Unsubscribe()
        end
    end)

    local function unsub()
        if subs.Key then
            subs.Key.Unsubscribe()
            subs.Key = nil
        end
        if subs.Mouse then
            subs.Mouse.Unsubscribe()
            subs.Mouse = nil
        end
    end

    return { Unsubscribe = unsub }
end

---@param input ExtuiInputText
---@param callback fun(input:string)
---@return LOPSubscription sub
function SetupInputEnterCallback(input, callback)
    local sub = nil

    sub = SubscribeKeyInput({}, function (e)
        local ok, focused = pcall(IsFocused, input)
        if not ok then
            Warning("[SetupInputEnterCallback] Failed to check focus state of input, unsubscribing key input listener.")
            return UNSUBSCRIBE_SYMBOL
        end

        local inputText = input.Text
        if not inputText or inputText == "" then
            return
        end

        if e.Key == "RETURN" and focused then
            callback(inputText)
            return UNSUBSCRIBE_SYMBOL
        end
    end)

    return sub
end