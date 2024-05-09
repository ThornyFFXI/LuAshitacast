local data = {};
local encoding = require('encoding');
local japanese = (AshitaCore:GetConfigurationManager():GetInt32('boot', 'ashita.language', 'ashita', 2) == 1);
data.Constants = require('constants');

data.CheckInMogHouse = function()
    --Default to false if pointer scan failed
    if (gState.pZoneFlags == 0) then
        return false;
    end

    local zonePointer = ashita.memory.read_uint32(gState.pZoneFlags + 0);
    if (zonePointer ~= 0) then
        local zoneFlags = ashita.memory.read_uint32(zonePointer + gState.pZoneOffset);
        if (bit.band(zoneFlags, 0x100) == 0x100) then
            return true;
        end
    end

    return false;
end

data.CheckForNomad = function()
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    for i = 0,1023,1 do
        if (entity:GetServerId(i) > 0) then
            local renderFlags = entity:GetRenderFlags0(i);
            if (bit.band(renderFlags, 0x200) == 0x200) and (entity:GetDistance(i) < 36) then
                local entityName = entity:GetName(i);
                if (entityName == 'Nomad Moogle') or (entityName == 'Pilgrim Moogle') then
                    return true;
                end
            end
        end
    end                
end

--Checks if player has access to a container
data.GetContainerAvailable = function(container)
    for _,v in pairs(gSettings.ForceEnableBags) do
        if (v == container) then
            return true;
        end
    end

    for _,v in pairs(gSettings.ForceDisableBags) do
        if (v == container) then
            return false;
        end
    end
 
    --Probably slightly unnecessary to check any of these besides wardrobe, but never know with topaz I guess?
    --Likely to be recycled for some other addon or potentially useful to whoever's reading this anyway.
    --Satchel, Wardrobe3, Wardrobe4 checks work on retail, but as of 9/4/2021 they do not work on topaz because flags are passed in POL(?)
    
    if ((container == 0) or (container == 8) or (container == 10)) then --Inventory, Wardrobe, Wardrobe2
        return true;
    elseif (container > 10) then --Wardrobe3
        local flag = 2 ^ (container - 9);
        return (bit.band(gData.GetAccountFlags(), flag) ~= 0);
    elseif ((container == 1) or (container == 4) or (container == 9)) then --Safe, Locker, Safe2
        return ((gData.CheckInMogHouse() == true) or (gData.CheckForNomad() == true));
    elseif (container == 2) then --Storage
        return ((gData.CheckInMogHouse() == true) or ((gData.CheckForNomad() == true) and (gSettings.EnableNomadStorage == true)));
    elseif (container == 3) then --Temporary
        return false;
    elseif (container == 5) then --Satchel
        return (bit.band(gData.GetAccountFlags(), 0x01) == 0x01);
    else --Sack, Case
        return true;
    end
end

--Gets max amount of items in a container
data.GetContainerMax = function(container)
    local max = AshitaCore:GetMemoryManager():GetInventory():GetContainerCountMax(container);
    if (max < 1) then
        return 0;
    elseif (max > 80) then
        return 80;
    else
        return max;
    end
end

data.GetEquipSlot = function(slot)
    local equipSlot = 0;
    if (type(slot) == 'string') then
        for tableKey,tableEntry in pairs(gData.Constants.EquipSlots) do
            if string.lower(tableKey) == string.lower(slot) then
                equipSlot = tableEntry;
            end
        end
    elseif (type(slot) == 'number') then
        equipSlot = slot;
    end

    if (equipSlot < 1) or (equipSlot > 16) then
        equipSlot = 0;
    end

    return equipSlot;
end

data.ResolveString = function(table, value)
    if (table[value + 1] == nil) then
        return 'Unknown';
    else
        return table[value + 1];
    end
end

data.GetAccountFlags = function()
    local subPointer = ashita.memory.read_uint32(gState.pWardrobe);
	subPointer = ashita.memory.read_uint32(subPointer);
    return ashita.memory.read_uint8(subPointer + 0xB4);
end

