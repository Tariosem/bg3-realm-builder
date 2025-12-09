--- @class KeybindManager
--- @field Keybinds table<KeybindingIdentifier, {Module:string, Name:string}>
--- @field Reverse table<string, table<string, Keybinding>> module -> eventName -> Keybinding
--- @field Listeners table<string, any> module -> Subscription
--- @field Events table<string, table<string, KeybindRegistry>> module -> eventName -> KeybindRegistry
--- @field Modules table<string, KeybindModule>
--- @field Disabled boolean
KeybindManager = {
    Keybinds = {},
    Reverse = {},
    Listeners = {},
    Events = {},
    Modules = {},
    Disabled = false,
}

local DEFAULT_KEYBINDS = Ext.Require("Client/Keybind/DefaultKeybinds.lua")

function KeybindManager:Enable(module)
    self:Disable(module)
    self.Listeners[module] = SubscribeKeyAndMouse(function(e)
        self:HandleInput(module, e)
    end)
end

function KeybindManager:Disable(module)
    if module then
        if self.Listeners[module] then
            self.Listeners[module]:Unsubscribe()
            self.Listeners[module] = nil
        end
    else
        for m, listener in pairs(self.Listeners) do
            listener:Unsubscribe()
            self.Listeners[m] = nil
        end
    end
end

function KeybindManager:GetEvents(module)
    return self.Events[module] or {}
end

function KeybindManager:GetEvent(module, eventName)
    if self.Events[module] and self.Events[module][eventName] then
        return self.Events[module][eventName]
    end
    return nil
end

function KeybindManager:GetEventByKey(key, modifiers)
    local identifier = Keybinding.new(key, modifiers or {}):CreateIdentifier()
    local module = self.Keybinds[identifier] and self.Keybinds[identifier].Module
    local name = self.Keybinds[identifier] and self.Keybinds[identifier].Name
    if self.Keybinds[identifier] and self.Keybinds[identifier].Module == module and self.Keybinds[identifier].Name == name then
        return self.Events[module] and self.Events[module][name]
    end

    return nil
end

function KeybindManager:GetKeyByEvent(module, eventName)
    if self.Reverse[module] and self.Reverse[module][eventName] then
        return self.Reverse[module][eventName]
    end
    return nil
end

function KeybindManager:GetKeybinding(key, modifiers)
    local searchKeybinding = Keybinding.new(key, modifiers or {})
    local identifier = searchKeybinding:CreateIdentifier()

    return self.Keybinds[identifier] and searchKeybinding or nil
end

function KeybindManager:HandleInput(module, e)
    if self.Disabled or self.rebinding then return end
    if not self.Events[module] then return end
    if not self.Modules[module] then return end

    for _, cond in ipairs(self.Modules[module].Conditions) do
        if not cond(e) then return end
    end

    local inputKeybinding = Keybinding.new(e.Key, e.Modifiers or {})
    local identifier = inputKeybinding:CreateIdentifier()
    local binding = self.Keybinds[identifier]

    if not binding or binding.Module ~= module then return end

    self:TriggerEvent(binding.Module, binding.Name, e)
end

function KeybindManager:Bind(module, eventName, key, modifiers)
    if not key or key == "" then
        --Warning("Invalid key")
        return false
    end
    modifiers = modifiers or {}

    key = tostring(key):upper()
    for i = #modifiers, 1, -1 do
        local mod = modifiers[i]
        if not Enums.ModfierToPresentation[mod] then
            Warning("Invalid modifier: " .. tostring(mod))
            table.remove(modifiers, i)
        end
    end

    if not Enums.InputCodeToPresentation[key] then
        --Warning("Invalid key code: " .. tostring(key))
        return false
    end

    if not self.Events[module] or not self.Events[module][eventName] then
        --Warning("Event not registered: " .. module .. ":" .. eventName)
        self:RegisterEvent(module, eventName)
    end

    if self:IsKeyBound(key, modifiers) then
        --Warning("Keybinding already in use: " .. key .. " + " .. table.concat(modifiers or {}, "|"))
        return false
    end

    local newKeybinding = Keybinding.new(key, modifiers or {})
    local identifier = newKeybinding:CreateIdentifier()
    self.Keybinds[identifier] = { Module = module, Name = eventName }

    self.Reverse[module] = self.Reverse[module] or {}
    self.Reverse[module][eventName] = newKeybinding
    return true
