--- @class Notification
--- @field panel ExtuiWindow?
--- @field isVisible boolean
--- @field timer integer?
--- @field Duration number ms
--- @field FadeInTime number ms
--- @field FadeInType AnimationEasing
--- @field FadeOutTime number ms
--- @field FadeOutType AnimationEasing
--- @field timeRemaining number
--- @field Pivot number[] 0-1, index 1 is horizontal (0=left, 1=right), index 2 is vertical (0=top, 1=bottom)
--- @field runningAnimation RunningAnimation?
--- @field AnimDirection "Horizontal"|"Vertical"
--- @field Fps integer
--- @field AutoFadeOut boolean
--- @field AutoResize boolean
--- @field Width integer|nil
--- @field Height integer|nil
--- @field Moveable boolean
--- @field FlickToDismiss boolean
--- @field ClickToDismiss boolean
--- @field FlickVelocityThreshold number Minimum velocity to trigger flick to dismiss
--- @field ChangeDirectionWhenFadeOut boolean
--- @field NeverShowAgain boolean
--- @field NoAnimation boolean
--- @field InstantDismiss boolean
--- @field Title string
--- @field MessageRenderFunc fun(panel: ExtuiWindow) A function that takes the panel and adds content to it
--- @field new fun(name:string):Notification
--- @field Show fun(self: Notification, title: string, messageRenderFunc:fun(panel: ExtuiWindow)|string):Notification
--- @field Dismiss fun(self: Notification)
--- @field Close fun(self: Notification)
--- @field StartAnimation fun(self: Notification, dir: "FadeIn"|"FadeOut", direction: "Horizontal"|"Vertical")
--- @field StopAnimation fun(self: Notification)
Notification = _Class("Notification")

function Notification:__init(name)
    self.panel = nil
    self.isVisible = false
    self.timer = nil
    self.Duration = 3000
    self.FadeInTime = 1000
    self.FadeInType = "EaseOutBack"
    self.FadeOutTime = 1000
    self.FadeOutType = "EaseInBack"
    self.timeRemaining = 0.0
    self.Pivot = {0, 0}
    self.runningAnimation = nil
    self.AnimDirection = "Horizontal"
    self.AutoFadeOut = true
    self.AutoResize = true
    self.Width = nil
    self.Height = nil
    self.Moveable = false
    self.ChangeDirectionWhenFadeOut = false
    self.FlickVelocityThreshold = 800
    self.NeverShowAgain = false
    self.NoAnimation = false
    self.FlickToDismiss = false
    self.InstantDismiss = false
    self.Fps = 90
    self.Title = name
    self.MessageRenderFunc = function(panel) panel:AddText("No Content") end
    self.OnDismiss = function() end
end

function Notification:ValidateConfig()
    local directions = {
        Horizontal = true,
        Vertical = true
    }
    if not directions[self.AnimDirection] then
        self.AnimDirection = "Horizontal"
    end

    self.Pivot[1] = Ext.Math.Clamp(self.Pivot[1] or 0, 0, 1)
    self.Pivot[2] = Ext.Math.Clamp(self.Pivot[2] or 0, 0, 1)

    self.Duration = math.max(0, self.Duration or 3000)
    self.FadeInTime = math.max(0, self.FadeInTime or 1000)
    self.FadeOutTime = math.max(0, self.FadeOutTime or 1000)

    self.FadeInType = AnimationEasing[self.FadeInType] and self.FadeInType or "EaseOutBack"
    self.FadeOutType = AnimationEasing[self.FadeOutType] and self.FadeOutType or "EaseInBack"

    self.Fps = math.max(1, self.Fps or 90)
end

