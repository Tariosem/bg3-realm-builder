---@param input ExtuiInputText
---@param callback fun(input:string)
function SetupInputEnterCallback(input, callback)
    local sub = nil

    sub = SubscribeKeyInput({}, function (e)
        local ok, focused = pcall(IsFocused, input)
        if not ok then
            Warning("[SetupInputEnterCallback] Failed to check focus state of input, unsubscribing key input listener.")
            return UNSUBSCRIBE_SYMBOL
        end

        local inputText = input.Text
        if not inputText or inputText == "" then
            return
        end

        if e.Key == "RETURN" and focused then
            callback(inputText)
            return UNSUBSCRIBE_SYMBOL
        end
    end)

    return sub
end