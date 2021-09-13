local AddSet = function(setName)
    if (gSettings.AllowAddSet == false) then
        print(chat.header('LuAshitacast') .. chat.error('Your profile has addset disabled.'));
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

    local lowerName = string.lower(setName);
    local setTableName = nil;
    for name,set in pairs(gProfile.Sets) do
        if (string.lower(name) == lowerName) then
            setTableName = name;
        end
    end

    local replaced = false;
    if (setTableName ~= nil) then
        gProfile.Sets[setTableName] = gData.GetCurrentSet();
        replaced = true;
    else
        gProfile.Sets[setName] = gData.GetCurrentSet();
    end

    if gFileTools.SaveSets() then
        if (replaced) then
            print(chat.header('LuAshitacast') .. chat.message('Replaced Set: ') .. chat.color1(2, setTableName));
        else
            print(chat.header('LuAshitacast') .. chat.message('Added Set: ') .. chat.color1(2, setName));
        end
    end
end

local CancelAction = function()
    if (gState.PlayerAction ~= nil) then
        gState.PlayerAction.Block = true;
    end
end

local ChangeActionId = function(id)
    local action = gState.PlayerAction;
    local packet = gState.PlayerAction.Packet;
    if (action.Type == 'Spell') then
        local resource = AshitaCore:GetResourceManager():GetSpellById(id);
        if (resource ~= nil) then
            packet[0x0C + 1] = bit.band(id, 0x00FF);
            packet[0x0D + 1] = bit.band(id, 0xFF00) / 256;
            action.Resource = resource;
            local baseCast = action.Resource.CastTime * 250;
            baseCast = (baseCast * (100 - gSettings.FastCast)) / 100;
            action.Completion = (os.clock() * 1000) + baseCast + gSettings.SpellOffset;
        end
    elseif (action.Type == 'Weaponskill') then
        local resource = AshitaCore:GetResourceManager():GetAbilityById(id);
        if (resource ~= nil) then
            packet[0x0C + 1] = bit.band(id, 0x00FF);
            packet[0x0D + 1] = bit.band(id, 0xFF00) / 256;
            action.Resource = resource;
            action.Completion = (os.clock() * 1000) + gSettings.WeaponskillDelay;
        end
    elseif (action.Type == 'Ability') then
        local resource = AshitaCore:GetResourceManager():GetAbilityById(id + 0x200);
        if (resource ~= nil) then
            packet[0x0C + 1] = bit.band(id, 0x00FF);
            packet[0x0D + 1] = bit.band(id, 0xFF00) / 256;
            action.Resource = resource;
            action.Completion = (os.clock() * 1000) + gSettings.AbilityDelay;
        end
    else
        print(chat.header('LuAshitacast') .. chat.error('ChangeId cannot be used for action of type: ' .. chat.color1(2, gState.PlayerAction.Type)));
    end
end

local ChangeActionTarget = function(target)
    if (gState.PlayerAction == nil) then
        return;
    end
    
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    local targetId = 0;
    local renderFlags = entity:GetRenderFlags0(target);
    if (bit.band(renderFlags, 0x200) == 0x200) then
        targetId = entity:GetServerId(target);
    end
        
    if (targetId == 0) then
        return;
    end

    local action = gState.PlayerAction;
    local packet = action.Packet;

    if (action.Type == 'Item') then
        packet[0x04 + 1] = bit.band(targetId, 0x000000FF);
        packet[0x05 + 1] = bit.band(targetId, 0x0000FF00) / 256;
        packet[0x06 + 1] = bit.band(targetId, 0x00FF0000) / 65536;
        packet[0x07 + 1] = bit.band(targetId, 0xFF000000) / 16777216;
        packet[0x0C + 1] = bit.band(target, 0x00FF);
        packet[0x0D + 1] = bit.band(target, 0xFF00) / 256;
        action.Target = target;
    else
        packet[0x04 + 1] = bit.band(targetId, 0x000000FF);
        packet[0x05 + 1] = bit.band(targetId, 0x0000FF00) / 256;
        packet[0x06 + 1] = bit.band(targetId, 0x00FF0000) / 65536;
        packet[0x07 + 1] = bit.band(targetId, 0xFF000000) / 16777216;
        packet[0x08 + 1] = bit.band(target, 0x00FF);
        packet[0x09 + 1] = bit.band(target, 0xFF00) / 256;
        action.Target = target;
    end