function Notification:BuildContent()
    if self.NeverShowAgain then return end
    if self.InstantDismiss then
        self:Close() 
    else
        self:QuickDismiss()
    end

    self:ValidateConfig()

    local screenWidth, screenHeight = UIHelpers.GetScreenSize()
    local panel = Ext.IMGUI.NewWindow("RB_Notification" .. tostring(math.random(1,1000000)))
    self.panel = panel
    panel:SetStyle("Alpha", 0)
    panel:SetPos({-screenWidth, -screenHeight})
    self.isVisible = true
    WindowManager.ApplyGuiParams(self.panel)

    
    local scale = UIHelpers.GetUIScale() or 1

    local baseHeight = screenHeight * 0.1
    local baseWidth = baseHeight * 6

    local width = baseWidth * scale
    local height = baseHeight * scale

    
    panel.NoResize = true
    panel.NoCollapse = true
    panel.NoTitleBar = true
    panel.AlwaysAutoResize = self.AutoResize ~= false
    panel:SetStyle("WindowRounding", 8 * scale)
    panel:SetStyle("WindowBorderSize", 1 * scale)

    self.titleText = panel:AddSeparatorText(self.Title)
    self.titleText:SetStyle("SeparatorTextAlign", 0.5)

    local titleText = self.titleText
    titleText.OnHoverEnter = function()
        local color = titleText:GetColor("Text") or {1,1,1,1}
        titleText:SetColor("Text", {color[1], color[2], color[3], color[4] - 0.4})
    end
    titleText.OnHoverLeave = function()
        local color = titleText:GetColor("Text") or {1,1,1,1}
        titleText:SetColor("Text", {color[1], color[2], color[3], color[4] + 0.4})
    end
    titleText.OnClick = function()
        if self.fadeOutTimer then
            Timer:Cancel(self.fadeOutTimer)
            self.fadeOutTimer = nil
        end
        self:Dismiss()
    end
    titleText:SetColor("Text", {1,1,1,1})
    self.MessageRenderFunc(panel)
    
    if self.ClickToDismiss then
        local clicked = false
        for i, child in ImguiHelpers.TraverseAllChildren(panel) do
            local childOnClick = child.OnClick or function() end
            child.OnClick = function()
                childOnClick(child)
                if not clicked then
                    if self.fadeOutTimer then
                        Timer:Cancel(self.fadeOutTimer)
                        self.fadeOutTimer = nil
                    end
                    self:Dismiss()
                    clicked = true
                end
            end
        end
    end

    if self.AutoResize == false then
        width = self.Width or width
        height = self.Height or height
        panel:SetSize({width, height})
    end

    Timer:Ticks(10, function (timerID)
        self:StartAnimation("FadeIn", self.AnimDirection)
    end)
end

function Notification:StartAnimation(dir, direction)
    self:StopAnimation()
    local panel = self.panel

    if not panel then return end
    
    panel.NoMove = true

    local onFrame = function(newPos, alpha)
        if not panel or not self.isVisible then
            self:StopAnimation()
            return
        end
        alpha = Ext.Math.Clamp(alpha, 0, 1)
        panel:SetPos(newPos)
        panel:SetStyle("Alpha", alpha)
    end
    

    local onComplete = function()
        if dir == "FadeOut" then
            self:Close()
        elseif dir == "FadeIn" and self.Duration > 0 and self.AutoFadeOut then
            self.fadeOutTimer = Timer:After(self.Duration, function(timerID)
                self:StartAnimation("FadeOut", direction)
            end)
            
        end
        if dir == "FadeIn" and self.FlickToDismiss then
            panel.NoMove = false
            self:SetupFlick()
        end
        if self.Moveable then
            panel.NoMove = false
        end
    end

    local screenWidth, screenHeight = UIHelpers.GetScreenSize()
    local oldRelativePos = self.Pivot
    if dir == "FadeOut" and self.Moveable then
        self.Pivot = {
            Ext.Math.Clamp(panel.LastPosition[1] / screenWidth, 0, 1),
            Ext.Math.Clamp(panel.LastPosition[2] / screenHeight, 0, 1)
        }
        self.panel.Disabled = true
    end
    if dir == "FadeOut" and self.ChangeDirectionWhenFadeOut then
        self.AnimDirection = direction == "Horizontal" and "Vertical" or "Horizontal"
    end

    if dir == "FadeIn" then
        self.EndPos = {self:CalcEndPosition()}
        self.StartPos = {self:CalcStartPosition()}
    elseif dir == "FadeOut" then
        self.EndPos = {panel.LastPosition[1], panel.LastPosition[2]}
        self.StartPos = {self:CalcStartPosition()}
        self.Pivot = oldRelativePos

        if self.FlickTimer then
            Timer:Cancel(self.FlickTimer)
            self.FlickTimer = nil
        end
    end

    local from = dir == "FadeIn" and 0 or 1
    local to = dir == "FadeIn" and 1 or 0
    local duration = (dir == "FadeIn") and self.FadeInTime or self.FadeOutTime
    local easing = (dir == "FadeIn") and self.FadeInType or self.FadeOutType
    local startPos = dir == "FadeIn" and self.StartPos or self.EndPos
    local endPos = dir == "FadeIn" and self.EndPos or self.StartPos
    if self.NoAnimation then
        duration = 1
    end

    self.runningAnimation = AnimateValue(self.Fps, startPos, endPos, duration, easing,
    onComplete,
    function(t, eased)
        local alpha = from + (to - from) * eased
        local newPos = t
        onFrame(newPos, alpha)
    end)

