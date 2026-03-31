local function StringToSet(refString, baseTable)
    refString = string.lower(refString);
    local refTable = (type(baseTable) == 'table') and baseTable or gProfile.Sets;
    local periodIndex = string.find(refString, '%.');
    while (periodIndex ~= nil) and (type(refTable) == 'table') do
        local matchName = string.sub(refString, 1, periodIndex - 1);
        local oldTable = refTable;
        refTable = nil;
        for tableName,tableEntry in pairs(oldTable) do
            if (string.lower(tableName) == matchName) then
                refTable = tableEntry;
                break;
            end
        end
        refString = string.sub(refString, periodIndex + 1);
        periodIndex = string.find(refString, '%.');
    end

    if (type(refTable) == 'table') then
        for name,setEntry in pairs(refTable) do
            if (string.lower(name) == refString) then
                return setEntry;
            end
        end
    end
end

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

local function EvaluateBaseSets(refCount, baseTable, currentTable)
    for _,set in pairs(currentTable) do
        if (type(set) == 'table') and (set.BaseSet ~= nil) then
            local refString = set.BaseSet;
            local refTable = StringToSet(refString, baseTable);
            if (refTable.BaseSet == nil) then
                for slotName,slotEntry in pairs(refTable) do                    
                    if (gData.Constants.EquipSlots[slotName] ~= nil) then
                        if (set[slotName] == nil) then
                            set[slotName] = slotEntry;
                        end
                    end
                end
                set.BaseSet = nil;
                refCount[1] = refCount[1] + 1;
            end
        end
        if (type(set) == 'table') then
            EvaluateBaseSets(refCount, baseTable, set);
        end
    end
    return refCount;
end

local ApplyBaseSets = function(baseTable)
    local refCount = { 1 };
    while (refCount[1] ~= 0) do
        refCount[1] = 0;
        EvaluateBaseSets(refCount, baseTable, baseTable);
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

local Combine = function(base, override)
    local newSet = {};
    local const = gData.Constants;

    for key,val in pairs(base) do
        if type(key) == 'string' then
            local index = const.EquipSlotsLC[string.lower(key)];
            if index then
                newSet[const.EquipSlotNames[index]] = val;
            end
        end
    end
    
    for key,val in pairs(override) do
        if type(key) == 'string' then
            local index = const.EquipSlotsLC[string.lower(key)];
            if index then
                newSet[const.EquipSlotNames[index]] = val;
            end
        end
    end
    
    return newSet;
end

local CompareItem = function(item, itemEntry, container)
    gEquip.UpdateJobLevel();
    local newItem = gEquip.MakeItemTable(itemEntry);
    if (container == nil) then
        newItem.Bag = nil;
        container = 0;
    end
    return gEquip.CheckItemMatch(container, item, newItem);
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
        
        local setTable = StringToSet(set);
        if (type(setTable) == 'table') then
            for k, v in pairs(setTable) do
                Equip(k, v);
            end
            return;
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

local function EvaluateItem(item, level)
    if type(item) == 'string' then
        local resource = AshitaCore:GetResourceManager():GetItemByName(item, 0);
        if (resource ~= nil) then
            return (level >= resource.Level);
        end
    elseif type(item) == 'table' then
        if type(item.Level) == 'number' then
            return (level >= item.Level);
        else
            local resource = AshitaCore:GetResourceManager():GetItemByName(item.Name, 0);
            if (resource ~= nil) then
                return (level >= resource.Level);
            end
        end
    end
    return false;
end

