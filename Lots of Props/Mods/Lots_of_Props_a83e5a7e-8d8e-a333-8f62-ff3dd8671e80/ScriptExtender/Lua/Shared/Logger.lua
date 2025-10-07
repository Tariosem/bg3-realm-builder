Logger = {
    logFile = "LOP_Logger.txt",
    buffer = {},
    autoFlush = true,
}

--- @param message string
function Logger.Log(message)
    local logLine = message
    if Logger.autoFlush then
        Logger.FlushLine(logLine)
    else
        table.insert(Logger.buffer, logLine)
    end
end

function Logger.FlushLine(line)
    local prev = Ext.IO.LoadFile(Logger.logFile) or ""
    local ok = Ext.IO.SaveFile(Logger.logFile, prev .. line .. "\n")
    if not ok then
        Ext.Utils.PrintError("Failed to write to log file: " .. Logger.logFile)
    end
end

function Logger.Flush()
    if #Logger.buffer > 0 then
        local prev = Ext.IO.LoadFile(Logger.logFile) or ""
        local content = table.concat(Logger.buffer)
        local ok = Ext.IO.SaveFile(Logger.logFile, prev .. content .. "\n")
        if not ok then
            Ext.Utils.PrintError("Failed to write log buffer to file.")
        else
            Logger.buffer = {}
        end
    end
end

function Logger.ToggleAutoFlush()
    Logger.autoFlush = not Logger.autoFlush
    if Logger.autoFlush then
        Ext.Utils.Print("Logger auto-flush enabled.")
    else
        Ext.Utils.Print("Logger auto-flush disabled. Logs will be buffered until manually flushed.")
    end
end
