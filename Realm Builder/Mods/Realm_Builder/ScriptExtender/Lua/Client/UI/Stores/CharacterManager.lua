--- @class RB_CharacterManager : ManagerBase
--- @field Characters table<string, RB_Character> Mapping of character UUIDs to RB_Character objects
CharacterManager = _Class("CharacterManager", ManagerBase)

local raceCache = {}

function CharacterManager:__init()
    ManagerBase.__init(self)
    self:HardCodeHierachy()
end

function CharacterManager:HardCodeHierachy()
    local raceTagTree = {
        ["Aberrations"] = {
            ["Aberration"] = 0,
            ["Doppelganger"] = 0,
            ["Ettercap"] = 0,
            ["Mind Flayer"] = 0
        },
        ["Beasts"] = {
            ["Badger"] = 0,
            ["Bat"] = 0,
            ["Bear"] = 0,
            ["Beast"] = 0,
            ["Bird"] = 0,
            ["Blink Dog"] = 0,
            ["Boar"] = 0,
            ["Crab"] = 0,
            ["Displacer Beast"] = 0,
            ["Frog"] = 0,
            ["Giant Eagle"] = 0,
            ["Hyena"] = 0,
            ["Rat"] = 0,
            ["Raven"] = 0,
            ["Spider"] = 0,
            ["Tressym"] = 0,
            ["Vengeful Boar"] = 0,
            ["Wolf"] = 0
        },
        ["Celestials"] = {
            ["Aasimar"] = 0,
            ["Celestial"] = 0,
            ["Hollyphant"] = 0
        },
        ["Constructs"] = {
            ["Animated Armour"] = 0,
            ["Automaton"] = 0,
            ["Construct"] = 0,
            ["Crawling Claw"] = 0,
            ["Flesh Golem"] = 0,
            ["Golem"] = 0,
            ["Steel Watcher"] = 0
        },
        ["Dragons"] = {
            ["Dragon"] = 0,
            ["Undead Dragon"] = 0
        },
        ["Elementals"] = {
            ["Azer"] = 0,
            ["Elemental"] = 0,
            ["Mephit"] = 0
        },
        ["Fey Race"] = {
            ["Fey"] = 0,
            ["Hag"] = 0,
            ["Redcap"] = 0,
            ["Shadar-Kai"] = 0
        },
        ["Fiends"] = {
            ["Archdevil"] = 0,
            ["Cambion"] = 0,
            ["Demon"] = 0,
            ["Devil"] = 0,
            ["Fiend"] = 0,
            ["Hellsboar"] = 0,
            ["Imp"] = 0,
            ["Incubus"] = 0,
            ["Merregon"] = 0,
            ["Shadow Mastiff"] = 0,
            ["Succubus"] = 0,
            ["Vengeful Cambion"] = 0,
            ["Vengeful Imp"] = 0
        },
        ["Giants"] = {
            ["Giant"] = 0,
            ["Ogre"] = 0
        },
        ["Humanoids"] = {
            ["CommonRaces"] = {
                ["Dwarf"] = 0,
                ["Elf"] = 0,
                ["Gnome"] = 0,
                ["Halfling"] = 0,
                ["Human"] = 0
            },
            ["Dragonborns"] = {
                ["Black Dragonborn"] = 0,
                ["Blue Dragonborn"] = 0,
                ["Brass Dragonborn"] = 0,
                ["Bronze Dragonborn"] = 0,
                ["Copper Dragonborn"] = 0,
                ["Dragonborn"] = 0,
                ["Gold Dragonborn"] = 0,
                ["Green Dragonborn"] = 0,
                ["Red Dragonborn"] = 0,
                ["Silver Dragonborn"] = 0,
                ["White Dragonborn"] = 0
            },
            ["Drows"] = {
                ["Drow"] = 0,
                ["Lolth-Sworn Drow"] = 0,
                ["Seldarine Drow"] = 0
            },
            ["Dwarves"] = {
                ["Duergar"] = 0,
                ["Gold Dwarf"] = 0,
                ["Shield Dwarf"] = 0
            },
            ["Elves"] = {
                ["High Elf"] = 0,
                ["Wood Elf"] = 0
            },
            ["Githyanki"] = 0,
            ["Gnomes"] = {
                ["Deep Gnome"] = 0,
                ["Forest Gnome"] = 0,
                ["Rock Gnome"] = 0
            },
            ["Goblinoids"] = {
                ["Bugbear"] = 0,
                ["Goblin"] = 0,
                ["Gnoll"] = 0,
                ["Gnoll Flind"] = 0,
                ["Hobgoblin"] = 0,
                ["Kuo-Toa"] = 0
            },
            ["HalfRaces"] = {
                ["Drow Half-Elf"] = 0,
                ["Half-Elf"] = 0,
                ["Half-Orc"] = 0,
                ["High Half-Elf"] = 0,
                ["Wood Half-Elf"] = 0
            },
            ["Halflings"] = {
                ["Lightfoot Halfling"] = 0,
                ["Strongheart Halfling"] = 0
            },
            ["Humanoid"] = 0,
            ["Monstrous"] = {
                ["Butler Of Bhaal"] = 0,
                ["Kobold"] = 0
            },
            ["Shapechangers"] = {
                ["Werewolf"] = 0
            },
            ["Tieflings"] = {
                ["Asmodeus Tiefling"] = 0,
                ["Baalzebul Tiefling"] = 0,
                ["Dispater Tiefling"] = 0,
                ["Fierna Tiefling"] = 0,
                ["Glasya Tiefling"] = 0,
                ["Levistus Tiefling"] = 0,
                ["Mammon Tiefling"] = 0,
                ["Mephistopheles Tiefling"] = 0,
                ["Tiefling"] = 0,
                ["Zariel Tiefling"] = 0
            }
        },
        ["Misc"] = {
            ["Coin Halberd"] = 0,
            ["Companion"] = 0,
            ["Dark Justiciar"] = 0,
            ["Grim Visage"] = 0,
            ["Ooze"] = 0,
            ["Unknown"] = 0
        },
        ["Monstrosities"] = {
            ["Alioramus"] = 0,
            ["Beholder"] = 0,
            ["Bulette"] = 0,
            ["Cloaker"] = 0,
            ["Drider"] = 0,
            ["Gremishka"] = 0,
            ["Harpy"] = 0,
            ["Hook Horror"] = 0,
            ["Meazel"] = 0,
            ["Meenlock"] = 0,
            ["Monstrosity"] = 0,
            ["Phase Spider"] = 0,
            ["Retriever"] = 0
        },
        ["Plants"] = {
            ["Blight"] = 0,
            ["Myconid"] = 0,
            ["Plant"] = 0,
            ["Shambling Mound"] = 0
        },
        ["Undead Race"] = {
            ["Conjured Spectre"] = 0,
            ["Death Knight"] = 0,
            ["Demilich"] = 0,
            ["Flying Ghoul"] = 0,
            ["Ghast"] = 0,
            ["Ghost"] = 0,
            ["Ghoul"] = 0,
            ["Lich"] = 0,
            ["Mummy"] = 0,
            ["Mummy Lord"] = 0,
            ["Shadow"] = 0,
            ["Skeleton"] = 0,
            ["Undead"] = 0,
            ["Undead Mind Flayer"] = 0,
            ["Vampire"] = 0,
            ["Vampire Spawn"] = 0,
            ["Wraith"] = 0,
            ["Zombie"] = 0
        }
    }

    local tabStack = {}

    while #tabStack > 0 do
        local t = table.remove(tabStack)
        for k,v in pairs(t) do
            if type(v) == "table" then
                table.insert(tabStack, v)
            else
                local localized = GetLoca(k)
                t[k] = nil
                t[localized] = v
            end
        end
    end

    self.tagTree:FromTable(raceTagTree)
