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


    hook.Add("EntityTakeDamage", "AIS_HandleArmorReduction", function(ply, dmginfo)
        if not IsValid(ply) or not ply:IsPlayer() then return end

        local slotTable = AIS_EquipedSlots[ply]
        if not slotTable then return end

        local armor = 0
        local elarmor = 0

        -- Sumujemy Armor i ELArmor z każdego slotu
        for _, itemID in pairs(slotTable) do
            local itemData = AIS_Items[itemID]
            if itemData and itemData.Attributes then
                armor = armor + (itemData.Attributes.ArmorPoints or 0)
                elarmor = elarmor + (itemData.Attributes.ELArmorPoints or 0)
            end
        end

        -- Określamy typ obrażeń
        local dmgType = dmginfo:GetDamageType()
        local dmg = dmginfo:GetDamage()

        -- Wartości redukcji
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

        local newDmg = dmg * reduction
        --PrintMessage(HUD_PRINTTALK, "Damage changed from: " .. dmg .. " -> " .. newDmg .. " | Damage Reduction %: " .. (1 - reduction) * 100 .. "%")
        dmginfo:SetDamage(newDmg)
    end)

end