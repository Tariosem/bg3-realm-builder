function RGBFloatToInt(r, g, b, a)
    return {
        math.floor(r * 255),
        math.floor(g * 255),
        math.floor(b * 255),
        a and math.floor(a * 255) or nil
    }
end

function RGBIntToFloat(r, g, b, a)
    return {
        r / 255,
        g / 255,
        b / 255,
        a and (a / 255) or nil
    }
end

local hexCache = {}
function HexToRGBA(hex)
    if hexCache[hex] then
        return hexCache[hex]
    end

    hex = hex:gsub("#", "")
    local r, g, b, a

    if #hex == 6 then
        r = tonumber(hex:sub(1, 2), 16)
        g = tonumber(hex:sub(3, 4), 16)
        b = tonumber(hex:sub(5, 6), 16)
        a = 255
    elseif #hex == 8 then
        a = tonumber(hex:sub(1, 2), 16)
        r = tonumber(hex:sub(3, 4), 16)
        g = tonumber(hex:sub(5, 6), 16)
        b = tonumber(hex:sub(7, 8), 16)
    else
        error("Invalid hex color length: " .. hex)
    end

    hexCache[hex] = { r / 255, g / 255, b / 255, a / 255 }

    return { r / 255, g / 255, b / 255, a / 255 }
end

function HexToRGB(hex)
    local rgba = HexToRGBA(hex)
    return { rgba[1], rgba[2], rgba[3] }
end

function RGBAToHex(r, g, b, a)
    local function toHex(n)
        return string.format("%02X", math.floor(Ext.Math.Clamp(n * 255, 0, 255)))
    end

    if a then
        return "#" .. toHex(a) .. toHex(r) .. toHex(g) .. toHex(b)
    else
        return "#" .. toHex(r) .. toHex(g) .. toHex(b)
    end
end

function RGBToHSL(r, g, b)
    local maxc = math.max(r, g, b)
    local minc = math.min(r, g, b)
    local h, s, l

    l = (maxc + minc) / 2
    if maxc == minc then
        h, s = 0, 0
    else
        local d = maxc - minc
        s = l > 0.5 and d / (2 - maxc - minc) or d / (maxc + minc)
        if maxc == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif maxc == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h, s, l
end

function HSLToRGB(h, s, l)
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end

    if s == 0 then
        return l, l, l
    else
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        local r = hue2rgb(p, q, h + 1 / 3)
        local g = hue2rgb(p, q, h)
        local b = hue2rgb(p, q, h - 1 / 3)
        return r, g, b
    end
end

function HSVtoRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end

    return r, g, b
end

