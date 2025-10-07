KeybindEvents = KeybindEvents or {}

KeybindEvents.TransformToolbar = {
    ["MultiSelect"] = "MultiSelect",
    ["Select"] = "Select",
    ["Clear Selection"] = "Clear Selection",
    ["Duplicate"] = "Duplicate",
    ["Hide Selection"] = "Hide Selection",
    ["Show Selection"] = "Show Selection",
    ["Apply Gravity"] = "Apply Gravity",
    ["Freeze Gravity"] = "Freeze Gravity",
    ["Box Select"] = "Box Select",
}

KeybindEvents.TransformEditor = {
    ["Translate Mode"] = "Translate Mode",
    ["Rotate Mode"] = "Rotate Mode",
    ["Scale Mode"] = "Scale Mode",
}


DefaultKeybinds = DefaultKeybinds or {}


DefaultKeybinds.TransformToolbar = {
    ["MultiSelect"] = { Key = "M" },
    ["Select"] = { Key = "3" },
    ["Clear Selection"] = { Key = "ESCAPE" },
    ["Duplicate"] = { Key = "D", Modifiers = "LShift" },
    ["Hide Selection"] = { Key = "H" },
    ["Show Selection"] = { Key = "S" },
    ["Apply Gravity"] = { Key = "G", Modifiers = "LCtrl" },
    ["Freeze Gravity"] = { Key = "G", Modifiers = "LShift" },
    ["Box Select"] = { Key = "B" },
}

DefaultKeybinds.TransformEditor = {
    ["Translate Mode"] = { Key = "G" },
    ["Rotate Mode"] = { Key = "R" },
    ["Scale Mode"] = { Key = "L" },
}
