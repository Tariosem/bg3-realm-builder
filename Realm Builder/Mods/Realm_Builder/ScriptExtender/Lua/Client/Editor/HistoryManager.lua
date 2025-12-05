--- @class HistoryCommand
--- @field Undo fun()
--- @field Redo fun()
--- @field Description string

--- @class HistoryManager
--- @field History table<number, HistoryCommand>
--- @field MaxHistory number
HistoryManager = {
    UndoStack = {},
    RedoStack = {},
    MaxHistory = 100,
}

--- @param command HistoryCommand
function HistoryManager:PushCommand(command)
    self.RedoStack = {}

    table.insert(self.UndoStack, command)

    if #self.UndoStack > self.MaxHistory then
        table.remove(self.UndoStack, 1)
    end
end

function HistoryManager:Undo()
    local command = table.remove(self.UndoStack)
    if command then
        command:Undo()
        if command.Description then
            Debug("Undo: " .. command.Description)
        end
        table.insert(self.RedoStack, command)
    end
end

function HistoryManager:Redo()
    local command = table.remove(self.RedoStack)
    if command then
        command:Redo()
        if command.Description then
            Debug("Redo: " .. command.Description)
        end
        table.insert(self.UndoStack, command)
    end
end

function HistoryManager:Clear()
    self.UndoStack = {}
    self.RedoStack = {}
end

NetChannel.ClearHistory:SetHandler(function(self, data)
    HistoryManager:Clear()
end)