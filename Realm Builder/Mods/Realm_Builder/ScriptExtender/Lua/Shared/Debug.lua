RB_DEBUG_LEVEL = 4

RB_ENABLE_LOGGER = false

--- @alias RB_DEBUG_LEVELS "Critical"|"Error"|"Warning"|"Info"|"Debug"|"Trace"

RB_DEBUG_LEVELS = {
    Critical = 0,
    Error = 1,
    Warning = 2,
    Info = 3,
    Debug = 4,
    Trace = 5,
    [1] = "Critical",
    [2] = "Error",
    [3] = "Warning",
    [4] = "Info",
    [5] = "Debug",
    [6] = "Trace",
}

local debugLevels = {
    "Critical",
    "Error",
    "Warning",
    "Info",
    "Debug",
    "Trace"
}

DEBUG_COLOR = {
    Title = "#BAA9FF",
    S = "#B2FF6F",
    C = "#6395FF",
    Critical = "#FF0000",
    Error = "#DC143C",
    Warning = "#FFBF00",
    Info = "#00BFFF",
    Debug = "#00A6FF",
    Trace = "#00FFC3",
}

local function rgbToANSI(rgb)
    local r = math.floor(rgb[1] * 255 + 0.5)
    local g = math.floor(rgb[2] * 255 + 0.5)
    local b = math.floor(rgb[3] * 255 + 0.5)

    r = math.max(0, math.min(255, r))
    g = math.max(0, math.min(255, g))
    b = math.max(0, math.min(255, b))

    return string.format("\x1b[38;2;%d;%d;%dm", r, g, b)
end

--- @param radiantResult RadiantResult
--- @return string ANSI colored text
function RadiantToANSI(radiantResult)
    if not radiantResult or not radiantResult.Segments then
        return ""
    end

    local result = {}
    local resetCode = "\x1b[0m"

    for _, segment in ipairs(radiantResult.Segments) do
        if segment.Text == "" then
            -- Skip empty segments
        elseif segment.Text:match("^%s+$") and radiantResult.Options.SkipWhitespace then
            table.insert(result, segment.Text)
        else
            local ansi = rgbToANSI(segment.Color)
            table.insert(result, ansi .. segment.Text .. resetCode)
        end
    end

    return table.concat(result)
end

local function RB_Print(prefix, level, message)
    local lvl = RB_DEBUG_LEVELS[level]
    if lvl == nil then
        _P("[Realm Builder] [" .. prefix .. "] Invalid log level: " .. tostring(level))
        return
    end
    if lvl > RB_DEBUG_LEVEL then
        return
    end
    local title = "[Realm Builder]"
    level = "[" .. level .. "]"
    prefix = "[" .. prefix .. "]"
    --[[title = palette(title, debugColor.Title)
    prefix = palette(prefix, debugColor[prefix])
    level = palette(level, debugColor[level])
    message = palette(message, debugColor[level])]]
    local logMessage = table.concat({ title, prefix, level, message }, " ")

    if RB_ENABLE_LOGGER then
        Logger.Log(logMessage)
    end

    if lvl == RB_DEBUG_LEVELS.Critical then
        RPrintCritical(logMessage)
    elseif lvl == RB_DEBUG_LEVELS.Error then
        RPrintRed(logMessage)
    elseif lvl == RB_DEBUG_LEVELS.Warning then
        RPrintYellow(logMessage)
    elseif lvl == RB_DEBUG_LEVELS.Info then
        RPrintCyan(logMessage)
    elseif lvl == RB_DEBUG_LEVELS.Debug then
        RPrintPurple(logMessage)
    elseif lvl == RB_DEBUG_LEVELS.Trace then
        RPrintMartix(logMessage)
    end
end

local function SPrint(level, message)
    RB_Print("S", level, message)
end

local function CPrint(level, message)
    RB_Print("C", level, message)
end

local function parse(...)
    local args = { ... }
    local parsedStr = ""
    for i, v in ipairs(args) do
        if i > 1 then
            parsedStr = parsedStr .. " "
        end
        if type(v) == "table" or Ext.Types.GetObjectType(v) == "userdata" or Ext.Types.GetObjectType(v) == "lightuserdata" then
            parsedStr = parsedStr .. "\n" .. Ext.Json.Stringify(v, { Beautify = true })
        else
            parsedStr = parsedStr .. tostring(v)
        end
    end
    return parsedStr
end

function Critical(...)
    local message = parse(...)
    if Ext.IsServer() then
        SPrint("Critical", message)
    else
        CPrint("Critical", message)
    end
end

function Error(...)
    local message = parse(...)
    if Ext.IsServer() then
        SPrint("Error", message)
    else
        CPrint("Error", message)
    end
end

function Warning(...)
    local message = parse(...)
    if Ext.IsServer() then
        SPrint("Warning", message)
    else
        CPrint("Warning", message)
    end
end

function Info(...)
    local message = parse(...)
    if Ext.IsServer() then
        SPrint("Info", message)
    else
        CPrint("Info", message)
    end
end

function Debug(...)
    local message = parse(...)
    if Ext.IsServer() then
        SPrint("Debug", message)
    else
        CPrint("Debug", message)
    end
end

function Trace(...)
    local message = parse(...)
    if Ext.IsServer() then
        SPrint("Trace", message)
    else
        CPrint("Trace", message)
    end
end

