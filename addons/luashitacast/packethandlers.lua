local ffi = require("ffi");
ffi.cdef[[
    int32_t memcmp(const void* buff1, const void* buff2, size_t count);
]];

local packethandlers = {};

packethandlers.HandleIncoming0x0A = function(e)
    local id = struct.unpack('L', e.data, 0x04 + 1);
    local name = struct.unpack('c16', e.data, 0x84 + 1);
    local i,j = string.find(name, '\0');
    if (i ~= nil) then
        name = string.sub(name, 1, i - 1);
    end
    local job = struct.unpack('B', e.data, 0xB4 + 1);
    if (gState.PlayerJob ~= job) or (gState.PlayerId ~= id) or (gState.PlayerName ~= name) then
        gState.PlayerId = id;
        gState.PlayerName = name;
        gState.PlayerJob = job;
        gState.AutoLoadProfile();
    end
end

packethandlers.HandleIncoming0x1B = function(e)
    for i = 1,16,1 do
        gState.Encumbrance[i] = (ashita.bits.unpack_be(e.data_raw, 0x60, i - 1, 1) == 1);
    end
end

packethandlers.HandleIncoming0x28 = function(e)
    local userId = struct.unpack('L', e.data, 0x05 + 1);
    local actionType = ashita.bits.unpack_be(e.data_raw, 10, 2, 4);

    if (userId == gState.PlayerId) then
        if (gData.Constants.ActionCompleteTypes:containskey(actionType)) then
            gState.PlayerAction = nil;
        elseif (actionType == 8) or (actionType == 12) then
            --Ranged or magic interrupt resets delay so idlegear resumes.
            if (ashita.bits.unpack_be(e.data_raw, 10, 6, 16) == 28787) then
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
        if (gData.Constants.PetActionCompleteTypes:containskey(actionType)) then
            gState.PetAction = nil;
            return;
        elseif (actionType == 8) or (actionType == 12) then
            --Ranged or magic interrupt resets delay so idlegear resumes.
            if (ashita.bits.unpack_be(e.data_raw, 10, 6, 16) == 28787) then
                gState.PetAction = nil;
				return;
            end
        end

        if (actionType == 7) or (actionType == 8) then
            local actionId = ashita.bits.unpack_be(e.data_raw, 0, 213, 17);
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
                Id = actionId;
                Target = actionTargetIndex
            };
            print(actionType);

            if (actionType == 7) then
                --Pet Ability
                gState.PetAction.Completion = os.clock() + gSettings.PetskillDelay;
                local actionMessage = ashita.bits.unpack_be(e.data_raw, 28, 6, 10);
                if (actionMessage == 43) then
                    gState.PetAction.Type = 'MobSkill';
                    gState.PetAction.Name = AshitaCore:GetResourceManager():GetString("monsters.abilities", actionId - 256);
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

packethandlers.HandleActionPacket = function(packet)
    local category = struct.unpack('H', packet, 0x0A + 0x01);
    local actionId = struct.unpack('H', packet, 0x0C + 0x01);
    local targetIndex = struct.unpack('H', packet, 0x08 + 0x01);
    if (category == 0x03) then
        gState.PlayerAction = { Block = false };
        gState.PlayerAction.Packet = packet:totable();
        gState.PlayerAction.Target = targetIndex;
        gState.PlayerAction.Type = 'Spell';
        gState.PlayerAction.Resource = AshitaCore:GetResourceManager():GetSpellById(actionId);
        local baseCast = gState.PlayerAction.Resource.CastTime * 0.25;
        baseCast = (baseCast * (100 - gSettings.FastCast)) / 100;
        gState.PlayerAction.Completion = os.clock() + baseCast + gSettings.SpellOffset;
        gState.HandleEquipEvent('HandlePrecast', 'set');
    elseif (category == 0x07) then
        gState.PlayerAction = { Block = false };
        gState.PlayerAction.Packet = packet:totable();
        gState.PlayerAction.Target = targetIndex;
        gState.PlayerAction.Type = 'Weaponskill';
        gState.PlayerAction.Resource = AshitaCore:GetResourceManager():GetAbilityById(actionId);
        gState.PlayerAction.Completion = os.clock() + gSettings.WeaponskillDelay;
        gState.HandleEquipEvent('HandleWeaponskill', 'auto');
    elseif (category == 0x09) then
        gState.PlayerAction = { Block = false };
        gState.PlayerAction.Packet = packet:totable();
        gState.PlayerAction.Target = targetIndex;
        gState.PlayerAction.Type = 'Ability';
        gState.PlayerAction.Resource = AshitaCore:GetResourceManager():GetAbilityById(actionId + 0x200);
        gState.PlayerAction.Completion = os.clock() + gSettings.AbilityDelay;
        gState.HandleEquipEvent('HandleAbility', 'auto');
    elseif (category == 0x10) then
        gState.PlayerAction = { Block = false };
        gState.PlayerAction.Packet = packet:totable();
        gState.PlayerAction.Target = targetIndex;
        gState.PlayerAction.Type = 'Ranged';
        local rangedBase = (gSettings.RangedBase * (100 - gSettings.Snapshot)) / 100;
        gState.PlayerAction.Completion = os.clock() + rangedBase + gSettings.RangedOffset;
        gState.HandleEquipEvent('HandlePreshot', 'set');
    else
        gState.Inject(0x1A, packet:totable());
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

