--- @class WindowManager
--- @field RegisterWindow fun(guid: string, displayName: string, iType: string, instance: any, pos: vec2 | nil, size: vec2 | nil): ExtuiWindow
--- @field DeleteWindow fun(handle: ExtuiWindow): boolean
--- @field IsWindowValid fun(handle: ExtuiWindow): boolean
--- @field CheckWindowExists fun(guid: string, iType: string): boolean, Class|nil
--- @field GetAllValidWindows fun(): ExtuiWindow[]
--- @field SetAllWindowsStyle fun(styleVar: GuiStyleVar, paramA: number, paramB: number|nil)
--- @field SetAllWindowsColor fun(guiColor: GuiColor, vec4: vec4)
--- @field ApplyGuiParams fun(window: ExtuiWindow)
WindowManager = WindowManager or {}

--- @class WindowEntry
--- @field window ExtuiWindow
--- @field type string
--- @field instance Class
--- @field isValid boolean

--- @type table<string, WindowEntry[]>
local WindowMap = {}
local handleToEntryMap = {}
local mainWindowHandle = nil

--- @param guid string
--- @param displayName string
--- @param pos vec2 | nil
--- @param size vec2 | nil
--- @return ExtuiWindow
function WindowManager.RegisterWindow(guid, displayName, pos, size)
    local screenWH = Ext.ClientIMGUI.GetViewportSize()
    local screenWidth, screenHeight = screenWH[1], screenWH[2]

    if not screenWidth then
        screenWidth = 3840 * (SCALE_FACTOR or 1)
    end

    if not screenHeight then
        screenHeight = 2160 * (SCALE_FACTOR or 1)
    end

    if WindowMap[guid] == nil then
        WindowMap[guid] = {}
    end

    if not pos then
        pos = { screenWidth * 0.1, screenHeight * 0.2 }
    end
    if not size then
        size = { screenWidth * 0.2, screenHeight * 0.6 }
    end

    local localizedDisplayName = GetLoca(displayName)
    local basename = localizedDisplayName .. "##" .. guid
    local finalname = basename

    local exists = WindowMap[finalname]
    if exists then
        WindowManager.DeleteWindow(exists.window)
        --Warning("[WindowManager] Window with name " .. finalname .. " already exists. Deleting existing window.")
    end
    
    --- @type ExtuiWindow
    local windowHandle = Ext.IMGUI.NewWindow(finalname)

    local newEntry = {
        window = windowHandle,
        isValid = true,
        finalName = finalname,
    }

    WindowMap[finalname] = newEntry
    handleToEntryMap[windowHandle] = finalname

    windowHandle:SetStyle("WindowTitleAlign", 0.5)

    if guid ~= "Citadel" then
        WindowManager.ApplyGuiParams(windowHandle)
    end

    if pos[1] + size[1] > screenWidth then
        pos[1] = screenWidth - size[1]
    end
    if pos[2] + size[2] > screenHeight then
        pos[2] = screenHeight - size[2]
    end

    windowHandle:SetPos(pos)
    windowHandle:SetSize(size)
    --windowHandle:SetFocus()

    return windowHandle
end

function WindowManager.SetMainWindowHandle(handle)
    mainWindowHandle = handle
end

--- @param handle ExtuiWindow
--- @return boolean
function WindowManager.DeleteWindow(handle)
    local finalName = handleToEntryMap[handle]
    if finalName then
        local entry = WindowMap[finalName]
        if entry then
            entry.isValid = false
            WindowMap[finalName] = nil
        end

        handleToEntryMap[handle] = nil

        handle:Destroy()
        return true
    end

    return false
end

function WindowManager.GetAllValidWindows()
    local validWindows = {}
    for _, entry in pairs(WindowMap) do
        if entry.isValid then
            table.insert(validWindows, entry.window)
        end
    end
    if GLOBAL_DEBUG_WINDOW then
        table.insert(validWindows, GLOBAL_DEBUG_WINDOW)
    end
    return validWindows
end

function WindowManager.SetAllWindowsStyle(styleVar, paramA, paramB)
    local allWindows = WindowManager.GetAllValidWindows()
    for _, window in ipairs(allWindows) do
        if window and window.SetStyle then
            window:SetStyle(styleVar, paramA, paramB)
        end
    end
end

function WindowManager.SetAllWindowsColor(guiColor, vec4)
    local allWindows = WindowManager.GetAllValidWindows()
    for _, window in ipairs(allWindows) do
        if window then
            window:SetColor(guiColor, vec4)
        end
    end
end

--- @param window ExtuiTreeParent
function WindowManager.ApplyGuiParams(window)
    local mainWindow = mainWindowHandle
    if not mainWindow then return end
    for name, _ in pairs(GetAllGuiColorNames()) do
        local color = mainWindow:GetColor(name)
        if color then
            window:SetColor(name, color)
        end
    end
    for name, _ in pairs(GetAllGuiStyleVarNames()) do
        local a, b = mainWindow:GetStyle(name)
        if a then
            window:SetStyle(name, a, b)
        end
    end
end
