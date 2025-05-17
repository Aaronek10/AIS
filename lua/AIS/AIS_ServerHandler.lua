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

    -----------------------[DAMAGE REDUCTION]-----------------------
    --[[ 
        This function handles the damage reduction based on the equipped items' armor and elemental armor.
        It checks the damage type and applies the appropriate reduction based on the equipped items.
    ]]
    hook.Add("EntityTakeDamage", "AIS_HandleArmorReduction", function(ply, dmginfo)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local slotTable = AIS_EquipedSlots[ply]
        if not slotTable then return end

        local armor = 0
        local elarmor = 0

        for _, itemID in pairs(slotTable) do
            local itemData = AIS_Items[itemID]
            if itemData and itemData.Attributes then
                armor = armor + (itemData.Attributes.ArmorPoints or 0)
                elarmor = elarmor + (itemData.Attributes.ELArmorPoints or 0)
            end
        end

        local dmgType = dmginfo:GetDamageType()
        local dmg = dmginfo:GetDamage()

        local reduction = 1
        for _, typ in ipairs(Physical) do
            if bit.band(dmgType, typ) > 0 then
                reduction = reduction * CalculateDamageReduction(armor)
                --PrintMessage(HUD_PRINTTALK, "Physical Damage Type")
            end
        end

        for _, typ in ipairs(Elemental) do
            if bit.band(dmgType, typ) > 0 then
                reduction = reduction * CalculateDamageReduction(elarmor)
                --PrintMessage(HUD_PRINTTALK, "Elemental Damage Type")
            end
        end

        --[[
        local HitGroupName = {
            [HITGROUP_HEAD] = "Head",
            [HITGROUP_CHEST] = "Chest",
            [HITGROUP_STOMACH] = "Stomach",
            [HITGROUP_LEFTARM] = "Left Arm",
            [HITGROUP_RIGHTARM] = "Right Arm",
            [HITGROUP_LEFTLEG] = "Left Leg",
            [HITGROUP_RIGHTLEG] = "Right Leg",
            [HITGROUP_GEAR] = "Gear"
        }
        ]]--
        local newDmg = dmg * reduction
        --PrintMessage(HUD_PRINTTALK, "Damage changed from: " .. dmg .. " -> " .. newDmg .. " | Damage Reduction %: " .. math.Round((1 - reduction) * 100, 2) .. "%")
        --PrintMessage(HUD_PRINTTALK, "Last Hit Group: " .. HitGroupName[ply:LastHitGroup()])
        dmginfo:SetDamage(newDmg)
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