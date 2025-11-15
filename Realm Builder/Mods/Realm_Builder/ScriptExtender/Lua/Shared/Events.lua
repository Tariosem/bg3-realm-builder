local onSessionLoadedFuncs = {}
local onStatsLoadedFuncs = {}

--- @class UNSUBSCRIBE_SYMBOL
UNSUBSCRIBE_SYMBOL = {}

--- @class RBSubscription
--- @field Unsubscribe function
--- @field ID integer

--- priority: lower number = higher priority
--- @param func function
--- @param priority number|nil
function RegisterOnSessionLoaded(func, priority)
    priority = priority or 0
    table.insert(onSessionLoadedFuncs, {
        func = func,
        priority = priority
    })

    table.sort(onSessionLoadedFuncs, function(a, b)
        return a.priority < b.priority
    end)
end

--- @param func function
--- @param priority number|nil
function RegisterOnStatsLoaded(func, priority)
    priority = priority or 0
    table.insert(onStatsLoadedFuncs, {
        func = func,
        priority = priority
    })

    table.sort(onStatsLoadedFuncs, function(a, b)
        return a.priority < b.priority
    end)
end

local function OnStatsLoaded()
    for _, entry in ipairs(onStatsLoadedFuncs) do
        if entry.func == nil or type(entry.func) ~= "function" then return end
        entry.func()
        --[[local success, err = pcall(entry.func)
        if not success then
            Error("Error in StatsLoaded callback (priority " .. entry.priority .. "): " .. tostring(err))
        end]]
    end
end

local function OnSessionLoaded()
    Debug("Realm Builder On Session Loaded")
    for _, entry in ipairs(onSessionLoadedFuncs) do
        if entry.func == nil or type(entry.func) ~= "function" then return end
        entry.func()
        --[[local success, err = pcall(entry.func)
        if not success then
            Error("Error in SessionLoaded callback (priority " .. entry.priority .. "): " .. tostring(err))
        end]]
    end
end

local allCommands = {}

--- @param command string
--- @param func fun(...:string)
function RegisterConsoleCommand(command, func, description)
    allCommands[command] = { 
        func = func,
        description = description or "No description provided."
    }
    Ext.RegisterConsoleCommand(command, function(cmd, args)
        args = SplitBySpace(args)
        func(command, table.unpack(args))
    end)
end

Ext.RegisterConsoleCommand("rb_help", function(args)
    print("Realm Builder Console Commands:")
    local info = allCommands[args]
    if info then
        print(args .. ": " .. info.description)
    else
        for cmd,_ in pairs(allCommands) do
            print(" - " .. cmd)
        end
        print(" Type 'rb_help <Command> for more info.")
    end
end)

Ext.Events.SessionLoaded:Subscribe(OnSessionLoaded)
Ext.Events.StatsLoaded:Subscribe(OnStatsLoaded)