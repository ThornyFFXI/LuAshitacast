local gui = {
    IsOpen = { false },
};
local imgui = require('imgui');

function gui:Hide()
    self.IsOpen[1] = false;
end

function gui:Initialize()
    --Create lists of sets and flag gui as active.
    if (gProfile == nil) then
        gFunc.Error('Profile does not exist.  Could not initialize set viewer.');
        return;
    end

    local sets = gProfile.Sets;
    if (sets == nil) then
        gFunc.Error('Profile.Sets does not exist.  Could not initialize set viewer.');
        return;
    end

    self.Sets = T{};
    for name,set in pairs(sets) do
        local newSet = T{
            Name = name,
            Equipment = T{}
        };
        for slot,item in pairs(set) do
            local equipSlot = gData.GetEquipSlot(slot);
            if (equipSlot ~= 0) then
                local equip = T { EquipmentSlot=equipSlot };
                if type(item) == 'string' then
                    equip.Name = item;
                elseif (type(item) == 'table') and (type(item.Name) == 'string') then
                    equip.Name = item.Name;
                end
                if (equip.Name ~= nil) then
                    newSet.Equipment:append(equip);
                end
            end
        end
        if (#newSet.Equipment > 0) then
            table.sort(newSet.Equipment, function(a,b) return (a.EquipmentSlot < b.EquipmentSlot) end);
            self.Sets:append(newSet);
        end
    end
    if (#self.Sets == 0) then
        gFunc.Error('Profile.Sets does not contain any valid sets.  Could not initialize set viewer.');
        return;
    end

    table.sort(self.Sets, function(a,b) return (a.Name < b.Name) end);
    self.SelectedIndex = 1;
    self.SelectedSet = self.Sets[1];
    self.IsOpen[1] = true;
end

function gui:ListSet(setName)
    if (gProfile == nil) then
        gFunc.Error('Profile does not exist.  Could not list set.');
        return;
    end

    local sets = gProfile.Sets;
    if (sets == nil) then
        gFunc.Error('Profile.Sets does not exist.  Could not list set.');
        return;
    end

    local compare = string.lower(setName);
    for name,set in pairs(sets) do
        if (string.lower(name) == compare) then
            local equipment = T{};
            for slot,item in pairs(set) do
                local equipSlot = gData.GetEquipSlot(slot);
                if (equipSlot ~= 0) then
                    local equip = T { EquipmentSlot=equipSlot };
                    if type(item) == 'string' then
                        equip.Name = item;
                    elseif (type(item) == 'table') and (type(item.Name) == 'string') then
                        equip.Name = item.Name;
                    end
                    if (equip.Name ~= nil) then
                        equipment:append(equip);
                    end
                end
            end

            gFunc.Message('Set: ' .. name);
            if (#equipment == 0) then
                gFunc.Message('Set is empty.');
            else
                table.sort(equipment, function(a,b) return (a.EquipmentSlot < b.EquipmentSlot) end);
                for _,slot in ipairs(equipment) do
                    local outString = string.format('%s: %s', gData.Constants.EquipSlotNames[slot.EquipmentSlot], slot.Name);
                    gFunc.Message(outString);
                end
                return;
            end
        end
    end

    gFunc.Error('Could not find set named: ' .. setName);
end

function gui:ListSets()
    if (gProfile == nil) then
        gFunc.Error('Profile does not exist.  Could not list sets.');
        return;
    end

    local sets = gProfile.Sets;
    if (sets == nil) then
        gFunc.Error('Profile.Sets does not exist.  Could not list sets.');
        return;
    end

    local foundSets = T{};
    for name,set in pairs(sets) do
        local foundEquip = false;
        for slot,item in pairs(set) do
            local equipSlot = gData.GetEquipSlot(slot);
            if (equipSlot ~= 0) then
                local equip = T { EquipmentSlot=equipSlot };
                if type(item) == 'string' then
                    foundEquip = true;
                    break;
                elseif (type(item) == 'table') and (type(item.Name) == 'string') then
                    foundEquip = true;
                    break;
                end
            end
        end

        if foundEquip then
            foundSets:append(name);
        end
    end

    if (#foundSets == 0) then
        gFunc.Error('No sets found.');
        return;
    end
    
    table.sort(foundSets, function(a,b) return (a < b) end);
    gFunc.Message(string.format('Found %d sets.', #foundSets));
    for _,setName in ipairs(foundSets) do
        gFunc.Message(setName);
    end
end

function gui:Render()
    if (self.IsOpen[1] == false) then
        return;
    end

    if (imgui.Begin(string.format('%s v%s Set Viewer', addon.name, addon.version), self.IsOpen, ImGuiWindowFlags_AlwaysAutoResize)) then
        if (imgui.BeginCombo('##LuashitacastSetViewerSelectSet', self.SelectedSet.Name, ImGuiComboFlags_None)) then
            for index,set in ipairs(self.Sets) do
                local isSelected = (index == self.SelectedIndex);
                if (imgui.Selectable(set.Name, isSelected)) then
                    if (not isSelected) then
                        self.SelectedIndex = index;
                        self.SelectedSet = set;
                    end
                end
            end
            imgui.EndCombo();
        end
    end

    for _,slot in ipairs(self.SelectedSet.Equipment) do
        local outString = string.format('%s: %s', gData.Constants.EquipSlotNames[slot.EquipmentSlot], slot.Name);
        imgui.Text(outString);
    end

    imgui.End();
    if (self.IsOpen[1] == false) then
        self.SelectedSet = nil;
    end
end

function gui:Reload()
    if (type(self.SelectedSet) == 'table') then
        local activeSet = self.SelectedSet.Name;
        self:Initialize();
        
        for index,set in ipairs(self.Sets) do
            if (set.Name == activeSet) then
                self.SelectedIndex = index;
                self.SelectedSet = set;
                break;
            end
        end
    end
end

return gui;