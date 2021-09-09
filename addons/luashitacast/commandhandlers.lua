local commands = {}

commands.HandleCommand = function(e)
    if string.sub(e.command, 1, 9) == '/lac exec' or string.sub(e.command,1,18) == '/luashitacast exec' then
        e.blocked = true;
        local command = string.sub(e.command, 10, string.len(e.command));
        if (string.sub(e.command, 1, 9) == '/luashitacast exec') then
            command = string.sub(e.command, 19, string.len(e.command));
        end
        local func = assert(loadstring(command));
        local success,error = pcall(func);
        if (not success) then
            print (chat.header('LuAshitacast') .. chat.error('Error in execute: ') .. chat.color1(2,command));
            print (chat.header('LuAshitacast') .. chat.error(error));
        end
        return;
    end

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
        
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('You must have a profile loaded to use addset.'));
            return;
        end
        
        if (gProfile.Sets == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Your profile must have a sets table to use addset.'));
            return;
        end

        local replaced = (gProfile.Sets[args[3]] ~= nil);
        gProfile.Sets[args[3]] = gData.GetCurrentSet();
        gFileTools.AddSet(gProfile.FilePath, gProfile.Sets);
        if (replaced) then
            print(chat.header('LuAshitacast') .. chat.message('Replaced Set: ') .. chat.color1(2, args[3]));
        else
            print(chat.header('LuAshitacast') .. chat.message('Added Set: ') .. chat.color1(2, args[3]));
        end
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
        if (#args == 2) then
            gFunc.Disable('all');
        else
            gFunc.Disable(args[3]);
        end
        return;
    end

    if (args[2] == 'enable') then
        if (#args == 2) then
            gFunc.Enable('all');
        else
            gFunc.Enable(args[3]);
        end
        return;
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