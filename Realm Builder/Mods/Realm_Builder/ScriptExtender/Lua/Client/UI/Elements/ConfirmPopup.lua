--- @class ConfirmPopup
ConfirmPopup = {
    panel = nil,
    isVisible = false,
    timer = nil,
    timeRemaining = 0,
}

--- @param message string
--- @param confirmText string?
--- @param cancelText string?
--- @param confirmCallback function?
--- @param cancelCallback function?
--- @param timeoutSeconds number?
--- @param components integer?
--- @return ConfirmPopup?
function ConfirmPopup:Show(message, confirmText, cancelText, confirmCallback, cancelCallback, timeoutSeconds, components)
    self:Close()

    message = message or "Are you sure?"
    confirmText = confirmText or "Confirm"
    cancelText = cancelText or "Cancel"
    timeoutSeconds = timeoutSeconds and math.max(0, timeoutSeconds) or nil
    components = components or 2
    
    self:_createWindow(message, confirmText, cancelText, confirmCallback, cancelCallback, timeoutSeconds, components)

    return self
end

function ConfirmPopup:_createWindow(message, confirmText, cancelText, confirmCallback, cancelCallback, timeoutSeconds, components)
    if self.isVisible then
        return
    end

    local screenWidth, screenHeight = UIHelpers.GetScreenSize()
    local scale = UIHelpers.GetUIScale() or 1

    local baseHeight = screenHeight * 0.12
    local baseWidth = baseHeight * 3.5

    local width = math.max(baseWidth , #message * 20 + 200) * scale --baseWidth * scale
    local height = baseHeight * scale

    self.panel = Ext.IMGUI.NewWindow("RB_ConfirmPopup")

    WindowManager.ApplyGuiParams(self.panel)

    self.panel.NoMove = true
    self.panel.NoResize = true
    self.panel.NoCollapse = true
    self.panel.NoTitleBar = true

    self.panel:SetPos({(screenWidth - width) / 2, (screenHeight - height) / 2})
    self.panel:SetSize({width, height})

    self.panel:SetStyle("WindowRounding", 8)
    self.panel:SetStyle("WindowPadding", 15, 10)

    self:_buildContent(width, height, message, confirmText, cancelText, confirmCallback, cancelCallback, timeoutSeconds, components)

    self.isVisible = true
    self.panel:SetFocus()
end

function ConfirmPopup:_buildContent(width, height, message, confirmText, cancelText, confirmCallback, cancelCallback, timeoutSeconds, components)
    self.panel:AddDummy(0, height * 0.08)

    local messageText = self.panel:AddSeparatorText(message)
    messageText:SetStyle("SeparatorTextAlign", 0.5, 0.5)
    messageText.TextWrapPos = width * 0.75

    self.panel:AddDummy(0, height * 0.12)


    local buttonTable = self.panel:AddTable("ConfirmButtons", 5)
    buttonTable.ColumnDefs[1] = { WidthStretch = true }
    buttonTable.ColumnDefs[2] = { WidthStretch = true }
    buttonTable.ColumnDefs[3] = { WidthStretch = true }
    buttonTable.ColumnDefs[4] = { WidthStretch = true }
    buttonTable.ColumnDefs[5] = { WidthStretch = true }

    local row = buttonTable:AddRow()

    local confirmButton = nil
    local cancelButton = nil

    if components == 1 then
        row:AddCell()
        row:AddCell()
        cancelButton = row:AddCell():AddButton(cancelText)
        row:AddCell()
        confirmButton = row:AddCell():AddButton(confirmText)
        confirmButton.Visible = false
    else
        row:AddCell()
        confirmButton = row:AddCell():AddButton(confirmText)
        row:AddCell()
        cancelButton = row:AddCell():AddButton(cancelText)
        row:AddCell()
    end

    local buttonWidth = width * 0.2
    local buttonHeight = height * 0.25

    confirmButton.Size = {buttonWidth, buttonHeight}
    cancelButton.Size = {buttonWidth, buttonHeight}

    confirmButton:SetStyle("ButtonTextAlign", 0.5)
    cancelButton:SetStyle("ButtonTextAlign", 0.5)

    self._getCurrentConfirmButton = function()
        return confirmButton
    end

    self._getCurrentCancelButton = function()
        return cancelButton
    end

    confirmButton.OnClick = function()
        self:_onConfirm(confirmCallback)
    end

    cancelButton.OnClick = function()
        self:_onCancel(cancelCallback)
    end

    if timeoutSeconds and timeoutSeconds > 0 then
        self:_setupTimeout(timeoutSeconds, cancelText, cancelButton, cancelCallback)
    end

    self.enterKeySubscription = InputEvents.SubscribeKeyInput({ Key= "RETURN", Pressed = true }, function()
        self:_onConfirm(confirmCallback)
    end)
    self.escapeKeySubscription = InputEvents.SubscribeKeyInput({ Key= "ESCAPE" }, function()
        self:_onCancel(cancelCallback)
    end)
end

function ConfirmPopup:_setupTimeout(timeoutSeconds, originalCancelText, cancelButton, cancelCallback)
    self.timeRemaining = timeoutSeconds

    local function updateButtonText()
        if cancelButton and self.isVisible then
            cancelButton.Label = originalCancelText .. " (" .. self.timeRemaining .. "s)"
        end
    end

    updateButtonText()

    self.timer = Timer:Every(1000, function()
        if not self.isVisible then
            return
        end

        self.panel:SetFocus()

        self.timeRemaining = self.timeRemaining - 1

        if self.timeRemaining <= 0 then
            self:_onCancel(cancelCallback)
        else
            updateButtonText()
        end
    end)
end

function ConfirmPopup:_onConfirm(confirmCallback)
    if not self.isVisible then
        return
    end

    self:Close()

    if confirmCallback then
        local success, result = pcall(confirmCallback, self.GetConfirmValue and self:GetConfirmValue() or nil)
        if not success then
            Error("[ConfirmPopup] Error in confirm callback" .. tostring(result))
        end
    end

end

function ConfirmPopup:_onCancel(cancelCallback)
    if not self.isVisible then
        return
    end
    
    self:Close()

    local success = true
    if cancelCallback then
        success = pcall(cancelCallback)
        if not success then
            Error("[ConfirmPopup] Error in cancel callback")
        end
    end

end

function ConfirmPopup:Close()
    if not self.isVisible then return end

    self.isVisible = false

    if self.timer then
        Timer:Cancel(self.timer)
        self.timer = nil
    end

    if self.panel then
        pcall(function()
            self.panel:Destroy()
        end)
        self.panel = nil
    end

    if ConfirmPopup._currentInstance == self then
        ConfirmPopup._currentInstance = nil
    end

    if self.enterKeySubscription then
        self.enterKeySubscription:Unsubscribe()
        self.enterKeySubscription = nil
    end

    if self.escapeKeySubscription then
        self.escapeKeySubscription:Unsubscribe()
        self.escapeKeySubscription = nil
    end
end

function ConfirmPopup:IsValid()
    return self.isVisible and self.panel ~= nil
end

---@param message string
---@param onConfirm function?
---@param onCancel function?
---@param timeoutSeconds number?
---@return ConfirmPopup?
function ConfirmPopup:QuickConfirm(message, onConfirm, onCancel, timeoutSeconds)
    local popupInstance =  ConfirmPopup:Show(message, "Yes", "No", onConfirm, onCancel, timeoutSeconds)

    if not popupInstance then
        return nil
    end
    
    local confirmButton = popupInstance._getCurrentConfirmButton and popupInstance._getCurrentConfirmButton() or nil
    if confirmButton then
        StyleHelpers.ApplyConfirmButtonStyle(confirmButton)
    end

    local cancelButton = popupInstance._getCurrentCancelButton and popupInstance._getCurrentCancelButton() or nil
    if cancelButton then
        StyleHelpers.ApplyDangerButtonStyle(cancelButton)
    end

    return popupInstance
end

---@param message string
---@param timeoutSeconds number?
---@param onConfirm function?
---@param onCancel function?
---@return ConfirmPopup?
function ConfirmPopup:TimedConfirm(message, timeoutSeconds, onConfirm, onCancel)
    return ConfirmPopup:Show(message, GetLoca("Confirm"), GetLoca("Cancel"), onConfirm, onCancel, timeoutSeconds)
end

---@param message string
---@param onConfirm function?
---@param onCancel function?
---@param confirmText string?
---@param cancelText string?
---@return ConfirmPopup?
function ConfirmPopup:DangerConfirm(message, onConfirm, onCancel, confirmText, cancelText)
    confirmText = confirmText or GetLoca("DELETE")
    cancelText = cancelText or GetLoca("Cancel")
    local popupInstance = ConfirmPopup:Show(message, confirmText, cancelText, onConfirm, onCancel, 10)

    if not popupInstance then
        return nil
    end
    
    local deleteButton = popupInstance._getCurrentConfirmButton and popupInstance._getCurrentConfirmButton() or nil
    if deleteButton then
        StyleHelpers.ApplyDangerButtonStyle(deleteButton)
    end

    return popupInstance
end

function ConfirmPopup:Popup(message)
    local popupInstance = ConfirmPopup:Show(message, nil, GetLoca("OK"), nil, nil, 5, 1)

    if not popupInstance then
        return nil
    end

    local okButton = popupInstance._getCurrentCancelButton and popupInstance._getCurrentCancelButton() or nil
    if okButton then
        StyleHelpers.ApplyConfirmButtonStyle(okButton)
    end

    return popupInstance
end