data.GetAugment = function(item)
    local augType = struct.unpack('B', item.Extra, 1);
    if (augType ~= 2) and (augType ~= 3) then
        return { Type = 'Unaugmented' };
    end

    local augFlag = struct.unpack('B', item.Extra, 2);
    local itemTable = item.Extra:totable();

    if (bit.band(augFlag, 0x20) ~= 0) then
        --Delve style augments
        local augment = {};
        augment.Type = 'Delve';
        augment.Path = gData.GetAugmentPath(ashita.bits.unpack_be(itemTable, 16, 2));
        augment.Rank = ashita.bits.unpack_be(itemTable, 18, 4);
        augment.Augs = {};

        for i = 0,3,1 do
            local augmentId = ashita.bits.unpack_be(itemTable, (16 * i) + 48, 8);
            local augmentValue = ashita.bits.unpack_be(itemTable, (16 * i) + 56, 8);
            local currAugment = gData.GetAugmentResource(augmentId, augmentValue, gData.Constants.DelveAugments);
            if (currAugment ~= nil) then
                for _,singleAug in pairs(currAugment) do
                    if (augment.Augs[singleAug.Stat] == nil) then
                        augment.Augs[singleAug.Stat] = singleAug;
                    else
                        augment.Augs[singleAug.Stat].Value = augment.Augs[singleAug.Stat].Value + singleAug.Value;
                    end
                end
            end
        end
    
        for k,v in pairs(augment.Augs) do
            local augString = v.Stat;
            if (v.Value > 0) then
                augString = augString .. '+' .. v.Value;
            elseif (v.Value < 0) then
                augString = augString .. '-' .. v.Value;
            end
            if (v.Percent) then
                augString = augString .. '%';
            end
            v.String = augString;
        end

        return augment;
    end

    if (augFlag == 131) then
        --Dynamis style augments
        local augment = {};
        augment.Type = 'Dynamis';
        augment.Path = gData.GetAugmentPath(ashita.bits.unpack_be(itemTable, 32, 2));
        augment.Rank = ashita.bits.unpack_be(itemTable, 50, 5);
        return augment;
    end

    if (bit.band(augFlag, 0x08) ~= 0) then
        --I have done nothing to break down shield extdata, but this is where synth shields end up.
        return { Type = 'Unaugmented' };
    end

    if (bit.band(augFlag, 0x80) ~= 0) then
        --Evolith style augment
        return { Type = 'Unaugmented' };
    end

    local augment = {};
    local maxAugments = 5;
    if (bit.band(augFlag, 0x40) ~= 0) then
        --Magian trial augment
        augment.Type = 'Magian';
        augment.Trial = ashita.bits.unpack_be(itemTable, 80, 15);
        augment.TrialComplete = (ashita.bits.unpack_be(itemTable, 95, 1) == 1);
		maxAugments = 4;
    else
        augment.Type = 'Oseem';
    end

    augment.Augs = {};
    for i = 1,maxAugments,1 do
        local augmentId = ashita.bits.unpack_be(itemTable, (16 * i), 11);
        local augmentValue = ashita.bits.unpack_be(itemTable, (16 * i) + 11, 5);
        local currAugment = gData.GetAugmentResource(augmentId, augmentValue, gData.Constants.BasicAugments);
        if (currAugment ~= nil) then
            for _,singleAug in ipairs(currAugment) do
                if (augment.Augs[singleAug.Stat] == nil) then
                    augment.Augs[singleAug.Stat] = singleAug;
                else
                    augment.Augs[singleAug.Stat].Value = augment.Augs[singleAug.Stat].Value + singleAug.Value;
                end
            end
        end
    end

    for k,v in pairs(augment.Augs) do
        local augString = v.Stat;
        if (v.Value > 0) then
            augString = augString .. '+' .. v.Value;
        elseif (v.Value < 0) then
            augString = augString .. v.Value;
        end
        if (v.Percent) then
            augString = augString .. '%';
        end
        v.String = augString;
    end

    return augment;
end

data.GetAugmentResource = function(id, value, table)
    local resource = table[id];
    if (resource == nil) then
        return nil;
    end

    local augment = {};
    local index = 1;
    if (resource.Multi == true) then
        for _,singleResource in ipairs(resource) do
            augment[index] = gData.GetAugmentSingle(value, singleResource);
            index = index + 1;
        end
    else
        augment[index] = gData.GetAugmentSingle(value, resource);
    end
    
    return augment;
