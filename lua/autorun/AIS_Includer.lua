if SERVER then

    local function LoadAISFiles(folder)
        local files, _ = file.Find(folder .. "/*.lua", "LUA")

        for _, filename in ipairs(files) do
            local filepath = folder .. "/" .. filename
            AddCSLuaFile(filepath)
            include(filepath)
            print("[Aaron's Inventory System] Server File " .. filename .. " has been loaded.")
        end
    end

    hook.Add("PreGamemodeLoaded", "LoadAISSystemServer", function() 
        LoadAISFiles("AIS")
        LoadAISFiles("AIS_Addon")
    end)

    concommand.Add("AIS_Reload", function(ply, cmd, args)
        LoadAISFiles("AIS")
        LoadAISFiles("AIS_Addon")
        for _, v in ipairs(player.GetAll()) do
            v:ConCommand("AIS_Reload_Client")
        end
    end, nil, "Reloads whole Aaron's Inventory System.")

else
    
    local function LoadAISFilesClient(folder)
        local files, _ = file.Find(folder .. "/*.lua", "LUA")

        for _, filename in ipairs(files) do
            local filepath = folder .. "/" .. filename
            include(filepath)
            print("[Aaron's Inventory System] Client file " .. filename .. " has been loaded.")
        end
    end

    hook.Add("PostGamemodeLoaded", "LoadAISSystemClient", function() 
        LoadAISFilesClient("AIS")
        LoadAISFilesClient("AIS_Addon")
    end)

    concommand.Add("AIS_Reload_Client", function()
        LoadAISFilesClient("AIS")
        LoadAISFilesClient("AIS_Addon")
    end)
end
