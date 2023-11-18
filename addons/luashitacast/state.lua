local state = {
    ActionDelay = 0,
    CurrentCall = 'N/A',
    DelayedEquip = {},
    ForceSet = nil,
    ForceSetTimer = 0,
    Injecting = false,
    PetAction = nil,
    PlayerAction = nil,
    PlayerId = 0,
    PlayerJob = 0,
    PlayerName = '',
    pWardrobe = 0,
    pZoneFlags = 0,
    pZoneOffset = 0
};

state.Init = function()
    gState.pVanaTime = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0, 0);
    gState.pWardrobe = ashita.memory.find('FFXiMain.dll', 0, 'A1????????8B88B4000000C1E907F6C101E9', 1, 0);
    gState.pWeather = ashita.memory.find('FFXiMain.dll', 0, '66A1????????663D????72', 0, 0);
    gState.pZoneFlags = ashita.memory.find('FFXiMain.dll', 0, '8B8C24040100008B90????????0BD18990????????8B15????????8B82', 0, 0);

    if (gState.pVanaTime == 0) then
        print(chat.header('LuAshitacast') .. chat.error('Vanatime signature scan failed.'));
    end

    if (gState.pWardrobe == 0) then
        print(chat.header('LuAshitacast') .. chat.error('Wardrobe access signature scan failed.'));
    end

    if (gState.pWeather == 0) then
        print(chat.header('LuAshitacast') .. chat.error('Weather signature scan failed.'));
    end

    if (gState.pZoneFlags == 0) then
        print(chat.header('LuAshitacast') .. chat.error('Zone flag signature scan failed.'));
    else
        gState.pZoneOffset = ashita.memory.read_uint32(gState.pZoneFlags, 0x09);
        if (gState.pZoneOffset == 0) then
            gState.pZoneFlags = 0;
            print(chat.header('LuAshitacast') .. chat.error('Zone flag offset not found.'));
        else
            gState.pZoneFlags = ashita.memory.read_uint32(gState.pZoneFlags, 0x17);
            if (gState.pZoneFlags == 0) then
                print(chat.header('LuAshitacast') .. chat.error('Zone flag sub pointer not found.'));
            end
        end
    end

    state.Disabled = {};
    state.Encumbrance = {};
    for i = 1,16,1 do
        state.Disabled[i] = false;
        state.Encumbrance[i] = false;
    end
    
    local configPath = string.format('%sconfig\\addons\\luashitacast\\?.lua;', AshitaCore:GetInstallPath());
    package.path = configPath .. package.path;
    gState.BasePath = package.path;
    
    if (AshitaCore:GetMemoryManager():GetParty():GetMemberIsActive(0) == 1) then
        gState.PlayerId = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
        gState.PlayerName = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0);
        gState.PlayerJob = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
        configPath = string.format('%sconfig\\addons\\luashitacast\\%s_%u\\?.lua;', AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId);
        package.path = configPath .. gState.BasePath;
        gState.AutoLoadProfile();
    end
end

state.ResetSettings = function(currentSettings)
    gSettings = {};
    for k,v in pairs(gDefaultSettings) do
        if (type(v) == 'table') then
            gSettings[k] = {};
            for subK,subV in pairs(v) do
                gSettings[k][subK] = subV;
            end
        else
            gSettings[k] = v;
        end
    end
    for k,v in pairs(gActiveSettings) do
        if (type(currentSettings) == 'table') and (currentSettings[k] ~= nil) then
            gSettings[k] = currentSettings[k];
        else
            gSettings[k] = v;
        end
    end
end

state.LoadProfile = function(profilePath)
    local shortFileName = profilePath:match("[^\\]*.$");
    local success, loadError = loadfile(profilePath);
    if not success then
        gProfile = nil;
        print(chat.header('LuAshitacast') .. chat.error('Failed to load profile: ') .. chat.color1(2, shortFileName));
        print(chat.header('LuAshitacast') .. chat.error(loadError));
        return;
	end
	gProfile = success();
	if (gProfile ~= nil) then
        state.ResetSettings();
        print(chat.header('LuAshitacast') .. chat.message('Loaded profile: ') .. chat.color1(2, shortFileName));
        if (gProfile.OnLoad ~= nil) and (type(gProfile.OnLoad) == 'function') then
            gProfile.FilePath = profilePath;
            gProfile.FileName = shortFileName;
            gState.SafeCall('OnLoad');
            gSetDisplay:Reload();
        end
    end
end