end

data.GetAugmentPath = function(index)
    return gData.ResolveString(gData.Constants.AugmentPaths, index);
end

data.GetAugmentSingle = function(value, resource)
    if (resource.Offset ~= nil) then
        value = value + resource.Offset;
    end

    if (resource.Multiplier ~= nil) then
        value = value * resource.Multiplier;
    end

    local augment = {};
    augment.Stat = resource.Stat;
    augment.Value = value;
    if (resource.Percent == true) then
        augment.Percent = true;
    end

    return augment;
end

data.GetCurrentCall = function()
    return gState.CurrentCall;
end

data.GetCurrentSet = function()
    local setTable = {};
    for i = 1,16,1 do
        local equip = gEquip.GetCurrentEquip(i);
        if (type(equip) == 'table') and (equip.Item ~= nil) then
            local resource = AshitaCore:GetResourceManager():GetItemById(equip.Item.Id);
            if (resource ~= nil) then
                local slot = gData.Constants.EquipSlotNames[i];
                local augment = gData.GetAugment(equip.Item);
                local resourceName = encoding:ShiftJIS_To_UTF8(resource.Name[1]);

                if (augment.Type == 'Unaugmented') then
                    setTable[slot] = resourceName;
                else
                    local entry = {};
                    entry.Name = resourceName;
                    if (augment.Path ~= nil) then
                        entry.AugPath = augment.Path;
                    elseif (augment.Trial ~= nil) then
                        entry.AugTrial = augment.Trial;
                    elseif (augment.Augs ~= nil) then
                        local augCount = 0;
                        for k,v in pairs(augment.Augs) do
                            augCount = augCount + 1;
                        end

                        if (augCount == 1) then
                            for k,v in pairs(augment.Augs) do
                                entry.Augment = v.String;
                            end
                        else
                            entry.Augment = {};
                            local index = 1;
                            for k,v in pairs(augment.Augs) do
                                entry.Augment[index] = v.String;
                                index = index + 1;
                            end
                        end
                    end
                    setTable[slot] = entry;
                end
            end
        end
    end
    return setTable;
end

data.GetTargetIndex = function()
    if (AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive() > 0) then
        return AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(1);
    else
        return AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
    end
end

data.GetTimestamp = function()
    local pointer = ashita.memory.read_uint32(gState.pVanaTime + 0x34);
    local rawTime = ashita.memory.read_uint32(pointer + 0x0C) + 92514960;
    local timestamp = {};
    timestamp.day = math.floor(rawTime / 3456);
    timestamp.hour = math.floor(rawTime / 144) % 24;
    timestamp.minute = math.floor((rawTime % 144) / 2.4);
    return timestamp;
end

data.GetWeather = function()
    local pointer = ashita.memory.read_uint32(gState.pWeather + 0x02);
    return ashita.memory.read_uint8(pointer + 0);
end

data.GetAlliance = function()
    local action = gState.PlayerAction;
    local allianceTable = {};
    allianceTable.ActionTarget = false;
    allianceTable.Count = 0;
    allianceTable.InAlly = false;
    allianceTable.Target = false;
    local myTarget = gData.GetTargetIndex();

    for i = 1,18,1 do
        if (AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(i - 1)) then
            allianceTable.Count = allianceTable.Count + 1;
            if (i > 6) then
                allianceTable.InAlly = true;
            end
            local index = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(i - 1);
            if (action ~= nil) and (index == action.Target) then
                allianceTable.ActionTarget = true;
            end
            if (index == myTarget) then
                allianceTable.Target = true;
            end
        end
    end

    return allianceTable;
end