end

function KeybindManager:Unbind(module, eventName)
    if self.Reverse[module] then
        local keybinding = self.Reverse[module][eventName]
        if keybinding then
            local identifier = keybinding:CreateIdentifier()
            self.Keybinds[identifier] = nil
            self.Reverse[module][eventName] = nil
        end
    end
end

--- @return table<string, {Identifier:string, EventName:string}[]>
function KeybindManager:GetAllBindings()
    local bindings = {}
    for identifier, binding in pairs(self.Keybinds) do
        bindings[binding.Module] = bindings[binding.Module] or {}
        table.insert(bindings[binding.Module], {
            Identifier = identifier,
            EventName = binding.Name
        })
    end
    return bindings
end

function KeybindManager:IsKeyBound(key, modifiers)
    local keybinding = Keybinding.new(key, modifiers or {})
    local identifier = keybinding:CreateIdentifier()
    return self.Keybinds[identifier] ~= nil
end

--- @class KeybindRegistry
--- @field Callback fun(e:SimplifiedInputEvent)
--- @field Conditions (fun(e:SimplifiedInputEvent):boolean)[]
--- @field Modifiers SDLKeyModifier|nil
--- @field AddCondition fun(self:KeybindRegistry, condition:fun(e:SimplifiedInputEvent):boolean)
--- @field SetCallback fun(self:KeybindRegistry, callback:fun(e:SimplifiedInputEvent))
--- @field AddDescription fun(self:KeybindRegistry, desc:string)
--- @field Disabled boolean

KeybindRegistry = _Class("KeybindRegistry")

function KeybindRegistry:__init(callback)
    self.Callback = callback or function() end
    self.Conditions = {}
    self.Modifiers = nil
    self.Description = nil
end

function KeybindRegistry:AddCondition(condition)
    table.insert(self.Conditions, condition)
end

function KeybindRegistry:SetCallback(callback)
    self.Callback = callback
end

function KeybindRegistry:AddDescription(desc)
    self.Description = desc
end

---@param module string
---@param eventName string
---@param callback fun(e:SimplifiedInputEvent)?
---@return KeybindRegistry
function KeybindManager:RegisterEvent(module, eventName, callback, desc)
    if not self.Events[module] then
        --Warning("Registering event for non-existent module: " .. module)
        self:CreateModule(module)
    end

    if not self.Events[module][eventName] then
        self.Events[module][eventName] = KeybindRegistry.new(callback)
    else
        if callback then
            self.Events[module][eventName].Callback = callback
        end
    end

    if desc then
        self.Events[module][eventName].Description = desc
    end

    return self.Events[module][eventName]
end

function KeybindManager:Unregister(module, eventName)
    if self.Events[module] then
        self.Events[module][eventName] = nil
    end
    if self.Reverse[module] and self.Reverse[module][eventName] then
        local keybinding = self.Reverse[module][eventName]
        self.Keybinds[keybinding:CreateIdentifier()] = nil
    end
end

function KeybindManager:Rebind(module, eventName, newKey, newModifiers)
    self:Unbind(module, eventName)
    return self:Bind(module, eventName, newKey, newModifiers)
end

