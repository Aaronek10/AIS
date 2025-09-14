if SERVER then

    util.AddNetworkString("AIS_SyncEventHandler")

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

    -- Non-blocked Damage Types
    -- These damage types will not be reduced by armor or elemental armor.
    local NotBlocked = {
        DMG_FALL,
        DMG_GENERIC,
        DMG_PREVENT_PHYSICS_FORCE
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
                [HITGROUP_HEAD] = "Head",
                [HITGROUP_CHEST] = "Chest",
                [HITGROUP_STOMACH] = "Chest",
                [HITGROUP_LEFTARM] = {"Arms", "Gloves"},
                [HITGROUP_RIGHTARM] = {"Arms", "Gloves"},
                [HITGROUP_LEFTLEG] = {"Pants", "Boots"},
                [HITGROUP_RIGHTLEG] = {"Pants", "Boots"},
                [HITGROUP_GENERIC] = "Chest",
            }

            local rawSlot = slotForHitGroup[hitgroup]
            local targetSlots = istable(rawSlot) and rawSlot or {rawSlot}

            if targetSlots then
                for slot, itemID in pairs(slotTable) do
                    local itemData = AIS_Items[itemID]
                    if not itemData then continue end

                    if table.HasValue(targetSlots, slot) then
                        AddItemArmor(itemID)
                        IfArmored = true
                    end

                    local covers = itemData.CoverHitGroup
                    if covers then
                        local coverTable = istable(covers) and covers or {covers}
                        for _, coveredSlot in ipairs(coverTable) do
                            if table.HasValue(targetSlots, coveredSlot) then
                                AddItemArmor(itemID)
                                IfArmored = true
                                break
                            end
                        end
                    end
                end
            end
        else
            -- Classic tryb bez hitgroup
            for _, itemID in pairs(slotTable) do
                AddItemArmor(itemID)
            end
            IfArmored = totalArmor > 0
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
        if IsValid(dmginfo:GetInflictor()) then
            ply.AIS_InflictorPosition = dmginfo:GetInflictor():GetPos()
        elseif IsValid(dmginfo:GetAttacker()) then
            ply.AIS_InflictorPosition = dmginfo:GetAttacker():GetPos()
        else
            ply.AIS_InflictorPosition = ply:WorldSpaceCenter()
        end



        timer.Simple(0, function()
            if not IsValid(ply) then return end

            local effectData = EffectData()
            effectData:SetOrigin(ply.AIS_LastHitPosition)

            if IfArmored then
                effectData:SetNormal(ply.AIS_InflictorPosition - ply.AIS_LastHitPosition)
                util.Effect("MetalSpark", effectData)
            else
                effectData:SetColor(0)
                util.Effect("BloodImpact", effectData)
            end
        end)

        if AIS_DebugMode then
            local hitgroupNames = {
                [HITGROUP_HEAD] = "Head",
                [HITGROUP_CHEST] = "Chest",
                [HITGROUP_STOMACH] = "Chest",
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
        ply:SetBloodColor(-1)
    end)
    
    hook.Add("PlayerInitialSpawn", "AIS_ArmorBloodEffect", function(ply) 
        ply:SetBloodColor(-1)
    end)


    local function CreateItemsHooks()
        for itemID, itemData in pairs(AIS_Items) do
            if itemData.ServerHooks then
                for index, hookData in ipairs(itemData.ServerHooks) do
                    if hookData.HookType then
                        local hookID = "AIS_ITEM_SERVERHOOK_" .. itemID .. "_" .. tostring(index)

                        -- Security check
                        if type(hookData.HookFunction) ~= "function" then
                            print("[AIS] Invalid HookFunction in item: " .. itemID)
                            continue
                        end

                        -- Create or update the hook
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
        for ply, slots in pairs(AIS_EquipedSlots) do
            if not IsValid(ply) or not ply:Alive() then continue end

            for slot, itemName in pairs(slots) do
                local itemData = AIS_Items[itemName]
                if itemData and isfunction(itemData.WhenWearing) then
                    local args = itemData.ExtraWearingArgs or {}
                    itemData.WhenWearing(ply, slot, unpack(args))
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

    net.Receive("AIS_SyncEventHandler", function()
        local TriggerEnt = net.ReadEntity()
        local TriggerPos = net.ReadVector()
        local ItemID = net.ReadString()
        local ItemHookID = net.ReadString()

        local SyncEvent = {
            TriggerEnt = TriggerEnt,
            TriggerPos = TriggerPos,
            ItemID = ItemID,
            ItemHookID = ItemHookID,
            ProcTime = CurTime()
        }

        if AIS_DebugMode then
            print("[AIS] Received Data about SyncEvent | ItemID: ", ItemID, " HookID: ", ItemHookID)
        end

        net.Start("AIS_SyncEventHandler")
            net.WriteTable(SyncEvent)
        net.Broadcast()
    end)

    function ServerSendSyncEvent(ent, itemID, hookID)
        local ply = ent
        local pos = ply:GetPos()
        local ItemIDProc = itemID
        local ItemHookID = hookID

        local SyncEvent = {
            TriggerEnt = ply,
            TriggerPos = pos,
            ItemID = ItemIDProc,
            ItemHookID = ItemHookID,
            ProcTime = CurTime()
        }

        net.Start("AIS_SyncEventHandler")
            net.WriteTable(SyncEvent)
        net.Broadcast()

        if AIS_DebugMode then
            print("[AIS] Sending SyncData to clients | ItemID: ", ItemIDProc, " HookID: ", ItemHookID)
        end
    end



    hook.Add("InitPostEntity", "AIS_CreateHooks", function()
        timer.Simple(3, function()
            print("[AIS] Creating item hooks...")
            CreateItemsHooks()
        end) 
    end)

    concommand.Add("AIS_CreateItemHooks", function(ply, cmd, args)
        CreateItemsHooks()
    end, nil, "Reloads or creates all AIS hooks.")