data.GetAction = function()
    local action = gState.PlayerAction;
    if (action == nil) then
        return nil;
    end

    local actionTable = {};
    actionTable.Resource = action.Resource;
    actionTable.ActionType = action.Type;
    actionTable.Resend = action.Resend;
    if (action.Type == 'Spell') then
        actionTable.CastTime = action.Resource.CastTime * 250;
        actionTable.Element = gData.ResolveString(gData.Constants.SpellElements, action.Resource.Element);
        actionTable.Id = action.Resource.Index;
        actionTable.MpCost = action.Resource.ManaCost;
        local currentMp = AshitaCore:GetMemoryManager():GetParty():GetMemberMP(0)
        actionTable.MpAftercast = currentMp - actionTable.MpCost;
        actionTable.MppAftercast = (actionTable.MpAftercast * 100) / AshitaCore:GetMemoryManager():GetPlayer():GetMPMax();
        actionTable.Name = encoding:ShiftJIS_To_UTF8(action.Resource.Name[1]);
        actionTable.Recast = action.Resource.RecastDelay * 250;
        actionTable.Skill = gData.ResolveString(gData.Constants.SpellSkills, action.Resource.Skill);
        actionTable.Type = gData.ResolveString(gData.Constants.SpellTypes, action.Resource.Type);
    elseif (action.Type == 'Weaponskill') then
        actionTable.Name = encoding:ShiftJIS_To_UTF8(action.Resource.Name[1]);
        actionTable.Id = action.Resource.Id;
    elseif (action.Type == 'Ability') then
        actionTable.Name = encoding:ShiftJIS_To_UTF8(action.Resource.Name[1]);
        actionTable.Id = action.Resource.Id - 0x200;
        local abilityType = gData.Constants.AbilityTypes[action.Resource.RecastTimerId];
        if (abilityType ~= nil) then
            actionTable.Type = abilityType;
        else
            actionTable.Type = 'Unknown';
        end
    elseif (action.Type == 'Ranged') then
        actionTable.Name = 'Ranged';
        actionTable.Id = 0;
    elseif (action.Type == 'Item') then
        actionTable.CastTime = action.Resource.CastTime * 250;
        actionTable.Id = action.Resource.Id;
        actionTable.Name = encoding:ShiftJIS_To_UTF8(action.Resource.Name[1]);
        actionTable.Recast = action.Resource.RecastDelay * 250;
    end

    return actionTable;
end

data.GetActionTarget = function()
    if (gState.PlayerAction == nil) or (gState.PlayerAction.Target == nil) then
        return nil;
    end
    return gData.GetEntity(gState.PlayerAction.Target);
end

data.GetBuffCount = function(matchBuff)
    local count = 0;
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();    
    if (type(matchBuff) == 'string') then
        local matchText = string.lower(matchBuff);
        for _, buff in pairs(buffs) do
            local buffString = AshitaCore:GetResourceManager():GetString("buffs.names", buff)
            if (buffString) then
                buffString = encoding:ShiftJIS_To_UTF8(buffString:trimend('\x00'));
                if (not japanese) then
                    buffString = string.lower(buffString);
                end
                
                if (buffString == matchText) then
                    count = count + 1;
                end
            end
        end
    elseif (type(matchBuff) == 'number') then
        for _, buff in pairs(buffs) do
            if (buff == matchBuff) then
                count = count + 1;
            end
        end
    end
    return count;
end

data.GetEntity = function(index)
    local entityTable = {};
    entityTable.Distance = math.sqrt(AshitaCore:GetMemoryManager():GetEntity():GetDistance(index));
    entityTable.HPP = AshitaCore:GetMemoryManager():GetEntity():GetHPPercent(index);
    entityTable.Id = AshitaCore:GetMemoryManager():GetEntity():GetServerId(index);
    entityTable.Index = index;
    entityTable.Name = AshitaCore:GetMemoryManager():GetEntity():GetName(index);
    entityTable.Status = gData.ResolveString(gData.Constants.EntityStatus, AshitaCore:GetMemoryManager():GetEntity():GetStatus(index));
    entityTable.Type = gData.ResolveString(gData.Constants.SpawnFlags, AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(index));
    return entityTable;
end

