EventsSubscriber = EventsSubscriber or {}

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
function EventsSubscriber.RegisterOnSessionLoaded(func, priority)
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
function EventsSubscriber.RegisterOnStatsLoaded(func, priority)
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
        local success, err = xpcall(entry.func, debug.traceback)
        if not success then
            Error("Error in StatsLoaded callback (priority " .. entry.priority .. "): " .. tostring(err))
        end
    end
end

local function OnSessionLoaded()
    _P("Realm Builder On Session Loaded")
    for _, entry in ipairs(onSessionLoadedFuncs) do
        local success, err = xpcall(entry.func, debug.traceback)
        if not success then
            Error("Error in SessionLoaded callback (priority " .. entry.priority .. "): " .. tostring(err))
        end
    end
end

local clientCommands = {}
local serverCommands = {}
local commonCommands = {}

local CommandChannel = Ext.Net.CreateChannel(ModuleUUID, "SyncCommands") --[[@as NetChannel]]

CommandChannel:SetHandler(function(data, user)
    if data.Request then
        CommandChannel:SendToClient({
            Commands = serverCommands,
        }, user)
        return
    end
    local commands = data.Commands
    if Ext.IsServer() then
        clientCommands = commands
    else
        serverCommands = commands
    end
    for cmd,_ in pairs(commands) do
        if clientCommands[cmd] and serverCommands[cmd] then
            commonCommands[cmd] = clientCommands[cmd]
            clientCommands[cmd] = nil
            serverCommands[cmd] = nil
        end
    end
end)

--- @param command string
--- @param func fun(command:string, ...:string)
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
        func(command, args)
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
        CommandChannel:SendToServer({
            Request = true,
        })
    end
end)

Ext.RegisterConsoleCommand("rb_help", function(cmd, args)
    if args and (clientCommands[args] or serverCommands[args] or commonCommands[args]) then
        local cmdData = clientCommands[args] or serverCommands[args] or commonCommands[args]
        print(string.format("Command:\n %s", args))
        print(string.format("Description:\n %s", cmdData.description or "No description provided."))
        return
    end

    RBPrintPurple("Realm Builder Console Commands:")

    RBPrintPurple("\n------- Common Context -------")
    local index = 1
    for command, cmdData in RBUtils.SortedPairs(commonCommands) do
        RBPrintPurple(string.format("%d. %s", index, command))
        index = index + 1
    end

    RBPrintGreen("\n------- Server Context -------")
    index = 1
    for command, cmdData in RBUtils.SortedPairs(serverCommands) do
        RBPrintGreen(string.format("%d. %s", index, command))
        index = index + 1
    end

    RBPrintBlue("\n------- Client Context -------")
    index = 1
    for command, cmdData in RBUtils.SortedPairs(clientCommands) do
        RBPrintBlue(string.format("%d. %s", index, command))
        index = index + 1
    end

    print("\nUse 'rb_help <command>' to get more information about a specific command.")
end)

Ext.Events.SessionLoaded:Subscribe(OnSessionLoaded)
Ext.Events.StatsLoaded:Subscribe(OnStatsLoaded)