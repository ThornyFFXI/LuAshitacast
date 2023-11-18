--These settings aren't saved to disc at all because they aren't meant to persist.
local activeSettings = {
    AllowAddSet = false,
    Debug = false,
    SafeCall = true,
};

--These settings save to disc and persist across character, but can be changed in OnLoad by profile.
local defaultSettings = T{
    --Miscellaneous
    AddSetEquipScreenOrder = true,
    AllowSyncEquip = true,
    AddSetBackups = true,
    HorizonMode = false,

    --Inventory
    EquipBags = { 8, 10, 11, 12, 13, 14, 15, 16, 0 };
    EnableNomadStorage = false,
    ForceDisableBags = { },
    ForceEnableBags = { },

    --Timing
    PetskillDelay = 4.0,
    WeaponskillDelay = 3.0,
    AbilityDelay = 2.5,
    SpellOffset = 1.0,
    RangedBase = 10.0,
    RangedOffset = 0.5,
    ItemBase = 8,
    ItemOffset = 1.0,
    FastCast = 0,
    Snapshot = 0,
};

local settings = require('settings');
gActiveSettings = activeSettings;
gDefaultSettings = settings.load(defaultSettings);

settings.register('settings', 'settings_update', function(newSettings)
    gDefaultSettings = newSettings;
end);

local header = { 1.0, 0.75, 0.55, 1.0 };
local imgui = require('imgui');
local state = { IsOpen = { false }, ContainerMenu = nil };
local gui = {};

