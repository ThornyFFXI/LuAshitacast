local encoding = require('encoding');
local ffi = require("ffi");
ffi.cdef[[
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];

local packethandlers = {};

packethandlers.HandleIncoming0x0A = function(e)
    local id = struct.unpack('L', e.data, 0x04 + 1);
    local name = struct.unpack('c16', e.data, 0x84 + 1):trim('\0');
    local job = struct.unpack('B', e.data, 0xB4 + 1);
    if (gState.PlayerJob ~= job) or (gState.PlayerId ~= id) or (gState.PlayerName ~= name) then
        gState.PlayerId = id;
        gState.PlayerName = name;
        gState.PlayerJob = job;
        local configPath = string.format('%sconfig\\addons\\luashitacast\\%s_%u\\?.lua;', AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId);
        package.path = configPath .. gState.BasePath;
        if (gProfile == nil) then
            coroutine.sleep(0.5);
        end
        gState.AutoLoadProfile();
    end
    gState.ZoneTimer = os.clock() + 10;
end

packethandlers.HandleIncoming0x1B = function(e)
    local job = struct.unpack('B', e.data, 0x08 + 1);
    for i = 1,16,1 do
        gState.Encumbrance[i] = (ashita.bits.unpack_be(e.data_raw, 0x60, i - 1, 1) == 1);
    end
    if (job ~= gState.PlayerJob) then
        gState.PlayerJob = job;
        gState.AutoLoadProfile();
    end
end

packethandlers.HandleIncoming0x61 = function(e)
    local job = struct.unpack('B', e.data, 0x0C + 1);
    if (job ~= gState.PlayerJob) then
        gState.PlayerJob = job;
        gState.AutoLoadProfile();
    end
end

packethandlers.HandleIncoming0x28 = function(e)
    local userId = struct.unpack('L', e.data, 0x05 + 1);
    local actionType = ashita.bits.unpack_be(e.data_raw, 10, 2, 4);

    if (userId == gState.PlayerId) then
        if (gData.Constants.ActionCompleteTypes:contains(actionType)) then
            if (gSettings.Debug) and (gState.PlayerAction ~= nil) then
                print(chat.header('LuAshitacast') .. chat.message('Action ending due to action packet of type ' .. tostring(actionType) .. '.'));
            end
            gState.DelayedEquip = {};
            gState.PlayerAction = nil;
        elseif (actionType == 8) or (actionType == 12) then
            --Ranged or magic interrupt resets delay so idlegear resumes.
            if (ashita.bits.unpack_be(e.data_raw, 10, 6, 16) == 28787) then
                if (gSettings.Debug) and (gState.PlayerAction ~= nil) then
                    print(chat.header('LuAshitacast') .. chat.message('Action ending due to action packet of type ' .. tostring(actionType) .. ' with parameters indicating interruption.'));
                end
                gState.DelayedEquip = {};
                gState.PlayerAction = nil;
            end
        end
        return;
    end

    local myIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
    local petIndex = AshitaCore:GetMemoryManager():GetEntity():GetPetTargetIndex(myIndex);
    if (petIndex == 0) then
        return;
    end

    if (userId == AshitaCore:GetMemoryManager():GetEntity():GetServerId(petIndex)) then
        if (gData.Constants.PetActionCompleteTypes:contains(actionType)) then
            if (gSettings.Debug) and (gState.PetAction ~= nil) then
                print(chat.header('LuAshitacast') .. chat.message('Pet action ending due to action packet of type ' .. tostring(actionType) .. '.'));
            end
            gState.PetAction = nil;
            return;
        elseif (actionType == 8) or (actionType == 12) then
            --Ranged or magic interrupt resets delay so idlegear resumes.
            if (ashita.bits.unpack_be(e.data_raw, 10, 6, 16) == 28787) then
                if (gSettings.Debug) and (gState.PetAction ~= nil) then
                    print(chat.header('LuAshitacast') .. chat.message('Pet action ending due to action packet of type ' .. tostring(actionType) .. ' with parameters indicating interruption.'));
                end
                gState.PetAction = nil;
				return;
            end
        end

        if (actionType == 7) or (actionType == 8) then
            local actionId = ashita.bits.unpack_be(e.data_raw, 0, 213, 17);
            if (actionId == 0) then
                return;
            end
            
            local actionTargetId = ashita.bits.unpack_be(e.data_raw, 18, 6, 32);

            --Anything in zone dat should work here.
            local actionTargetIndex = bit.band(actionTargetId, 0x7FF);

            --If target is given index dynamically, we have to iterate to find index.
            if (AshitaCore:GetMemoryManager():GetEntity():GetServerId(actionTargetIndex) ~= actionTargetId) then
                actionTargetIndex = 0;
                for i = 0x400,0x8FF,1 do
                    if (AshitaCore:GetMemoryManager():GetEntity():GetServerId(i) == actionTargetId) then
                        actionTargetIndex = i;
                        break;
                    end
                end
            end
            
            gState.PetAction = {
                Id = actionId,
                Target = actionTargetIndex
            };

            if (actionType == 7) then
                --Pet Ability
                gState.PetAction.Completion = os.clock() + gSettings.PetskillDelay;
                local actionMessage = ashita.bits.unpack_be(e.data_raw, 28, 6, 10);
                if (actionMessage == 43) then
                    gState.PetAction.Type = 'MobSkill';
                    gState.PetAction.Name = AshitaCore:GetResourceManager():GetString("monsters.abilities", actionId - 256);
                    if type(gState.PetAction.Name) == 'string'then
                        gState.PetAction.Name = encoding:ShiftJIS_To_UTF8(gState.PetAction.Name:trimend('\x00'));
                    end
                else
                    gState.PetAction.Type = 'Ability';
                    gState.PetAction.Resource = AshitaCore:GetResourceManager():GetAbilityById(actionId + 512);
                end
            else
                --Pet Spell (8)
                gState.PetAction.Type = 'Spell';
                gState.PetAction.Resource = AshitaCore:GetResourceManager():GetSpellById(actionId);
                gState.PetAction.Completion = os.clock() + (gState.PetAction.Resource.CastTime * 0.25) + gSettings.SpellOffset;
            end
        end
    end
end

packethandlers.HandleActionPacket = function(packet, resend)
    local category = struct.unpack('H', packet, 0x0A + 0x01);
    local actionId = struct.unpack('H', packet, 0x0C + 0x01);
    local targetIndex = struct.unpack('H', packet, 0x08 + 0x01);
    if (category == 0x03) then
        gState.DelayedEquip = {};
        gState.PlayerAction = { Block = false, Resend = resend };
        gState.PlayerAction.Packet = packet:totable();
        gState.PlayerAction.Target = targetIndex;
        gState.PlayerAction.Type = 'Spell';
        gState.PlayerAction.Resource = AshitaCore:GetResourceManager():GetSpellById(actionId);
        local baseCast = gState.PlayerAction.Resource.CastTime * 0.25;
        baseCast = (baseCast * (100 - gSettings.FastCast)) / 100;
        gState.PlayerAction.Completion = os.clock() + baseCast + gSettings.SpellOffset;
        gState.HandleEquipEvent('HandlePrecast', 'set');
    elseif (category == 0x07) then
        gState.DelayedEquip = {};
        gState.PlayerAction = { Block = false, Resend = resend };
        gState.PlayerAction.Packet = packet:totable();
        gState.PlayerAction.Target = targetIndex;
        gState.PlayerAction.Type = 'Weaponskill';
        gState.PlayerAction.Resource = AshitaCore:GetResourceManager():GetAbilityById(actionId);
        gState.PlayerAction.Completion = os.clock() + gSettings.WeaponskillDelay;
        gState.HandleEquipEvent('HandleWeaponskill', 'auto');
    elseif (category == 0x09) then
        gState.DelayedEquip = {};
        gState.PlayerAction = { Block = false, Resend = resend };
        gState.PlayerAction.Packet = packet:totable();
        gState.PlayerAction.Target = targetIndex;
        gState.PlayerAction.Type = 'Ability';
        gState.PlayerAction.Resource = AshitaCore:GetResourceManager():GetAbilityById(actionId + 0x200);
        gState.PlayerAction.Completion = os.clock() + gSettings.AbilityDelay;
        gState.HandleEquipEvent('HandleAbility', 'auto');
    elseif (category == 0x10) then
        gState.DelayedEquip = {};
        gState.PlayerAction = { Block = false, Resend = resend };
        gState.PlayerAction.Packet = packet:totable();
        gState.PlayerAction.Target = targetIndex;
        gState.PlayerAction.Type = 'Ranged';
        local rangedBase = (gSettings.RangedBase * (100 - gSettings.Snapshot)) / 100;
        gState.PlayerAction.Completion = os.clock() + rangedBase + gSettings.RangedOffset;
        gState.HandleEquipEvent('HandlePreshot', 'set');
    else
        return;
    end

    if (gState.PlayerAction.Block == true) then
        gState.PlayerAction = nil;
        return;
    else
        gState.Inject(0x1A, gState.PlayerAction.Packet);
    end

    if (gState.PlayerAction.Type == 'Spell') then
        local baseCast = gState.PlayerAction.Resource.CastTime * 0.25;
        baseCast = (baseCast * (100 - gSettings.FastCast)) / 100;
        gState.PlayerAction.Completion = os.clock() + baseCast + gSettings.SpellOffset;
        gState.HandleEquipEvent('HandleMidcast', 'single');
    elseif (gState.PlayerAction.Type == 'Ranged') then
        local rangedBase = (gSettings.RangedBase * (100 - gSettings.Snapshot)) / 100;
        gState.PlayerAction.Completion = os.clock() + rangedBase + gSettings.RangedOffset;
        gState.HandleEquipEvent('HandleMidshot', 'single');
    end
end

packethandlers.HandleItemPacket = function(packet, resend)
    local itemIndex = struct.unpack('B', packet, 0x0E + 0x01);
    local itemContainer = struct.unpack('B', packet, 0x10 + 0x01);
    local targetIndex = struct.unpack('H', packet, 0x0C + 0x01);
    local item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(itemContainer, itemIndex);
    
    gState.DelayedEquip = {};
    gState.PlayerAction = { Block = false, Resend = resend };
    gState.PlayerAction.Packet = packet:totable();
    gState.PlayerAction.Target = targetIndex;
    gState.PlayerAction.Type = 'Item';
    if (item == nil) or (item.Id == 0) or (item.Count == 0) then
        gState.PlayerAction.Completion = os.clock() + gSettings.ItemBase + gSettings.ItemOffset;
    else
        gState.PlayerAction.Resource = AshitaCore:GetResourceManager():GetItemById(item.Id);
        gState.PlayerAction.Completion = os.clock() + (gState.PlayerAction.Resource.CastTime * 0.25) + gSettings.ItemOffset;
    end

    gState.HandleEquipEvent('HandleItem', 'auto');
    if (gState.PlayerAction.Block == true) then
        gState.PlayerAction = nil;
        return;
    end
    
    gState.Inject(0x37, gState.PlayerAction.Packet);
end

--Check for duplicate packets..   
local packetBuffer = ffi.new('uint8_t[?]', 512);
local function CheckDuplicate(chunk, offset, size)
    local ptr = ffi.cast('uint8_t*', chunk) + offset;
    if (ffi.C.memcmp(packetBuffer, ptr, size) == 0) then
        return true;
    end
    ffi.copy(packetBuffer, ptr, size);
    return false;
end

packethandlers.HandleOutgoingChunk = function(e)
    --Clear expired actions.
    local time = os.clock();
    if (gState.PlayerAction ~= nil) and (gState.PlayerAction.Completion < time) then
        if (gSettings.Debug) then
            print(chat.header('LuAshitacast') .. chat.message('Action ending due to timeout.'));
        end
        gState.PlayerAction = nil;
    end
    if (gState.PetAction ~= nil) and (gState.PetAction.Completion < time) then
        if (gSettings.Debug) then
            print(chat.header('LuAshitacast') .. chat.message('Pet action ending due to timeout.'));
        end
        gState.PetAction = nil;
    end

    local newPositionX = gState.PositionX;
    local newPositionY = gState.PositionY;

    --Read ahead to handle any action packets, so we aren't doing idle and action at once.
    local offset = 0;
    while (offset < e.chunk_size) do
        local id    = ashita.bits.unpack_be(e.chunk_data_raw, offset, 0, 9);
        local size  = ashita.bits.unpack_be(e.chunk_data_raw, offset, 9, 7) * 4;
        if (id == 0x1A) then
            local isResend = CheckDuplicate(e.chunk_data_raw, offset, size);
            local sequencer = (AshitaCore:GetPluginManager():Get('Sequencer') ~= nil);
            if (not isResend) or (sequencer) then
                gPacketHandlers.HandleActionPacket(struct.unpack('c' .. size, e.chunk_data, offset + 1), isResend);
            end
        elseif (id == 0x15) then
            newPositionX = struct.unpack('f', e.chunk_data, offset + 0x04 + 1);
            newPositionY = struct.unpack('f', e.chunk_data, offset + 0x0C + 1);
        elseif (id == 0x37) then
            local isResend = CheckDuplicate(e.chunk_data_raw, offset, size);
            local sequencer = (AshitaCore:GetPluginManager():Get('Sequencer') ~= nil);
            if (not isResend) or (sequencer) then
                gPacketHandlers.HandleItemPacket(struct.unpack('c' .. size, e.chunk_data, offset + 1), isResend);
            end
        end
        offset = offset + size;
    end


    if (gState.PlayerAction == nil) then
        gState.HandleEquipEvent('HandleDefault', 'auto');
    elseif (gState.DelayedEquip.Timer ~= nil) then
        local timer = os.clock() + (AshitaCore:GetPluginManager():Get('PacketFlow') and 0.25 or 0.4);
        if (timer > gState.DelayedEquip.Timer) then
            local backup = gState.CurrentCall;
            gState.CurrentCall = gState.DelayedEquip.Tag;
            gFunc.ForceEquipSet(gState.DelayedEquip.Set);
            gState.DelayedEquip = {};
            gState.CurrentCall = backup;
        end
    end

    gState.PositionX = newPositionX;
    gState.PositionY = newPositionY;
end

packethandlers.HandleIncomingPacket = function(e)
    if (e.id == 0x00A) then
        gPacketHandlers.HandleIncoming0x0A(e);
    elseif (e.id == 0x1B) then
        gPacketHandlers.HandleIncoming0x1B(e);
    elseif (e.id == 0x61) then
        gPacketHandlers.HandleIncoming0x61(e);
    elseif (e.id == 0x028) then
        gPacketHandlers.HandleIncoming0x28(e);
    end
end

local handledCategories = T{0x03, 0x07, 0x09, 0x10};
packethandlers.HandleOutgoingPacket = function(e)
    --Handle packets that are being injected by anything else in real time.
    if (e.injected == true) then
        if (gState.Injecting == false) then
            if (e.id == 0x1A) then
                local category = struct.unpack('H', e.data, 0x0A + 0x01);
                if handledCategories:contains(category) then
                    gPacketHandlers.HandleActionPacket(struct.unpack('c' .. e.size, e.data, 1));
                    e.blocked = true;
                end
            elseif (e.id == 0x37) then
                gPacketHandlers.HandleItemPacket(struct.unpack('c' .. e.size, e.data, 1));
                e.blocked = true;
            end
        end
        return;
    end

    --If we're in a new outgoing chunk, handle idle / action stuff.
    if (ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0) then
        gPacketHandlers.HandleOutgoingChunk(e);
    end

    --Block all action packets that LAC triggers on.
    --HandleOutgoingChunk will automatically reinject them if keeping them.
    if (e.id == 0x1A) then
        local category = struct.unpack('H', e.data, 0x0A + 0x01);
        if handledCategories:contains(category) then
            e.blocked = true;
            return;
        end
    end

    --Block item use packets.
    --HandleOutgoingChunk will automatically reinject them if keeping them.
    if (e.id == 0x37) then
        e.blocked = true;
        return;
    end

    --Manual lockstyle packet
    if (e.id == 0x53) and (e.injected == false) then
        local type = struct.unpack('B', e.data, 0x05 + 1);

        if (type == 0) then
            if (gState.ZoneTimer ~= nil) and (os.clock() < gState.ZoneTimer) and (gState.LockStyle ~= nil) then
                ashita.bits.pack_be(e.data_modified_raw, 1, 5, 0, 8);
            else
                gState.LockStyle = nil;
            end
        
        --Clear lockstyle state if player manually did a lockstyle.
        elseif (type == 3) then
            gState.LockStyle = nil;
        end
    end
end


return packethandlers;