local ffi = require('ffi');
ffi.cdef[[
    typedef struct lacItemOrder_t {
        uint8_t Name[32];
        int32_t Quantity;
        int32_t AugPath;
        int32_t AugRank;
        int32_t AugTrial;
        int32_t AugCount;
        uint8_t AugString[5][100];
    } lacItemOrder_t;
]];
ffi.cdef[[
    typedef struct lacPackerEvent_t {
        int32_t EntryCount;
        lacItemOrder_t Entries[400];
    } lacPackerEvent_t;
]]

ashita.events.register('plugin_event', 'plugin_event_cb', function (e)
    if gSettings.RemoveEquipmentForPacker then
        if (e.name == 'LAC_GEAR_FAILED') or (e.name == 'LAC_GEAR_SUCCEEDED') or (e.name == 'LAC_GEAR_INTERRUPTED') then
            for i = 1,16,1 do
                gState.Disabled[i] = false;
            end
        end
    end
end);

local compareFields = { 'Name', 'AugPath', 'AugRank', 'AugTrial', 'AugCount' };
--Checks if 2 fetch orders are equal.
local function CheckOrdersEqual(lhs, rhs)
    for _,field in ipairs(compareFields) do
        if lhs[field] ~= rhs[field] then
            return false;
        end
    end

    local count = lhs.AugCount;
    if (count == 0) then
        return true;
    end

    for i = 1,count do
        if (lhs.AugStrings[i] ~= rhs.AugStrings[i]) then
            return false;
        end
    end

    return true;
end

--This is used to combine a new order with an existing order.  Quantities will be added together.
--This should be repeated on the same array within a set to ensure that multiples of the same item in the same set are counted appropriately.
local function CombineItems(baseTable, order)
    for _,v in pairs(baseTable) do
        if CheckOrdersEqual(order, v) then
            if ((order.Quantity == -1) or (v.Quantity == -1)) then
                v.Quantity = -1;
            else
                v.Quantity = order.Quantity + v.Quantity;
            end
            return;
        end
    end

    baseTable:append(order);
end

--This is used to add an array of item orders into another array of item orders.
--Unlike combine, this will take the larger count, so that we take the highest requirement of any set.
local function IntegrateItems(baseTable, orders)
    for _,order in ipairs(orders) do
        local addNewOrder = true;
        for _,v in pairs(baseTable) do
            if CheckOrdersEqual(order, v) then
                if ((order.Quantity == -1) or (v.Quantity == -1)) then
                    v.Quantity = -1;
                elseif (order.Quantity > v.Quantity) then
                    v.Quantity = order.Quantity;
                end
                addNewOrder = false;
            end
        end
        if addNewOrder then
            baseTable:append(order);
        end
    end
end

local keyWords = T{ 'displaced', 'remove', 'ignore' };
--Formats item into an intermediary lua format
local function CreateOrder(item)
    if type(item) == 'string' then
        if keyWords:contains(string.lower(item)) then
            return nil;
        end
        return {
            Name = string.lower(item),
            Quantity = 1,
            AugPath = -1,
            AugRank = -1,
            AugTrial = -1,
            AugCount = 0,
            AugStrings = {}
        };
    end
    
    if (type(item) ~= 'table') then
        return nil;
    end
    
    if (item.Name == nil) or keyWords:contains(string.lower(item.Name)) then
        return nil;
    end

    local order = {};
    order.Name = string.lower(item.Name);

    local quantity = item.Quantity;
    if (type(quantity) == 'string') and (quantity == 'all') then
        order.Quantity = -1;
    elseif (type(quantity) == 'number') then
        order.Quantity = math.floor(quantity);
    else
        order.Quantity = 1;
    end

    local path = item.AugPath;
    if type(path) == 'string' then
        path = string.lower(item.AugPath);
        if (path == 'a') then
            order.AugPath = 1;
        elseif (path == 'b') then
            order.AugPath = 2;
        elseif (path == 'c') then
            order.AugPath = 3;
        elseif (path == 'd') then
            order.AugPath = 4;
        else
            order.AugPath = -1;
        end
    else
        order.AugPath = -1;
    end

    local rank = item.AugRank;
    if (type(rank) == 'number') then
        order.AugRank = rank;
    else
        order.AugRank = -1;
    end

    local trial = item.AugTrial;
    if (type(trial) == 'number') then
        order.AugTrial = trial;
    else
        order.AugTrial = -1;
    end

    local augment = item.Augment;
    if (type(augment) == 'table') then
        order.AugCount = #augment;
        order.AugStrings = {};
        for k,v in ipairs(augment) do
            order.AugStrings[k] = string.gsub(v, '\"', '\'');
        end
    elseif (type(augment) == 'string') then
        order.AugCount = 1;
        order.AugStrings = { [1] = string.gsub(augment, '\"', '\'') };
    else
        order.AugCount = 0;
        order.AugStrings = {};
    end

    return order;