function KeybindManager:RebindByInput(module, eventName, callback)
    self.rebinding = true
    SubscribeKeyAndMouse(function(e)
        if e.Event == "KeyUp" then
            self.rebinding = false
            if self:GetKeyByEvent(module, eventName) then
                local keybinding = self:GetKeyByEvent(module, eventName)
                if keybinding == Keybinding.new(e.Key, e.Modifiers or {}) then
                    callback(keybinding)
                    return UNSUBSCRIBE_SYMBOL
                end
            end

            if self:GetEventByKey(e.Key, e.Modifiers) then
                local identifier = Keybinding.new(e.Key, e.Modifiers or {}):CreateIdentifier()
                if callback then callback(nil, self.Keybinds[identifier].Module, self.Keybinds[identifier].Name) end
                return UNSUBSCRIBE_SYMBOL
            end
            if not self:Rebind(module, eventName, e.Key, e.Modifiers) then
                if callback then callback(nil, nil, nil) end
                return UNSUBSCRIBE_SYMBOL
            end
            local newKeybinding = Keybinding.new(e.Key, e.Modifiers or {})
            if callback then callback(newKeybinding) end
            return UNSUBSCRIBE_SYMBOL
        end
    end)
end

function KeybindManager:On(module, eventName, callback)
    self:RegisterEvent(module, eventName, callback)
end

function KeybindManager:AddCondition(module, eventName, condition)
    self:RegisterEvent(module, eventName)
    table.insert(self.Events[module][eventName].Conditions, condition)
end

function KeybindManager:AddModuleCondition(module, condition)
    local mod = self:CreateModule(module)
    table.insert(mod.Conditions, condition)
end

function KeybindManager:TriggerEvent(module, eventName, e)
    local event = self.Events[module] and self.Events[module][eventName]
    if not event or not event.Callback then return end
    if event.Disabled then return end
    for _, cond in ipairs(event.Conditions) do
        if not cond(e) then return end
    end
    return event.Callback(e)
end

function KeybindManager:Save()
    local data = {}
    for identifier, binding in pairs(self.Keybinds) do
        local module = binding.Module
        local eventName = binding.Name

        data[module] = data[module] or {}

        local parts = string.split(identifier, "|")
        local key = parts[1]
        local modifiers = {}
        for i = 2, #parts do
            table.insert(modifiers, parts[i])
        end

        table.sort(modifiers)
        data[module][eventName] = {
            Key = key,
            Modifiers = #modifiers > 0 and modifiers or nil,
        }
    end
    return data
end

function KeybindManager:Load(data)
    for module, events in pairs(data) do
        for eventName, keyInfo in pairs(events) do
            if keyInfo.Modifiers then
                table.sort(keyInfo.Modifiers)
            end
            self:ForceBindTo(module, eventName, keyInfo.Key, keyInfo.Modifiers)
        end
    end
end

function KeybindManager:ForceBindTo(module, eventName, key, modifiers)
    self:Unbind(module, eventName)
    self:Bind(module, eventName, key, modifiers)
end

function KeybindManager:SaveToFile()
    local path = RealmPath.GetKeybindPath()
    local data = self:Save()
    Ext.IO.SaveFile(path, Ext.Json.Stringify(data))
end

function KeybindManager:LoadFromFile()
    local path = RealmPath.GetKeybindPath()
    local content = Ext.IO.LoadFile(path)
    if not content then return end
    local data = Ext.Json.Parse(content)
    if data then
        self:Load(data)
    end
end

--- @class KeybindModule
--- @field Name string
--- @field Conditions (fun(e:SimplifiedInputEvent):boolean)[]
--- @field Enable fun(self:KeybindModule)
--- @field Disable fun(self:KeybindModule)
--- @field RegisterEvent fun(self:KeybindModule, eventName:string, callback:fun(e:SimplifiedInputEvent)?, desc:string?):KeybindRegistry
--- @field Unregister fun(self:KeybindModule, eventName:string)
--- @field Bind fun(self:KeybindModule, eventName:string, key:SDLScanCode, modifiers:SDLKeyModifier?)
--- @field Unbind fun(self:KeybindModule, eventName:string)
--- @field Rebind fun(self:KeybindModule, eventName:string, newKey:SimplifiedInputCode, newModifiers:SDLKeyModifier[]?)
--- @field RebindByInput fun(self:KeybindModule, eventName:string, callback:fun(e:Keybinding, conflictModule:string?, conflictEvent:string?)?)
--- @field GetEvents fun(self:KeybindModule):table<string, KeybindRegistry>
--- @field GetEvent fun(self:KeybindModule, eventName:string):KeybindRegistry|nil
--- @field GetKeyByEvent fun(self:KeybindModule, eventName:string):Keybinding
--- @field GetEventByKey fun(self:KeybindModule, key:SDLScanCode, modfiers:SDLKeyModifier[]):KeybindRegistry|nil
--- @field On fun(self:KeybindModule, eventName:string, callback:fun(e:SimplifiedInputEvent))
--- @field AddCondition fun(self:KeybindModule, eventName:string, condition:fun(e:SimplifiedInputEvent):boolean)
--- @field AddModuleCondition fun(self:KeybindModule, condition:fun(e:SimplifiedInputEvent):boolean)
--- @field TriggerEvent fun(self:KeybindModule, eventName:string, e:SimplifiedInputEvent)
--- @field new fun(name:string):KeybindModule
local KeybindModule = _Class("KeybindModule")