data.GetEnvironment = function()
    local environmentTable = {};
    environmentTable.Area = AshitaCore:GetResourceManager():GetString("zones.names", AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0));
    if type(environmentTable.Area) == 'string' then
        environmentTable.Area = encoding:ShiftJIS_To_UTF8(environmentTable.Area:trimend('\x00'));
    end
    local timestamp = gData.GetTimestamp();
    environmentTable.Day = gData.Constants.WeekDay[(timestamp.day % 8) + 1];
    environmentTable.DayElement = gData.Constants.WeekDayElement[(timestamp.day % 8) + 1];
    environmentTable.MoonPhase = gData.ResolveString(gData.Constants.MoonPhase, ((timestamp.day + 26) % 84) + 1);
    environmentTable.MoonPercent = gData.Constants.MoonPhasePercent[((timestamp.day + 26) % 84) + 1];
    local weather = gData.GetWeather();
    environmentTable.RawWeather = gData.ResolveString(gData.Constants.Weather, weather);
    environmentTable.RawWeatherElement = gData.ResolveString(gData.Constants.WeatherElement, weather);
    environmentTable.Time = timestamp.hour + (timestamp.minute / 100);
    environmentTable.Timestamp = timestamp;
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();    
    for _, buff in pairs(buffs) do
        if (gData.Constants.StormWeather[buff] ~= nil) then
            weather = gData.Constants.StormWeather[buff];
        end
    end
    environmentTable.Weather = gData.ResolveString(gData.Constants.Weather, weather);
    environmentTable.WeatherElement = gData.ResolveString(gData.Constants.WeatherElement, weather);
    return environmentTable;
end

data.GetEquipment = function()
    local equipTable = {};
    for i = 1,16,1 do
        local equip = gEquip.GetCurrentEquip(i);
        if (type(equip) == 'table') and (equip.Item ~= nil) then
            local resource = AshitaCore:GetResourceManager():GetItemById(equip.Item.Id);
            if (resource ~= nil) then
                local singleTable = {};
                singleTable.Container = equip.Container;
                singleTable.Item = equip.Item;
                singleTable.Name = encoding:ShiftJIS_To_UTF8(resource.Name[1]);
                singleTable.Resource = resource;
                local slot = gData.Constants.EquipSlotNames[i];
                equipTable[slot] = singleTable;
            end
        end
    end
    return equipTable;
end

data.GetEquipScreen = function()
    local equipScreenTable = {};
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer();

    equipScreenTable.Attack = pPlayer:GetAttack();
    equipScreenTable.DarkResistance = pPlayer:GetResist(7);
    equipScreenTable.Defense = pPlayer:GetDefense();
    equipScreenTable.EarthResistance = pPlayer:GetResist(3);
    equipScreenTable.FireResistance = pPlayer:GetResist(0);
    equipScreenTable.IceResistance = pPlayer:GetResist(1);
    equipScreenTable.LightningResistance = pPlayer:GetResist(4);
    equipScreenTable.LightResistance = pPlayer:GetResist(6);
    equipScreenTable.WaterResistance = pPlayer:GetResist(5);
    equipScreenTable.WindResistance = pPlayer:GetResist(2);

    return equipScreenTable;
end

data.GetPet = function()
    local myIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
    local petIndex = AshitaCore:GetMemoryManager():GetEntity():GetPetTargetIndex(myIndex);
    if (petIndex == 0) or AshitaCore:GetMemoryManager():GetEntity():GetHPPercent(petIndex) == 0 then
        return nil;
    end

    local petTable = {};
    petTable.Distance = math.sqrt(AshitaCore:GetMemoryManager():GetEntity():GetDistance(petIndex));
    petTable.HPP = AshitaCore:GetMemoryManager():GetEntity():GetHPPercent(petIndex);
    petTable.Id = AshitaCore:GetMemoryManager():GetEntity():GetServerId(petIndex);
    petTable.Index = petIndex;
    petTable.Name = AshitaCore:GetMemoryManager():GetEntity():GetName(petIndex);
    petTable.Status = gData.ResolveString(gData.Constants.EntityStatus, AshitaCore:GetMemoryManager():GetEntity():GetStatus(petIndex));
    petTable.TP = AshitaCore:GetMemoryManager():GetPlayer():GetPetTP();
    return petTable;
end