end

local ClearEquipBuffer = function()
    gEquip.ClearBuffer();
end

local Disable = function(slot)
    if (slot == 'all') then
        for i = 1,16,1 do
            gState.Disabled[i] = true;
        end            
        print(chat.header('LuAshitacast') .. chat.message('All slots disabled.'));
        return;
    end
    local slotIndex = gData.GetEquipSlot(slot);
    if (slotIndex ~= 0) then
        gState.Disabled[slotIndex] = true;
        print(chat.header('LuAshitacast') .. chat.color1(2, gData.Constants.EquipSlotNames[slotIndex]) .. chat.message(' disabled.'));
    else
        print(chat.header('LuAshitacast') .. chat.error('Could not identify slot: ' .. chat.color1(2, slot)));
    end
end

local Echo = function(color, text)
    print(chat.header('LuAshitacast') .. chat.color1(color, text));
end

local Enable = function(slot)
    if (slot == 'all') then
        for i = 1,16,1 do
            gState.Disabled[i] = false;
        end            
        print(chat.header('LuAshitacast') .. chat.message('All slots enabled.'));
        return;
    end
    local slotIndex = gData.GetEquipSlot(slot);
    if (slotIndex ~= 0) then
        gState.Disabled[slotIndex] = false;
        print(chat.header('LuAshitacast') .. chat.color1(2, gData.Constants.EquipSlotNames[slotIndex]) .. chat.message(' enabled.'));
    else
        print(chat.header('LuAshitacast') .. chat.error('Could not identify slot: ' .. chat.color1(2, slot)));
    end
end

local Equip = function(slot, item)
    local equipSlot = gData.GetEquipSlot(slot);
    if (equipSlot == 0) then
        print(chat.header('LuAshitacast') .. chat.error("Invalid slot specified: ") .. chat.color1(2, slot));
        return;
    end

    local table = gEquip.MakeItemTable(item);
    if (table == nil) or (type(table.Name) ~= 'string') then
        return;
    end    
    gEquip.EquipItemToBuffer(equipSlot, table);
end