function KeybindModule:__init(name)
    self.Name = name
    self.Conditions = {}

    setmetatable(self, {
        __index = function(t, k)
            local localValue = rawget(t, k)
            if localValue then return localValue end

            if KeybindManager[k] then
                return function(_, ...)
                    return KeybindManager[k](KeybindManager, t.Name, ...)
                end
            end

            return nil
        end
    })
end

--- @param moduleName string
--- @return KeybindModule
function KeybindManager:CreateModule(moduleName)
    if self.Modules[moduleName] then
        return self.Modules[moduleName]
    end

    local module = KeybindModule.new(moduleName)

    self.Modules[moduleName] = module
    self.Reverse[moduleName] = {}
    self.Events[moduleName] = {}
    self:Enable(moduleName)
    return module
end

RegisterOnSessionLoaded(function()
    KeybindManager:Load(DEFAULT_KEYBINDS)
    KeybindManager:LoadFromFile()
end)

RegisterConsoleCommand("rb_dump_keybinds", function()
    local bindings = KeybindManager:GetAllBindings()
    local count = #bindings
    local longest = -1 -- for formatting
    local toPrint = {}
    for moduleName, moduleBindings in pairs(bindings) do
        toPrint[moduleName] = {}
        for _, bindingInfo in pairs(moduleBindings) do
            local eventName = bindingInfo.EventName
            local identifier = bindingInfo.Identifier
            toPrint[moduleName][eventName] = identifier
            count = count + 1
            if #eventName > longest then
                longest = #eventName
            end
        end
    end
    local lastHue = 0
    local function runHue()
        lastHue = (lastHue + 53) % 360
        local r, g, b = HSLToRGB(lastHue / 360, 1, 0.5)
        return { r, g, b }
    end

    local separator = string.rep("=", longest + 7)
    for module, events in pairs(toPrint) do
        local strings = {}
        table.insert(strings, "Module: " .. module)
        table.insert(strings, separator)
        for eventName, identifier in SortedPairs(events) do
            local padding = string.rep(" ", longest - #eventName)
            table.insert(strings, "  " .. eventName .. padding .. " : " .. identifier)
        end
        table.insert(strings, separator)
        local finalStr = "\n" .. table.concat(strings, "\n") .. "\n"
        local fromColor = runHue()
        local toColor = runHue()
        GradientPrint(finalStr, fromColor, toColor, "hsv")
    end
    print("Total keybindings: " .. tostring(count))
end, "Dumps all current keybindings to the console.")

RegisterConsoleCommand("rb_inspect_keybind_subscriptions", function()
    for moduleName, events in pairs(KeybindManager.Events) do
        print("Module: " .. moduleName)
        if KeybindManager.Listeners[moduleName] then
            local moduleObj = KeybindManager.Modules[moduleName]
            local meetConditions = true
            for _, cond in ipairs(moduleObj.Conditions) do
                if not cond({}) then
                    print("  Module listener active, but condition is blocking input.")
                    meetConditions = false
                    break
                end
            end
            if meetConditions then
                print("  Module listener active.")
            end
        else
            print("  Module listener inactive.")
        end
        print("\n")
    end
end, "Inspects all registered keybind event descriptions.")