packethandlers.HandleItemPacket = function(packet)
    local itemIndex = struct.unpack('B', packet, 0x0E + 0x01);
    local itemContainer = struct.unpack('B', packet, 0x10 + 0x01);
    local targetIndex = struct.unpack('H', packet, 0x0C + 0x01);
    local item = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(itemContainer, itemIndex);
    
    gState.PlayerAction = { Block = false };
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

packethandlers.HandleOutgoingChunk = function(e)
    --Clear expired actions.
    local time = os.clock();
    if (gState.PlayerAction ~= nil) and (gState.PlayerAction.Completion < time) then
        gState.PlayerAction = nil;
    end
    if (gState.PetAction ~= nil) and (gState.PetAction.Completion < time) then
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
            gPacketHandlers.HandleActionPacket(struct.unpack('c' .. size, e.chunk_data, offset + 1));
        elseif (id == 0x15) then
            newPositionX = struct.unpack('f', e.chunk_data, offset + 0x04 + 1);
            newPositionY = struct.unpack('f', e.chunk_data, offset + 0x0C + 1);
        elseif (id == 0x37) then
            gPacketHandlers.HandleItemPacket(struct.unpack('c' .. size, e.chunk_data, offset + 1));
        elseif (id == 0x100) then
            gPacketHandlers.HandleOutgoing0x100(struct.unpack('c' .. size, e.chunk_data, offset + 1));
        end
        offset = offset + size;
    end


    if (gState.PlayerAction == nil) then
        gState.HandleEquipEvent('HandleDefault', 'auto');
    end

    gState.PositionX = newPositionX;
    gState.PositionY = newPositionY;
end

packethandlers.HandleOutgoing0x100 = function(packet)
    local newJob = struct.unpack('B', packet, 0x04 + 1);
    if (newJob ~= 0) then
        gState.PlayerJob = newJob;
        gState.AutoLoadProfile();
    end
end

packethandlers.HandleIncomingPacket = function(e)
    if (e.id == 0x00A) then
        gPacketHandlers.HandleIncoming0x0A(e);
    elseif (e.id == 0x1B) then
        gPacketHandlers.HandleIncoming0x1B(e);
    elseif (e.id == 0x028) then
        gPacketHandlers.HandleIncoming0x28(e);
    end
end

packethandlers.HandleOutgoingPacket = function(e)
    --Handle packets that are being injected by anything else in real time.
    if (e.injected == true) then
        if (gState.Injecting == false) then
            if (e.id == 0x1A) then
                gPacketHandlers.HandleActionPacket(struct.unpack('c' .. e.size, e.data, 1));
                e.blocked = true;
            elseif (e.id == 0x37) then
                gPacketHandlers.HandleItemPacket(struct.unpack('c' .. e.size, e.data, 1));
                e.blocked = true;
            end
        end
        if (e.id == 0x100) then
            gPacketHandlers.HandleOutgoing0x100(struct.unpack('c' .. e.size, e.data, 1));
        end
        return;
    end

    --If we're in a new outgoing chunk, handle idle / action stuff.
    if (ffi.C.memcmp(e.data_raw, e.chunk_data_raw, e.size) == 0) then
        gPacketHandlers.HandleOutgoingChunk(e);
    end

    --Block all action and item packets that aren't injected.
    --HandleOutgoingChunk will automatically reinject them if keeping them.
    if (e.id == 0x1A) or (e.id == 0x37) then
        e.blocked = true;
        return;
    end
end


return packethandlers;