local EquipSet = function(set)
    if (type(set) == 'string') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('You must have a profile loaded to use EquipSet(string).'));
            return;
        end
        
        if (gProfile.Sets == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Your profile must have a sets table to use EquipSet(string).'));
            return;
        end
        
        local setName = string.lower(set);
        for name,setEntry in pairs(gProfile.Sets) do
            if (string.lower(name) == setName) then
                for k, v in pairs(setEntry) do
                    Equip(k, v);
                end
                return;
            end
        end
        
        print(chat.header('LuAshitacast') .. chat.error('Set not found: ' .. set));
    elseif (type(set) == 'table') then
        for k, v in pairs(set) do
            Equip(k, v);
        end
    end
end

local Error = function(text)
    print(chat.header('LuAshitacast') .. chat.error(text));
end

local ForceEquip = function(slot, item)
    local equipSlot = gData.GetEquipSlot(slot);
    if (equipSlot == 0) then
        print(chat.header('LuAshitacast') .. chat.error("Invalid slot specified: ") .. chat.color1(2, slot));
        return;
    end

    local itemTable = gEquip.MakeItemTable(item);
    if (itemTable == nil) or (type(itemTable.Name) ~= 'string') then
        return;
    end
    
    gEquip.EquipSet({[equipSlot] = itemTable}, 'auto');
end

local ForceEquipSet = function(set)
    local table = nil;
    if (type(set) == 'string') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('You must have a profile loaded to use ForceEquipSet(string).'));
            return;
        end
        
        if (gProfile.Sets == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Your profile must have a sets table to use ForceEquipSet(string).'));
            return;
        end
        
        local setName = string.lower(set);
        for name,setEntry in pairs(gProfile.Sets) do
            if (string.lower(name) == setName) then
                table = setEntry;
            end
        end
        
        if (table == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Set not found: ' .. set));
            return;
        end
    elseif (type(set) == 'table') then
        table = set;
    else
        return;
    end
    local newTable = {};
    for k,v in pairs(table) do
        local equipSlot = gData.GetEquipSlot(k);
        if (equipSlot == 0) then
            print(chat.header('LuAshitacast') .. chat.error("Invalid slot specified: ") .. chat.color1(2, k));
            return;
        end

        local table = gEquip.MakeItemTable(v);
        if (table ~= nil) and (type(table.Name) == 'string') then
            newTable[equipSlot] = table;
        end
    end
    gEquip.EquipSet(newTable, 'auto');
end

local Message = function(text)
    print(chat.header('LuAshitacast') .. chat.message(text));
end

local LoadFile = function(path)
    if not string.match(path, '.lua') then
        path = path .. '.lua';
    end
    local filePath = path;
    if (not ashita.fs.exists(filePath)) then
        filePath = ('%sconfig\\addons\\luashitacast\\%s_%u\\%s'):fmt(AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId, path);
        if (not ashita.fs.exists(filePath)) then
            filePath = ('%sconfig\\addons\\luashitacast\\%s'):fmt(AshitaCore:GetInstallPath(), path);
            if (not ashita.fs.exists(filePath)) then
                print(chat.header('LuAshitacast') .. chat.error('File not found matching: ') .. chat.color1(2, path));
                return nil;
            end
        end
    end

    local func = nil;
    local success,error = pcall(function()
        func  = loadfile(filePath);
    end);
    if (not success) then
        print (chat.header('LuAshitacast') .. chat.error('Failed to load file: ') .. chat.color1(2,filePath));
        print (chat.header('LuAshitacast') .. chat.error(error));
        return nil;
    end

    local fileValue = nil;
    success, error = pcall(function ()
        fileValue = func();
    end);
    if (not success) then
        print (chat.header('LuAshitacast') .. chat.error('Failed to process file: ') .. chat.color1(2,filePath));
        print (chat.header('LuAshitacast') .. chat.error(error));
        return nil;
    end

    return fileValue;
end

--Equips a set and locks it in for a given period of time
local LockSet = function(set, seconds)
    local table = nil;
    if (type(set) == 'string') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('You must have a profile loaded to use LockSet(string).'));
            return;
        end
        
        if (gProfile.Sets == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Your profile must have a sets table to use LockSet(string).'));
            return;
        end
        
        local setName = string.lower(set);
        for name,setEntry in pairs(gProfile.Sets) do
            if (string.lower(name) == setName) then
                table = setEntry;
            end
        end
        
        if (table == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Set not found: ' .. set));
            return;
        end
    elseif (type(set) == 'table') then
        table = set;
    else
        return;
    end

    gState.ForceSet = table;
    gState.ForceSetTimer = os.clock() + seconds;

    local newTable = {};
    for k,v in pairs(table) do
        local equipSlot = gData.GetEquipSlot(k);
        if (equipSlot == 0) then
            print(chat.header('LuAshitacast') .. chat.error("Invalid slot specified: ") .. chat.color1(2, k));
            return;
        end
    
        local table = gEquip.MakeItemTable(v);
        if (table ~= nil) and (type(table.Name) == 'string') then
            newTable[equipSlot] = table;
        end
    end
    gEquip.EquipSet(newTable, 'auto');
end

local exports = {
    AddSet = AddSet,
    CancelAction = CancelAction,
    ChangeActionId = ChangeActionId,
    ChangeActionTarget = ChangeActionTarget,
    ClearEquipBuffer = ClearEquipBuffer,
    Disable = Disable,
    Echo = Echo,
    Enable = Enable,
    Equip = Equip,
    EquipSet = EquipSet,
    Error = Error,
    ForceEquip = ForceEquip,
    ForceEquipSet = ForceEquipSet,
    Message = Message,
    LoadFile = LoadFile,
    LockSet = LockSet
};

return exports;