end

function Notification:Dismiss()
    if not self.isVisible then return end
    if self.fadeOutTimer then
        Timer:Cancel(self.fadeOutTimer)
        self.fadeOutTimer = nil
    end
    if self.FlickTimer then
        Timer:Cancel(self.FlickTimer)
        self.FlickTimer = nil
    end
    self:StartAnimation("FadeOut", self.AnimDirection)
    self.OnDismiss()
end

function Notification:QuickDismiss()
    if not self.isVisible then return end

    local panel = self.panel
    self.panel = nil
    if not panel then return end

    Timer:After(1005, function ()
        if panel then
            panel:SetStyle("Alpha", 0)
            panel:Destroy()
        end
    end)

    if self.FlickTimer then
        Timer:Cancel(self.FlickTimer)
        self.FlickTimer = nil
    end
    if self.fadeOutTimer then
        Timer:Cancel(self.fadeOutTimer)
        self.fadeOutTimer = nil

        AnimateValue(self.Fps or 60, 0, 1, 500, "Linear",
            function()
                panel:Destroy()
                panel = nil
            end,
            function(t, eased)
                panel:SetStyle("Alpha", 1 - eased)
            end
        )
        return
    end

    local runningAnimation = self.runningAnimation
    self.runningAnimation = nil
    if not runningAnimation then return end

    runningAnimation.ChangeOnComplete(function()
        AnimateValue(self.Fps or 60, 0, 1, 500, "Linear",
            function()
                panel:Destroy()
                panel = nil
            end,
            function(t, eased)
                panel:SetStyle("Alpha", 1 - eased)
            end
        )
    end)
end

function Notification:StopAnimation()
    if self.runningAnimation then
        self.runningAnimation:Stop()
    end
    self.runningAnimation = nil
end

function Notification:Close()
    if not self.isVisible then return end

    if self.fadeOutTimer then
        Timer:Cancel(self.fadeOutTimer)
        self.fadeOutTimer = nil
    end
    if self.FlickTimer then
        Timer:Cancel(self.FlickTimer)
        self.FlickTimer = nil
    end

    
    self:StopAnimation()
    if self.panel then
        self.panel:SetStyle("Alpha", 0)
        self.panel:Destroy()
        self.panel = nil
    end
    self.isVisible = false
end

function Notification:CalcStartPosition(width, height, screenWidth, screenHeight)
    width, height = table.unpack(self.panel.LastSize)
    if not screenWidth or not screenHeight then
        screenWidth, screenHeight = UIHelpers.GetScreenSize()
    end
    if not width or not height or not screenWidth or not screenHeight then
        Error("Invalid size for Notification")
        return {-1000, -1000}
    end
    local x, y = self.EndPos[1], self.EndPos[2]

    if self.AnimDirection == "Horizontal" then
        if self.Pivot[1] < 0.5 then
            x = -width
        else
            x = screenWidth
        end
    elseif self.AnimDirection == "Vertical" then
        if self.Pivot[2] < 0.5 then
            y = -height
        else
            y = screenHeight
        end
    end
    return x, y
end

function Notification:CalcEndPosition(width, height, screenWidth, screenHeight)
    width, height = table.unpack(self.panel.LastSize)
    if not screenWidth or not screenHeight then
        screenWidth, screenHeight = UIHelpers.GetScreenSize()
    end
    if not width or not height or not screenWidth or not screenHeight then
        Error("Invalid size for Notification")
        return {-1000, -1000}
    end
    local x, y

    x = screenWidth * self.Pivot[1] - width / 2

    y = screenHeight * self.Pivot[2] - height / 2

    x = Ext.Math.Clamp(x, 0, screenWidth - width)
    y = Ext.Math.Clamp(y, 0, screenHeight - height)
    

    return x, y
end

