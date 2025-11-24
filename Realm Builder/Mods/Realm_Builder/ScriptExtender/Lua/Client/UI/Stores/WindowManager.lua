--- @class WindowManager
--- @field RegisterWindow fun(guid: string, displayName: string, iType: string, instance: any, pos: vec2 | nil, size: vec2 | nil): ExtuiWindow | nil

--- @class WindowEntry
--- @field window ExtuiWindow
--- @field type string
--- @field instance Class
--- @field isValid boolean

--- @alias WindowMap table<string, WindowEntry[]>

--- @type WindowMap
local WindowMap = {}

--- @param guid string
--- @param displayName string
--- @param iType string
--- @param instance any
--- @param pos vec2 | nil
--- @param size vec2 | nil
--- @return ExtuiWindow
function RegisterWindow(guid, displayName, iType, instance, pos, size)
    local screenWH = Ext.ClientIMGUI.GetViewportSize()
    local screenWidth, screenHeight = screenWH[1], screenWH[2]
    if WindowMap[guid] == nil then
        WindowMap[guid] = {}
    end

    if not pos then
        pos = {screenWidth * 0.1, screenHeight * 0.2}
    end
    if not size then
        size = {screenWidth * 0.2, screenHeight * 0.6}
    end

    local basename = displayName .. "##" .. guid .. "-" .. iType
    local finalname = basename

    for _, win in ipairs(WindowMap[guid]) do
        if win.isValid and win.finalName == finalname then
            Debug("[Window] Window with name " .. finalname .. " already exists for GUID: " .. guid .. ", deleting existing window.")
            DeleteWindow(win.window)
        end
    end

    --- @type ExtuiWindow
    local windowHandle = Ext.IMGUI.NewWindow(finalname, false)

    if WindowMap[guid] == nil then
        WindowMap[guid] = {}
    end

    if windowHandle then
        table.insert(WindowMap[guid], {window = windowHandle, type = iType or "default", instance = instance or nil, isValid = true, finalName = finalname})
        --Info("[Window] Registered window with GUID: " .. guid .. " and name: " .. displayName .. "-" .. iType)
    else
        Error("[Window] Failed to register window with GUID: " .. guid .. " and name: " .. displayName .. "-" .. iType)
    end

    windowHandle:SetStyle("WindowTitleAlign", 0.5)

    if guid ~= "Citadel" then
        ApplyGuiParams(windowHandle)
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

function DeleteWindow(handle)
    for guid, windows in pairs(WindowMap) do
        for i = #windows, 1, -1 do
            local entry = windows[i]
            if entry.window == handle and entry.isValid then
                entry.window:Destroy()
                entry.isValid = false
                table.remove(windows, i)

                if #windows == 0 then
                    WindowMap[guid] = nil
                end

                return true
            end
        end
    end

    return false
end

function IsWindowValid(handle)
    for guid, windows in pairs(WindowMap) do
        for i = #windows, 1, -1 do
            local entry = windows[i]
            if entry.window == handle then
                return entry.isValid
            end
        end
    end
    return false
end

function CheckWindowExists(guid, iType)
    if not guid or not iType then
        return false
    end

    local windows = WindowMap[guid]
    if not windows then
        return false
    end

    for _, win in ipairs(windows) do
        if win.isValid and win.type == iType then
            --win.window.Open = true
            --win.window:SetFocus()
            return true, win.instance
        end
    end

    return false
end

function GetAllValidWindows()
    local validWindows = {}
    for guid, windows in pairs(WindowMap) do
        for _, win in ipairs(windows) do
            if win.isValid then
                table.insert(validWindows, win.window)
            end
        end
    end
    if GLOBAL_DEBUG_WINDOW then
        table.insert(validWindows, GLOBAL_DEBUG_WINDOW)
    end
    return validWindows
end

function SetAllWindowsStyle(styleVar, paramA, paramB)
    local allWindows = GetAllValidWindows()
    for _, window in ipairs(allWindows) do
        if window and window.SetStyle then
            window:SetStyle(styleVar, paramA, paramB)
        end
    end
end

function SetAllWindowsColor(guiColor, vec4)
    local allWindows = GetAllValidWindows()
    for _, window in ipairs(allWindows) do
        if window then
            window:SetColor(guiColor, vec4)
            --CONFIG.Theme.Color[guiColor] = vec4
        end
    end
end

function ApplyGuiParams(window)
    if not WindowMap["Citadel"] or #WindowMap["Citadel"] == 0 then
        return
    end

    local mainWindow = WindowMap["Citadel"][1].window
    for name,_ in pairs(GetAllGuiColorNames()) do
        local color = mainWindow:GetColor(name)
        if color then
            window:SetColor(name, color)
        end
    end
    for name,_ in pairs(GetAllGuiStyleVarNames()) do
        local a, b = mainWindow:GetStyle(name)
        if a then
            window:SetStyle(name, a, b)
        end
    end
end