end

--- @param template CharacterTemplate
function CharacterManager:PopulateCharacter(template)
    self.Data[template.Id] = {
        Uuid = template.Id,
        TemplateId = template.Name .. "_" .. template.Id,
        TemplateName = template.Name,
        DisplayName = template.DisplayName:Get(),
        Icon = "Item_Unknown",
    }

    if not self.Data[template.Id].DisplayName or self.Data[template.Id].DisplayName == "" then
        self.Data[template.Id].DisplayName = self.Data[template.Id].TemplateName
        if not self.Data[template.Id].DisplayName or self.Data[template.Id].DisplayName == "" then
            self.Data[template.Id].DisplayName = "Unknown"
        end
    end


    if template.Race and template.Race ~= "" then
        if raceCache[template.Race] == nil then
            local raceRes = Ext.StaticData.Get(template.Race, "Race") --[[@as ResourceRace]]
            if not raceRes then return end
            local displayName = raceRes and raceRes.DisplayName:Get() or "Unknown"

            raceCache[template.Race] = displayName
            self.Data[template.Id].Tags = self.Data[template.Id].Tags or {}
            table.insert(self.Data[template.Id].Tags, displayName)
        else
            self.Data[template.Id].Tags = self.Data[template.Id].Tags or {}
            table.insert(self.Data[template.Id].Tags, raceCache[template.Race])
        end
    end
end