--- Shortcut
--- @param text string
--- @param startColor string|table
--- @param endColor string|table?
--- @param mode "rgb"|"hsv"|"perceptual"|"sine"|"rainbow"
--- @param options RadianceOpts?
function RPrint(text, startColor, endColor, mode, options)
    _P(RadiantToANSI(RadiantText(text, startColor, endColor, mode, options)))
end

--- @type table<RB_DEBUG_LEVELS, fun(text:string, opts:RadianceOpts?):RB_TextToken[]>
DebugRadiant = {
    Error = function(text, opts)
        return RadiantText(text, "#FF4500", "#FFB3A7", "perceptual", opts).Segments
    end,
    Warning = function(text, opts)
        return RadiantText(text, "#FFD700", "#FFFFDC", "perceptual", opts).Segments
    end,
    Info = function(text, opts)
        return RadiantText(text, "#00BFFF", "#DCFFFF", "perceptual", opts).Segments
    end,
    Debug = function(text, opts)
        return RadiantText(text, "#6254FD", "#D6B4FF", "perceptual", opts).Segments
    end,
    Trace = function(text, opts)
        return RadiantText(text, "#003300", "#007700", "perceptual", opts).Segments
    end,
}

function RPrintPurple(text, opts)
    RPrint(text, "#6254FD", "#D6B4FF", "perceptual", opts)
end

function RPrintYellow(text, opts)
    RPrint(text, "#FFD700", "#FFFFDC", "perceptual", opts)
end

function RPrintCyan(text, opts)
    RPrint(text, "#00FFFF", "#DCFFFF", "perceptual", opts)
end

function RPrintRed(text, opts)
    RPrint(text, "#FF4500", "#FFB3A7", "perceptual", opts)
end

function RPrintCritical(text, opts)
    RPrint(text, "#FF0000", "#FF7F7F", "perceptual", opts)
end

function RPrintMartix(text, opts)
    RPrint(text, "#003300", "#007700", "perceptual", opts)
end

function PrintDivider(text)
    local totalWidth = 50
    local divider = "-"

    if not text or text == "" then
        _P(string.rep(divider, totalWidth))
    else
        local textLen = string.len(text)
        local sideLen = math.floor((totalWidth - textLen - 2) / 2)

        if sideLen > 0 then
            local leftSide = string.rep(divider, sideLen)
            local rightSide = string.rep(divider, totalWidth - textLen - 2 - sideLen)
            _P(leftSide .. " " .. text .. " " .. rightSide)
        else
            _P(divider .. " " .. text .. " " .. divider)
        end
    end
end

function SetDebugLevel(level)
    local lvl = nil

    if not level then
        return
    end

    local numLevel = tonumber(level)

    if numLevel ~= nil then
        if numLevel % 1 == 0 and numLevel >= 0 and numLevel <= 5 then
            lvl = numLevel
        end
    elseif type(level) == "string" then
        lvl = RB_DEBUG_LEVELS[level]
    end

    if lvl ~= nil and lvl >= 0 and lvl <= 5 then
        RB_DEBUG_LEVEL = lvl
        --Info("Debug level set to: " .. tostring(level))
    else
        --_P("[Realm Builder] Invalid debug level: " .. tostring(level))
    end
end

function RainbowDumpTable(o, from, to)
    local colors = {91, 92, 93, 94, 95, 96}
    if from and to then
        colors = {}
        for i=from,to do
            table.insert(colors, i)
        end
    end
    local randomized = {}
    for _, color in ipairs(colors) do
        table.insert(randomized, math.random(#randomized + 1), color)
    end
    local resetCode = "\x1b[0m"
    local stringified = Ext.DumpExport(o)
    local result = {}
    local splited = {}
    for line in stringified:gmatch("([^\n]*)\n?") do
        table.insert(splited, line)
    end
    local indentParttern = "^%s*"
    local allColorsCount = #randomized
    for _, line in ipairs(splited) do
        local indent = line:match(indentParttern) or ""
        local indentLevel = #indent
        local colorCodeIndex = (indentLevel % allColorsCount) + 1
        local colorCode = randomized[colorCodeIndex]
        local colorCodeStr = string.format("\x1b[%dm", colorCode)
        table.insert(result, colorCodeStr .. line .. resetCode)
    end
    _P(table.concat(result, "\n"))
end

local debuglevelCommandDes =
[[
    Sets the Realm Builder debug level.
    Usage: rb_debug_level <level>
    Where <level> is one of the following:
    - Critical - 0 (never used)
    - Error - 1
    - Warning - 2
    - Info - 3
    - Debug - 4
    - Trace - 5 
]]

RegisterConsoleCommand("rb_debug_level", function(cmd, level)
    if not level or level == "" then
        _P("[Realm Builder] Current debug level: " .. tostring(debugLevels[RB_DEBUG_LEVEL + 1]))
        return
    end
    SetDebugLevel(level)
    _P("[Realm Builder] Debug level set to: " .. tostring(debugLevels[RB_DEBUG_LEVEL + 1]))

    if Ext.IsServer() then
    end

    if Ext.IsClient() then
        Post("SetDebugLevel", { Level = RB_DEBUG_LEVEL })
        CONFIG.DEBUG_LEVEL = RB_DEBUG_LEVEL
    end
end, debuglevelCommandDes)

RegisterConsoleCommand("rb_how_many_globals", function()
    local count = 0
    for k, v in pairs(Mods["Realm_Builder"]) do
        _P(" -" .. tostring(k))
        count = count + 1
    end
    _P("Total: " .. count)
end, "Inspect how many global variables Realm Builder is using.")
