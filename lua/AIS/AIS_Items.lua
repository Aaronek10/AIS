AIS_Items = {
    ArmorTest = {
        Icon = "materials/AIS_Items/LightArmor.png",
        Name = "Light Military Armor",
        Description = "One of the basic armors used by military. Isn't great, but grants some protection.",
        Slot = "Torso",
        EquipSound = "",
        UnEquipSound = "",
        OnEquip = function(ply, item)
            -- Default equip function
        end,
        OnUnEquip = function(ply, item)
            -- Default unequip function
        end,
        WhenWearing = function(ply, item)
            -- Default wearing function
        end,
        Attributes = {
            ["ArmorPoints"] = 25,
        },
        ClientHooks = {},
        ServerHooks = {}
    },
    BootsTest = {
        Icon = "materials/AIS_Items/boots.png",
        Name = "Armor Boots",
        Description = "Common boots armor.",
        Slot = "Boots",
        OnEquip = function(ply, item)
            -- Default equip function
        end,
        OnUnEquip = function(ply, item)
            -- Default unequip function
        end,
        WhenWearing = function(ply, item)
            -- Default wearing function
        end,
        Attributes = {
            ["ArmorPoints"] = 0,
            ["ELArmorPoints"] = 0,
        },
        ClientHooks = {},
        ServerHooks = {}
    },
    GlovesTest = {
        Icon = "materials/AIS_Items/gloves.png",
        Name = "Armor Gloves",
        Description = "Common Gloves armor.",
        Slot = "Gloves",
        OnEquip = function(ply, item)
            -- Default equip function
        end,
        OnUnEquip = function(ply, item)
            -- Default unequip function
        end,
        WhenWearing = function(ply, item)
            -- Default wearing function
        end,
        Attributes = {
            ["ArmorPoints"] = 15,
            ["ELArmorPoints"] = 5,
        },
        ClientHooks = {},
        ServerHooks = {}
    },
    GlovesTestA = {
        Icon = "materials/AIS_Items/glovesA.png",
        Name = "Armor Gloves A",
        Description = "Common Gloves armor.",
        Slot = "Gloves",
        OnEquip = function(ply, item)
            -- Default equip function
        end,
        OnUnEquip = function(ply, item)
            -- Default unequip function
        end,
        WhenWearing = function(ply, item)
            -- Default wearing function
        end,
        Attributes = {
            ["ArmorPoints"] = 0,
            ["ELArmorPoints"] = 0,
        },
        ClientHooks = {},
        ServerHooks = {}
    },
    TrinketTestA = {
        Icon = "entities/sent_ball.png",
        Name = "Trinket A",
        Description = "Common trinket.",
        Slot = {"Trinket 1", "Trinket 2", "Trinket 3", "Trinket 4"},
        OnEquip = function(ply, item)
            -- Default equip function
        end,
        OnUnEquip = function(ply, item)
            -- Default unequip function
        end,
        WhenWearing = function(ply, item)
            -- Default wearing function
        end,
        Attributes = {
            ["ArmorPoints"] = 0,
            ["ELArmorPoints"] = 1250,
        },
        ClientHooks = {},
        ServerHooks = {}
    },
    TrinketTestB = {
        Icon = "entities/sent_ball.png",
        Name = "Trinket B",
        Description = "Common trinket A.",
        Slot = {"Trinket 1", "Trinket 2", "Trinket 3", "Trinket 4"},
        OnEquip = function(ply, item)
            -- Default equip function
        end,
        OnUnEquip = function(ply, item)
            -- Default unequip function
        end,
        WhenWearing = function(ply, item)
            -- Default wearing function
        end,
        Attributes = {
            ["ArmorPoints"] = 5500,
            ["ELArmorPoints"] = 0,
        },
        ClientHooks = {},
        ServerHooks = {}
    }
}