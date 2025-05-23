if SERVER then
    -- Physical Damage Types
    local Physical = {
        DMG_CRUSH,
        DMG_BULLET,
        DMG_SLASH,
        DMG_VEHICLE,
        DMG_BLAST,
        DMG_CLUB,
        DMG_BLAST_SURFACE,
        DMG_BUCKSHOT,
        DMG_SNIPER,
        DMG_MISSILEDEFENSE,
        DMG_PHYSGUN,
        DMG_AIRBOAT
    }

    -- Elemental Damage Types
    local Elemental = {
        DMG_BURN,
        DMG_SHOCK,
        DMG_SONIC,
        DMG_POISON,
        DMG_RADIATION,
        DMG_ACID,
        DMG_SLOWBURN,
        DMG_NERVEGAS,
        DMG_DISSOLVE,
        DMG_PLASMA
    }
    
    -------------------[DAMAGE REDUCTION]-----------------------
    --[[ 
        This function calculates the damage reduction based on the armor value.
        It uses a formula to determine the reduction percentage based on the armor value.
        The formula is:
            - If armor >= 0: reduction = 100 / (100 + armor)
            - If armor < 0: reduction = 1 + abs(armor) / 100
    ]]
    function CalculateDamageReduction(armor)
        if armor >= 0 then
            return 100 / (100 + armor)
        else
            return 1 + math.abs(armor) / 100
        end
    end

    CreateConVar("AIS_Debug", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable debug messages for AIS", 0, 1)

    AIS_DebugMode = GetConVar("AIS_Debug"):GetBool()

    cvars.AddChangeCallback("AIS_Debug", function(convar_name, old_value, new_value)
        AIS_DebugMode = tobool(new_value)
        print("[AIS] Debug mode changed to:", AIS_DebugMode)
    end, "AIS_Debug_Changed")

    CreateConVar("AIS_RealismMode", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable realism mode (hitgroup-based armor reduction)", 0, 1)
    AIS_RealismMode = GetConVar("AIS_RealismMode"):GetBool()

    cvars.AddChangeCallback("AIS_RealismMode", function(convar_name, old_value, new_value)
        AIS_RealismMode = tobool(new_value)
        print("[AIS] Realism mode changed to:", AIS_RealismMode)
    end, "AIS_RealismMode_Changed")

    -----------------------[DAMAGE REDUCTION]-----------------------
    --[[ 
        This function handles the damage reduction based on the equipped items' armor and elemental armor.
        It checks the damage type and applies the appropriate reduction based on the equipped items.
    ]]
    hook.Add("EntityTakeDamage", "AIS_HandleArmorReduction", function(ply, dmginfo)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local slotTable = AIS_EquipedSlots[ply]
        if not slotTable then return end

        local totalArmor = 0
        local totalElArmor = 0
        local IfArmored = false

        local function AddItemArmor(itemID)
            local itemData = AIS_Items[itemID]
            if itemData and itemData.Attributes then
                local armor = itemData.Attributes.ArmorPoints or 0
                local elArmor = itemData.Attributes.ELArmorPoints or 0
                totalArmor = totalArmor + armor
                totalElArmor = totalElArmor + elArmor
            end
        end

        if AIS_RealismMode then
            local hitgroup = ply:LastHitGroup()
            local slotForHitGroup = {
                [HITGROUP_HEAD] = {"Head"},
                [HITGROUP_CHEST] = {"Torso"},
                [HITGROUP_STOMACH] = {"Torso"},
                [HITGROUP_LEFTARM] = {"Arms", "Gloves"},
                [HITGROUP_RIGHTARM] = {"Arms", "Gloves"},
                [HITGROUP_LEFTLEG] = {"Pants", "Boots"},
                [HITGROUP_RIGHTLEG] = {"Pants", "Boots"},
                [HITGROUP_GENERIC] = {"Torso"},
            }

            local slots = slotForHitGroup[hitgroup]
            if slots then
                for _, slot in ipairs(slots) do
                    if slotTable[slot] then
                        AddItemArmor(slotTable[slot])
                        IfArmored = true -- ✅ pancerz pokrywa miejsce trafienia
                    end
                end
            end
        else
            for _, itemID in pairs(slotTable) do
                AddItemArmor(itemID)
            end
            IfArmored = totalArmor > 0 -- opcjonalnie, żeby w trybie arcade też był efekt
        end

        local dmgType = dmginfo:GetDamageType()
        local dmg = dmginfo:GetDamage()
        local reduction = 1

        for _, typ in ipairs(Physical) do
            if bit.band(dmgType, typ) > 0 then
                reduction = reduction * CalculateDamageReduction(totalArmor)
            end
        end

        for _, typ in ipairs(Elemental) do
            if bit.band(dmgType, typ) > 0 then
                reduction = reduction * CalculateDamageReduction(totalElArmor)
            end
        end

        local finalDmg = dmg * reduction
        dmginfo:SetDamage(finalDmg)
        ply.AIS_LastHitPosition = dmginfo:GetDamagePosition()
        ply.AIS_InflictorPosition = dmginfo:GetInflictor():GetPos()


        timer.Simple(0, function()
            if not IsValid(ply) then return end

            local effectData = EffectData()
            effectData:SetOrigin(ply.AIS_LastHitPosition)

            if IfArmored then
                effectData:SetNormal(ply.AIS_InflictorPosition - ply.AIS_LastHitPosition)
                util.Effect("MetalSpark", effectData)
            else
                util.Effect("BloodImpact", effectData)
            end
        end)

        if AIS_DebugMode then
            local hitgroupNames = {
                [HITGROUP_HEAD] = "Head",
                [HITGROUP_CHEST] = "Torso",
                [HITGROUP_STOMACH] = "Torso",
                [HITGROUP_LEFTARM] = "Arms",
                [HITGROUP_RIGHTARM] = "Arms",
                [HITGROUP_LEFTLEG] = "Pants",
                [HITGROUP_RIGHTLEG] = "Pants",
                [HITGROUP_GEAR] = "Gear",
                [HITGROUP_GENERIC] = "Generic",
            }
            local hitName = hitgroupNames[ply:LastHitGroup()] or "Unknown"
            print(("[AIS] Damage reduced from %.2f to %.2f (Hitgroup: %s, Armor Absorbed: %s)"):format(dmg, finalDmg, hitName, tostring(IfArmored)))
        end
    end)


    hook.Add("PlayerSpawn", "AIS_ArmorBloodEffect", function(ply) 
        ply:SetBloodColor(DONT_BLEED)
    end)
    
    hook.Add("PlayerInitialSpawn", "AIS_ArmorBloodEffect", function(ply) 
        ply:SetBloodColor(DONT_BLEED)
    end)


    local function CreateItemsHooks()
        for itemID, itemData in pairs(AIS_Items) do
            if itemData.ServerHooks then
                for index, hookData in ipairs(itemData.ServerHooks) do
                    if hookData.HookType then
                        local hookID = "AIS_ITEM_SERVERHOOK_" .. itemID .. "_" .. tostring(index)

                        -- Zabezpieczenie
                        if type(hookData.HookFunction) ~= "function" then
                            print("[AIS] Invalid HookFunction in item: " .. itemID)
                            continue
                        end

                        -- Tworzenie lub aktualizacja hooka
                        if not hookData.HookInit then
                            hookData.LastHookFunction = hookData.HookFunction

                            print("[AIS] Created item hook: " .. itemID .. " | Hook: " .. hookID)

                            hook.Add(hookData.HookType, hookID, function(...)
                                hookData.HookFunction(...)
                            end)

                            hookData.HookInit = true
                        elseif hookData.LastHookFunction ~= hookData.HookFunction then
                            print("[AIS] Updated item hook: " .. itemID .. " | Hook: " .. hookID)

                            hook.Add(hookData.HookType, hookID, function(...)
                                hookData.HookFunction(...)
                            end)

                            hookData.LastHookFunction = hookData.HookFunction
                        end
                    end
                end
            end
        end
    end

    hook.Add("Think", "AIS_ApplyWhenWearing", function()
        for _, ply in ipairs(player.GetAll()) do
            local slots = AIS_EquipedSlots[ply]
            if not slots then continue end

            for _, item in pairs(slots) do
                local itemData = AIS_Items[item]
                if itemData and isfunction(itemData.WhenWearing) then
                    local args = itemData.ExtraWearingArgs or {}
                    itemData.WhenWearing(ply, item, unpack(args))
                end
            end
        end
    end)

    hook.Add("PlayerSpawn", "AIS_OnEquipOnRespawn", function(ply)
        local slots = AIS_EquipedSlots[ply]
        if not slots then return end

        for _, item in pairs(slots) do
            local itemData = AIS_Items[item]
            if itemData and isfunction(itemData.OnEquip) then
                local args = itemData.ExtraEquipArgs or {}
                itemData.OnEquip(ply, item, unpack(args))
            end
        end
    end)



    hook.Add("InitPostEntity", "AIS_CreateHooks", function() 
        CreateItemsHooks()
    end)

    concommand.Add("AIS_CreateItemHooks", function(ply, cmd, args)
        CreateItemsHooks()
    end, nil, "Reloads or creates all AIS hooks.")
end

if CLIENT then
    local function CreateClientItemsHooks()
        for itemID, itemData in pairs(AIS_Items) do
            if itemData.ServerHooks then
                for index, hookData in ipairs(itemData.ClientHooks) do
                    if hookData.HookType then
                        local hookID = "AIS_ITEM_CLIENTHOOK_" .. itemID .. "_" .. tostring(index)

                        -- Zabezpieczenie
                        if type(hookData.HookFunction) ~= "function" then
                            print("[AIS] Invalid HookFunction in item: " .. itemID)
                            continue
                        end

                        -- Tworzenie lub aktualizacja hooka
                        if not hookData.HookInit then
                            hookData.LastHookFunction = hookData.HookFunction

                            print("[AIS] Created item hook: " .. itemID .. " | Hook: " .. hookID)

                            hook.Add(hookData.HookType, hookID, function(...)
                                hookData.HookFunction(...)
                            end)

                            hookData.HookInit = true
                        elseif hookData.LastHookFunction ~= hookData.HookFunction then
                            print("[AIS] Updated item hook: " .. itemID .. " | Hook: " .. hookID)

                            hook.Add(hookData.HookType, hookID, function(...)
                                hookData.HookFunction(...)
                            end)

                            hookData.LastHookFunction = hookData.HookFunction
                        end
                    end
                end
            end
        end
    end

    hook.Add("InitPostEntity", "AIS_CreateHooks", function() 
        CreateClientItemsHooks()
    end)

    concommand.Add("AIS_CreateClientItemHooks", function(ply, cmd, args)
        CreateClientItemsHooks()
    end, nil, "Reloads or creates all AIS hooks.")
end