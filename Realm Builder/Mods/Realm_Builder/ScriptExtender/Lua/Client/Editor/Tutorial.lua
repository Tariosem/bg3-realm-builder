--- @class TutorialManager
--- @field ConfirmTimer integer?
--- @field CurrentStep TutorialStep?
--- @field CurrentQueue TutorialStep[]
--- @field HistoryStack TutorialStep[]
local TutorialManager = {
    ConfirmTimer = nil,
    CurrentQueue = {},
    HistoryStack = {},
}


--- @class TutorialStep
--- @field Position number[] 0-1
--- @field Name string
--- @field Description string
--- @field ParsedDescription RB_TextToken[]
--- @field Confirm fun(self):boolean
--- @field ConfirmByButton boolean
--- @field WrapPos integer -- in characters

local color_lookup = {
    RED = {1, 0, 0, 1},
    GREEN = {0, 1, 0, 1},
    LIGHTBLUE = {0, 0.3, 0.7, 1},
    LIGHTGREEN = {0.5, 1, 0.5, 1},
    VIOLIET = {0.5, 0, 1, 1},
    HIGHLIGHT = UI_COLORS.HighLight,
    H = UI_COLORS.HighLight,
    EMPHASIS = {0.8, 0.5, 0, 1},
    UI = {0.3, 0.8, 0.3, 1}
}

local auto_stop_time = 10 * 60 * 1000

local desColor = nil
local desFont = nil

--- cheap since only used here
--- @param raw string
--- @return RB_TextToken[]
local function parseDescriptionLine(raw)
    --- @class RB_TextToken[]
    local tokens = {}

    local i = 1
    
    while i <= #raw do
        local nextLeft = string.find(raw, "%[", i)
        local nextRight = string.find(raw, "%]", i)

        local left = nextLeft or #raw + 1
        local right = nextRight or #raw + 1

        if left < right then
            -- push left
            if left > i then
                table.insert(tokens, {
                    Text = string.sub(raw, i, left - 1),
                    Color = desColor,
                    Font = desFont,
                    SameLine = true
                })
            end

            local content = string.sub(raw, left + 1, right - 1)

            -- parse content
            if string.find(content, "COLOR:") then
                local colorName = string.match(content, "COLOR:(%w+)")
                desColor = color_lookup[colorName] or desColor
                i = right + 1
            elseif string.find(content, "FONT:") then
                desFont = string.match(content, "FONT:(%w+)") or desFont
                i = right + 1
            elseif string.find(content, "/COLOR") then
                desColor = nil
                i = right + 1
            elseif string.find(content, "/FONT") then
                desFont = nil
                i = right + 1
            elseif string.find(content, ":") then
                local mod, event = string.match(content, "(%w+):(%w+)")
                --- @class RB_TextToken
                local token = {
                    Text = KeybindHelpers.GetPresentationByEvent(mod, event),
                    Color = UI_COLORS.HighLight,
                    Font = desFont,
                    Tooltip = function(panel)
                        local localizedMod = RB_KEYBIND_LOCALIZED_NAMES[mod] or mod
                        local localizedEvent = RB_KEYBIND_LOCALIZED_NAMES[event] or event
                        panel:AddText(localizedMod .. " : " .. localizedEvent):SetColor("Text", {1, 1, 1, 1})
                        panel:AddText("Can be changed in the Keybinds menu"):SetColor("Text", {1, 1, 1, 1})
                    end,
                    SameLine = true
                }
                table.insert(tokens, token)
                i = right + 1
            else
                table.insert(tokens, {
                    Text = string.sub(raw, left, right),
                    Color = desColor,
                    Font = desFont,
                    SameLine = true
                })
                i = right + 1
            end
        else
            if i <= #raw then
                table.insert(tokens, {
                    Text = string.sub(raw, i),
                    Color = desColor,
                    Font = desFont,
                    SameLine = true
                })
            end
            break
        end
    end

    return tokens
end