function Notification:SetupFlick()
    local lastInputTime = 0
    local lastCursorPos = {0, 0}

    local function GetPanelPos()
        if not self.panel or not self.panel.LastPosition then
            return nil
        end
        return table.unpack(self.panel.LastPosition)
    end

    self.FlickTimer = Timer:Every(1000 / self.Fps, function()
        if not self.isVisible or not self.panel or not self.panel.LastPosition then
            Timer:Cancel(self.FlickTimer)
            self.FlickTimer = nil
            return
        end

        local currentTime = Ext.Timer.MonotonicTime()
        local panelX, panelY = GetPanelPos()
    
        if not lastCursorPos[1] or not lastCursorPos[2] then
            lastCursorPos = {panelX, panelY}
            lastInputTime = currentTime
            return
        end

        local deltaTime = currentTime - lastInputTime
        if deltaTime < 16 then
            return
        end

        local dt = deltaTime/ 1000
        lastInputTime = currentTime
        
        local dx = panelX - lastCursorPos[1]
        local dy = panelY - lastCursorPos[2]
        lastCursorPos = {panelX, panelY}

        local velocityX = dx / dt
        local velocityY = dy / dt
        local velocity = math.sqrt(velocityX * velocityX + velocityY * velocityY)

        local panelW, panelH = table.unpack(self.panel.LastSize)
        local dist = math.sqrt(dx * dx + dy * dy)

        if velocity > self.FlickVelocityThreshold and dist > 10 and dist < panelW then
            local directionX = dx / dist
            local directionY = dy / dist

            local animVelocity = math.min(velocity, self.FlickVelocityThreshold)

            local throwDistance = math.min(velocity * 0.5, 2000)
            local endX = panelX + directionX * throwDistance
            local endY = panelY + directionY * throwDistance
            local startPos = {panelX, panelY}
            local endPos = {endX, endY}
            local animationDistance = math.sqrt((endX - panelX)^2 + (endY - panelY)^2)
            local duration = Ext.Math.Clamp((animationDistance / animVelocity) * 1000, 200, 800)

            self.panel.NoMove = true
            self:StopAnimation()
            if self.fadeOutTimer then
                Timer:Cancel(self.fadeOutTimer)
                self.fadeOutTimer = nil
            end
            self.runningAnimation = AnimateValue(self.Fps or 60, startPos, endPos, duration, "Linear",
                function()
                    self:Close()
                end,
                function(t, eased)
                    if not self.panel or not self.isVisible then
                        self:StopAnimation()
                        return
                    end
                    self.panel:SetPos(Vec2.new(t))
                    self.panel:SetStyle("Alpha", 1 - eased)
                end
            )
            Timer:Cancel(self.FlickTimer)
            self.FlickTimer = nil
        end
    end)
end

---@param title string
---@param messageRenderFunc fun(panel: ExtuiWindow)|string
---@return Notification
function Notification:Show(title, messageRenderFunc)
    self.Title = title or self.Title or "Notification"
    if type(messageRenderFunc) == "function" then
        self.MessageRenderFunc = messageRenderFunc or function(panel) panel:AddText("No Content") end
    elseif type(messageRenderFunc) == "string" then
        local msg = messageRenderFunc
        self.MessageRenderFunc = function(panel) panel:AddText(msg).TextWrapPos = 800 * SCALE_FACTOR end
    end
    self:BuildContent()
    return self
end

--- @param level RB_DEBUG_LEVELS
--- @param message string
function ErrorNotify(level, message)
    if not DebugGradient[level] then return end
    local notification = Notification.new("RB_Notification_" .. tostring(math.random(1,1000000)))
    notification.Pivot = {0.9, 0.8}
    notification.AnimDirection = "Vertical"
    notification.FlickToDismiss = true
    notification.Duration = 8000
    notification:Show(level, function(panel)
        panel:SetColor("WindowBg", ColorUtils.AdjustColor(ColorUtils.HexToRGBA(DEBUG_COLOR[level]), -0.5, -0.5, -0.2))
        panel:SetColor("Border", ColorUtils.HexToRGBA(DEBUG_COLOR[level]))
        notification.titleText:SetColor("Text", ColorUtils.HexToRGBA(DEBUG_COLOR[level]))
        notification.titleText:SetColor("Separator", ColorUtils.AdjustColor(ColorUtils.HexToRGBA(DEBUG_COLOR[level]), -0.2, -0.3))
        local tokens = DebugGradient[level](message)
        tokens = RBUtils.WrapTextTokens(tokens)
        for _, token in ipairs(tokens) do
            token.Style = {
                ItemSpacing = {0, 0}
            }
        end
        RenderTokenTexts(panel:AddTable("", 1):AddRow():AddCell(), tokens)
    end)
    return notification
end