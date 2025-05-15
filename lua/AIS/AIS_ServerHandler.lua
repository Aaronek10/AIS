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
end