local EvaluateLevels = function(baseTable, level)
    local buffer = {};
    for name,set in pairs(baseTable) do
        if (#name > 9) and (string.sub(name, -9) == '_Priority') then
            local newSet = {};
            for slotName,slotEntries in pairs(set) do
                if (gData.Constants.EquipSlots[slotName] ~= nil) then
                    if type(slotEntries) == 'string' then
                        newSet[slotName] = slotEntries;
                    elseif type(slotEntries) == 'table' then
                        if slotEntries[1] == nil then
                            newSet[slotName] = slotEntries;
                        else
                            for _,potentialEntry in ipairs(slotEntries) do
                                if EvaluateItem(potentialEntry, level) then
                                    newSet[slotName] = potentialEntry;
                                    break;
                                end
                            end
                        end
                    end
                end
            end
            local newKey = string.sub(name, 1, -10);
            buffer[newKey] = newSet;
        end
    end
    for key,val in pairs(buffer) do
        baseTable[key] = val;
    end
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
    local setTable = nil;
    if (type(set) == 'string') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('You must have a profile loaded to use ForceEquipSet(string).'));
            return;
        end
        
        if (gProfile.Sets == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Your profile must have a sets table to use ForceEquipSet(string).'));
            return;
        end
        
        setTable = StringToSet(set);
        
        if (setTable == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Set not found: ' .. set));
            return;
        end
    elseif (type(set) == 'table') then
        setTable = set;
    else
        return;
    end
    local newTable = {};
    for k,v in pairs(setTable) do
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

local InterimEquip = function(slot, item)
    local equipSlot = gData.GetEquipSlot(slot);
    if (equipSlot == 0) then
        print(chat.header('LuAshitacast') .. chat.error("Invalid slot specified: ") .. chat.color1(2, slot));
        return;
    end

    local table = gEquip.MakeItemTable(item);
    if (table == nil) or (type(table.Name) ~= 'string') then
        return;
    end    
    gEquip.EquipItemToBuffer(equipSlot, table, true);
end

local InterimEquipSet = function(set)
    if (type(set) == 'string') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('You must have a profile loaded to use InterimEquipSet(string).'));
            return;
        end
        
        if (gProfile.Sets == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Your profile must have a sets table to use InterimEquipSet(string).'));
            return;
        end
        
        local setTable = StringToSet(set);
        if (type(setTable) == 'table') then
            for k, v in pairs(setTable) do
                InterimEquip(k, v);
            end
            return;
        end
        
        print(chat.header('LuAshitacast') .. chat.error('Set not found: ' .. set));
    elseif (type(set) == 'table') then
        for k, v in pairs(set) do
            InterimEquip(k, v);
        end
    end
end

local Message = function(text)
    print(chat.header('LuAshitacast') .. chat.message(text));
end

local LoadFile = function(path)
    local paths = T{
        path,
        string.format('%s.lua', path),
        string.format('%sconfig\\addons\\luashitacast\\%s_%u\\%s', AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId, path),
        string.format('%sconfig\\addons\\luashitacast\\%s_%u\\%s.lua', AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId, path),
        string.format('%sconfig\\addons\\luashitacast\\%s', AshitaCore:GetInstallPath(), path),
        string.format('%sconfig\\addons\\luashitacast\\%s.lua', AshitaCore:GetInstallPath(), path),
    };
    for token in string.gmatch(package.path, "[^;]+") do
        paths:append(string.gsub(token, '?', path));
    end

    local filePath;
    for _,path in ipairs(paths) do
        if (ashita.fs.exists(path)) then
            filePath = path;
            break;
        end
    end

    if (filePath == nil) then
        print(chat.header('LuAshitacast') .. chat.error('File not found matching: ') .. chat.color1(2, path));
        return nil;
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
    local setTable = nil;
    if (type(set) == 'string') then
        if (gProfile == nil) then
            print(chat.header('LuAshitacast') .. chat.error('You must have a profile loaded to use LockSet(string).'));
            return;
        end
        
        if (gProfile.Sets == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Your profile must have a sets table to use LockSet(string).'));
            return;
        end

        setTable = StringToSet(set);

        if (setTable == nil) then
            print(chat.header('LuAshitacast') .. chat.error('Set not found: ' .. set));
            return;
        end
    elseif (type(set) == 'table') then
        setTable = set;
    else
        return;
    end

    gState.ForceSet = setTable;
    gState.ForceSetTimer = os.clock() + seconds;

    local newTable = {};
    for k,v in pairs(setTable) do
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

local SetMidDelay = function(delay)
    gState.DelayedEquip.Timer = os.clock() + delay;
end

local exports = {
    AddSet = AddSet,
    ApplyBaseSets = ApplyBaseSets,
    CancelAction = CancelAction,
    ChangeActionId = ChangeActionId,
    ChangeActionTarget = ChangeActionTarget,
    ClearEquipBuffer = ClearEquipBuffer,
    Combine = Combine,
    CompareItem = CompareItem,
    Disable = Disable,
    Echo = Echo,
    Enable = Enable,
    Equip = Equip,
    EquipSet = EquipSet,
    Error = Error,
    EvaluateLevels = EvaluateLevels,
    ForceEquip = ForceEquip,
    ForceEquipSet = ForceEquipSet,
    InterimEquip = InterimEquip,
    InterimEquipSet = InterimEquipSet,
    Message = Message,
    LoadFile = LoadFile,
    LockSet = LockSet,
    LockStyle = LockStyle,
    SetMidDelay = SetMidDelay,
};

return exports;