end

local function AddToStructure(structure, order)
    local index = structure.EntryCount;
    structure.Entries[index].Name = order.Name;
    structure.Entries[index].Quantity = order.Quantity;
    structure.Entries[index].AugPath = order.AugPath;
    structure.Entries[index].AugRank = order.AugRank;
    structure.Entries[index].AugTrial = order.AugTrial;
    structure.Entries[index].AugCount = order.AugCount;
    for i = 1,order.AugCount do
        structure.Entries[index].AugString[i - 1] = order.AugStrings[i];
    end
    structure.EntryCount = index + 1;
end

local function CreateOrderStruct()
    local allOrders = T{};
    if type(gProfile.Sets) == 'table' then
        for _,set in pairs(gProfile.Sets) do
            local setOrders = T{};
            for __,equip in pairs(set) do
                local order = CreateOrder(equip);
                if order then
                    CombineItems(setOrders, order);
                end
            end
            IntegrateItems(allOrders, setOrders);
        end
    end

    if type(gProfile.Packer) == 'table' then
        for _,item in pairs(gProfile.Packer) do
            local order = CreateOrder(item);
            if order then
                IntegrateItems(allOrders, T{order});
            end
        end
    end

    local structure = ffi.new('lacPackerEvent_t');    
    for _,v in ipairs(allOrders) do
        AddToStructure(structure, v);
    end
    return ffi.string(structure, ffi.sizeof(structure)):totable();
end

local function TriggerEvent(eventName, eventStructure)
    AshitaCore:GetPluginManager():RaiseEvent(eventName, eventStructure);
end

local function Gear()
    if not AshitaCore:GetPluginManager():IsLoaded('Packer') then
        gFunc.Error('Could not perform gear.  Packer is not loaded.');
        return;
    end

    if gProfile == nil then
        gFunc.Error('Could not perform gear.  No profile loaded.');
        return;
    end

    local eventStruct = CreateOrderStruct();

    if gSettings.RemoveEquipmentForPacker then
        for i = 1,16,1 do
            gEquip.UnequipSlot(i);
            gState.Disabled[i] = true;
        end

        gFunc.Message('Equipment removed.  Waiting 2 seconds to contact Packer.');
        ashita.tasks.once(2, TriggerEvent:bindn('packer_lac_gear', eventStruct));
        return;
    else
        TriggerEvent('packer_lac_gear', eventStruct);        
    end
end

local function Validate()
    if not AshitaCore:GetPluginManager():IsLoaded('Packer') then
        gFunc.Error('Could not perform gear.  Packer is not loaded.');
        return;
    end

    if gProfile == nil then
        gFunc.Error('Could not perform gear.  No profile loaded.');
        return;
    end

    local eventStruct = CreateOrderStruct();
    TriggerEvent('packer_lac_validate', eventStruct);
end

local exports = {
    Gear = Gear,
    Validate = Validate
};

return exports;