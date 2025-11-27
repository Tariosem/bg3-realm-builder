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

local clientCommands = {}
local serverCommands = {}

local CommandChannel = Ext.Net.CreateChannel(ModuleUUID, "SyncCommands") --[[@as NetChannel]]

CommandChannel:SetHandler(function(data, user)
    local commands = data.Commands
    if Ext.IsServer() then
        clientCommands = commands
    else
        serverCommands = commands
    end
end)

--- @param command string
--- @param func fun(...:string)
function RegisterConsoleCommand(command, func, description)
    if Ext.IsServer() then
        serverCommands[command] = {
            description = description or "No description provided.",
        }
    else
        clientCommands[command] = {
            description = description or "No description provided.",
        }
    end
    Ext.RegisterConsoleCommand(command, function(cmd, args)
        args = SplitBySpace(args)
        func(command, table.unpack(args))
    end)
end

Ext.Events.SessionLoaded:Subscribe(function (e)
    if Ext.IsServer() then
        CommandChannel:Broadcast({
            Commands = serverCommands,
        })
    else
        CommandChannel:SendToServer({
            Commands = clientCommands,
        })
    end
end)

Ext.RegisterConsoleCommand("rb_help", function(args)
    if args and (clientCommands[args] or serverCommands[args]) then
        local cmdData = clientCommands[args] or serverCommands[args]
        print(string.format("Command: %s", args))
        print(string.format("Description: %s", cmdData.description or "No description provided."))
        return
    end

    print("Realm Builder Console Commands:\n")
    print("------- Server Context -------")
    local index = 1
    for command, cmdData in pairs(serverCommands) do
        print(string.format("%d. %s", index, command))
        index = index + 1
    end
    print("\n------- Client Context -------")
    index = 1
    for command, cmdData in pairs(clientCommands) do
        print(string.format("%d. %s", index, command))
        index = index + 1
    end

    print("\nUse 'rb_help <command>' to get more information about a specific command.")
end)

Ext.Events.SessionLoaded:Subscribe(OnSessionLoaded)
Ext.Events.StatsLoaded:Subscribe(OnStatsLoaded)