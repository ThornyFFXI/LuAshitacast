local fileTools = {};

fileTools.CreateDirectories = function(path)
    local backSlash = string.byte('\\');
    for c = 1,#path,1 do
        if (path:byte(c) == backSlash) then
            local directory = string.sub(path,1,c);            
            if (ashita.fs.create_directory(directory) == false) then
                gFunc.Error('Failed to create directory: ' .. directory);
                return false;
            end
        end
    end
    return true;
end

fileTools.CreateProfile = function(path)
    if ashita.fs.exists(path) then
        gFunc.Error('Profile already exists: ' .. path);
        return false;
    end

    if (gFileTools.CreateDirectories(path) == false) then        
        return;
    end

    local file = io.open(path, 'w');
    if (file == nil) then
        gFunc.Error('Failed to access file: ' .. path);
        return false;
    end
    file:write('local profile = {};\n');
    file:write('local sets = {\n');
    file:write('};\n\n');
    file:write('profile.Sets = sets;\n\n');
    file:write('profile.OnLoad = function()\n    gSettings.AllowAddSet = true;\nend\n\n');
    file:write('profile.OnUnload = function()\nend\n\n');
    file:write('profile.HandleCommand = function(args)\nend\n\n');
    file:write('profile.HandleDefault = function()\nend\n\n');
    file:write('profile.HandleAbility = function()\nend\n\n');
    file:write('profile.HandleItem = function()\nend\n\n');
    file:write('profile.HandlePrecast = function()\nend\n\n');
    file:write('profile.HandleMidcast = function()\nend\n\n');
    file:write('profile.HandlePreshot = function()\nend\n\n');
    file:write('profile.HandleMidshot = function()\nend\n\n');
    file:write('profile.HandleWeaponskill = function()\nend\n\n');
    file:write('return profile;');
    file:close();
    return true;
end

fileTools.SaveSets = function()
    local file = io.open(gProfile.FilePath, 'r');
    if (file == nil) then
        print(chat.header('LuAshitacast') .. chat.error('Failed to open profile in read mode: ' .. gProfile.FilePath));
        return false;
    end
    local lines = {};
    
    local index = 0;
    for line in file:lines() do
        index = index + 1;
        lines[index] = line;
    end
    file:close();

    file = io.open(gProfile.FilePath, 'w');
    if (file == nil) then
        print(chat.header('LuAshitacast') .. chat.error('Failed to open profile in write mode: ' .. gProfile.FilePath));
        return false;
    end

    local setsFound = false;
    local parenthesisCount = 0;
    local parenthesisOpen = string.byte('{');
    local parenthesisClose = string.byte('}');

    for i = 1,index,1 do
        local line = lines[i];

        if (setsFound == false) then
            if (string.sub(line,1,14) == 'local sets = {') then
                setsFound = true;
                for c = 1,#line,1 do
                    if (line:byte(c) == parenthesisOpen) then
                        parenthesisCount = parenthesisCount + 1;
                    elseif (line:byte(c) == parenthesisClose) then
                        parenthesisCount = parenthesisCount - 1;
                    end
                end
                if (parenthesisCount < 1) then
                    gFileTools.WriteSets(file, gProfile.Sets);
                end
            else
                file:write(line .. '\n');
            end
        elseif (parenthesisCount > 0) then
            for c = 1,#line,1 do
                if (line:byte(c) == parenthesisOpen) then
                    parenthesisCount = parenthesisCount + 1;
                elseif (line:byte(c) == parenthesisClose) then
                    parenthesisCount = parenthesisCount - 1;
                end
            end
            if (parenthesisCount < 1) then
                gFileTools.WriteSets(file, gProfile.Sets);
            end
        else
            file:write(line .. '\n');
        end
    end

    file:close();
    return true;
end

fileTools.WriteSet = function(file, set)
    for i = 1,16,1 do
        local index = i;
        if (gSettings.AddSetEquipScreenOrder == true) then
            index = gData.Constants.EquipScreenOrder[i];
        end
        local slot = gData.Constants.EquipSlotNames[index];
        local v = set[slot];
        if (v ~= nil) then
            local outString = '        ' .. slot .. ' = ';
            if (type(v) == 'string') then
                outString = outString .. '\'' .. string.gsub(v, '\'', '\\\'') .. '\',\n';
                file:write(outString);
            elseif type(v) == 'table' and v.Name ~= nil then
                outString = outString .. '{ Name = \'' .. string.gsub(v.Name, '\'', '\\\'') .. '\'';
                if (v.Augment ~= nil) then
                    if (type(v.Augment) == 'string') then
                        outString = outString .. ', Augment = \'' .. v.Augment .. '\'';
                    elseif (type(v.Augment) == 'table') then
                        local augIndex = 1;
                        outString = outString .. ', Augment = { ';
                        for _,checkAugment in pairs(v.Augment) do
                            if (augIndex ~= 1) then
                                outString = outString .. ', ';
                            end
                            outString = outString .. '[' .. augIndex .. '] = \'' .. checkAugment .. '\'';
                            augIndex = augIndex + 1;
                        end
                        outString = outString .. ' }';
                    end
                end

                if (v.AugPath ~= nil) then
                    outString = outString .. ', AugPath=\'' .. v.AugPath .. '\'';
                end

                if (v.AugRank ~= nil) then
                    outString = outString .. ', AugRank=' .. v.AugRank;
                end

                if (v.AugTrial ~= nil) then
                    outString = outString .. ', AugTrial=' .. v.AugTrial;
                end

                if (v.Bag ~= nil) then
                    outString = outString .. ', Bag=\'' .. v.Bag .. '\'';
                end
                outString = outString .. ' },\n';
                file:write(outString);
            end
        end
    end
end

fileTools.WriteSets = function(file, sets)
    file:write('local sets = {\n');
    for k,v in pairs(sets) do
        if type(v) == 'table' then
            if (v.NoWrite ~= true) then
                file:write('    ' .. k .. ' = {\n');
                gFileTools.WriteSet(file, v);
                file:write('    },\n');
            end
        end
    end
    file:write('};\n');
end

return fileTools;