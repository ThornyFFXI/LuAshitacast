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

    --Try to match an exact case set.
    local setTableName = nil;
    for name,set in pairs(gProfile.Sets) do
        if (setName == name) then
            setTableName = name;
        end
    end

    --Try to match differing case.
    if setTableName == nil then
        local lowerName = string.lower(setName);
        for name,set in pairs(gProfile.Sets) do
            if (string.lower(name) == lowerName) then
                setTableName = name;
            end
        end
        if setTableName == nil then
            setTableName = setName;
        end
    end
    
    local set = gData.GetCurrentSet();
    if gFileTools.SaveSet(setTableName, set) then
        --Mixed feelings about forcing a reload here.
        --If user is assigning augments in OnLoad or anything of the sort, I think it's better to ensure those get applied.
        gState.LoadProfileEx(gProfile.FilePath);
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
            packet[0x0D + 1] = bit.rshift(id, 8);
            action.Resource = resource;
            local baseCast = action.Resource.CastTime * 250;
            baseCast = (baseCast * (100 - gSettings.FastCast)) / 100;
            action.Completion = (os.clock() * 1000) + baseCast + gSettings.SpellOffset;
        end
    elseif (action.Type == 'Weaponskill') then
        local resource = AshitaCore:GetResourceManager():GetAbilityById(id);
        if (resource ~= nil) then
            packet[0x0C + 1] = bit.band(id, 0x00FF);
            packet[0x0D + 1] = bit.rshift(id, 8);
            action.Resource = resource;
            action.Completion = (os.clock() * 1000) + gSettings.WeaponskillDelay;
        end
    elseif (action.Type == 'Ability') then
        local resource = AshitaCore:GetResourceManager():GetAbilityById(id + 0x200);
        if (resource ~= nil) then
            packet[0x0C + 1] = bit.band(id, 0x00FF);
            packet[0x0D + 1] = bit.rshift(id, 8);
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
        packet[0x04 + 1] = bit.band(targetId, 0xFF);
        packet[0x05 + 1] = bit.band(bit.rshift(targetId, 8), 0xFF)
        packet[0x06 + 1] = bit.band(bit.rshift(targetId, 16), 0xFF)
        packet[0x07 + 1] = bit.band(bit.rshift(targetId, 24), 0xFF)
        packet[0x0C + 1] = bit.band(target, 0x00FF);
        packet[0x0D + 1] = bit.band(bit.rshift(target, 8), 0xFF);
        action.Target = target;
    else
        packet[0x04 + 1] = bit.band(targetId, 0xFF);
        packet[0x05 + 1] = bit.band(bit.rshift(targetId, 8), 0xFF)
        packet[0x06 + 1] = bit.band(bit.rshift(targetId, 16), 0xFF)
        packet[0x07 + 1] = bit.band(bit.rshift(targetId, 24), 0xFF)
        packet[0x08 + 1] = bit.band(target, 0xFF);
        packet[0x09 + 1] = bit.band(bit.rshift(target, 8), 0xFF);
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
	
    local func, loadError = loadfile(filePath);
    if (not func) then
        print (chat.header('LuAshitacast') .. chat.error('Failed to load file: ') .. chat.color1(2,filePath));
        print (chat.header('LuAshitacast') .. chat.error(loadError));
        return nil;
    end

    local fileValue = nil;
    local success, execError = pcall(function ()
        fileValue = func();
    end);
    if (not success) then
        print (chat.header('LuAshitacast') .. chat.error('Failed to execute file: ') .. chat.color1(2,filePath));
        print (chat.header('LuAshitacast') .. chat.error(execError));
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

local LockStyle = function(set)
    local reducedSet = {};
    for slot,equip in pairs(set) do
        local equipSlot = gData.GetEquipSlot(slot);
        if (equipSlot ~= 0) and (equipSlot < 10) then
            if type(equip) == 'string' then
                reducedSet[equipSlot] = string.lower(equip);
            elseif (type(equip) == 'table') and equip.Name then
                reducedSet[equipSlot] = string.lower(equip.Name);
            end
        end
    end
    gEquip.LockStyle(reducedSet);    
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
    LockSet = LockSet,
    LockStyle = LockStyle
};

return exports;