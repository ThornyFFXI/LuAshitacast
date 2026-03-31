local commands = {}

commands.HandleCommand = function(e)
    if string.lower(string.sub(e.command, 1, 9)) == '/lac exec' or string.lower(string.sub(e.command,1,18)) == '/luashitacast exec' then
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
    if (#args == 0) then
        return;
    end
    args[1] = string.lower(args[1]);
    if (args[1] ~= '/lac') and (args[1] ~= '/luashitacast') then
        return;
    end
    e.blocked = true;
    if (#args < 2) then
        gConfigGUI:Show();
        return;
    end
    args[2] = string.lower(args[2]);

    if (args[2] == 'addset') then
        if (#args == 2) then
            print(chat.header('LuAshitacast') .. chat.error('You must specify a set name for addset.'));
            return;
        end

        local setName = AshitaCore:GetChatManager():ParseAutoTranslate(args[3], false);
        local cleanSetName = setName:gsub('[^%w%s_]+', '');
        if (setName ~= cleanSetName) then
            print(chat.header('LuAshitacast') .. chat.error('Invalid characters located in set name.  Set must be only letters, numbers and underscores.'));
            return;
        end

        if (string.sub(setName, 1, 1) == '_') then
            print(chat.header('LuAshitacast') .. chat.error('Set name should not start with an underscore.'));            
            return;
        end
        
        if (tonumber(string.sub(setName, 1, 1)) ~= nil) then
            print(chat.header('LuAshitacast') .. chat.error('Set name cannot start with a number.'));            
            return;
        end

        gFunc.AddSet(setName);
        return;
    end

    if (args[2] == 'debug') then
        if (#args == 2) then
            if (gSettings.Debug == true) then
                gSettings.Debug = false;
            else
                gSettings.Debug = true;
            end
        elseif (string.lower(args[3]) == 'on') then
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
        local argCount = #args;
        if (argCount < 4) or (argCount % 2) ~= 0 then  
            print(chat.header('LuAshitacast') .. chat.error("Correct syntax is:  /lac equip [slot] [item] [optional: slot2] [optional: item2] [repeating]"));
            return;
        elseif (argCount == 4) then
            local slot = gData.GetEquipSlot(args[3]);
            gFunc.ForceEquip(args[3], args[4]);
        else
            local set = {};
            local i = 3;
            while i < argCount do
                set[args[i]] = args[i + 1];
				i = i + 2;
            end
            gFunc.ForceEquipSet(set);
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

    if (args[2] == 'list') then
        if (#args > 2) then
            if (args[3] == 'gui') then
                gSetDisplay:Initialize();
            else
                gSetDisplay:ListSet(args[3]);
            end
        else
            gSetDisplay:ListSets();
        end
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
    
    if (args[2] == 'lockstyle') then
        if (#args > 2) then
            local compString = string.lower(args[3]);
            if (type(gProfile) == 'table') and (type(gProfile.Sets) == 'table') then
                for setName,set in pairs(gProfile.Sets) do
                    if (string.lower(setName) == compString) then
                        gFunc.LockStyle(set);
                    end
                end
            end
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
    
    if (args[2] == 'safecall') then
        gSettings.SafeCall = not gSettings.SafeCall;
        print(chat.header('LuAshitacast') .. chat.message('Safecall ') .. chat.color1(2, gSettings.SafeCall and 'enabled' or 'disabled') .. chat.message('.'));
        return;
    end
    
    if (args[2] == 'newlua') then
        local path = ('%sconfig\\addons\\luashitacast\\%s_%u\\'):fmt(AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId);
        if (#args == 2) then
            local job = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", gState.PlayerJob);
            if (type(job) == 'string') then
                job = job:trimend('\x00');
            end
            path = path .. job .. '.lua';
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

    
    if (args[2] == 'edit') then
        if (gProfile ~= nil) then
            ashita.misc.execute(gProfile.FilePath, '');
        else
            print(chat.header('LuAshitacast') .. chat.error("No profile loaded."));
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
            if (#args > 3) then
                delay = args[4];
            end

            gFunc.LockSet(args[3], delay);
            return;
        end
    end
    
    if (args[2] == 'unload') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('No profile loaded.'));
        else
            gState.UnloadProfile();
            print(chat.header('LuAshitacast') .. chat.message('Profile unloaded.'));
        end
    end
    
    if (args[2] == 'gear') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Could not perform gear.  No profile loaded.'));            
        elseif not AshitaCore:GetPluginManager():IsLoaded('Packer') then
            gFunc.Error('Could not perform gear.  Packer is not loaded.');
            return;
        else
            gIntegration.HandleEvent('packer_gear');
        end
    end
    
    if (args[2] == 'validate') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Could not perform validate.  No profile loaded.'));            
        elseif not AshitaCore:GetPluginManager():IsLoaded('Packer') then
            gFunc.Error('Could not perform validate.  Packer is not loaded.');
            return;
        else
            gIntegration.HandleEvent('packer_validate');
        end
    end
    
    if (args[2] == 'pack') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Could not perform pack.  No profile loaded.'));
        else
            gIntegration.HandleEvent('porter_pack');
        end
    end
    
    if (args[2] == 'unpack') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Could not perform unpack.  No profile loaded.'));
        else
            gIntegration.HandleEvent('porter_unpack');
        end
    end
    
    if (args[2] == 'preppack') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Could not perform preppack.  No profile loaded.'));
        else
            gIntegration.HandleEvent('porter_preppack');
        end
    end
    
    if (args[2] == 'prepunpack') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Could not perform prepunpack.  No profile loaded.'));
        else
            gIntegration.HandleEvent('porter_prepunpack');
        end
    end

end

return commands;