local containerNames = {
    'Inventory',
    'Safe',
    'Storage',
    'Temporary',
    'Locker',
    'Satchel',
    'Sack',
    'Case',
    'Wardrobe',
    'Safe2',
    'Wardrobe2',
    'Wardrobe3',
    'Wardrobe4',
    'Wardrobe5',
    'Wardrobe6',
    'Wardrobe7',
    'Wardrobe8',
    'Recycle'
};
local currentSettings;
local function DrawContainerMenu(menuState)
    if (menuState.IsOpen[1] == false) then
        state.ContainerMenu = nil;
        return;
    end
    imgui.SetNextWindowSize({ 335, 220, });
    imgui.SetNextWindowSizeConstraints({ 335, 220, }, { FLT_MAX, FLT_MAX, });
    if (imgui.Begin(menuState.WindowTitle, menuState.IsOpen, ImGuiWindowFlags_NoResize)) then
        imgui.BeginGroup();
        imgui.BeginChild('##LuAshitacastContainerLeftPane', { 100, 157 }, false, 128);
        for i = 1,6 do
            imgui.Checkbox(string.format('%s##LuAshitacastContainerCheck%s', containerNames[i], containerNames[i]), menuState.Current[i - 1]);
        end
        imgui.EndChild();
        imgui.EndGroup();
        imgui.SameLine();
        imgui.BeginGroup();
        imgui.BeginChild('##LuAshitacastContainerMiddlePane', { 100, 157 }, false, 128);
        for i = 7,12 do
            imgui.Checkbox(string.format('%s##LuAshitacastContainerCheck%s', containerNames[i], containerNames[i]), menuState.Current[i - 1]);
        end
        imgui.EndChild();
        imgui.EndGroup();
        imgui.SameLine();
        imgui.BeginGroup();
        imgui.BeginChild('##LuAshitacastContainerRightPane', { 100, 157 }, false, 128);
        for i = 13,18 do
            imgui.Checkbox(string.format('%s##LuAshitacastContainerCheck%s', containerNames[i], containerNames[i]), menuState.Current[i - 1]);
        end
        imgui.EndChild();
        imgui.EndGroup();
        if (imgui.Button('Cancel', { 106 })) then
            state.ContainerMenu = nil;
            return;
        end
        imgui.SameLine(imgui.GetWindowWidth() - 111);
        if (imgui.Button('Save', { 106 })) then
            for k,_ in pairs(menuState.Buffer) do
                menuState.Buffer[k] = nil;
            end
            for i = 0,17 do
                if (menuState.Current[i][1]) then
                    menuState.Buffer[#menuState.Buffer + 1] = i;
                end
            end
            settings.save();
            gState.ResetSettings(currentSettings);
            state.ContainerMenu = nil;
            return;
        end
        imgui.End();
    end
end

local function SliderFloat(setting, text, min, max, helpText)
    imgui.TextColored(header, text);
    if helpText then
        imgui.ShowHelp(helpText);
    end
    local buffer = { currentSettings[setting] };
    if (imgui.SliderFloat(string.format('##LuAshitacastConfigSlider%s', text), buffer, min, max, '%.1f', ImGuiSliderFlags_AlwaysClamp)) then
        gDefaultSettings[setting] = buffer[1];
        settings.save();
        gState.ResetSettings(currentSettings);
    end
end

local function SliderInt(setting, text, min, max, helpText)
    imgui.TextColored(header, text);
    if helpText then
        imgui.ShowHelp(helpText);
    end
    local buffer = { currentSettings[setting] };
    if (imgui.SliderInt(string.format('##LuAshitacastConfigSlider%s', text), buffer, min, max, '%d', ImGuiSliderFlags_AlwaysClamp)) then
        gDefaultSettings[setting] = buffer[1];
        settings.save();
        gState.ResetSettings(currentSettings);
    end
end

function gui:Render()
    currentSettings = gSettings;
    if (state.IsOpen[1]) and (currentSettings) then
        local buffer = {};
        if (imgui.Begin(string.format('%s v%s Configuration', addon.name, addon.version), state.IsOpen, ImGuiWindowFlags_AlwaysAutoResize)) then
            if imgui.BeginTabBar('##LuAshitacastConfigTabBar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) then
                if imgui.BeginTabItem('General##LuAshitacastConfigGeneralTab') then
                    imgui.TextColored(header, 'Sequencer');
                    if (AshitaCore:GetPluginManager():Get('Sequencer') ~= nil) then
                        imgui.TextColored({0, 1, 0, 1}, '  Active');
                        imgui.ShowHelp('Sequencer is a plugin that enables LuAshitacast to utilize the game\'s built in auto-resend function for actions.  You have it loaded, so no further action is needed.');
                    else
                        imgui.TextColored({1, 0, 0, 1}, '  Inactive');
                        imgui.ShowHelp('Sequencer is a plugin that enables LuAshitacast to utilize the game\'s built in auto-resend function for actions.  It is recommended you load it for best performance.');
                    end

                    imgui.TextColored(header, 'PacketFlow');
                    if (AshitaCore:GetPluginManager():Get('PacketFlow') ~= nil) then
                        imgui.TextColored({0, 1, 0, 1}, '  Active');
                        imgui.ShowHelp('PacketFlow is a plugin that reduces the delay between outgoing packets when latency permits.  This increases performance.  You have it loaded, so no further action is needed.');
                    else
                        imgui.TextColored({1, 1, 0, 1}, '  Inactive');
                        imgui.ShowHelp('PacketFlow is a plugin that reduces the delay between outgoing packets when latency permits.  This increases performance, but could put you at risk on retail servers.  Load at your own risk.');
                    end
                    
                    imgui.TextColored(header, 'Profile');
                    if (gProfile ~= nil) then
                        imgui.TextColored({0, 1, 0, 1}, '  ' .. gProfile.FilePath);
                        if (imgui.Button('Launch Editor')) then
                            ashita.misc.execute(gProfile.FilePath, '');
                        end
                        imgui.SameLine();
                        if (imgui.Button('Reload')) then
                            gState.LoadProfileEx(gProfile.FilePath);
                        end
                        imgui.SameLine();
                        if (imgui.Button('Unload')) then
                            gState.UnloadProfile();
                            print(chat.header('LuAshitacast') .. chat.message('Profile unloaded.'));
                        end
                        imgui.SameLine();
                    else
                        imgui.TextColored({1, 0, 0, 1}, '  Not loaded.');
                    end
                    if (imgui.Button('Load Default')) then
                        gState.AutoLoadProfile();
                    end
                    
                    imgui.TextColored(header, 'Debug Functions');
                    buffer[1] = currentSettings.Debug;
                    if (imgui.Checkbox('Equipment Debug##LuAshitacastConfigEquipmentDebug', buffer)) then
                        currentSettings.Debug = buffer[1];
                    end
                    imgui.ShowHelp('When enabled, equipment swaps and action states will be printed to chat log.');
                    
                    buffer[1] = currentSettings.SafeCall;
                    if (imgui.Checkbox('Safe Call##LuAshitacastConfigSafeCall', buffer)) then
                        currentSettings.SafeCall = buffer[1];
                    end
                    imgui.ShowHelp('When enabled, calls to Handle functions will use pcall.  Disabling this can provide a more explicit error message for debugging, but will allow the addon to fully crash.');

                    imgui.TextColored(header, 'Misc. Settings');
                    buffer[1] = currentSettings.AddSetEquipScreenOrder;
                    if (imgui.Checkbox('AddSet Equip Screen Order##LuAshitacastConfigAddSetEquipScreenOrder', buffer)) then
                        gDefaultSettings.AddSetEquipScreenOrder = buffer[1];
                        settings.save();
                        gState.ResetSettings(currentSettings);
                    end
                    imgui.ShowHelp('When enabled, sets will be written in the order equip screen shows slots, rather than the internal item index order.');

                    buffer[1] = currentSettings.AllowSyncEquip;
                    if (imgui.Checkbox('Allow Sync Equip##LuAshitacastConfigAllowSyncEquip', buffer)) then
                        gDefaultSettings.AllowSyncEquip = buffer[1];
                        settings.save();
                        gState.ResetSettings(currentSettings);
                    end
                    imgui.ShowHelp('When enabled, LuAshitacast will try to equip items higher than your current sync level if your real job level is high enough to wear them.');

                    buffer[1] = currentSettings.AddSetBackups;
                    if (imgui.Checkbox('AddSet Backups##LuAshitacastConfigAddSetBackups', buffer)) then
                        gDefaultSettings.AddSetBackups = buffer[1];
                        settings.save();
                        gState.ResetSettings(currentSettings);
                    end
                    imgui.ShowHelp('When enabled, LuAshitacast will make backups of your profiles prior to writing them for AddSet commands.');

                    buffer[1] = currentSettings.HorizonMode;
                    if (imgui.Checkbox('Horizon Mode##LuAshitacastHorizonMode', buffer)) then
                        gDefaultSettings.HorizonMode = buffer[1];
                        settings.save();
                        gState.ResetSettings(currentSettings);
                    end
                    imgui.ShowHelp('When Horizon Mode is enabled, LuAshitacast will only parse HandleDefault once after any given action.');
                    imgui.EndTabItem();
                end
            
                if imgui.BeginTabItem('Inventory##LuAshitacastConfigInventoryTab') then
                    if (imgui.Button('EquipBags##LuAshitacastConfigEquipBags')) then
                        local newState = {};
                        newState.Buffer = T(gDefaultSettings.EquipBags);
                        newState.Current = {};
                        for i = 0,17 do
                            newState.Current[i] = { newState.Buffer:contains(i) };
                        end
                        newState.IsOpen = { true };
                        newState.WindowTitle = 'Equip Bags';
                        state.ContainerMenu = newState;
                    end
                    imgui.ShowHelp('Edit the list of containers that will be checked for equipment.');
                    if (imgui.Button('ForceDisableBags##LuAshitacastConfigForceDisableBags')) then
                        local newState = {};
                        newState.Buffer = T(gDefaultSettings.ForceDisableBags);
                        newState.Current = {};
                        for i = 0,17 do
                            newState.Current[i] = { newState.Buffer:contains(i) };
                        end
                        newState.IsOpen = { true };
                        newState.WindowTitle = 'Force Disabled Bags';
                        state.ContainerMenu = newState;
                    end
                    imgui.ShowHelp('Edit the list of containers that will always be treated as disabled.');
                    if (imgui.Button('ForceEnableBags##LuAshitacastConfigForceEnableBags')) then
                        local newState = {};
                        newState.Buffer = T(gDefaultSettings.ForceEnableBags);
                        newState.Current = {};
                        for i = 0,17 do
                            newState.Current[i] = { newState.Buffer:contains(i) };
                        end
                        newState.IsOpen = { true };
                        newState.WindowTitle = 'Force Enabled Bags';
                        state.ContainerMenu = newState;
                    end
                    imgui.ShowHelp('Edit the list of containers that will always be treated as enabled.');
                    buffer = { currentSettings.EnableNomadStorage };
                    if (imgui.Checkbox('Nomad Storage', buffer)) then
                        gDefaultSettings.EnableNomadStorage = buffer[1];
                        settings.save();
                        gState.ResetSettings(currentSettings);
                    end
                    imgui.ShowHelp('Flag storage as accessible at nomad moogles.');
                    imgui.TextColored(header, 'Description');
                    imgui.TextWrapped('Most of these settings are likely to remain unused.  They exist to solve future edge cases where private servers allow for equipping from bags other than those allowed in retail.');
                    imgui.EndTabItem();
                end
                
                if imgui.BeginTabItem('Timeouts##LuAshitacastConfigTimeoutsTab') then
                    SliderFloat('PetskillDelay', 'Pet Skill Delay', 0, 8, 'Maximum time allowed for a pet\'s weaponskill to finish.');
                    SliderFloat('WeaponskillDelay', 'Weaponskill Delay', 0, 8, 'Maximum time allowed for a player\'s weaponskill to finish.');
                    SliderFloat('AbilityDelay', 'Ability Delay', 0, 5, 'Maximum time allowed for a job ability to finish.');
                    SliderFloat('SpellOffset', 'Spell Offset', 0, 15, 'Amount of extra time allotted for a spell to finish, after calculated casttime.');
                    SliderFloat('RangedBase', 'Ranged Base', 0, 20, 'Base duration for a ranged attack, effected by snapshot if set.');
                    SliderFloat('RangedOffset', 'Ranged Offset', 0, 5, 'Amount of extra time allotted for a ranged attack to finish, after calculated delay.');
                    SliderFloat('ItemBase', 'Item Base', 0, 10, 'Base amount of time for an item to be used, if dats do not specify.');
                    SliderFloat('ItemOffset', 'Item Offset', 0, 5, 'Amount of extra time allotted for an item to finish, after calculated time.');
                    SliderInt('FastCast', 'Fast Cast', 0, 99, 'Amount of fast cast to be used when calculating spell casttimes.');
                    SliderInt('Snapshot', 'Snapshot', 0, 99, 'Amount of snapshot to be used when calculating ranged attack execution times.');
                    imgui.TextColored(header, 'Note');
                    imgui.TextWrapped('These settings are used to calculate timeouts, which only apply if an action completion packet is not received.  They should be fine in most cases, servers with inaccurate dats may want to increase spell offset to compensate.');
                    imgui.EndTabItem();
                end

                imgui.EndTabBar();
            end
        end
    end
    if (state.IsOpen[1] ~= true) then
        state.ContainerMenu = nil;
    end
    if (state.ContainerMenu ~= nil) then
        DrawContainerMenu(state.ContainerMenu);
    end
end

function gui:Show()
    state.IsOpen = { true };
end

return gui;