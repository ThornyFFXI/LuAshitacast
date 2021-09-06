local commands = {}

commands.HandleCommand = function(e)
    local args = e.command:args();
    if (#args == 0) or ((args[1] ~= '/lac') and (args[1] ~= '/luashitacast')) then
        return;
    end
    e.blocked = true;
    if (#args < 2) then
        return;
    end

    if (args[2] == 'addset') then
        if (gSettings.AllowAddSet == false) then
            print(chat.header('LuAshitacast') .. chat.error('Your profile has addset disabled.'));
            return;
        end

        if (#args == 2) then
            print(chat.header('LuAshitacast') .. chat.error('You must specify a set name for addset.'));
            return;
        end

        gProfile.Sets[args[3]] = gData.GetCurrentSet();
        gFileTools.AddSet(gProfile.FilePath, gProfile.Sets);
        return;
    end

    if (args[2] == 'debug') then
        if (#args == 2) then
            if (gSettings.Debug == true) then
                gSettings.Debug = false;
            else
                gSettings.Debug = true;
            end
        elseif (args[3] == 'on') then
            gSettings.Debug = true;
        else
            gSettings.Debug = false;
        end
        if (gSettings.Debug) then
            print(chat.header('LuAshitacast') .. chat.message('Debug mode ') .. chat.color1(2, 'enabled') .. chat.message('.'));
        else
            print(chat.header('LuAshitacast') .. chat.message('Debug mode ') .. chat.color1(2, 'disabled') .. chat.message('.'));
        end
    end

    if (args[2] == 'disable') then
        if (#args == 2) or (args[3] == 'all') then
            for i = 1,16,1 do
                gState.Disabled[i] = true;
            end            
            print(chat.header('LuAshitacast') .. chat.message('All slots disabled.'));
        else
            local slot = gData.GetEquipSlot(args[3]);
            if (slot ~= 0) then
                gState.Disabled[slot] = true;
                print(chat.header('LuAshitacast') .. chat.color1(2, gData.ResolveString(gData.Constants.EquipSlotNames, slot - 1)) .. chat.message(' disabled.'));
            else
                print(chat.header('LuAshitacast') .. chat.error('Could not identify slot: ' .. chat.color1(2, args[3])));
            end
        end
    end

    if (args[2] == 'enable') then
        if (#args == 2) or (args[3] == 'all') then
            for i = 1,16,1 do
                gState.Disabled[i] = false;
            end            
            print(chat.header('LuAshitacast') .. chat.message('All slots enabled.'));
        else
            local slot = gData.GetEquipSlot(args[3]);
            if (slot ~= 0) then
                gState.Disabled[slot] = false;
                print(chat.header('LuAshitacast') .. chat.color1(2, gData.ResolveString(gData.Constants.EquipSlotNames, slot)) .. chat.message(' enabled.'));
            else
                print(chat.header('LuAshitacast') .. chat.error('Could not identify slot: ' .. chat.color1(2, args[3])));
            end
        end
    end
    
    if (args[2] == 'equip') then
        if (#args < 4) then  
            print(chat.header('LuAshitacast') .. chat.error("Correct syntax is:  /lac equip [slot] [item]"));
            return;
        else
            local slot = gData.GetEquipSlot(args[3]);
            gFunc.ForceEquip(args[3], args[4]);
        end
    end

    if (args[2] == 'fwd') then
        local fwdArgs = {};
        for i = 3,#args,1 do
          fwdArgs[i - 2] = args[i];
        end
        gState.SafeCall('HandleCommand', fwdArgs);
        return;
    end


    if (args[2] == 'load') then
        if (#args > 2) then
            gState.LoadProfileEx(args[3]);
        else
            gState.AutoLoadProfile();
        end
        return;
    end
    
    if (args[2] == 'naked') then
        for i = 1,16,1 do
            gEquip.UnequipSlot(i);
            gState.Disabled[i] = true;
        end
        return;
    end
    
    if (args[2] == 'newlua') then
        local path = ('%sconfig\\addons\\luashitacast\\%s_%u\\'):fmt(AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId);
        if (#args == 2) then
            path = path .. AshitaCore:GetResourceManager():GetString("jobs_abbr", gState.PlayerJob) .. '.lua';
        else
            if (string.match(args[3], '.') == true) then
                path = path .. args[3];
            else
                path = path .. args[3] .. '.lua';
            end
        end
        if (gFileTools.CreateProfile(path) == true) then
            gState.LoadProfileEx(path);
        end        
        return;
    end

    
    if (args[2] == 'reload') then
        if (gProfile ~= nil) then
            gState.LoadProfileEx(gProfile.FilePath);
        else
            print(chat.header('LuAshitacast') .. chat.error("No profile loaded."));
        end
        return;
    end
    
    if (args[2] == 'set') then
        if (#args > 2) then
            local delay = 3.0;
            local set = args[3];
            if (#args > 3) then
                delay = args[4];
            end
            gFunc.LockSet(set, delay);
            return;
        end
    end
    
    if (args[2] == 'unload') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error("No profile loaded."));
        else
            gState.Unload();
        end
    end
end

return commands;