--- @return RB_TextToken[]
local function parseDescription(raw, wrapPos)
    local lines = {}
    local wrapTokens = RBUtils.WrapTextTokens
    for line in string.gmatch(raw .. "\n", "([^\n]*)\n") do
        if line == "" then
            table.insert(lines, {Text = "", SameLine = false})
            goto continue
        end
        local parsed = parseDescriptionLine(line)
        parsed = wrapTokens(parsed, wrapPos or 50)
        parsed[1].SameLine = false
        for i, token in ipairs(parsed) do
            table.insert(lines, token)
        end

        ::continue::
    end
    return lines
end

function TutorialManager:Init()
    local notif = Notification.new("Tutorial")
    self.TutorialPanel = notif
    notif.NoAnimation = true
    notif.DismissOnTitleClick = false
    notif.Duration = auto_stop_time
    notif.Moveable = true
    notif.PivotOnLeftTop = true
    notif.InstantDismiss = true
end

function TutorialManager:Start()
    if self.ConfirmTimer then
        Timer:Cancel(self.ConfirmTimer)
    end

    self:Step(table.remove(self.CurrentQueue, 1))
end

local function dumpStacks()
    print("[TutorialManager] CurrentQueue:")
    for i, step in ipairs(TutorialManager.CurrentQueue) do
        print(string.format("  %d: %s", i, step.Name))
    end
    print("[TutorialManager] HistoryStack:")
    for i, step in ipairs(TutorialManager.HistoryStack) do
        print(string.format("  %d: %s", i, step.Name))
    end
end