data.GetPetAction = function()
    local action = gState.PetAction;
    if (action == nil) then
        return nil;
    end
    
    local myIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
    local petIndex = AshitaCore:GetMemoryManager():GetEntity():GetPetTargetIndex(myIndex);
    if (petIndex == 0) or AshitaCore:GetMemoryManager():GetEntity():GetHPPercent(petIndex) == 0 then
        return nil;
    end

    local actionTable = {};
    actionTable.ActionType = action.Type;
    if (action.Type == 'Spell') then
        actionTable.CastTime = action.Resource.CastTime * 250;
        actionTable.Element = gData.ResolveString(gData.Constants.SpellElements, action.Resource.Element);
        actionTable.Id = action.Resource.Index;
        actionTable.MpCost = action.Resource.ManaCost;
        actionTable.Name = encoding:ShiftJIS_To_UTF8(action.Resource.Name[1]);
        actionTable.Recast = action.Resource.RecastDelay * 250;
        actionTable.Skill = gData.ResolveString(gData.Constants.SpellSkills, action.Resource.Skill);
        actionTable.Type = gData.ResolveString(gData.Constants.SpellTypes, action.Resource.Type);
    elseif (action.Type == 'Ability') then
        actionTable.Name = encoding:ShiftJIS_To_UTF8(action.Resource.Name[1]);
        actionTable.Id = action.Resource.Id - 0x200;
        local abilityType = gData.Constants.AbilityTypes[action.Resource.RecastTimerId];
        if (abilityType ~= nil) then
            actionTable.Type = abilityType;
        else
            actionTable.Type = 'Generic';
        end
    elseif (action.Type == 'MobSkill') then
        actionTable.Id = action.Id;
        actionTable.Name = action.Name;
        if type(actionTable.Name) == 'string'then
            actionTable.Name = encoding:ShiftJIS_To_UTF8(actionTable.Name:trimend('\x00'));
        end
    end

    return actionTable;
end

data.GetPlayer = function()
    local playerTable = {};
    local pEntity = AshitaCore:GetMemoryManager():GetEntity();
    local pParty = AshitaCore:GetMemoryManager():GetParty();
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer();
    local myIndex = pParty:GetMemberTargetIndex(0);

    playerTable.HP = pParty:GetMemberHP(0);
    playerTable.MaxHP = pPlayer:GetHPMax();
    playerTable.HPP = pParty:GetMemberHPPercent(0);
    playerTable.IsMoving =  ((pEntity:GetLocalPositionX(myIndex) ~= gState.PositionX) or (pEntity:GetLocalPositionY(myIndex) ~= gState.PositionY));
    local mainJob = pPlayer:GetMainJob();
    local job = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", mainJob);
    if (type(job) == 'string') then
        job = encoding:ShiftJIS_To_UTF8(job:trimend('\x00'));
    end
    playerTable.MainJob = job;
    playerTable.MainJobLevel = pPlayer:GetJobLevel(mainJob);
    playerTable.MainJobSync = pPlayer:GetMainJobLevel();
    playerTable.MP = pParty:GetMemberMP(0);
    playerTable.MaxMP = pPlayer:GetMPMax();
    playerTable.MPP = pParty:GetMemberMPPercent(0);
    playerTable.Name = pParty:GetMemberName(0);
    playerTable.Status = gData.ResolveString(gData.Constants.EntityStatus, pEntity:GetStatus(myIndex));
    local subJob = pPlayer:GetSubJob();
    job = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", subJob);
    if (type(job) == 'string') then
        job = encoding:ShiftJIS_To_UTF8(job:trimend('\x00'));
    end
    playerTable.SubJob = job;
    playerTable.SubJobLevel = pPlayer:GetJobLevel(subJob);
    playerTable.SubJobSync = pPlayer:GetSubJobLevel();
    playerTable.TP = pParty:GetMemberTP(0);

    return playerTable;
end

data.GetParty = function()    
    local action = gState.PlayerAction;
    local partyTable = {};
    partyTable.ActionTarget = false;
    partyTable.Count = 0;
    partyTable.InParty = false;
    partyTable.Target = false;
    local myTarget = gData.GetTargetIndex();

    for i = 1,18,1 do
        if (AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(i - 1) == 1) then
            partyTable.Count = partyTable.Count + 1;
            if (i > 1) then
                partyTable.InParty = true;
            end
            local index = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(i - 1);
            if (action ~= nil) and (index == action.Target) then
                partyTable.ActionTarget = true;
            end
            if (index == myTarget) then
                partyTable.Target = true;
            end
        end
    end

    return partyTable;
end

data.GetTarget = function()
    local targetIndex = gData.GetTargetIndex();
    if (targetIndex == 0) then
        return nil;
    end
    return gData.GetEntity(targetIndex);
end

return data;