function RGBtoHSV(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local h, s, v = 0, 0, max

    local d = max - min
    s = max == 0 and 0 or d / max

    if max ~= min then
        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        elseif max == b then
            h = (r - g) / d + 4
        end
        h = h / 6
    end

    return h, s, v
end

---@param color vec4
---@param dl? number
---@param ds? number
---@param da? number
---@return vec4
function AdjustColor(color, dl, ds, da)
    local r, g, b, a = color[1], color[2], color[3], color[4] or 1
    local h, s, l = RGBToHSL(r, g, b)
    l = Ext.Math.Clamp(l + (dl or 0), 0, 1)
    s = Ext.Math.Clamp(s + (ds or 0), 0, 1)
    a = Ext.Math.Clamp(a + (da or 0), 0, 1)
    local nr, ng, nb = HSLToRGB(h, s, l)
    return { nr, ng, nb, a }
end

function InvertColor(color)
    return { 1 - color[1], 1 - color[2], 1 - color[3], color[4] or 1 }
end

--- t is the interpolation factor of color 1 to color 2 (0 to 1)
---@param color1 vec4
---@param color2 vec4
---@param t number
---@return vec4
function BlendColors(color1, color2, t)
    t = Ext.Math.Clamp(t, 0, 1)
    local r = color1[1] * (1 - t) + color2[1] * t
    local g = color1[2] * (1 - t) + color2[2] * t
    local b = color1[3] * (1 - t) + color2[3] * t
    local a = (color1[4] or 1) * (1 - t) + (color2[4] or 1) * t
    return { r, g, b, a }
end

function CompareRGBA(color1, color2)
    for i = 1, 4 do
        if (color1[i] or 1) < (color2[i] or 1) then
            return true
        elseif (color1[i] or 1) > (color2[i] or 1) then
            return false
        end
    end
    return false
end

function CompareRGBAByHSV(color1, color2)
    local h1, s1, v1 = RGBtoHSV(color1[1], color1[2], color1[3])
    local h2, s2, v2 = RGBtoHSV(color2[1], color2[2], color2[3])

    if h1 ~= h2 then
        return h1 < h2
    elseif s1 ~= s2 then
        return s1 < s2
    elseif v1 ~= v2 then
        return v1 < v2
    else
        return CompareRGBA(color1, color2)
    end
end

--- @param accent vec4
--- @param accent2 vec4?
--- @param bg vec4
--- @return table<GuiColor, vec4>
function GenerateTheme(accent, accent2, bg)
    local colors = {} --[[@as table<GuiColor, vec4> ]]
    accent2 = accent2 or accent

    ----------------------------------------------------
    -- Borders & Separators
    ----------------------------------------------------
    colors["Border"]            = AdjustColor(accent, -0.2, -0.3)
    colors["BorderShadow"]      = AdjustColor(colors["Border"], -0.3, 0, -0.5)
    colors["Separator"]         = colors["Border"]
    colors["SeparatorHovered"]  = AdjustColor(accent, 0.15, 0)
    colors["SeparatorActive"]   = AdjustColor(accent, 0.15, 0)

    ----------------------------------------------------
    -- Buttons
    ----------------------------------------------------
    colors["Button"]            = AdjustColor(accent, -0.05, -0.1)
    colors["ButtonHovered"]     = AdjustColor(colors["Button"], 0.1, 0)
    colors["ButtonActive"]      = AdjustColor(colors["Button"], -0.1, 0)
    colors["CheckMark"]         = AdjustColor(accent2, 0, -0.3)

    ----------------------------------------------------
    -- Frames (Inputs, Sliders, etc.)
    ----------------------------------------------------
    colors["FrameBg"]           = AdjustColor(bg, 0.05, 0)
    colors["FrameBgHovered"]    = AdjustColor(accent, 0.1, 0)
    colors["FrameBgActive"]     = AdjustColor(accent, -0.1, 0)
    colors["SliderGrab"]        = accent
    colors["SliderGrabActive"]  = AdjustColor(accent, -0.15, 0)

    ----------------------------------------------------
    -- Headers & Menus
    ----------------------------------------------------
    colors["Header"]           = AdjustColor(accent, -0.05, -0.15)
    colors["HeaderHovered"]    = AdjustColor(colors["Header"], 0.15, 0)
    colors["HeaderActive"]     = AdjustColor(colors["Header"], -0.15, 0)
    colors["MenuBarBg"]        = AdjustColor(bg, 0.03, 0)

    ----------------------------------------------------
    -- Tabs
    ----------------------------------------------------
    colors["Tab"]                       = colors["HeaderActive"]
    colors["TabActive"]                 = colors["Header"]
    colors["TabHovered"]                = colors["HeaderHovered"]
    colors["TabUnfocused"]              = AdjustColor(colors["Tab"], -0.05, 0)
    colors["TabUnfocusedActive"]        = AdjustColor(colors["TabActive"], -0.05, 0)
    colors["TabDimmedSelectedOverline"] = AdjustColor(accent, 0.05, -0.1)

    ----------------------------------------------------
    -- Tables
    ----------------------------------------------------
    colors["TableHeaderBg"]    = colors["Header"]
    colors["TableRowBg"]       = bg
    colors["TableRowBgAlt"]    = AdjustColor(bg, 0.05, 0)
    colors["TableBorderStrong"]= colors["Border"]
    colors["TableBorderLight"] = AdjustColor(colors["Border"], 0.1, 0)

    ----------------------------------------------------
    -- Scrollbars & Resize Grips
    ----------------------------------------------------
    colors["ScrollbarBg"]          = AdjustColor(bg, -0.02, 0)
    colors["ScrollbarGrab"]        = AdjustColor(accent, 0, -0.3)
    colors["ScrollbarGrabHovered"] = AdjustColor(colors["ScrollbarGrab"], 0.1, 0)
    colors["ScrollbarGrabActive"]  = AdjustColor(colors["ScrollbarGrab"], -0.1, 0)
    colors["ResizeGrip"]           = AdjustColor(accent, 0.2, -0.2)
    colors["ResizeGripHovered"]    = AdjustColor(accent, 0.1, 0)
    colors["ResizeGripActive"]     = AdjustColor(accent, -0.1, 0)

    ----------------------------------------------------
    -- Navigation & Windows
    ----------------------------------------------------
    colors["NavHighlight"]          = accent2
    colors["NavWindowingHighlight"] = AdjustColor(accent, 0, 0, -0.25)
    colors["NavWindowingDimBg"]     = AdjustColor(bg, 0, 0, -0.65)
    colors["ModalWindowDimBg"]      = AdjustColor(bg, 0, 0, -0.65)
    colors["ChildBg"]               = AdjustColor(bg, 0.02, 0)
    colors["PopupBg"]               = AdjustColor(bg, -0.05, 0)
    colors["WindowBg"]              = bg
    colors["TitleBg"]               = AdjustColor(bg, -0.1, 0)
    colors["TitleBgActive"]         = AdjustColor(accent, 0, -0.2)
    colors["TitleBgCollapsed"]      = AdjustColor(bg, -0.05, 0)

    ----------------------------------------------------
    -- Text & Links
    ----------------------------------------------------
    colors["Text"]           = {1, 1, 1, 1}
    colors["TextDisabled"]   = AdjustColor(colors["Text"], -0.2, -0.7)
    colors["TextLink"]       = AdjustColor(accent2, 0.3)
    colors["TextSelectedBg"] = AdjustColor(accent, 0, 0, -0.3)

    ----------------------------------------------------
    -- Plots
    ----------------------------------------------------
    colors["PlotLines"]            = AdjustColor(accent, 0.3, 0.15, -0.45)
    colors["PlotLinesHovered"]     = AdjustColor(accent, 0.2, 0.08, -0.25)
    colors["PlotHistogram"]        = AdjustColor(accent, 0.3, 0.15, -0.45)
    colors["PlotHistogramHovered"] = AdjustColor(accent, 0.2, 0.08, -0.25)

    ----------------------------------------------------
    -- Misc
    ----------------------------------------------------
    colors["DragDropTarget"] = AdjustColor(accent, 0.1, 0)

    return colors
end

function GenerateUIStyle(baseRounding, basePadding, baseBorder)
    local style                      = {}

    style["WindowRounding"]          = baseRounding
    style["ChildRounding"]           = baseRounding * 0.8
    style["PopupRounding"]           = baseRounding * 0.8
    style["FrameRounding"]           = baseRounding * 0.5
    style["GrabRounding"]            = baseRounding * 0.4
    style["TabRounding"]             = baseRounding * 0.6
    style["ScrollbarRounding"]       = baseRounding * 0.3

    --style["WindowPadding"]            = { basePadding, basePadding }
    --style["FramePadding"]             = { basePadding * 0.6, basePadding * 0.6 }
    --style["ItemSpacing"]              = { basePadding * 0.7, basePadding * 0.7 }
    --style["ItemInnerSpacing"]         = { basePadding * 0.5, basePadding * 0.5 }
    --style["CellPadding"]              = { basePadding * 0.6, basePadding * 0.6 }
    --style["SeparatorTextPadding"]     = { basePadding * 0.5, basePadding * 0.5 }

    --style["ScrollbarSize"]           = basePadding * 1.5
    --style["GrabMinSize"]             = basePadding * 2

    style["WindowBorderSize"]        = baseBorder
    style["ChildBorderSize"]         = baseBorder
    style["PopupBorderSize"]         = baseBorder
    style["FrameBorderSize"]         = baseBorder
    style["TabBorderSize"]           = baseBorder
    style["TabBarBorderSize"]        = baseBorder * 0.8
    style["SeparatorTextBorderSize"] = baseBorder

    return style
end

local GradientModes = {
    rgb = function(color1, color2, t)
        return {
            color1[1] * (1 - t) + color2[1] * t,              -- R
            color1[2] * (1 - t) + color2[2] * t,              -- G
            color1[3] * (1 - t) + color2[3] * t,              -- B
            (color1[4] or 1) * (1 - t) + (color2[4] or 1) * t -- A
        }
    end,

    hsv = function(color1, color2, t)
        local h1, s1, v1 = RGBtoHSV(color1[1], color1[2], color1[3])
        local h2, s2, v2 = RGBtoHSV(color2[1], color2[2], color2[3])
        local a1, a2 = color1[4] or 1, color2[4] or 1

        local dh = h2 - h1
        if dh > 0.5 then
            h1 = h1 + 1
        elseif dh < -0.5 then
            h2 = h2 + 1
        end

        local h = (h1 * (1 - t) + h2 * t) % 1
        local s = s1 * (1 - t) + s2 * t
        local v = v1 * (1 - t) + v2 * t
        local a = a1 * (1 - t) + a2 * t

        local r, g, b = HSVtoRGB(h, s, v)
        return { r, g, b, a }
    end,

    hsl = function(color1, color2, t)
        local h1, s1, l1 = RGBToHSL(color1[1], color1[2], color1[3])
        local h2, s2, l2 = RGBToHSL(color2[1], color2[2], color2[3])
        local a1, a2 = color1[4] or 1, color2[4] or 1

        local dh = h2 - h1
        if dh > 0.5 then
            h1 = h1 + 1
        elseif dh < -0.5 then
            h2 = h2 + 1
        end

        local h = (h1 * (1 - t) + h2 * t) % 1
        local s = s1 * (1 - t) + s2 * t
        local l = l1 * (1 - t) + l2 * t
        local a = a1 * (1 - t) + a2 * t

        local r, g, b = HSLToRGB(h, s, l)
        return { r, g, b, a }
    end,

    perceptual = function(color1, color2, t)
        local gamma = 2.2
        local r1, g1, b1 = color1[1] ^ gamma, color1[2] ^ gamma, color1[3] ^ gamma
        local r2, g2, b2 = color2[1] ^ gamma, color2[2] ^ gamma, color2[3] ^ gamma
        local a1, a2 = color1[4] or 1, color2[4] or 1

        local r = (r1 * (1 - t) + r2 * t) ^ (1 / gamma)
        local g = (g1 * (1 - t) + g2 * t) ^ (1 / gamma)
        local b = (b1 * (1 - t) + b2 * t) ^ (1 / gamma)
        local a = a1 * (1 - t) + a2 * t

        return { r, g, b, a }
    end,

    sine = function(color1, color2, t)
        local smoothT = 0.5 * (1 - math.cos(t * math.pi))
        local a1, a2 = color1[4] or 1, color2[4] or 1
        return {
            color1[1] * (1 - smoothT) + color2[1] * smoothT,
            color1[2] * (1 - smoothT) + color2[2] * smoothT,
            color1[3] * (1 - smoothT) + color2[3] * smoothT,
            a1 * (1 - smoothT) + a2 * smoothT
        }
    end,

    rainbow = function(color1, color2, t)
        local hue = t
        local r, g, b = HSVtoRGB(hue, 1.0, 1.0)
        local a1, a2 = color1[4] or 1, color2[4] or 1
        local a = a1 * (1 - t) + a2 * t
        return { r, g, b, a }
    end
}

--- @class RadianceOpts
--- @field Reverse boolean
--- @field Cycles number
--- @field CycleMode 'forward'|'pingpong'|'reverse'
--- @field Horizontal boolean
--- @field Vertical boolean
--- @field SkipWhitespace boolean
--- @field LineGradient boolean
--- @field LineCycles number

--- @class RadiantResult
--- @field Segments RB_TextToken
--- @field RawText string
--- @field Options RadianceOpts

--- @param text string
--- @param startColor string|table
--- @param endColor string|table?
--- @param mode 'rgb'|'hsv'|'sine'|'perceptual'|'rainbow'
--- @param options RadianceOpts?
--- @return RadiantResult
function Radiant(text, startColor, endColor, mode, options)
    if not text or text == "" then
        return {
            Segments = {},
            RawText = "",
            Options = options or {}
        }
    end

    mode = mode:lower() or "hsv"
    options = options or {}

    local color1
    if type(startColor) == "string" then
        color1 = HexToRGBA(startColor)
    else
        color1 = startColor
    end

    local color2 = color1
    if endColor then
        if type(endColor) == "string" then
            color2 = HexToRGBA(endColor)
        else
            color2 = endColor
        end
    end

    if #text <= 1 or (color1[1] == color2[1] and color1[2] == color2[2] and color1[3] == color2[3]) then
        return {
            Segments = { {
                Text = text,
                Color = color1
            } },
            RawText = text,
            Options = options
        }
    end

    local interpolate = GradientModes[mode] or GradientModes.hsv
    local function applyCycleMode(t, cycles, cycleMode, reverse)
        if cycles <= 1 then
            return t
        end

        cycleMode = cycleMode or "forward"

        local expandedT = t * cycles
        local cycleIndex = math.floor(expandedT)
        local cycleProgress = expandedT - cycleIndex

        if cycleMode == "pingpong" and (cycleIndex % 2) == 1 then
            cycleProgress = 1 - cycleProgress
        end

        if reverse then
            cycleProgress = 1 - cycleProgress
        end

        return cycleProgress
    end

    local reverse = options.Reverse or false
    local cycles = options.Cycles or 1
    local cycleMode = options.CycleMode or "forward"

    local vertical = false
    if options.Vertical == true then
        vertical = true
    elseif options.Vertical == nil then
        vertical = text:find('\n') ~= nil
    end

    local segments = {}

    if vertical then
        local lines = {}
        local currentLine = ""

        for i = 1, #text do
            local char = text:sub(i, i)
            if char == '\n' then
                table.insert(lines, currentLine)
                currentLine = ""
            else
                currentLine = currentLine .. char
            end
        end

        if currentLine ~= "" then
            table.insert(lines, currentLine)
        end

        local totalLines = #lines

        for lineIndex, line in ipairs(lines) do
            if line == "" then
                table.insert(segments, {
                    Text = "",
                    Color = color1
                })
            else
                local rawT = (lineIndex - 1) / math.max(1, totalLines - 1)
                local t = applyCycleMode(rawT, cycles, cycleMode, reverse)

                local lineColor = interpolate(color1, color2, t)

                if options.LineGradient ~= false and #line > 1 then
                    local lineOptions = {}
                    for k, v in pairs(options) do
                        lineOptions[k] = v
                    end
                    lineOptions.Vertical = false
                    lineOptions.Cycles = options.LineCycles or 1

                    local lineResult = Radiant(line, lineColor, lineColor, mode, lineOptions)
                    for _, segment in ipairs(lineResult.Segments) do
                        table.insert(segments, segment)
                    end
                else
                    table.insert(segments, {
                        Text = line,
                        Color = lineColor
                    })
                end
            end

            if lineIndex < totalLines then
                table.insert(segments, {
                    Text = "\n",
                    Color = color1
                })
            end
        end
    else
        local textLen = #text

        for i = 1, textLen do
            local char = text:sub(i, i)

            if options.SkipWhitespace and char:match("%s") then
                table.insert(segments, {
                    Text = char,
                    Color = color1
                })
            else
                local rawT = (i - 1) / math.max(1, textLen - 1)
                local t = applyCycleMode(rawT, cycles, cycleMode, reverse)

                local color = interpolate(color1, color2, t)
                table.insert(segments, {
                    Text = char,
                    Color = color
                })
            end
        end
    end

    return {
        Segments = segments,
        RawText = text,
        Options = options
    }
end

Ext.RegisterConsoleCommand("rb_test_radiant", function(cmd, mode, text)
    local text = text or "Hello World"
    mode = mode or "rainbow"

    _P("Testing gradient mode: " .. mode)
    RPrint(text, "#FF0000", "#0000FF", mode)

    _P("Available modes:")
    for modeName, v in pairs(GradientModes) do
        if type(v) == "function" then
            RPrint(" -" .. modeName .. " This is a test text", "#FFFFFF", "#888888", modeName)
        end
    end

    _P("Vertical Test")
    local multiLine = ""
    local lines = 5
    for i = 1, lines do
        for j = 1, i do
            multiLine = multiLine .. "|"
        end
        multiLine = multiLine .. "\n"
    end
    for i = lines, 1, -1 do
        for j = 1, i do
            multiLine = multiLine .. "|"
        end
        multiLine = multiLine .. "\n"
    end
    RPrintPurple(multiLine, { Cycles = 2 })
end)