--- @param step TutorialStep
function TutorialManager:Step(step)
    if not step then
        self:Stop()
        return
    end

    if not step.ParsedDescription then
        step.ParsedDescription = parseDescription(step.Description or "", step.WrapPos)
    end

    local renderText = ImguiElements.RenderTokenTexts
    local notif = self.TutorialPanel
    notif:Dismiss()

    local function prevStep()
        if self.ConfirmTimer then
            Timer:Cancel(self.ConfirmTimer)
            self.ConfirmTimer = nil
        end
        table.insert(self.CurrentQueue, 1, step)
        self:Step(table.remove(self.HistoryStack))
    end

    local function nextStep()
        if self.ConfirmTimer then
            Timer:Cancel(self.ConfirmTimer)
            self.ConfirmTimer = nil
        end
        table.insert(self.HistoryStack, step)
        self:Step(table.remove(self.CurrentQueue, 1))
    end

    if step.Confirm then
        self.ConfirmTimer = Timer:EveryFrame(function()
            if step:Confirm() then
                Timer:Cancel(self.ConfirmTimer)
                self.ConfirmTimer = nil
                nextStep()
                return UNSUBSCRIBE_SYMBOL
            end
        end)
    end
    
    notif.Pivot = step.Position or {0.5, 0.2}
    notif.PivotOnLeftTop = not step.PivotOnMiddle
    notif:Show(step.Name, function(panel)
        local actualDes = step.ParsedDescription 
        renderText(panel, actualDes)
 
        local lastLine = panel:AddTable("PrevOrNext", 4)
        lastLine.ColumnDefs[1] = { WidthStretch = true }
        lastLine.ColumnDefs[2] = { WidthFixed = true }
        lastLine.ColumnDefs[3] = { WidthFixed = true }
        lastLine.ColumnDefs[4] = { WidthStretch = true }
        local row = lastLine:AddRow()
        local _, prevBtn, nextBtn, _ = row:AddCell(), row:AddCell(), row:AddCell(), row:AddCell()
            
        if #self.HistoryStack > 0 then
            prevBtn:AddButton("<-").OnClick = prevStep
        end

        if step.ConfirmByButton or not step.Confirm then
            nextBtn:AddButton(#self.CurrentQueue > 0 and "->" or "End").OnClick = nextStep
        end
    end)
end

function TutorialManager:Stop()
    if self.ConfirmTimer then
        Timer:Cancel(self.ConfirmTimer)
        self.ConfirmTimer = nil
    end

    self.CurrentQueue = {}
    self.HistoryStack = {}

    if self.TutorialPanel then
        self.TutorialPanel:Dismiss()
    end
end

--- @type TutorialStep[]
local transformEditorTut = {
    {
        Name = "Transform Editor",
        PivotOnMiddle = true,
        Description =
[[Use the Transform Editor to move, rotate, and scale items in the world.]],
    },
    {
        Name = "Open Transform Toolbar",
        PivotOnMiddle = true,
        Description = "Press [GeneralShortcuts:OpenTransformToolbar] to open the Transform Toolbar.",
        Confirm = function ()
            local mainMenu = RB_GLOBALS.MainMenu
            local transformBar = mainMenu and mainMenu.transformBar
            return transformBar and transformBar.panel and transformBar.panel.Open
        end
    },
    {
        Name = "Select A Item",
        Position = { 0.1, 0.2 },
        Description = [[Hover over an item and press [TransformToolbar:Select] to select an item in the world.
    
[FONT:Small][COLOR:LIGHTGREEN]Tips[/COLOR]: [TransformToolbar:OpenNearbyPopup] can help you select items that are behind other items.
Hold [COLOR:HIGHLIGHT]Ctrl[/COLOR] to select multiple items,
and [TransformToolbar:BoxSelect] to select a group of items.[/FONT]
]],
        Confirm = function ()
            local editor = RB_GLOBALS.TransformEditor
            return editor and editor.Target and #editor.Target > 0 or false
        end
    },
    {
        Name = "Move Gizmo",
        Position = { 0.1, 0.2 },
        Description = 
[[Drag the gizmo to transform the selected item.

Use [TransformEditor:Grab] to move, [TransformEditor:Rotate] to rotate, and [TransformEditor:Scale] to scale the selected item.
Use [TransformEditor:CycleMode] to cycle between move, rotate, scale and transform modes.
Use [COLOR:HIGHLIGHT]X/Y/Z[/COLOR] keys to constrain the transformation to a specific axis.
Use [COLOR:HIGHLIGHT]Shift + X/Y/Z[/COLOR] to constrain the transformation to a specific plane.
Pressing [COLOR:HIGHLIGHT]Shift[/COLOR] for more precise movement.
[COLOR:HIGHLIGHT]Right Click[/COLOR] to cancel the transformation.

Check the [COLOR:LIGHTBLUE]Keybind[/COLOR] menu to see more short-cuts for the transform toolbar.
Some of the keybinds are only available when the toolbar is opened.]],
        WrapPos = 60
    },
    {
        Name = "Change gizmo's behavior",
        Position = { 0.5, 0.05 },
        Description =
[[^You can change the gizmo's behavior by the transform toolbar.
Such as changing the gizmo's orientation, or changing the gizmo's pivot point.
]]
    },
    {
        Name = "Gizmo's behavior",
        Position = { 0.5, 0.05 },
        WrapPos = 120,
        Description = [[Orientation
[COLOR:LIGHTGREEN]Local[/COLOR]: aligned to the selected item's local orientation.
[COLOR:LIGHTGREEN]Global[/COLOR]: aligned to the world orientation.
[COLOR:LIGHTGREEN]View[/COLOR]: aligned to the camera's orientation.
[COLOR:LIGHTGREEN]Parent[/COLOR]: aligned to the selected item's parent's orientation.
[COLOR:LIGHTGREEN]3D Cursor[/COLOR]: aligned to the 3D cursor's orientation. (Create by [TransformToolbar:Move3DCursor])
[COLOR:LIGHTGREEN]Active Element[/COLOR] aligned to the last selected item's orientation.

Pivot
[COLOR:LIGHTGREEN]Indiviual Origins[/COLOR]: at the selected item's origin.
[COLOR:LIGHTGREEN]Median Point[/COLOR]: at the median point of all selected items.
[COLOR:LIGHTGREEN]Active Element[/COLOR]: at the last selected item's origin.
[COLOR:LIGHTGREEN]3D Cursor[/COLOR]: at the 3D cursor's position. (Create by [TransformToolbar:Move3DCursor])
]]
    }
}

--- @type TutorialStep[]
local spawnTut = {
    {
        Name = "Spawn An Item",
        PivotOnMiddle = true,
        Description = "This tutorial will teach you how to spawn an item with the browser and manipulate it with the [COLOR:UI]Outliner Menu[/COLOR].",
    },
    {
        Name = "Open the browser menu",
        PivotOnMiddle = true,
        Description = "Press [GeneralShortcuts:OpenBrowserMenu] to open the [COLOR:UI]Browser Menu[/COLOR].",
        Confirm = function ()
            local mainMenu = RB_GLOBALS.MainMenu
            local browserMenu = mainMenu and mainMenu.browserMenu
            return browserMenu and browserMenu and browserMenu.Open
        end
    },
    {
        Name = "Open the browser",
        PivotOnMiddle = true,
        Description = "Click the [COLOR:LIGHTBLUE]Item/Scenery[/COLOR] button to open the Item/Scenery browser and continue.",
        Confirm = function (self)
            local mainMenu = RB_GLOBALS.MainMenu
            local browsers = mainMenu and mainMenu.browsers
            if not browsers then return false end
            local item = browsers.item
            local scenery = browsers.scenery
            return (item and item.panel and item.panel.Open) or (scenery and scenery.panel and scenery.panel.Open)
        end
    },
    {
        Name = "Browse the browser",
        PivotOnMiddle = true,
        WrapPos = 80,
        Description = [[You can use [COLOR:HIGHLIGHT],< .>[/COLOR] to turn pages in the browser.
Press [COLOR:HIGHLIGHT]F[/COLOR] to quickly add a [COLOR:LIGHTBLUE]Favorite[/COLOR] tag to the item you are hovering.
[COLOR:HIGHLIGHT]Click[/COLOR] on the item to view its detailed information.
[COLOR:HIGHLIGHT]Right Click[/COLOR] to [COLOR:EMPHASIS]spawn[/COLOR] or edit its tags
You can also [COLOR:HIGHLIGHT]Drag and Drop[/COLOR] it to start a [COLOR:EMPHASIS]Placement Preview[/COLOR].

Tag filters are available in the browser, you can [COLOR:HIGHLIGHT]Click[/COLOR] on the tag to include the items by the tag.
Or [COLOR:HIGHLIGHT]Right Click[/COLOR] on the tag to exclude it from the item you are hovering.
The tag filters default to match all tags, but you can change that in the [COLOR:LIGHTBLUE]Misc[/COLOR] menu of the browser.
]],
    },
    {
        Name = "Manage Spawned Items",
        PivotOnMiddle = true,
        WrapPos = 80,
        Description = [[You can manage the items you spawned by the [COLOR:UI]Outliner Menu[/COLOR].
Open it by pressing [GeneralShortcuts:OpenMainMenu] and then click on the Outliner tab.

In outliner menu, you can [COLOR:HIGHLIGHT]Click[/COLOR] on an item to select it,
[COLOR:HIGHLIGHT]Ctrl + Click[/COLOR] to select multiple items, 
[COLOR:HIGHLIGHT]Shift + Click[/COLOR] to select a range of items.
[COLOR:HIGHLIGHT]Click[/COLOR] on the item icon to quickly select it in the transfotm editor.
[COLOR:HIGHLIGHT]Double Click[/COLOR] on the item to rename it.
[FONT:Small](Note: The rename only works in the UI of Realm Builder, it will not change any gameplay.)[/FONT]

To change the height of the upper panel, drag the vertical slider next to the upper panel.]],
    },
    {
        Name = "Context Menu",
        Position = { 0.56, 0.08 },
        Description = [[You can [COLOR:HIGHLIGHT]Right Click[/COLOR] on an item to open the context menu.
Where you can group, copy or delete the item.

[COLOR:HIGHLIGHT]Drag and Drop[/COLOR] a item under a group to add it under the group.
[COLOR:HIGHLIGHT]Right Click[/COLOR] on a group also opens the context menu.
Where functions like [COLOR:LIGHTBLUE]Save as scene[/COLOR] are available.
Learn more about the scene in the [COLOR:VIOLIET]Make Scene[/COLOR] tutorial.
]],
    },
    {
        Name = "Entity Tab",
        Position = { 0.56, 0.5 },
        Description = [[Once you select an item, the entity tab will automatically open at the bottom of the [COLOR:UI]Outliner Menu[/COLOR].
Where you can view and edit the selected item's properties.

[COLOR:LIGHTGREEN]Monitor[/COLOR] tab allows you to view the item's properties, such as its position, rotation, scale, and guid.
[COLOR:LIGHTGREEN]Filter[/COLOR] tab is currently not implemented, but you can still edit the item's icon's color.
[COLOR:LIGHTGREEN]Visual[/COLOR] tab allows you to view and edit the item's visual properties, such as its materials and effects.]]
    },
    {
        Name = "More about the visual tab",
        Position = { 0.56, 0.5 },
        Description = [[In visual tab, you can also save the item's visual properties as a preset
Edit the item then type the name in the input box above, press [COLOR:HIGHLIGHT]Return[/COLOR] or click the [COLOR:LIGHTBLUE]Save[/COLOR] Button to save it.
Once saved, you can select the preset from the combo box below and click [COLOR:LIGHTBLUE]Load[/COLOR] to apply the preset to the item.

[COLOR:HIGHLIGHT]Right Click[/COLOR] on the material or effect to open the context menu, where hides several functions.

[FONT:Small][COLOR:LIGHTGREEN]Tips[/COLOR]: When editing the item's properties, [COLOR:HIGHLIGHT]Right Click[/COLOR] on the sliders to open a popup where you can edit it's min max values, and step size.[/FONT]
]],
    }
}

--- @type TutorialStep[]
local sceneTutorial = {
    {
        Name = "Scene Tutorial",
        PivotOnMiddle = true,
        Description = [[The scene system allows you to save and load a group of items as a scene.
You can save a scene by the group's context menu and then right click to open the context menu,
or manually save all the items in the [COLOR:UI]Scene Menu[/COLOR].]]
    },
    {
        Name = "How the scene works",
        PivotOnMiddle = true,
        WrapPos = 120,
        Description = [[
[COLOR:LIGHTGREEN]To save a scene[/COLOR], you need to choose an [COLOR:EMPHASIS]anchor[/COLOR] item, which will be the reference point of the scene.
All the items in the scene will be saved relative to the [COLOR:EMPHASIS]anchor[/COLOR]'s position, rotation.

[COLOR:LIGHTGREEN]To load a scene[/COLOR], you need to choose an [COLOR:EMPHASIS]anchor[/COLOR] item, and the scene will be loaded relative to the [COLOR:EMPHASIS]anchor[/COLOR]'s position and rotation.

Any visual changes you made to the items will also be saved in the scene]],
    },
    {
        Name = "Open the scene menu",
        PivotOnMiddle = true,
        Description = "Press [GeneralShortcuts:OpenMainMenu] to open the [COLOR:UI]Main Menu[/COLOR], then click on the [COLOR:LIGHTBLUE]Scene[/COLOR] tab to open the [COLOR:UI]Scene Menu[/COLOR].",
    },
    {
        Name = "Choose the anchor",
        PivotOnMiddle = true,
        Description = [[In the [COLOR:UI]Scene Menu[/COLOR], you can choose the [COLOR:EMPHASIS]anchor[/COLOR] item by clicking on the [COLOR:LIGHTBLUE]Anchor[/COLOR] Combo Box]]
    },
    {
        Name = "Name and save the scene",
        PivotOnMiddle = true,
        Description = [[You can name the scene by typing in the input box above the anchor combo box and then save it by pressing [COLOR:HIGHLIGHT]Return[/COLOR] or clicking the [COLOR:HIGHLIGHT]Save[/COLOR] button.
        
The scene will save everything that is currently listed in the [COLOR:UI]Outliner Menu[/COLOR],
you can tick [COLOR:LIGHTBLUE]Visible Props Only[/COLOR] to only save the items that are currently visible in the world.]],
    },
    {
        Name = "Preview the scene",
        PivotOnMiddle = true,
        Description = [[Now the scene is saved, you can see it's listed in the left bottom panel of the [COLOR:UI]Scene Menu[/COLOR].
[COLOR:HIGHLIGHT]Click[/COLOR] on the scene entry to bring more details in the right panel.
[COLOR:HIGHLIGHT]Right Click[/COLOR] on the scene entry to open the context menu, where you can load, preview, or delete the scene.]]
    },
    {
        Name = "Load the scene",
        PivotOnMiddle = true,
        Description = [[Once you load the scene, all the items will be spawned as a group named after the scene name in the [COLOR:UI]Outliner Menu[/COLOR].
You can also preview the scene, which will spawn the items in the world and then delete them after a few seconds.]],
    }
}

--- @type TutorialStep[]
local effectTutorial = {
    {
        Name = "Effect Tutorial",
        PivotOnMiddle = true,
        Description = [[The effect system allows you to add visual effects to items/characters in the world.]]
    },
    {
        Name = "Open the effect menu",
        PivotOnMiddle = true,
        Description = "Press [GeneralShortcuts:OpenMainMenu] to open the [COLOR:UI]Main Menu[/COLOR], then click on the Effect tab to open the [COLOR:UI]Effect Menu[/COLOR].",
    },
    {
        Name = "Create an effect",
        PivotOnMiddle = true,
        Description = [[In the [COLOR:UI]Effect Menu[/COLOR], you can create a new effect by clicking the [COLOR:LIGHTBLUE]Create New Effect[/COLOR] button
There are three types of effects you can create: 
Effect, Spell, Status

We start with the Effect type.

Once you create an effect, 
[COLOR:LIGHTGREEN]Profile tab[/COLOR] will show the effect's name, uuid and icon, and you can change the name of the effect.
[COLOR:LIGHTGREEN]Effects tab[/COLOR] will show the effect's composition, where you can add effects to your custom effect.

Now keep it open for later.
If you closed it, click the effect entry in the [COLOR:UI]Effects Menu[/COLOR] to open it again.]],
    },
    {
        Name = "Find the effects",
        PivotOnMiddle = true,
        Description = [[You can find the effects you want to use in the [COLOR:UI]Effect Browser[/COLOR],
which can be opened through the [COLOR:UI]Browser Menu[/COLOR].
Press [GeneralShortcuts:OpenBrowserMenu] to open the browser menu, then click on the [COLOR:LIGHTBLUE]Effect[/COLOR] button to open the effect browser.]],
    },
    {
        Name = "Browse the effects",
        PivotOnMiddle = true,
        Description = [[You can browse the effects in the effect browser.
It shares a similar logic with the item/scenery browser, you can learn the basic operation from the [COLOR:VIOLIET]Spawn An Item[/COLOR] tutorial.

But instead of Placement Preview, [COLOR:HIGHLIGHT]Drag and Drop[/COLOR] the effect will try to play the effect on the item you dropped it on.]],
    },
    {
        Name = "Details of the effect",
        PivotOnMiddle = true,
        Description = [[[COLOR:HIGHLIGHT]Right Click[/COLOR] the effect in the browser, then click the [COLOR:LIGHTBLUE]Info[/COLOR] button will open a tab with more details about the effect.
The tabs are similar to the custom effect's tabs, where you can view the effect's name, uuid, icon and composition in the Profile tab, and view the effect's composition in the Effects tab.
]]
    },
    {
        Name = "Add effect to your custom effects",
        PivotOnMiddle = true,
        WrapPos = 120,
        Description = [[Once you find an effect you want, you can add it to your custom effect in three ways:

[COLOR:LIGHTGREEN]1: Using the Browser[/COLOR]
Open your custom effect's [COLOR:LIGHTBLUE]Effects[/COLOR] tab, then open the effect browser.
Drag and drop any effect icon directly into your custom effect's composition. [FONT:Small](Note: Multi-effects will add all included effects at once.)[/FONT]

[COLOR:LIGHTGREEN]2: Drag & Drop[/COLOR]
Open the [COLOR:LIGHTBLUE]Effects[/COLOR] tab for both source and custom effects.
Drag an effect entry from the source composition and drop it into your custom effect's composition. [FONT:Small](Note: A highlight will appear when you can drop it)[/FONT]

[COLOR:LIGHTGREEN]3: Copy Uuid[/COLOR]
Copy the effect's UUID and paste it into the input box in your custom effect's composition.

If you want to remove the effect from your list, [COLOR:HIGHLIGHT]Right Click[/COLOR] on the effect and click the [COLOR:LIGHTBLUE]Remove Selected[/COLOR] button in the context menu.

You can add multiple effects to your custom effect.]],
    },
    {
        Name = "Edit the effect",
        PivotOnMiddle = true,
        WrapPos = 120,
        Description = [[Once you add the effect to your custom effect, click on the effect, it should expand a panel with more options for editing the effect.

[FONT:Small][COLOR:LIGHTGREEN]Tips[/COLOR]: You can [COLOR:HIGHLIGHT]Right Click[/COLOR] on the arrow of the ui tree, it will always expand all the descandants of the ui tree.[/FONT]

[COLOR:LIGHTGREEN]Bone Input[/COLOR]: allows you to specify which bone of the item/character the effect should be played on.
The input can be a bone name, or a more indirect way to specify the bone, such as 'root' or 'head'.
[COLOR:LIGHTGREEN]Example[/COLOR]: input [FONT:Tiny]righthand,leftHand[/FONT] then click the [COLOR:LIGHTBLUE]Left Arrow[/COLOR] button next to it to see the output: [FONT:Tiny]Dummy_R_HandFX,Dummy_L_HandFX[/FONT]

If you dont want to play on item/character, you can also set the effect to play at the item/character's position.
]]
    },
    {
        Name = "Play the effect",
        PivotOnMiddle = true,
        WrapPos = 120,
        Description = [[Once you finish editing your custom effect, you can play it on an item/character in the world.

[COLOR:LIGHTGREEN]Step 1[/COLOR]:
Expand the [COLOR:LIGHTBLUE]Selector[/COLOR] in the [COLOR:LIGHTBLUE]Effects[/COLOR] tab of your custom effect, and first select a caster, then select a target.

[FONT:Small](Note: Target mostly matters for beam effects, where the effect will be played from the caster to the target.
Otherwise you can just select the same item/character for both caster and target.)[/FONT]

Once you select a pair of caster and target, it'll get added to the right panel, and you can view and delete the pair in the right panel by clicking on it.

[COLOR:LIGHTGREEN]Step 2[/COLOR]:
Once you finished the pair, expand the below [COLOR:LIGHTBLUE]Controls[/COLOR] panel, and click the [COLOR:LIGHTBLUE]Play[/COLOR] button to play the effect on the selected pair of caster and target.

You can also set a delay for the effect to be loop-played.
]]
    },
    {
        Name = "Spell and Status",
        PivotOnMiddle = true,
        WrapPos = 120,
        Description = [[The spell and status effects are special types of effects that can be used.
They're workaround for photo mode, since the game will create dummies for party memebers when you enter photo mode, 
and the dummyies will not have any effects on them, so you can use the spell and status effects to play on your characters and keep the effects on them in photo mode.

There are composed in a different way, it has multipe fields like 'StartEffect', 'EndEffect' and such.
The way to edit them is the same as the custom effect, you can add effects to those fields by drag and drop.

But the behavior may be different for multi-effct and other effects,

[COLOR:LIGHTGREEN]For multi-effect[/COLOR], you can only select one effect to be played per field and will not be able to edit the bone they play on.
[COLOR:LIGHTGREEN]For others[/COLOR], you can add multiple effects to a field and edit the bone they play on.

You can tell them apart by the tag filter in the browser.
]]
    },
    {
        Name = "Details about the status",
        PivotOnMiddle = true,
        WrapPos = 80,
        Description = [[Status is much simpler, it has one field and you don't need to select target for this one.

You can set status's duration to -1 to make it infinite.

But some effects are designed to play only once while others are designed to loop, 
so when you set the duration to -1,
[COLOR:LIGHTGREEN]Loop effects[/COLOR] will keep playing
[COLOR:LIGHTGREEN]One-shot effects[/COLOR] will only play once and then stop, even if the status is still active.
]],
    },
    {
        Name = "More about the spell",
        PivotOnMiddle = true,
        WrapPos = 80,
        Description = [[Spell is more complicated, it has a lot of fields that you can edit, and they will be played differently according to how you set up the animation.

But usually you don't need to worry about that much, you can change the pose in the photo mode.
so just treat the spell as a container for your effects, and play it like the custom effect.]],
    },
    {
        Name = "Save your custom effect",
        PivotOnMiddle = true,
        Description = [[Once you finish editing your custom effect, you can save it by using the [COLOR:LIGHTBLUE]File[/COLOR] menu in the effect menu,
all the changes you made will not be automatically saved, so you need to save it manually.

Right click on the effect in the effect menu to open the context menu, where you can [COLOR:RED]Delete[/COLOR] the effect from the list]],
    },
}

local funfacts = {
    {
        Name = "Character Creation Apperance Visuals Browser",
        PivotOnMiddle = true,
        WrapPos = 80,
        Description = [[Found in [COLOR:UI]Browser Menu[/COLOR],
This shares a similar logic with the item/scenery browser, you can learn the basic operation from the [COLOR:VIOLIET]Spawn An Item[/COLOR] tutorial.

But this is for adding attachments to your character, such as hairs, horns, tails, and piercings.
You can stack as many attachments as you want.
The tag filter is handy for finding the attachment you want.

To see what attachments your character have, click the combo box next to the [COLOR:LIGHTBLUE]Keywords[/COLOR] input box, and select your character,
then the browser will generate a tag for your character to use. 
To refresh it, select your charcter again.]]
    },
    {
        Name = "Visual Tab",
        PivotOnMiddle = true,
        WrapPos = 80,
        Description = [[You can bind a key to [GeneralShortcuts:OpenVisualTab] to open the visual tab of the item your hovering over. You can also use this to temporarily change your character's visual.]]
    },
    {
        Name = "More to come",
        PivotOnMiddle = true,
        Description = [[]],
    }
}

--- @class TutorialMenu
--- @field Add fun(tabbar: ExtuiTabBar)
local TutorialMenu = {}

--- @param tabbar ExtuiTabBar
function TutorialMenu.Add(tabbar)
    local parent = tabbar:AddTabItem("Tutorial")

    local space = 200 * SCALE_FACTOR
    local makeCenterButtons = function(text, onclick)
        parent:AddDummy(space, 1)
        local btn = parent:AddButton(text)
        btn.OnClick = onclick
        btn.Size = { -space, 0 }
        btn.SameLine = true
    end

    local tuts = {
        {Name = "Transform Editor", Steps = transformEditorTut},
        {Name = "Spawn An Item", Steps = spawnTut},
        {Name = "Make Scene", Steps = sceneTutorial},
        {Name = "Effect", Steps = effectTutorial},
        {Name = "Fun Facts", Steps = funfacts}
    }

    for _, tut in ipairs(tuts) do
        makeCenterButtons(tut.Name, function()
            TutorialManager.CurrentQueue = {}
            for _, step in ipairs(tut.Steps) do
                table.insert(TutorialManager.CurrentQueue, step)
            end
            TutorialManager:Start()
        end)
    end
end

return TutorialMenu