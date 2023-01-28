local CreateDirectories = function(path)
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

local CreateProfile = function(path)
    if ashita.fs.exists(path) then
        gFunc.Error('Profile already exists: ' .. path);
        return false;
    end

    if (CreateDirectories(path) == false) then        
        return;
    end

    local file = io.open(path, 'w');
    if (file == nil) then
        gFunc.Error('Failed to access file: ' .. path);
        return false;
    end
    file:write('local profile = {};\n');
    file:write('local sets = {\n');
    file:write('};\n');
    file:write('profile.Sets = sets;\n\n');
    file:write('profile.Packer = {\n');
    file:write('};\n\n');
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

--Parses a string representing a table, creating a table of Name, StartIndex, EndIndex entries for each key-value pair
--startIndex should be the index of the first character inside the table's opening curly brace
local ParseTable = function(wholeFile, startIndex)
    local comma = string.byte(',');
    local openBracket = string.byte('[');
    local closeBracket = string.byte(']');
    local parenthesisOpen = string.byte('{');
    local parenthesisClose = string.byte('}');
    local escapeSlash = string.byte('\\');
    local equalSign = string.byte('=');
    local singleQuote = string.byte('\'');
    local doubleQuote = string.byte('\"');
    local lineBreak = string.byte('\n');
    local underscore = string.byte('_');
    local function isLetter(byte)
        if ((byte >= 65) and (byte <= 90)) then
            return true;
        end
        return ((byte >= 97) and (byte <= 122));
    end
    local function isNumber(byte)
        return ((byte >= 48) and (byte <= 57));
    end

    local parenthesisCount = 1;
    local commentState = 'none';
    local stringState = 'none';
    local entryName = '';
    local entryState = 'none';
    local entryStart = 0;

    local keyIndices = T{};
    local i = startIndex;
    local len = #wholeFile;
    while i <= len do
        local byte = wholeFile:byte(i);
        
        if commentState == 'blockcomment' then
            if string.sub(wholeFile, i, i + 1) == ']]' then
                commentState = 'none';
                i = i + 1;
            end
        elseif commentState == 'comment' then
            if byte == lineBreak then
                commentState = 'none';
            end
        elseif stringState == 'singlequote' then
            if byte == singleQuote then
                stringState = 'none';
            elseif byte == escapeSlash then
                i = i + 1;
            end
        elseif stringState == 'doublequote' then
            if byte == doubleQuote then
                stringState = 'none';
            elseif byte == escapeSlash then
                i = i + 1;
            end
        elseif string.sub(wholeFile, i, i + 3) == '--[[' then
            commentState = 'blockcomment';
            i = i + 3;
        elseif string.sub(wholeFile, i, i + 1) == '--' then
            commentState = 'comment';
            i = i + 1;
        elseif byte == singleQuote then
            stringState = 'singlequote';
        elseif byte == doubleQuote then
            stringState = 'doublequote';
        elseif byte == parenthesisOpen then
            parenthesisCount = parenthesisCount + 1;
        elseif byte == parenthesisClose then
            parenthesisCount = parenthesisCount - 1;
            if (parenthesisCount == 0) then
                if entryState == 'value' then
                    keyIndices:append({ Name = entryName, StartIndex = entryStart, EndIndex = i - 1});               
                end
                return keyIndices, i;
            end

        --Track lua term..
        elseif entryState == 'key' then
            if (not isLetter(byte)) and (not isNumber(byte)) and (byte ~= underscore) then
                entryName = string.sub(wholeFile, entryStart, i - 1);
                if byte == equalSign then
                    entryState = 'value';
                else
                    entryState = 'space';
                end
            end
        elseif entryState == 'bracketkey' then
            if byte == closeBracket then
                entryName = string.sub(wholeFile, entryStart + 1, i - 1);
                local firstByte = string.byte(entryName, 1);
                local lastByte = string.byte(entryName, #entryName);
                if (firstByte == singleQuote) or (firstByte == doubleQuote) then
                    entryName = string.sub(entryName, 2);
                end
                if ((lastByte == singleQuote) or (lastByte == doubleQuote)) then
                    entryName = string.sub(entryName, 1, -2);
                end
                entryState = 'space';
            end
        elseif entryState == 'none' then
            if isLetter(byte) or byte == underscore then
                entryStart = i;
                entryState = 'key';
            elseif byte == openBracket then
                entryStart = i;
                entryState = 'bracketkey';
            end
        elseif entryState == 'space' then
            if byte == comma then
                entryState = 'none';
            elseif byte == equalSign then
                entryState = 'value';
            end
        elseif entryState == 'value' then
            if (byte == comma) and (parenthesisCount == 1) then
                keyIndices:append({ Name = entryName, StartIndex = entryStart, EndIndex = i -1});
                entryState = 'none';
            end
        end
        
        i = i + 1;
    end
    return keyIndices, #wholeFile;
end

local WriteSet = function(file, name, set)
    file:write('[\'' .. name .. '\'] = {\n');
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
    file:write('    }');
end

local SaveSet = function(name, set)
    local file = io.open(gProfile.FilePath, 'r');
    if (file == nil) then
        print(chat.header('LuAshitacast') .. chat.error('Failed to open profile in read mode: ') .. chat.color1(2, gProfile.FilePath));
        return false;
    end
    local wholeFile = file:read('*all');
    file:close();
    
    local matchStrings = {
        'local sets = {',
        'local Sets = {',
        'profile.Sets = {',
        'local sets = T{',
        'local Sets = T{',
        'profile.Sets = T{'
    };

    local setsStart, setsEnd;
    for _,match in ipairs(matchStrings) do
        setsStart, setsEnd = string.find(wholeFile, match);
        if setsStart then
            break;
        end
    end
    
    if not setsStart then
        print(chat.header('LuAshitacast') .. chat.error('SaveSet could not locate sets table in: ' .. gProfile.FilePath));
        return false;
    end

    if gSettings.AddSetBackups then
        local copyName = string.format('%s_%s', os.date("%Y.%m.%d_%H.%M.%S"), gProfile.FileName);
        local copyPath = string.format('%sconfig\\addons\\luashitacast\\%s_%u\\backups\\%s', AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId, copyName);
        CreateDirectories(copyPath);
        local backup = io.open(copyPath, 'w');
        if (backup == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Failed to open backup file in write mode: ') .. chat.color1(2, gProfile.FilePath));
            return false;
        end
        backup:write(wholeFile);
        backup:close();
    end

    local keys, tableEnd = ParseTable(wholeFile, setsEnd + 1);
    file = io.open(gProfile.FilePath, 'w');
    if (file == nil) then
        print(chat.header('LuAshitacast') .. chat.error('Failed to open profile in write mode: ') .. chat.color1(2, gProfile.FilePath));
        return false;
    end

    if #keys == 0 then
        file:write(string.sub(wholeFile, 1, setsEnd));
        file:write('\n    ');
        WriteSet(file, name, set);
        file:write(',\n');
        if tableEnd < #wholeFile then
            file:write(string.sub(wholeFile, tableEnd));
        end
        file:close();
        print(chat.header('LuAshitacast') .. chat.message('Added the set ') .. chat.color1(2, name) .. chat.message(' to file: ') .. chat.color1(2, gProfile.FilePath));
        return true;
    end

    for _,key in pairs(keys) do
        if (key.Name == name) then
            file:write(string.sub(wholeFile, 1, key.StartIndex - 1));
            WriteSet(file, name, set);
            if ((key.EndIndex + 1) < #wholeFile) then
                file:write(string.sub(wholeFile, key.EndIndex + 1));
            end
            file:close();
            print(chat.header('LuAshitacast') .. chat.message('Replaced the set ') .. chat.color1(2, name) .. chat.message(' in file: ') .. chat.color1(2, gProfile.FilePath));
            return true;
        end
    end

    local offset = keys[#keys].EndIndex;
    file:write(string.sub(wholeFile, 1, offset));
    file:write(',\n    ');
    WriteSet(file, name, set);
    if ((offset + 1) < #wholeFile) then
        file:write(string.sub(wholeFile, offset + 1));
    end
    file:close();    
    print(chat.header('LuAshitacast') .. chat.message('Added the set ') .. chat.color1(2, name) .. chat.message(' to file: ') .. chat.color1(2, gProfile.FilePath));
    return true;
end

local exports = {
    CreateDirectories = CreateDirectories,
    CreateProfile = CreateProfile,
    SaveSet = SaveSet
};
return exports;