state.AutoLoadProfile = function()
    gState.UnloadProfile();
    
    local jobString = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", gState.PlayerJob);
    if type(jobString) == 'string'then
        jobString = jobString:trimend('\x00');
    end
    local profilePath = ('%sconfig\\addons\\luashitacast\\%s_%u\\%s.lua'):fmt(AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId, jobString);
    if (not ashita.fs.exists(profilePath)) then
        profilePath = ('%sconfig\\addons\\luashitacast\\%s_%s.lua'):fmt(AshitaCore:GetInstallPath(), gState.PlayerName, jobString);
        if (not ashita.fs.exists(profilePath)) then
            print(chat.header('LuAshitacast') .. chat.error('Profile not found matching: ') .. chat.color1(2, gState.PlayerName .. '_' .. jobString));
            return;
        end
    end
    gState.LoadProfile(profilePath);
end

state.LoadProfileEx = function(path)
    gState.UnloadProfile();
    
    local profilePath = path;
    if (not ashita.fs.exists(profilePath)) then
        profilePath = path .. '.lua';
        if (not ashita.fs.exists(profilePath)) then
            profilePath = ('%sconfig\\addons\\luashitacast\\%s_%u\\%s'):fmt(AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId, path);
            if (not ashita.fs.exists(profilePath)) then
                profilePath = ('%sconfig\\addons\\luashitacast\\%s_%u\\%s.lua'):fmt(AshitaCore:GetInstallPath(), gState.PlayerName, gState.PlayerId, path);
                if (not ashita.fs.exists(profilePath)) then
                    profilePath = ('%sconfig\\addons\\luashitacast\\%s'):fmt(AshitaCore:GetInstallPath(), path);
                    if (not ashita.fs.exists(profilePath)) then
                        profilePath = ('%sconfig\\addons\\luashitacast\\%s.lua'):fmt(AshitaCore:GetInstallPath(), path);
                        if (not ashita.fs.exists(profilePath)) then
                            print(chat.header('LuAshitacast') .. chat.error('Profile not found matching: ') .. chat.color1(2, path));
                            return;
                        end
                    end
                end
            end
        end
    end

    gState.LoadProfile(profilePath);
end

state.UnloadProfile = function()
    if (gProfile ~= nil) then
        gSetDisplay:Hide();
        gState.SafeCall('OnUnload');
        coroutine.sleep(0.5);
    end
    gState.Reset();
end

local defaultParsed = false;
state.HandleEquipEvent = function(eventName, equipStyle)
    if (gProfile ~= nil) then
        if (eventName == 'HandleDefault') then
            if (gSettings.HorizonMode) and (defaultParsed) then
                return;
            end
        end

        local event = gProfile[eventName];
        if (event ~= nil) and (type(event) == 'function') then
            gEquip.ClearBuffer();
            gState.CurrentCall = eventName;
            gState.SafeCall(eventName);
            if (eventName == 'HandleDefault') then
                gEquip.ProcessBuffer(equipStyle);
                defaultParsed = true;
            elseif (gState.PlayerAction ~= nil) and (gState.PlayerAction.Block ~= true) then
                if (gState.DelayedEquip.Timer ~= nil) and ((eventName == 'HandleMidcast') or (eventName == 'HandleMidshot')) then
                    gState.DelayedEquip.Tag = eventName .. 'Delayed';
                    gEquip.ProcessImmediateBuffer(equipStyle);
                else
                    gEquip.ProcessBuffer(equipStyle);
                end
            end
            gState.CurrentCall = 'N/A';
        end
    end
end

state.Inject = function(id, data)
    gState.Injecting = true;
    AshitaCore:GetPacketManager():AddOutgoingPacket(id, data);
    gState.Injecting = false;
end

state.Reset = function()
    gProfile = nil;
    state.Disabled = {};
    state.Encumbrance = {};
    for i = 1,16,1 do
        state.Disabled[i] = false;
        state.Encumbrance[i] = false;
    end
    state.LockStyle = nil;
    state.DelayedEquip = {};
    gState.ForceSet = nil;
    
    --Iterate global table to look for any leftover globals that didn't exist before profile was loaded.
    local newGlobs = T{};
    for key,_ in pairs(_G) do
        if gPreservedGlobalKeys[key] == nil then
            newGlobs:append(key);
        end
    end

    --Get rid of all new globals..
    for _,glob in ipairs(newGlobs) do
        _G[glob] = nil;
    end

    state.ResetSettings();
end

state.SafeCall = function(name,...)
    if (gProfile ~= nil) then
        if (type(gProfile[name]) == 'function') then
            if (gSettings.SafeCall) then
                local success,err = pcall(gProfile[name],...);
                if (not success) then
                    print(chat.header('LuAshitacast') .. chat.error('Error in profile function: ') .. chat.color1(2, name));
                    print(chat.header('LuAshitacast') .. chat.error(err));
                end
            else
                gProfile[name](...);
            end
            defaultParsed = false;
        elseif (gProfile[name] ~= nil) then
            print(chat.header('LuAshitacast') .. chat.error('Profile member exists but is not a function: ') .. chat.color1(2, name));
        end
    end
end

return state;