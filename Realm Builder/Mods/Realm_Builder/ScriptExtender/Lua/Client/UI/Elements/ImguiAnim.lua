--- @class GuiAnim
--- @field Vibrate fun(gui: ExtuiStyledRenderable, dur: number|nil, freq: number|nil, amp: number|nil, fps: number|nil): RunningAnimation?
--- @field Shake fun(gui: ExtuiStyledRenderable, dur: number|nil, freq: number|nil, amp: number|nil, fps: number|nil): RunningAnimation?
--- @field PulseBorder fun(gui: ExtuiStyledRenderable, originalSize: number|nil, dur: number|nil, freq: number|nil, amp: number|nil, fps: number|nil): RunningAnimation?
--- @field Blend fun(gui: ExtuiColorEdit, fromColor: vec3, toColor: vec3, dur: number?, fps: integer?): RunningAnimation?
--- @field FlashColor fun(gui: ExtuiStyledRenderable, flashColor: vec3?, dur: number?, fps: integer?, originalColor: vec3?): RunningAnimation?
GuiAnim = {}

---@param gui ExtuiStyledRenderable
---@param dur number|nil
---@param freq number|nil
---@param amp number|nil
---@return RunningAnimation?
function GuiAnim.Vibrate(gui, dur, freq, amp, fps)
    local amplitude = tonumber(amp) or 10
    local frequency = tonumber(freq) or 30 -- Hz
    local duration = tonumber(dur) or 500  -- ms
    local framePerSecond = tonumber(fps) or 90

    local originalPos = gui.PositionOffset

    local phaseX = math.random() * 2 * math.pi
    local phaseY = math.random() * 2 * math.pi

    local startTime = Ext.Utils.MonotonicTime()
    local anim = AnimateValue(framePerSecond, { 0, 0 }, { 1, 1 }, duration, AnimationEasing.EaseOutSine,
        function()
            gui.PositionOffset = originalPos
        end,
        function(value, eased)
            local now = Ext.Utils.MonotonicTime()
            local elapsedMs = now - startTime
            local tsec = elapsedMs / 1000.0

            local angleX = 2 * math.pi * frequency * tsec + phaseX
            local angleY = 2 * math.pi * frequency * tsec + phaseY
            local oscX = math.sin(angleX)
            local oscY = math.sin(angleY)

            local jitter = (math.random() * 2 - 1) * (amplitude * 0.15)

            local offsetX = (oscX * amplitude + jitter) * (1 - eased)
            local offsetY = (oscY * amplitude + jitter) * (1 - eased)

            gui.PositionOffset = { offsetX, offsetY }
        end
    )

    return anim
end

function GuiAnim.Shake(gui, dur, freq, amp, fps)
    local amplitude = tonumber(amp) or 10
    local frequency = tonumber(freq) or 10 -- Hz
    local duration = tonumber(dur) or 500  -- ms
    local framePerSecond = tonumber(fps) or 90

    local originalPos = gui.PositionOffset

    local anim = AnimateValue(framePerSecond, { 0, 0 }, { 1, 1 }, duration, AnimationEasing.EaseOutSine,
        function()
            gui.PositionOffset = originalPos
        end,
        function(value, eased)
            local t = value[1]
            local angle = t * frequency * 2 * math.pi
            local osc = math.sin(angle)

            local offsetX = osc * amplitude * (1 - eased)
            local offsetY = osc * amplitude * (1 - eased)

            gui.PositionOffset = { offsetX, offsetY }
        end
    )

    return anim
end

---@param gui ExtuiStyledRenderable
---@param originalSize number?
---@param dur number?
---@param freq number?
---@param amp number?
---@param fps number?
---@return RunningAnimation?
function GuiAnim.PulseBorder(gui, originalSize, dur, freq, amp, fps)
    local amplitude = tonumber(amp) or 5
    local frequency = tonumber(freq) or 2  -- Hz
    local duration = tonumber(dur) or 1000 -- ms
    local framePerSecond = tonumber(fps) or 90

    local function setBorderSize(size)
        gui:SetStyle("TabBorderSize", size)
        gui:SetStyle("ChildBorderSize", size)
        gui:SetStyle("FrameBorderSize", size)
        gui:SetStyle("ImageBorderSize", size)
        gui:SetStyle("TabBarBorderSize", size)
        gui:SetStyle("WindowBorderSize", size)
        gui:SetStyle("SeparatorTextBorderSize", size)
    end

    local originalWidth = originalSize or 0

    local anim = AnimateValue(framePerSecond, 0, 1, duration, AnimationEasing.EaseInOutSine,
        function()
            setBorderSize(originalWidth)
        end,
        function(value, eased)
            local t = value
            local angle = t * frequency * 2 * math.pi
            local osc = (math.sin(angle) + 1) / 2 -- Normalize to [0,1]

            local borderWidth = originalWidth + osc * amplitude * (1 - eased)
            setBorderSize(borderWidth)
        end
    )

    return anim
end

---@param gui ExtuiColorEdit
---@param fromColor vec3
---@param toColor vec3
---@param dur number?
---@param fps integer?
---@return RunningAnimation?
function GuiAnim.Blend(gui, fromColor, toColor, dur, fps)
    local duration = tonumber(dur) or 500 -- ms
    local framePerSecond = tonumber(fps) or 90

    local anim = AnimateValue(framePerSecond, fromColor, toColor, duration, AnimationEasing.Linear,
        nil,
        function(value, eased)
            value = {
                value[1],
                value[2],
                value[3],
                value[4],
            }
            gui.Color = value
        end
    )

    return anim
end

---@param gui ExtuiStyledRenderable
---@param flashColor vec3?
---@param dur number?
---@param fps integer?
---@param originalColor vec3?
function GuiAnim.FlashColor(gui, flashColor, dur, fps, originalColor)
    local duration = tonumber(dur) or 500 -- ms
    local framePerSecond = tonumber(fps) or 90

    flashColor = flashColor or { 1, 1, 1, 1 }
    local origColor = originalColor or gui.Color

    local anim = AnimateValue(framePerSecond, 0, 1, duration, AnimationEasing.EaseInOutSine,
        function()
            gui.Color = origColor
        end,
        function(value, eased)
            local t = value
            local r = origColor[1] + (flashColor[1] - origColor[1]) * (1 - math.abs(0.5 - t) * 2)
            local g = origColor[2] + (flashColor[2] - origColor[2]) * (1 - math.abs(0.5 - t) * 2)
            local b = origColor[3] + (flashColor[3] - origColor[3]) * (1 - math.abs(0.5 - t) * 2)
            local a = origColor[4] + (flashColor[4] - origColor[4]) * (1 - math.abs(0.5 - t) * 2)
            gui.Color = { r, g, b, a }
        end
    )

    return anim
end