end

if CLIENT then

    AIS_SyncEventTable = {}

    net.Receive("AIS_SyncEventHandler", function()
        local SyncEvent = net.ReadTable()
        if AIS_DebugMode then
            print("[AIS] Received Data about SyncEvent from Server | ItemID: ", SyncEvent.ItemID, " HookID: ", SyncEvent.ItemHookID)
        end
        table.insert(AIS_SyncEventTable, SyncEvent)
    end)

    function GetSyncEventEnts(hookID)
        local results = {}

        for _, event in ipairs(AIS_SyncEventTable) do
            if event.ItemHookID == hookID then
                table.insert(results, event)
            end
        end

        return results
    end

    function RemoveSyncEventEnt(ent, hookID)
        for i = #AIS_SyncEventTable, 1, -1 do
            local event = AIS_SyncEventTable[i]
            if event.ItemHookID == hookID and event.TriggerEnt == ent then
                table.remove(AIS_SyncEventTable, i)
            end
        end
    end

    function SendSyncEvent(itemID, hookID)
        local ply = LocalPlayer()
        local pos = ply:GetPos()
        local ItemIDProc = itemID
        local ItemHookID = hookID

        net.Start("AIS_SyncEventHandler")
            net.WriteEntity(ply)
            net.WriteVector(pos)
            net.WriteString(ItemIDProc)
            net.WriteString(ItemHookID)
        net.SendToServer()

        if AIS_DebugMode then
            print("[AIS] Sending SyncData to server | ItemID: ", ItemIDProc, " HookID: ", ItemHookID)
        end
    end

    local function CreateClientItemsHooks()
        for itemID, itemData in pairs(AIS_Items) do
            if itemData.ClientHooks then
                for index, hookData in ipairs(itemData.ClientHooks) do
                    if hookData.HookType then
                        local hookID = "AIS_ITEM_CLIENTHOOK_" .. itemID .. "_" .. tostring(index)

                        -- Security check
                        if type(hookData.HookFunction) ~= "function" then
                            print("[AIS] Invalid HookFunction in item: " .. itemID)
                            continue
                        end

                        -- Create or update the hook
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

    local function CreateSyncItemsHooks()
        for itemID, itemData in pairs(AIS_Items) do
            if itemData.SyncEvents then
                for index, hookData in ipairs(itemData.SyncEvents) do
                    if hookData.HookType and hookData.HookID then
                        local SyncEventHookID = "AIS_ITEM_SYNCEVENT_" .. itemID .. "_" .. hookData.HookID

                        -- Security check
                        if type(hookData.HookFunction) ~= "function" then
                            print("[AIS] Invalid HookFunction in item: " .. SyncEventHookID)
                            continue
                        end

                        -- Create or update the hook
                        if not hookData.HookInit then
                            hookData.LastHookFunction = hookData.HookFunction

                            print("[AIS] Created SyncEvent hook: " .. itemID .. " | Hook: " .. SyncEventHookID)

                            hook.Add(hookData.HookType, SyncEventHookID, function(...)
                                hookData.HookFunction(...)
                            end)

                            hookData.HookInit = true
                        elseif hookData.LastHookFunction ~= hookData.HookFunction then
                            print("[AIS] Updated SyncEvent hook: " .. itemID .. " | Hook: " .. SyncEventHookID)

                            hook.Add(hookData.HookType, SyncEventHookID, function(...)
                                hookData.HookFunction(...)
                            end)

                            hookData.LastHookFunction = hookData.HookFunction
                        end
                    end
                end
            end
        end
    end

    hook.Add("Think", "AIS_ApplyWhenWearingClient", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        for slot, itemName in pairs(PlayerEquippedItems) do
            if not itemName or itemName == "" then continue end

            local itemData = AIS_Items[itemName]
            if not itemData then
                if AIS_DebugMode then
                    print("[AIS CLIENT] Unknown equipped item for slot:", slot, "->", tostring(itemName))
                end
                continue
            end

            if isfunction(itemData.WhenWearingClient) then
                local args = itemData.ExtraWearingArgsClient or {}
                itemData.WhenWearingClient(ply, item, unpack(args))
            end
        end
    end)


    hook.Add("PlayerSpawn", "AIS_OnEquipOnRespawnClient", function(ply)
        local slots = PlayerEquippedItems[ply]
        if not slots then return end

        for _, item in pairs(slots) do
            local itemData = AIS_Items[item]
            if itemData and isfunction(itemData.OnEquipClient) then
                local args = itemData.ExtraEquipArgsClient or {}
                itemData.OnEquipClient(ply, item, unpack(args))
            end
        end
    end)

    hook.Add("InitPostEntity", "AIS_CreateClientHooks", function()
        if AIS_Items == nil or next(AIS_Items) == nil then
            print("[AIS] Cannot create ClientHooks! AIS_Items table is missing.")
            return
        end
        CreateClientItemsHooks()
        CreateSyncItemsHooks()
        print("[AIS] Client hooks created successfully.")
    end)

    concommand.Add("AIS_CreateClientItemHooks", function(ply, cmd, args)
        CreateClientItemsHooks()
        CreateSyncItemsHooks()
    end, nil, "Reloads or creates all AIS hooks.")
end